"""Daily TPC-H pipeline: load new raw data into Snowflake, then build and test with dbt."""
import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.sdk import dag
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import LoadMode, SourceRenderingBehavior, TestBehavior
from cosmos.profiles import SnowflakeEncryptedPrivateKeyFilePemProfileMapping

DBT_PROJECT_DIR = Path(os.getenv("DBT_PROJECT_DIR", "/opt/airflow/dbt/tpch_analytics"))
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE", "/opt/airflow/dbt_venv/bin/dbt")

profile_config = ProfileConfig(
    profile_name="tpch_analytics",
    target_name="prod",
    profile_mapping=SnowflakeEncryptedPrivateKeyFilePemProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "ANALYTICS",
            "schema": "PROD",
            "warehouse": "TRANSFORM_WH",
            "role": "TRANSFORMER",
        },
    ),
)


def notify_failure(context):
    """Called when a task fails after its retries. Swap the print for Slack or email."""
    ti = context["task_instance"]
    print(f"FAILED: {ti.dag_id}.{ti.task_id} for {context['logical_date']}")


@dag(
    schedule="0 2 * * *",              # every day at 02:00 UTC
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(hours=2),
    default_args={
        "owner": "data-eng",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
        "on_failure_callback": notify_failure,
    },
    tags=["tpch", "dbt", "snowflake"],
)
def tpch_daily():

    load_raw = SQLExecuteQueryOperator(
        task_id="load_raw_orders",
        conn_id="snowflake_default",
        sql="sql/load_raw_orders.sql",
        split_statements=True,
    )

    transform = DbtTaskGroup(
        group_id="transform",
        project_config=ProjectConfig(
            DBT_PROJECT_DIR,
            manifest_path=DBT_PROJECT_DIR / "target" / "manifest.json",
        ),
        profile_config=profile_config,
        execution_config=ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE),
        render_config=RenderConfig(
            load_method=LoadMode.DBT_MANIFEST,
            test_behavior=TestBehavior.AFTER_EACH,
            source_rendering_behavior=SourceRenderingBehavior.WITH_TESTS_OR_FRESHNESS,
        ),
        operator_args={"install_deps": True},
    )

    load_raw >> transform


tpch_daily()
