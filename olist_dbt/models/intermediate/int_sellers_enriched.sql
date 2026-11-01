WITH Sellers AS (
    SELECT
        Seller_ID
       ,Seller_Zip_Code_Prefix
       ,Seller_city
       ,Seller_state
    FROM {{ ref('stg_sellers') }}
),

Regions AS (
    SELECT
        UPPER(TRIM(Sigla))                         AS State_Code
       ,Estado                                     AS State_Name
       ,Regiao                                     AS Region_Name
       ,Ordem_regiao                               AS Region_Order
    FROM {{ ref('seed_regioes_estados') }}
)

SELECT
    Sellers.Seller_ID
    ,Sellers.Seller_Zip_Code_Prefix
    ,Sellers.Seller_city
    ,Sellers.Seller_state
    ,Regions.State_Name
    ,Regions.Region_Name
    ,Regions.Region_Order
    ,Geolocation.Geolocation_Latitude
    ,Geolocation.Geolocation_Longitude
FROM Sellers
LEFT JOIN Regions
    ON Sellers.Seller_state = Regions.State_Code
LEFT JOIN {{ ref('int_geolocation_by_zip') }}       AS Geolocation
    ON Sellers.Seller_Zip_Code_Prefix = Geolocation.Geolocation_Zip_Code_Prefix
