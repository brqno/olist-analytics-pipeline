WITH Geolocation AS (
    SELECT
        Geolocation_Zip_Code_Prefix
       ,Geolocation_Latitude
       ,Geolocation_Longitude
    FROM {{ ref('stg_geolocation') }}
)

SELECT
    Geolocation.Geolocation_Zip_Code_Prefix
   ,AVG(Geolocation.Geolocation_Latitude)      AS Geolocation_Latitude
   ,AVG(Geolocation.Geolocation_Longitude)     AS Geolocation_Longitude
FROM Geolocation
GROUP BY Geolocation.Geolocation_Zip_Code_Prefix
