# tpch_analytics

Companion project for the series **"Build a modern data pipeline with Snowflake, dbt and Airflow"**
on [bigdatadwbi.com](https://www.bigdatadwbi.com).

| Folder | What it is | Series part |
|---|---|---|
| `snowflake/` | Setup, loading, next-batch and monitoring SQL | 2, 3, 7, 10 |
| `models/` | dbt staging, intermediate and mart models | 4, 5 |
| `tests/`, `*.yml` | dbt data tests | 6 |
| `snapshots/` | Customer history (SCD type 2) | 7 |
| `airflow/` | Daily DAG (COPY INTO, source freshness, then dbt via Astronomer Cosmos) and its requirements | 8 |
| `ci/`, `../.github/workflows/dbt_ci.yml` | Snowflake profiles and the pull-request CI job (the workflow sits at the repo root) | 4, 9 |
| `macros/` | Schema naming and CI clean-up | 4, 9 |
| `scripts/dbt_run_report.py` | Failures and slowest nodes from run_results.json | 10 |
| `local/` | Run everything on DuckDB without a Snowflake account | all |

Tested with dbt-core 1.12.5, dbt-snowflake 1.12.1, dbt-duckdb 1.11.0, Apache Airflow 3.1.8 and
astronomer-cosmos 1.15.1. The dbt project, tests, snapshot, CI flow and DAG were run end to end
on DuckDB; the Snowflake SQL follows the documented syntax but was not executed against a
Snowflake account.

## Quick start (Snowflake)

1. Run `snowflake/01_setup.sql`, then `snowflake/02_load_raw.sql` and `airflow/dags/sql/load_raw_orders.sql`.
2. `pip install -r requirements.txt`
3. `export DBT_PROFILES_DIR=ci SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=...`
4. `dbt deps && dbt build`

## Quick start (local, no Snowflake)

    pip install tpchgen-cli dbt-duckdb
    python local/make_raw_duckdb.py
    DBT_PROFILES_DIR=local dbt deps
    DBT_PROFILES_DIR=local dbt build
