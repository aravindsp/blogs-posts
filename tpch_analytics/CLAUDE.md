# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Companion dbt project for the blog series "Build a modern data pipeline with Snowflake, dbt and Airflow" (bigdatadwbi.com). Code is meant to be read alongside the posts. `README.md` maps each folder to a series part, so keep that table in sync when you add or move files.

Tested with these pinned versions: dbt-core 1.12.5, dbt-snowflake 1.12.1, dbt-duckdb 1.11.0, Airflow 3.1.8, astronomer-cosmos 1.15.1. Everything has been run end to end on DuckDB. The Snowflake SQL in `snowflake/` has never been run against a real account.

## Commands

Run all commands from this directory. dbt picks its profile from `DBT_PROFILES_DIR`: use `local` for DuckDB and `ci` for Snowflake.

Local (no Snowflake):

    pip install tpchgen-cli dbt-duckdb
    python local/make_raw_duckdb.py          # builds raw.duckdb (TPC-H SF 0.05, orders before 1998-07-01)
    DBT_PROFILES_DIR=local dbt deps
    DBT_PROFILES_DIR=local dbt build         # models + snapshot + tests

Single model / test:

    DBT_PROFILES_DIR=local dbt build --select fct_orders
    DBT_PROFILES_DIR=local dbt test --select assert_order_total_matches_line_items
    DBT_PROFILES_DIR=local dbt build --select stg_tpch__orders+   # model and everything downstream
    DBT_PROFILES_DIR=local dbt build --full-refresh --select fct_order_items

Source freshness: `dbt source freshness`. Run summary: `python scripts/dbt_run_report.py [target/run_results.json]`. It exits 1 if any node errored or failed.

Snowflake: run `snowflake/01_setup.sql`, `02_load_raw.sql`, `airflow/dags/sql/load_raw_orders.sql` in that order. Then `pip install -r requirements.txt`, `export DBT_PROFILES_DIR=ci SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=...`, `dbt deps && dbt build`.

## Architecture

**Data flow:** files land in the Snowflake stage `RAW.TPCH.LANDING`. `COPY INTO` loads them into `RAW.TPCH.ORDERS`/`LINEITEM` and adds the audit columns `_loaded_at` and `_source_file`. dbt then builds the layers into the `ANALYTICS` database:
- `staging/` (views): one `stg_tpch__*` per source table, rename and decode only.
- `intermediate/` (views): `int_order_items__enriched` joins line items to orders and computes all money columns (gross, discount, net, tax, total).
- `marts/` (tables): `fct_order_items` is **incremental** and filters on `_loaded_at > max(_loaded_at)`. It uses the `merge` strategy on Snowflake and `delete+insert` elsewhere. `fct_orders` aggregates it. The finance aggregate is built on `fct_orders` + `dim_customers`.
- `snapshots/snap_customers`: SCD2 with the `check` strategy on the segment, balance and address columns.

`_loaded_at` must flow from the raw tables through staging and intermediate into `fct_order_items`. The incremental filter and source freshness checks both depend on it.

**Schema naming** (`macros/generate_schema_name.sql`): on the `prod` target, models go to bare folder schemas (`STAGING`, `MARTS`). On every other target they go to `<target.schema>_<folder>`, e.g. `DBT_ARAVIND_MARTS` or `CI_PR_42_MARTS`. `drop_ci_schemas` relies on that prefix: it drops every schema that starts with `target.schema` and refuses to run on any target other than `ci`.

**Targets** (`ci/profiles.yml`):
- `dev`: browser SSO, schema `DBT_<USER>`.
- `ci`: key-pair auth, schema from `DBT_CI_SCHEMA`.
- `prod`: key-pair auth, schema `PROD`. CI only uses it to parse main's manifest.

`local/profiles.yml` mirrors these targets for DuckDB. Its `ci` target attaches `analytics.duckdb` read-only so it can test `--defer`.

**Slim CI** (`../.github/workflows/dbt_ci.yml`, at the repo root):
1. On a PR, check out `main` and run `dbt parse --target prod` to get a manifest.
2. Run `dbt build --target ci --select state:modified+ --defer --state prod-state`.
3. Always run `drop_ci_schemas` at the end.

The workflow sits at the root of the `blogs-posts` repo because GitHub only runs workflows from there. Its steps default to `working-directory: tpch_analytics`, and its path filters are prefixed with `tpch_analytics/`. If you move or rename this folder, update the workflow too.

**Airflow** (`airflow/dags/tpch_daily.py`) runs daily at 02:00 UTC. It runs `sql/load_raw_orders.sql`, which is idempotent because COPY INTO tracks files it has loaded. It then runs a Cosmos `DbtTaskGroup` on the `prod` target. That task group renders from `target/manifest.json` (`LoadMode.DBT_MANIFEST`), so you need a fresh `dbt parse` after model changes. Tests run after each model, and source freshness checks appear as tasks. `DBT_PROJECT_DIR` and `DBT_EXECUTABLE` are read from env vars. Airflow 3.1 needs `sqlalchemy<2.1`.

## Conventions

- Models are written in CTE style (`with source as (...), renamed as (...) select * from renamed`), with lowercase SQL and descriptive snake_case columns (`order_key`, `customer_key`).
- Model-specific SQL must work on both Snowflake and DuckDB. Branch on `target.type` when the two differ, as `fct_order_items` does.
- Tests and docs live in `_<folder>__models.yml` / `_tpch__sources.yml`. Singular tests go in `tests/`. dbt-utils 1.3.0 is available.
- `+query_tag: dbt_tpch_analytics` is what `snowflake/04_monitoring.sql` filters on, so don't remove it.
