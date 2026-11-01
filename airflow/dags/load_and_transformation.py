import logging
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow.decorators import dag, task

PROJECT_ROOT = Path(
    os.getenv("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))
)
DBT_PROJECT_DIR = PROJECT_ROOT / "olist_dbt"
DBT_PROFILES_DIR = os.getenv("DBT_PROFILES_DIR", str(DBT_PROJECT_DIR))
logger = logging.getLogger(__name__)


def run_command(command: list[str], cwd: Path) -> None:
    result = subprocess.run(
        command,
        check=False,
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    output = "\n".join(part for part in (result.stdout, result.stderr) if part)
    for variable in (
        "DB_PASSWORD",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "AWS_SESSION_TOKEN",
    ):
        secret = os.getenv(variable)
        if secret:
            output = output.replace(secret, "[REDACTED]")

    if result.returncode:
        logger.error(
            "Command '%s' failed with exit code %d.\n%s",
            command[0],
            result.returncode,
            output,
        )
        raise subprocess.CalledProcessError(result.returncode, command)

    if output:
        logger.info("Command '%s' output:\n%s", command[0], output)


def run_dbt_command(command: str) -> None:
    run_command(
        [
            "dbt",
            command,
            "--project-dir",
            str(DBT_PROJECT_DIR),
            "--profiles-dir",
            DBT_PROFILES_DIR,
        ],
        DBT_PROJECT_DIR,
    )


@dag(
    dag_id="pipeline_load_and_transformation",
    schedule="0 6 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args={
        "owner": "engenharia-dados",
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
    tags=["olist", "python", "dbt", "postgresql"],
)
def pipeline_load_and_transformation():
    @task
    def load_data():
        run_command(
            [
                sys.executable,
                str(PROJECT_ROOT / "load" / "data_load.py"),
            ],
            PROJECT_ROOT,
        )

    @task
    def run_dbt_seed():
        run_dbt_command("seed")

    @task
    def run_dbt():
        run_dbt_command("run")

    @task
    def run_dbt_test():
        run_dbt_command("test")

    @task
    def export_marts_to_s3():
        run_command(
            [
                sys.executable,
                str(PROJECT_ROOT / "send" / "marts_to_s3.py"),
            ],
            PROJECT_ROOT,
        )

    (
        load_data()
        >> run_dbt_seed()
        >> run_dbt()
        >> run_dbt_test()
        >> export_marts_to_s3()
    )


pipeline_load_and_transformation()
