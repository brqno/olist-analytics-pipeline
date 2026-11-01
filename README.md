# Pipeline analítico Olist

<img width="1597" height="662" alt="pipeline_load_and_transformation - Grid - Airflow - Google Chrome 01_11_2026 20_51_58" src="https://github.com/user-attachments/assets/a11977bf-2b6d-48c2-909d-d0dd07bb9ebf" />

Pipeline de dados de e-commerce que carrega os CSVs públicos da Olist em PostgreSQL, transforma os dados com dbt e exporta as tabelas analíticas para CSV no Amazon S3. O projeto usa pandas e SQLAlchemy na ingestão e na exportação.

## Arquitetura

```text
data/raw/*.csv
    └── load/data_load.py (pandas + SQLAlchemy)
          └── PostgreSQL: bronze
                └── dbt staging
                      └── dbt intermediate (ephemeral)
                            └── dbt marts
                                  └── send/marts_to_s3.py
                                        └── Amazon S3: CSV por tabela
```

O perfil dbt usa `olist` como schema base. Com a convenção do adaptador PostgreSQL, os modelos são gravados em schemas como `olist_staging`, `olist_marts` e `olist_seeds`. As relações intermediate são efêmeras e incorporadas aos modelos dependentes.

## Estrutura

```text
data/raw/                       CSVs de origem
load/data_load.py               Carga dos CSVs para PostgreSQL
olist_dbt/
  dbt_project.yml               Configuração do projeto dbt
  profiles.yml                  Perfil dbt baseado em variáveis de ambiente
  models/staging/               Padronização e tipagem
  models/intermediate/          Enriquecimentos reutilizáveis
  models/marts/                 Dimensões e fatos analíticos
  seeds/                        Dados de referência
send/marts_to_s3.py             Exportação das marts para o S3
airflow/
  Dockerfile                    Imagem Airflow com as dependências do projeto
  docker-compose.yml            Serviços locais do Airflow
```

## Pré-requisitos

- Python 3.10–3.12 para as dependências locais do projeto.
- PostgreSQL acessível e banco `olist_project`.
- Schema de entrada `bronze` criado no banco.
- Os nove arquivos CSV Olist em `data/raw/`.
- Credenciais AWS com permissão de escrita no bucket configurado.
- Docker Desktop com containers Linux para executar o Airflow no Windows.

O Airflow não é instalado pelas dependências locais: no Windows, execute-o por Docker Desktop/WSL2. A imagem do projeto usa Airflow 2.10.5 com Python 3.12 e `LocalExecutor`, adequado para este pipeline local de execução sequencial.

## Configuração

1. Crie e ative um ambiente virtual na raiz do projeto:

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```

2. Instale as dependências Python:

   ```powershell
   python -m pip install -r requirements.txt
   ```

3. Crie `.env` na raiz (não versione esse arquivo) e configure:

   ```dotenv
   DB_USER=seu_usuario
   DB_PASSWORD=sua_senha
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=olist_project

   AWS_ACCESS_KEY_ID=sua_access_key_id
   AWS_SECRET_ACCESS_KEY=sua_secret_access_key
   AWS_DEFAULT_REGION=sa-east-1
   AWS_SESSION_TOKEN=
   S3_BUCKET=nome-do-bucket
   S3_PREFIX=marts
   MARTS_SCHEMA=olist_marts
   DBT_SCHEMA=olist
   ```

   `AWS_SESSION_TOKEN` só é necessário para credenciais temporárias. Em produção, prefira uma IAM role em vez de guardar chaves AWS em arquivo. A identidade AWS precisa de `s3:PutObject` nos objetos do prefixo de destino; para uploads multipart, conceda também `s3:AbortMultipartUpload`.

4. Crie o banco e o schema de entrada, se ainda não existirem:

   ```sql
   CREATE DATABASE olist_project;
   ```

   Conectado ao banco:

   ```sql
   CREATE SCHEMA IF NOT EXISTS bronze;
   ```

5. Para usar dbt diretamente no PowerShell, carregue as variáveis do `.env` na sessão atual:

   ```powershell
   $dotenvJson = & .\.venv\Scripts\python.exe -c "import json; from dotenv import dotenv_values; print(json.dumps({key: value for key, value in dotenv_values('.env').items() if value is not None}))"
   $dotenvValues = $dotenvJson | ConvertFrom-Json
   $dotenvValues.PSObject.Properties | ForEach-Object {
       Set-Item -Path "Env:$($_.Name)" -Value ([string]$_.Value)
   }
   ```

   O perfil em `olist_dbt/profiles.yml` lê as variáveis de conexão. Os scripts Python carregam o `.env` automaticamente.

## Execução local

Execute a ingestão:

```powershell
python .\load\data_load.py
```

As tabelas `bronze.raw_*` são recriadas a cada carga (`if_exists="replace"`); faça backup antes de alterar esse comportamento em um banco compartilhado.

Depois, compile/execute os modelos e os testes:

```powershell
dbt debug --project-dir .\olist_dbt --profiles-dir .\olist_dbt
dbt build --project-dir .\olist_dbt --profiles-dir .\olist_dbt
```

`dbt build` executa seeds, modelos e testes respeitando as dependências. Para exportar as tabelas do schema `olist_marts`:

```powershell
python .\send\marts_to_s3.py
```

O script cria um CSV por tabela e envia para `s3://<S3_BUCKET>/<S3_PREFIX>/<tabela>.csv`. O schema e o prefixo podem ser alterados por `MARTS_SCHEMA` e `S3_PREFIX`.

## Execução com Airflow

O `docker-compose.yml` usa o serviço PostgreSQL interno apenas para o metadatabase do Airflow. O PostgreSQL do projeto continua sendo a instância indicada por `DB_HOST` no `.env`; dentro dos containers, o Compose define `DB_HOST=host.docker.internal`.

Na raiz do projeto, construa a imagem e inicialize o Airflow:

```powershell
docker compose -f .\airflow\docker-compose.yml build
docker compose -f .\airflow\docker-compose.yml up airflow-init
docker compose -f .\airflow\docker-compose.yml up -d --remove-orphans
```

Acesse `http://localhost:8081` (ou a porta definida em `AIRFLOW_WEBSERVER_PORT`). O usuário e a senha locais padrão são `airflow`/`airflow`; defina `_AIRFLOW_WWW_USER_USERNAME` e `_AIRFLOW_WWW_USER_PASSWORD` no `.env` para alterá-los. A DAG `pipeline_load_and_transformation` executa, em sequência:

1. carga dos CSVs;
2. seed do dbt;
3. modelos dbt;
4. testes dbt;
5. exportação das marts para o S3.

Cada etapa falha explicitamente se o processo chamado retornar erro. A DAG é criada pausada; revise a configuração e ative-a pela interface quando quiser permitir execuções agendadas. O Compose injeta as variáveis do `.env` nos serviços Airflow e monta o projeto em `/opt/airflow/project`. DAGs de exemplo do Airflow ficam desativadas.

## Modelagem

As marts incluem:

- Dimensões: `dim_customer`, `dim_date`, `dim_product`, `dim_seller` e `dim_state_region`.
- Fatos: `fact_orders` (uma linha por pedido), `fact_order_items` (uma linha por item) e `fact_order_payments` (uma linha por pagamento sequencial).

<img width="1920" height="819" alt="pipeline_load_and_transformation - Grid - Airflow - Google Chrome 01_11_2026 20_39_25" src="https://github.com/user-attachments/assets/938a1f81-7534-440d-9073-559a6d0933eb" />

As tabelas fato têm granularidades diferentes. Não some medidas entre elas sem considerar a granularidade, para evitar dupla contagem. `customer_unique_id` também pode se repetir na fonte: identifica a mesma pessoa em mais de um registro de cliente e, por isso, não é testado como único.

## Logs e validação

- A ingestão grava em `pipeline_ingestao.log` e no console.
- O dbt grava logs em `olist_dbt/logs/`.
- Os logs, ambientes virtuais, arquivos `.env` e artefatos temporários são ignorados pelo Git.
- Execute `dbt test` ou `dbt build` para validar as regras declaradas nos arquivos `schema.yml`.
