WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_orders') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Order_id)                         AS VARCHAR(50))      AS Order_ID
       ,CAST(TRIM(Customer_id)                      AS VARCHAR(50))      AS Customer_ID
       ,CAST(UPPER(TRIM(Order_status))              AS VARCHAR(20))      AS Order_Status
       ,CAST(TRIM(Order_purchase_timestamp)         AS TIMESTAMP)        AS Order_Purchase_Timestamp
       ,CAST(TRIM(Order_approved_at)                AS TIMESTAMP)        AS Order_Approved_At
       ,CAST(TRIM(Order_delivered_carrier_date)     AS TIMESTAMP)        AS Order_Delivered_Carrier_Date
       ,CAST(TRIM(Order_delivered_customer_date)    AS TIMESTAMP)        AS Order_Delivered_Customer_Date
       ,CAST(TRIM(Order_estimated_delivery_date)    AS TIMESTAMP)        AS Order_Estimated_Delivery_Date

       ,{{ dbt.current_timestamp() }}                                    AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted