WITH Order_items AS (
    SELECT
        Order_ID
       ,Order_item_ID
       ,Product_ID
       ,Seller_ID
       ,Shipping_Limit_Date
       ,Price
       ,Freight_Value
    FROM {{ ref('stg_order_items') }}
)

SELECT
    Order_items.Order_ID
   ,Order_items.Order_Item_ID
   ,Order_items.Product_ID
   ,Order_items.Seller_ID
   ,Order_items.Shipping_Limit_Date
   ,Order_items.Price
   ,Order_items.Freight_Value
   ,Products.Product_Category_Name
   ,Products.Product_Category_Name_English
   ,Sellers.Seller_City
   ,Sellers.Seller_State
   ,Sellers.Region_Name                               AS Seller_Region
   ,Sellers.Geolocation_Latitude                      AS Seller_Latitude
   ,Sellers.Geolocation_Longitude                     AS Seller_Longitude
FROM Order_items
LEFT JOIN {{ ref('int_products_enriched') }}          AS Products
    ON Order_items.Product_id = Products.Product_id
LEFT JOIN {{ ref('int_sellers_enriched') }}           AS Sellers
    ON Order_items.Seller_id = Sellers.Seller_id
