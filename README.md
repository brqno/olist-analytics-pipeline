# Pipeline analítico Olist

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

As tabelas fato têm granularidades diferentes. Não some medidas entre elas sem considerar a granularidade, para evitar dupla contagem. `customer_unique_id` também pode se repetir na fonte: identifica a mesma pessoa em mais de um registro de cliente e, por isso, não é testado como único.

## Perguntas de negócio respondidas pelas marts

Depois de executar `dbt build`, conecte-se ao banco `olist_project` e rode as consultas abaixo. Elas usam o schema `olist_marts` e mostram como combinar fatos e dimensões para analisar vendas, pagamentos, clientes, produtos, vendedores, datas e regiões. Os resultados dependem dos dados carregados; interprete-os a partir da saída real, sem assumir valores fixos.

### Pedidos: onde estão as vendas e os atrasos?

`fact_orders` tem uma linha por pedido. Esta consulta compara estados pelo valor de pagamento registrado e pela pontualidade dos pedidos entregues. `delivery_days_variance` negativo indica entrega antes da previsão; positivo, atraso.

```sql
SELECT
    r.region_name,
    r.state_code,
    r.state_name,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(o.payment_total), 2) AS recorded_paid_total,
    ROUND(AVG(o.payment_total), 2) AS avg_paid_per_order,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE o.delivery_days_variance IS NOT NULL
              AND o.delivery_days_variance <= 0
        ) / NULLIF(
            COUNT(*) FILTER (WHERE o.delivery_days_variance IS NOT NULL),
            0
        ),
        2
    ) AS on_time_delivery_pct
FROM olist_marts.fact_orders AS o
JOIN olist_marts.dim_customer AS c
    ON c.customer_key = o.customer_key
JOIN olist_marts.dim_state_region AS r
    ON r.state_code = c.state_code
WHERE o.order_status = 'delivered'
GROUP BY r.region_name, r.state_code, r.state_name
ORDER BY recorded_paid_total DESC;
```

### Itens e produtos: quais categorias geram mais vendas?

`fact_order_items` tem uma linha por item. O valor de itens não inclui frete; as duas medidas são apresentadas separadamente. A consulta considera apenas pedidos entregues.

```sql
SELECT
    COALESCE(p.product_category_name, 'Sem categoria') AS category,
    COUNT(*) AS delivered_items,
    COUNT(DISTINCT i.order_id) AS delivered_orders,
    ROUND(SUM(i.price), 2) AS item_sales,
    ROUND(SUM(i.freight_value), 2) AS freight_total
FROM olist_marts.fact_order_items AS i
JOIN olist_marts.dim_product AS p
    ON p.product_key = i.product_key
WHERE i.order_status = 'delivered'
GROUP BY COALESCE(p.product_category_name, 'Sem categoria')
ORDER BY item_sales DESC;
```

### Pagamentos: quais métodos e parcelamentos são mais usados?

`fact_order_payments` tem uma linha por pagamento sequencial. Um pedido pode aparecer em mais de um método; por isso, pedidos distintos por método não devem ser somados para obter o total geral de pedidos.

```sql
SELECT
    payment_type,
    payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders_using_this_combination,
    ROUND(SUM(payment_value), 2) AS payment_total,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM olist_marts.fact_order_payments
GROUP BY payment_type, payment_installments
ORDER BY payment_total DESC;
```

### Datas: pedidos feitos no fim de semana têm um valor médio diferente?

`dim_date` permite comparar a atividade por tipo de dia sem recalcular atributos de calendário.

```sql
SELECT
    CASE WHEN d.is_weekend THEN 'Fim de semana' ELSE 'Dia útil' END AS day_type,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(o.payment_total), 2) AS recorded_paid_total,
    ROUND(AVG(o.payment_total), 2) AS avg_paid_per_order
FROM olist_marts.fact_orders AS o
JOIN olist_marts.dim_date AS d
    ON d.date_key = o.order_date_key
WHERE o.order_status = 'delivered'
GROUP BY d.is_weekend
ORDER BY d.is_weekend;
```

### Clientes: quais estados têm mais recorrência de compra?

O identificador `customer_unique_id` representa a pessoa e pode aparecer em mais de um registro de cliente. A consulta conta pessoas distintas por estado e divide os pedidos pelo número de pessoas com pedido registrado.

```sql
SELECT
    c.region_name,
    c.state_code,
    c.state_name,
    COUNT(DISTINCT c.customer_unique_id) AS distinct_buyers,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)::numeric
        / NULLIF(COUNT(DISTINCT c.customer_unique_id), 0),
        2
    ) AS orders_per_buyer
FROM olist_marts.dim_customer AS c
JOIN olist_marts.fact_orders AS o
    ON o.customer_key = c.customer_key
GROUP BY c.region_name, c.state_code, c.state_name
ORDER BY orders_per_buyer DESC, orders DESC;
```

### Produtos: como está distribuído o sortimento do catálogo?

Além das vendas por categoria, os atributos de `dim_product` ajudam a avaliar a cobertura do catálogo e informações úteis para logística.

```sql
SELECT
    COALESCE(product_category_name, 'Sem categoria') AS category,
    COUNT(*) AS products,
    ROUND(AVG(product_weight_g), 2) AS avg_product_weight_g,
    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
    ) AS products_without_weight
FROM olist_marts.dim_product
GROUP BY COALESCE(product_category_name, 'Sem categoria')
ORDER BY products DESC;
```

### Vendedores: quais regiões concentram vendas dos vendedores?

O valor abaixo é a soma dos preços dos itens vendidos por vendedores da região, sem frete. Um mesmo pedido pode envolver vendedores de mais de uma região, então os totais regionais não são parcelas exclusivas do total de pedidos.

```sql
SELECT
    s.region_name,
    s.state_code,
    s.state_name,
    COUNT(DISTINCT s.seller_key) AS sellers,
    COUNT(DISTINCT i.order_id) AS orders_with_seller_items,
    ROUND(SUM(i.price), 2) AS item_sales
FROM olist_marts.dim_seller AS s
JOIN olist_marts.fact_order_items AS i
    ON i.seller_key = s.seller_key
WHERE i.order_status = 'delivered'
GROUP BY s.region_name, s.state_code, s.state_name
ORDER BY item_sales DESC;
```

### Regiões: como se comparam em pedidos entregues?

`dim_state_region` fornece a classificação de estados e regiões usada para agrupar os pedidos pela localização do cliente.

```sql
SELECT
    r.region_name,
    COUNT(DISTINCT r.state_code) AS states_in_region,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT c.customer_unique_id) FILTER (
        WHERE o.order_id IS NOT NULL
    ) AS distinct_buyers,
    ROUND(COALESCE(SUM(o.payment_total), 0), 2) AS recorded_paid_total
FROM olist_marts.dim_state_region AS r
LEFT JOIN olist_marts.dim_customer AS c
    ON c.state_code = r.state_code
LEFT JOIN olist_marts.fact_orders AS o
    ON o.customer_key = c.customer_key
   AND o.order_status = 'delivered'
GROUP BY r.region_name
ORDER BY recorded_paid_total DESC;
```

## Logs e validação

- A ingestão grava em `pipeline_ingestao.log` e no console.
- O dbt grava logs em `olist_dbt/logs/`.
- Os logs, ambientes virtuais, arquivos `.env` e artefatos temporários são ignorados pelo Git.
- Execute `dbt test` ou `dbt build` para validar as regras declaradas nos arquivos `schema.yml`.
