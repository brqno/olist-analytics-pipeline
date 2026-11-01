WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_order_items') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Order_id)                 AS VARCHAR(50))       AS Order_ID
       ,CAST(TRIM(CAST(Order_item_id AS VARCHAR)) AS VARCHAR(50)) AS Order_Item_ID
       ,CAST(TRIM(Product_id)               AS VARCHAR(50))       AS Product_ID
       ,CAST(TRIM(Seller_id)                AS VARCHAR(50))       AS Seller_ID 
       ,CAST(TRIM(Shipping_limit_date)       AS TIMESTAMP)        AS Shipping_Limit_Date
       ,CAST(Price AS NUMERIC(16, 2))                             AS Price
       ,CAST(Freight_value AS NUMERIC(16, 2))                     AS Freight_Value
       
       ,{{ dbt.current_timestamp() }}                             AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted