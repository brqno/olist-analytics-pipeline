WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_products') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Product_id)                         AS VARCHAR(50))       AS Product_ID
       ,CAST(UPPER(TRIM(Product_category_name))       AS VARCHAR(100))      AS Product_Category_Name
       ,CAST(Product_name_lenght                     AS INTEGER)            AS Product_Name_Length
       ,CAST(Product_description_lenght              AS INTEGER)            AS Product_Description_Length
       ,CAST(Product_photos_qty                      AS INTEGER)            AS Product_Photos_Qty
       ,CAST(Product_weight_g                        AS INTEGER)            AS Product_Weight_g
       ,CAST(Product_length_cm                       AS INTEGER)            AS Product_Length_cm
       ,CAST(Product_height_cm                       AS INTEGER)            AS Product_Height_cm
       ,CAST(Product_width_cm                        AS INTEGER)            AS Product_Width_cm

       ,{{ dbt.current_timestamp() }}                                       AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted