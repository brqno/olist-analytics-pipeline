SELECT
     Customer_ID                AS Customer_Key
    ,Customer_Unique_ID
    ,Customer_Zip_Code_Prefix
    ,Customer_City
    ,Customer_State             AS State_Code
    ,State_Name
    ,Region_Name
    ,Region_Order
    ,Geolocation_Latitude
    ,Geolocation_Longitude
FROM {{ ref('int_customers_enriched') }}
