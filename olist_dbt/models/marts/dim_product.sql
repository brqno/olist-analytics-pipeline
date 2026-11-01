SELECT
    Product_ID AS Product_Key
    ,Product_Category_Name
    ,Product_Category_Name_English
    ,Product_Name_Length
    ,Product_Description_Length
    ,Product_Photos_Qty
    ,Product_Weight_g
    ,Product_Length_cm
    ,Product_Height_cm
    ,Product_Width_cm
FROM {{ ref('int_products_enriched') }}
