SELECT
    Seller_ID               AS Seller_Key
    ,Seller_Zip_Code_Prefix
    ,Seller_City
    ,Seller_State           AS State_Code
    ,State_Name
    ,Region_Name
    ,Region_Order
    ,Geolocation_Latitude
    ,Geolocation_Longitude
FROM {{ ref('int_sellers_enriched') }}
