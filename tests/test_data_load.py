from unittest.mock import Mock, call
import pandas as pd
from load import data_load

def test_create_database_engine_uses_configured_database_url(monkeypatch):
    monkeypatch.setattr(data_load, "load_dotenv", lambda _: None)
    monkeypatch.setenv("DB_USER", "test-user")
    monkeypatch.setenv("DB_PASSWORD", "test-password")
    monkeypatch.setenv("DB_HOST", "localhost")
    monkeypatch.setenv("DB_PORT", "5432")
    monkeypatch.setenv("DB_NAME", "test_database")
    
    expected_engine = Mock()
    create_engine = Mock(return_value=expected_engine)
    monkeypatch.setattr(data_load, "create_engine", create_engine)

    engine = data_load.create_database_engine()

    assert engine is expected_engine
    database_url = create_engine.call_args.args[0]
    assert database_url.drivername == "postgresql+psycopg2"
    assert database_url.username == "test-user"
    assert database_url.password == "test-password"
    assert database_url.host == "localhost"
    assert database_url.port == 5432
    assert database_url.database == "test_database"

def test_ingestao_idempotente(monkeypatch, tmp_path):
    data_directory = tmp_path / "raw"
    data_directory.mkdir()
    for file_name, _ in data_load.DATASETS:
        (data_directory / file_name).touch()
    monkeypatch.setattr(data_load, "RAW_DATA_DIR", data_directory)

    engine = Mock()
    monkeypatch.setattr(data_load, "create_database_engine", lambda: engine)
    dataframe = pd.DataFrame({"order_id": ["id_1", "id_2"]})
    monkeypatch.setattr(data_load.pd, "read_csv", Mock(return_value=dataframe))
    to_sql = Mock()
    monkeypatch.setattr(pd.DataFrame, "to_sql", to_sql)

    data_load.load_data()
    data_load.load_data()

    expected_calls = [
        call(
            table_name,
            con=engine,
            schema="bronze",
            if_exists="replace",
            index=False,
        )
        for _ in range(2)
        for _, table_name in data_load.DATASETS
    ]
    assert to_sql.call_args_list == expected_calls
    assert engine.dispose.call_count == 2
