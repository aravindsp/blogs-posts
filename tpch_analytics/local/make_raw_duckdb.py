"""Build a local raw.duckdb with TPC-H data so you can run the dbt project without Snowflake.

    pip install tpchgen-cli dbt-duckdb
    python local/make_raw_duckdb.py
    DBT_PROFILES_DIR=local dbt build
"""
import subprocess
import tempfile

import duckdb

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["tpchgen-cli", "parquet", "-s", "0.05", f"--output-dir={tmp}"], check=True)
    con = duckdb.connect("raw.duckdb")
    con.execute("CREATE SCHEMA IF NOT EXISTS tpch")
    for t in ["customer", "nation", "region", "part", "supplier"]:
        con.execute(f"CREATE OR REPLACE TABLE tpch.{t} AS SELECT * FROM '{tmp}/{t}.parquet'")
    # history up to June 1998, like part 3 of the series
    con.execute(f"""CREATE OR REPLACE TABLE tpch.orders AS
        SELECT *, current_timestamp AS _loaded_at FROM '{tmp}/orders.parquet'
        WHERE o_orderdate < DATE '1998-07-01'""")
    con.execute(f"""CREATE OR REPLACE TABLE tpch.lineitem AS
        SELECT l.*, current_timestamp AS _loaded_at FROM '{tmp}/lineitem.parquet' l
        WHERE l_orderkey IN (SELECT o_orderkey FROM tpch.orders)""")
    print(con.sql("SELECT count(*) AS orders FROM tpch.orders"))
