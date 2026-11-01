WITH Order_items AS (
    SELECT *
    FROM {{ ref('int_order_items_enriched') }}
),

Orders AS (
    SELECT
        Order_ID
        ,Customer_ID
        ,Order_Status
        ,Order_Purchase_Timestamp
    FROM {{ ref('int_orders_enriched') }}
)

SELECT
    Order_items.Order_ID
    ,Order_items.Order_Item_ID
    ,Order_items.Order_ID || '-' || Order_items.Order_Item_ID  AS Order_Item_Key
    ,Orders.Customer_ID                                        AS Customer_Key
    ,Order_items.Product_ID                                    AS Product_Key
    ,Order_items.Seller_ID                                     AS Seller_Key
    ,Order_date.Date_Key                                       AS Order_Date_Key
    ,Shipping_date.Date_Key                                    AS Shipping_Limit_Date_Key
    ,Orders.Order_Status
    ,Order_items.Price
    ,Order_items.Freight_Value
    ,Order_items.Price + Order_items.Freight_Value             AS Item_And_Freight_Total
FROM Order_items
INNER JOIN Orders
    ON Order_items.Order_ID = Orders.Order_ID
LEFT JOIN {{ ref('dim_date') }} AS Order_date
    ON CAST(Orders.Order_Purchase_Timestamp AS DATE) = Order_date.Date_Day
LEFT JOIN {{ ref('dim_date') }} AS Shipping_date
    ON CAST(Order_items.Shipping_Limit_Date AS DATE) = Shipping_date.Date_Day
