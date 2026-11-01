WITH Orders AS (
    SELECT *
    FROM {{ ref('int_orders_enriched') }}
)

SELECT
    Orders.Order_ID
    ,Orders.Customer_ID                                                  AS Customer_Key
    ,CAST(Orders.Order_Purchase_Timestamp AS DATE)                       AS Order_Date
    ,Order_date.Date_Key                                                 AS Order_Date_Key
    ,CAST(Orders.Order_Delivered_Customer_Date AS DATE)                  AS Delivered_Date
    ,Delivered_date.Date_Key                                             AS Delivered_Date_Key
    ,CAST(Orders.Order_Estimated_Delivery_Date AS DATE)                  AS Estimated_Delivery_Date
    ,Estimated_date.Date_Key                                             AS Estimated_Delivery_Date_Key
    ,Orders.Order_Status
    ,Orders.Payment_Count
    ,Orders.Payment_Total
    ,Orders.Review_Count
    ,Orders.Average_Review_Score
    ,Orders.Latest_Review_Creation_Date
    ,Orders.Item_Count
    ,Orders.Items_Total
    ,Orders.Freight_Total
    ,COALESCE(Orders.Items_Total, 0) + COALESCE(Orders.Freight_Total, 0)  AS Order_Items_And_Freight_Total
    ,CASE
        WHEN Orders.Order_Delivered_Customer_Date IS NOT NULL
         AND Orders.Order_Estimated_Delivery_Date IS NOT NULL
        THEN CAST(Orders.Order_Delivered_Customer_Date AS DATE)
           - CAST(Orders.Order_Estimated_Delivery_Date AS DATE)
    END AS Delivery_Days_Variance
FROM Orders
LEFT JOIN {{ ref('dim_date') }} AS Order_date
    ON CAST(Orders.Order_Purchase_Timestamp AS DATE) = Order_date.Date_Day
LEFT JOIN {{ ref('dim_date') }} AS Delivered_date
    ON CAST(Orders.Order_Delivered_Customer_Date AS DATE) = Delivered_date.Date_Day
LEFT JOIN {{ ref('dim_date') }} AS Estimated_date
    ON CAST(Orders.Order_Estimated_Delivery_Date AS DATE) = Estimated_date.Date_Day
