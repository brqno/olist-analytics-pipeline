import logging
import os
from io import BytesIO
from pathlib import Path

import boto3
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import URL

PROJECT_ROOT = Path(__file__).resolve().parents[1]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

def create_database_engine():
    load_dotenv(PROJECT_ROOT / ".env")

    required_variables = ("DB_USER", "DB_PASSWORD")
    missing_variables = [
        variable for variable in required_variables if not os.getenv(variable)
    ]
    if missing_variables:
        raise ValueError(
            "Variáveis de banco ausentes no ambiente: "
            + ", ".join(missing_variables)
        )

    database_url = URL.create(
        "postgresql+psycopg2",
        username=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        database=os.getenv("DB_NAME", "olist_project"),
    )
    return create_engine(database_url)


def export_marts_to_s3():
    load_dotenv(PROJECT_ROOT / ".env")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise ValueError("A variável S3_BUCKET não foi configurada.")

    marts_schema = os.getenv("MARTS_SCHEMA", "olist_marts")
    prefix = os.getenv("S3_PREFIX", "marts").strip("/")
    engine = create_database_engine()

    try:
        s3_client = boto3.client("s3")
        table_names = inspect(engine).get_table_names(schema=marts_schema)
        if not table_names:
            raise RuntimeError(
                f"Nenhuma tabela encontrada no schema '{marts_schema}'. "
                "Verifique se o dbt já executou os modelos marts."
            )

        for table_name in sorted(table_names):
            logging.info("Consultando %s.%s", marts_schema, table_name)
            dataframe = pd.read_sql_table(
                table_name,
                con=engine,
                schema=marts_schema,
            )

            csv_buffer = BytesIO()
            dataframe.to_csv(csv_buffer, index=False, encoding="utf-8")
            csv_buffer.seek(0)

            object_name = f"{prefix}/{table_name}.csv" if prefix else f"{table_name}.csv"
            s3_client.upload_fileobj(
                csv_buffer,
                bucket,
                object_name,
                ExtraArgs={"ContentType": "text/csv; charset=utf-8"},
            )
            logging.info(
                "Enviado s3://%s/%s (%d linhas)",
                bucket,
                object_name,
                len(dataframe),
            )
    except Exception:
        logging.exception("Falha ao exportar as marts para o S3.")
        raise
    finally:
        engine.dispose()


if __name__ == "__main__":
    export_marts_to_s3()
