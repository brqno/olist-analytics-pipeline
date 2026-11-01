WITH Relevant_dates AS (
    SELECT CAST(Order_Purchase_Timestamp AS DATE)      AS Date_Day
    FROM {{ ref('stg_orders') }}

    UNION ALL

    SELECT CAST(Order_Delivered_Customer_Date AS DATE) AS Date_Day
    FROM {{ ref('stg_orders') }}

    UNION ALL

    SELECT CAST(Order_Estimated_Delivery_Date AS DATE) AS Date_Day
    FROM {{ ref('stg_orders') }}

    UNION ALL

    SELECT CAST(Shipping_Limit_Date AS DATE)           AS Date_Day
    FROM {{ ref('stg_order_items') }}
),

Date_bounds AS (
    SELECT
        MIN(Date_Day)                                  AS Min_Date
       ,MAX(Date_Day)                                  AS Max_Date
    FROM Relevant_dates
    WHERE Date_Day IS NOT NULL
),

Calendar AS (
    SELECT Generated_date::DATE AS Date_Day
    FROM Date_bounds
    CROSS JOIN LATERAL Generate_series(
        Min_Date
        ,Max_Date
        ,INTERVAL '1 day'
    ) AS Generated_date
)

SELECT
    CAST(TO_CHAR(Date_Day, 'YYYYMMDD') AS INTEGER)    AS Date_Key
    ,Date_Day
    ,EXTRACT(YEAR FROM Date_Day)::INTEGER             AS Year_Number
    ,EXTRACT(QUARTER FROM Date_Day)::INTEGER          AS Quarter_Number
    ,EXTRACT(MONTH FROM Date_Day)::INTEGER            AS Month_Number
    ,EXTRACT(DAY FROM Date_Day)::INTEGER              AS Day_Of_Month
    ,EXTRACT(ISODOW FROM Date_Day)::INTEGER           AS Day_Of_Week
    ,EXTRACT(ISODOW FROM Date_Day)::INTEGER IN (6, 7) AS Is_Weekend
FROM Calendar
