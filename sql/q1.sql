-- month-over-month (MoM)

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS month_start,
        TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM') AS order_month,
        ROUND(SUM(ol.net_amount), 2) AS recognized_revenue
    FROM clean_orders o
    JOIN clean_order_lines ol
        ON o.order_id = ol.order_id
    WHERE o.status = 'delivered'
    GROUP BY 1, 2
),
with_previous AS (
    SELECT
        month_start,
        order_month,
        recognized_revenue,
        LAG(recognized_revenue) OVER (ORDER BY month_start) AS prev_month_revenue
    FROM monthly_revenue
)
SELECT
    order_month,
    recognized_revenue,
    prev_month_revenue,
    ROUND(
        ((recognized_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0)) * 100.0,
        2
    ) AS mom_growth_pct
FROM with_previous
ORDER BY month_start;