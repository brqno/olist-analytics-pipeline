SELECT
    UPPER(TRIM(Sigla))  AS State_Code
    ,Estado             AS State_Name
    ,Regiao             AS Region_Name
    ,Ordem_regiao       AS Region_Order
FROM {{ ref('seed_regioes_estados') }}
