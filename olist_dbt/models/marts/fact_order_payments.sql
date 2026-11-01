WITH Payments AS (
    SELECT
        Order_ID
        ,Payment_Sequential
        ,Payment_Type
        ,Payment_Installments
        ,Payment_Value
    FROM {{ ref('stg_order_payments') }}
),

Orders AS (
    SELECT
        Order_ID
        ,Customer_ID
        ,Order_Purchase_Timestamp
    FROM {{ ref('int_orders_enriched') }}
)

SELECT
    Payments.Order_ID
    ,Payments.Payment_Sequential
    ,Payments.Order_ID || '-' || CAST(Payments.Payment_Sequential AS VARCHAR)   AS Payment_Key
    ,Orders.Customer_ID                                                         AS Customer_Key
    ,Order_date.Date_Key                                                        AS Order_Date_Key
    ,Payments.Payment_Type
    ,Payments.Payment_Installments
    ,Payments.Payment_Value
FROM Payments
INNER JOIN Orders
    ON Payments.Order_ID = Orders.Order_ID
LEFT JOIN {{ ref('dim_date') }} AS Order_date
    ON CAST(Orders.Order_Purchase_Timestamp AS DATE) = Order_date.Date_Day
