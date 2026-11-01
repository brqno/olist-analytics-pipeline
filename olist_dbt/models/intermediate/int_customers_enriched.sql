WITH Customers AS (
    SELECT
        Customer_ID
       ,Customer_Unique_ID
       ,Customer_Zip_Code_Prefix
       ,Customer_City
       ,Customer_State
    FROM {{ ref('stg_customers') }}
),

Regions AS (
    SELECT
        UPPER(TRIM(Sigla)) AS State_Code
       ,Estado AS State_Name
       ,Regiao AS Region_Name
       ,Ordem_regiao AS Region_Order
    FROM {{ ref('seed_regioes_estados') }}
)

SELECT
    Customers.Customer_ID
   ,Customers.Customer_Unique_ID
   ,Customers.Customer_Zip_Code_Prefix
   ,Customers.Customer_City
   ,Customers.Customer_State
   ,Regions.State_Name
   ,Regions.Region_Name
   ,Regions.Region_Order
   ,Geolocation.Geolocation_Latitude
   ,Geolocation.Geolocation_Longitude
FROM Customers
LEFT JOIN Regions
    ON Customers.Customer_State = Regions.State_Code
LEFT JOIN {{ ref('int_geolocation_by_zip') }} AS Geolocation
    ON Customers.Customer_Zip_Code_Prefix = Geolocation.Geolocation_Zip_Code_Prefix
