WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_sellers') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Seller_id)                   AS VARCHAR(50))        AS Seller_ID
       ,CAST(TRIM(CAST(Seller_zip_code_prefix AS VARCHAR)) AS VARCHAR(10)) AS Seller_Zip_Code_Prefix
       ,CAST(UPPER(TRIM(Seller_city))          AS VARCHAR(100))       AS Seller_City
       ,CAST(UPPER(TRIM(Seller_state))         AS VARCHAR(100))       AS Seller_State

       ,{{ dbt.current_timestamp() }}                                 AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted