WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_geolocation') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(CAST(Geolocation_zip_code_prefix AS VARCHAR)) AS VARCHAR(10)) AS Geolocation_Zip_Code_Prefix
       ,CAST(UPPER(TRIM(Geolocation_city))     AS VARCHAR(100))   AS Geolocation_City
       ,CAST(UPPER(TRIM(Geolocation_state))    AS VARCHAR(100))   AS Geolocation_State
       ,CAST(Geolocation_lat             AS NUMERIC(18, 15))      AS Geolocation_Latitude
       ,CAST(Geolocation_lng             AS NUMERIC(18, 15))      AS Geolocation_Longitude
       
       ,{{ dbt.current_timestamp() }}                             AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted