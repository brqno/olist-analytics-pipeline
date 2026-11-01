WITH Products AS (
    SELECT
        Product_ID
       ,Product_category_name
       ,Product_name_length
       ,Product_description_length
       ,Product_photos_qty
       ,Product_weight_g
       ,Product_length_cm
       ,Product_height_cm
       ,Product_width_cm
    FROM {{ ref('stg_products') }}
)

SELECT
    Products.Product_ID
   ,Products.Product_Category_Name
   ,Translations.Product_Category_Name_English
   ,Products.Product_Name_Length
   ,Products.Product_Description_Length
   ,Products.Product_Photos_Qty
   ,Products.Product_Weight_G
   ,Products.Product_Length_Cm
   ,Products.Product_Height_Cm
   ,Products.Product_Width_Cm
FROM Products
LEFT JOIN {{ ref('stg_category_translation') }} AS Translations
    ON Products.Product_Category_Name = Translations.Product_Category_Name
