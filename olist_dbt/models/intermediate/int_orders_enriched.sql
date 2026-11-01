WITH Orders AS (
    SELECT
        Order_ID
       ,Customer_ID
       ,Order_Status
       ,Order_Purchase_Timestamp
       ,Order_Approved_At
       ,Order_Delivered_Carrier_Date
       ,Order_Delivered_Customer_Date
       ,Order_Estimated_Delivery_Date
    FROM {{ ref('stg_orders') }}
),

Payments_by_order AS (
    SELECT
        Order_ID
       ,COUNT(*)                                  AS Payment_Count
       ,SUM(Payment_value)                        AS Payment_Total
    FROM {{ ref('stg_order_payments') }}
    GROUP BY Order_ID
),

Reviews_by_order AS (
    SELECT
        Order_ID
       ,COUNT(*) AS Review_Count
       ,AVG(Review_score)                          AS Average_Review_Score
       ,MAX(Review_creation_date)                  AS Latest_Review_Creation_Date
    FROM {{ ref('stg_order_reviews') }}
    GROUP BY Order_ID
),

Items_by_order AS (
    SELECT
        Order_ID
       ,COUNT(*)                                   AS Item_Count
       ,SUM(Price)                                 AS Items_Total
       ,SUM(Freight_value)                         AS Freight_Total
    FROM {{ ref('stg_order_items') }}
    GROUP BY Order_ID
)

SELECT
    Orders.Order_ID
    ,Orders.Customer_ID
    ,Customers.Customer_Unique_ID
    ,Orders.Order_Status
    ,Orders.Order_Purchase_Timestamp
    ,Orders.Order_Approved_At
    ,Orders.Order_Delivered_Carrier_Date
    ,Orders.Order_Delivered_Customer_Date
    ,Orders.Order_Estimated_Delivery_Date
    ,Customers.Customer_City
    ,Customers.Customer_State
    ,Customers.Region_Name                           AS Customer_Region
    ,Customers.Geolocation_Latitude                  AS Customer_Latitude
    ,Customers.Geolocation_Longitude                 AS Customer_Longitude
    ,COALESCE(Payments.Payment_count, 0)             AS Payment_Count
    ,Payments.Payment_Total
    ,COALESCE(Reviews.Review_count, 0)               AS Review_Count
    ,Reviews.Average_Review_Score
    ,Reviews.Latest_Review_Creation_Date
    ,COALESCE(Items.Item_count, 0)                   AS Item_Count
    ,Items.Items_Total
    ,Items.Freight_Total
FROM Orders
LEFT JOIN {{ ref('int_customers_enriched') }}        AS Customers
    ON Orders.Customer_id = Customers.Customer_id
LEFT JOIN Payments_by_order                          AS Payments
    ON Orders.Order_id = Payments.Order_id
LEFT JOIN Reviews_by_order                           AS Reviews
    ON Orders.Order_id = Reviews.Order_id
LEFT JOIN Items_by_order                             AS Items
    ON Orders.Order_id = Items.Order_id
