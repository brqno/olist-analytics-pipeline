import logging
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine, URL

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
DATASETS = (
    ("olist_customers_dataset.csv", "raw_customers"),
    ("olist_geolocation_dataset.csv", "raw_geolocation"),
    ("olist_order_items_dataset.csv", "raw_order_items"),
    ("olist_order_payments_dataset.csv", "raw_order_payments"),
    ("olist_order_reviews_dataset.csv", "raw_order_reviews"),
    ("olist_orders_dataset.csv", "raw_orders"),
    ("olist_products_dataset.csv", "raw_products"),
    ("olist_sellers_dataset.csv", "raw_sellers"),
    ("product_category_name_translation.csv", "raw_category_translation"),
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler(PROJECT_ROOT / "pipeline_ingestao.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


def create_database_engine() -> Engine:
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


def load_data() -> None:
    if not RAW_DATA_DIR.is_dir():
        raise FileNotFoundError(f"Diretório de dados não encontrado: {RAW_DATA_DIR}")

    missing_files = [
        file_name
        for file_name, _ in DATASETS
        if not (RAW_DATA_DIR / file_name).is_file()
    ]
    if missing_files:
        raise FileNotFoundError(
            "Arquivos de dados não encontrados: " + ", ".join(missing_files)
        )

    engine = create_database_engine()
    try:
        for file_name, table_name in DATASETS:
            file_path = RAW_DATA_DIR / file_name
            logger.info("Lendo o arquivo: %s", file_path.name)
            dataframe = pd.read_csv(
                file_path,
                encoding="utf-8",
                low_memory=False,
            )

            logger.info(
                "Carregando %d linhas para a tabela 'bronze.%s'.",
                len(dataframe),
                table_name,
            )
            dataframe.to_sql(
                table_name,
                con=engine,
                schema="bronze",
                if_exists="replace",
                index=False,
            )
            logger.info("Tabela 'bronze.%s' atualizada.", table_name)
    except Exception:
        logger.exception("Falha ao carregar os dados para o PostgreSQL.")
        raise
    finally:
        engine.dispose()


if __name__ == "__main__":
    load_data()
