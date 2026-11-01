WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_customers') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Customer_id)        AS VARCHAR(50))       AS Customer_ID
       ,CAST(TRIM(Customer_unique_id) AS VARCHAR(50))       AS Customer_Unique_ID
       ,CAST(Customer_zip_code_prefix AS VARCHAR(10))       AS Customer_Zip_Code_Prefix
       ,CAST(UPPER(TRIM(Customer_city))  AS VARCHAR(100))   AS Customer_City
       ,CAST(UPPER(TRIM(Customer_state)) AS VARCHAR(100))   AS Customer_State
       
       ,{{ dbt.current_timestamp() }}                       AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted