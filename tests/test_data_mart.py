from io import BytesIO
from unittest.mock import Mock

import pandas as pd
import pytest
import yaml

from send import marts_to_s3

def _configure_export(monkeypatch, table_names):
    monkeypatch.setattr(marts_to_s3, "load_dotenv", lambda _: None)
    monkeypatch.setenv("S3_BUCKET", "test-bucket")
    monkeypatch.setenv("MARTS_SCHEMA", "olist_marts")
    monkeypatch.setenv("S3_PREFIX", "/test-prefix/")

    engine = Mock()
    monkeypatch.setattr(
        marts_to_s3,
        "create_database_engine",
        Mock(return_value=engine),
    )
    inspector = Mock()
    inspector.get_table_names.return_value = table_names
    monkeypatch.setattr(marts_to_s3, "inspect", Mock(return_value=inspector))
    return engine


def test_export_marts_uploads_nonempty_csv_for_every_gold_model(monkeypatch):
    models_directory = marts_to_s3.PROJECT_ROOT / "olist_dbt" / "models" / "marts"
    model_names = sorted(path.stem for path in models_directory.glob("*.sql"))
    engine = _configure_export(monkeypatch, model_names)

    def read_table(table_name, *, con, schema):
        assert con is engine
        assert schema == "olist_marts"
        return pd.DataFrame({"model": [table_name], "row_count": [1]})

    uploads = {}

    def upload_fileobj(fileobj, bucket, key, *, ExtraArgs):
        uploads[key] = {
            "bucket": bucket,
            "content_type": ExtraArgs["ContentType"],
            "content": fileobj.getvalue(),
        }

    monkeypatch.setattr(marts_to_s3.pd, "read_sql_table", read_table)
    s3_client = Mock()
    s3_client.upload_fileobj.side_effect = upload_fileobj
    monkeypatch.setattr(marts_to_s3.boto3, "client", Mock(return_value=s3_client))

    marts_to_s3.export_marts_to_s3()

    assert set(uploads) == {
        f"test-prefix/{model_name}.csv" for model_name in model_names
    }
    for model_name in model_names:
        upload = uploads[f"test-prefix/{model_name}.csv"]
        assert upload["bucket"] == "test-bucket"
        assert upload["content_type"] == "text/csv; charset=utf-8"
        exported = pd.read_csv(BytesIO(upload["content"]))
        assert not exported.empty
        assert exported.to_dict("records") == [
            {"model": model_name, "row_count": 1}
        ]
    assert engine.dispose.call_count == 1


def test_export_marts_does_not_upload_an_empty_table(monkeypatch):
    engine = _configure_export(monkeypatch, ["dim_customer"])
    monkeypatch.setattr(
        marts_to_s3.pd,
        "read_sql_table",
        Mock(return_value=pd.DataFrame(columns=["customer_key"])),
    )
    s3_client = Mock()
    monkeypatch.setattr(marts_to_s3.boto3, "client", Mock(return_value=s3_client))

    with pytest.raises(RuntimeError, match="vazia"):
        marts_to_s3.export_marts_to_s3()

    s3_client.upload_fileobj.assert_not_called()
    engine.dispose.assert_called_once_with()


def test_export_marts_fails_when_no_tables_exist(monkeypatch):
    engine = _configure_export(monkeypatch, [])
    s3_client = Mock()
    monkeypatch.setattr(marts_to_s3.boto3, "client", Mock(return_value=s3_client))

    with pytest.raises(RuntimeError, match="Nenhuma tabela encontrada"):
        marts_to_s3.export_marts_to_s3()

    s3_client.upload_fileobj.assert_not_called()
    engine.dispose.assert_called_once_with()


def test_export_marts_requires_s3_bucket(monkeypatch):
    monkeypatch.setattr(marts_to_s3, "load_dotenv", lambda _: None)
    monkeypatch.delenv("S3_BUCKET", raising=False)
    create_engine = Mock()
    monkeypatch.setattr(marts_to_s3, "create_database_engine", create_engine)

    with pytest.raises(ValueError, match="S3_BUCKET"):
        marts_to_s3.export_marts_to_s3()

    create_engine.assert_not_called()


def test_every_gold_model_has_a_dbt_schema_contract():
    models_directory = marts_to_s3.PROJECT_ROOT / "olist_dbt" / "models" / "marts"
    schema_file = models_directory / "schema.yml"
    schema = yaml.safe_load(schema_file.read_text(encoding="utf-8"))
    model_files = {path.stem for path in models_directory.glob("*.sql")}
    declared_models = {model["name"]: model for model in schema["models"]}

    assert set(declared_models) == model_files
    assert all(
        any(column.get("data_tests") for column in model.get("columns", []))
        for model in declared_models.values()
    )