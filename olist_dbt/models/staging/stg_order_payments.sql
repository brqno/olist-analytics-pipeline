WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_order_payments') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Order_id)                 AS VARCHAR(50))      AS Order_ID
       ,CAST(Payment_sequential             AS INTEGER)          AS Payment_Sequential
       ,CAST(TRIM(Payment_type)             AS VARCHAR(50))      AS Payment_Type
       ,CAST(Payment_installments           AS INTEGER)          AS Payment_Installments
       ,CAST(Payment_value                  AS NUMERIC(16, 2))   AS Payment_Value

       ,{{ dbt.current_timestamp() }}                            AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted