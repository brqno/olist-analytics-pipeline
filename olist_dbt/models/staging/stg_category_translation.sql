WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_category_translation') }}
),

Renamed_and_casted AS (
    SELECT
        UPPER(TRIM(Product_category_name))           AS Product_Category_Name
       ,UPPER(TRIM(Product_category_name_english))   AS Product_Category_Name_English

       ,{{ dbt.current_timestamp() }}                AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted