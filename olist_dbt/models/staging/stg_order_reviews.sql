WITH Source_data AS (
    SELECT * FROM {{ source('olist', 'raw_order_reviews') }}
),

Renamed_and_casted AS (
    SELECT
        CAST(TRIM(Review_id)                        AS VARCHAR(50))                     AS Review_ID
       ,CAST(TRIM(Order_id)                         AS VARCHAR(50))                     AS Order_ID
       ,CAST(Review_score                           AS INTEGER)                         AS Review_Score
       ,COALESCE(CAST(TRIM(Review_comment_title)    AS VARCHAR(100)), 'Sem Título')     AS Review_comment_title
       ,COALESCE(CAST(TRIM(Review_comment_message)  AS VARCHAR(500)), 'Sem Comentário') AS Review_comment_message
       ,CAST(TRIM(Review_creation_date)             AS TIMESTAMP)                       AS Review_Creation_Date
       ,CAST(TRIM(Review_answer_timestamp)          AS TIMESTAMP)                       AS Review_Answer_Timestamp

       ,{{ dbt.current_timestamp() }}                                                   AS Processed_Timestamp

    FROM Source_data
)

SELECT * FROM Renamed_and_casted 