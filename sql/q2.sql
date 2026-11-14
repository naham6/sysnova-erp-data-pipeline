
-- Top 3 customers by recognised revenue in each region IN 2025

WITH customer_2025_revenue AS (
    SELECT
        c.region,
        c.customer_id,
        c.customer_name,
        c.segment,
        ROUND(SUM(ol.net_amount), 2) AS recognized_revenue
    FROM clean_orders o
    JOIN clean_order_lines ol
        ON o.order_id = ol.order_id
    JOIN clean_customers c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'delivered'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <= DATE '2025-12-31'
    GROUP BY c.region, c.customer_id, c.customer_name, c.segment
),
ranked_customers AS (
    SELECT
        region,
        DENSE_RANK() OVER (
            PARTITION BY region
            ORDER BY recognized_revenue DESC
        ) AS region_rank,
        customer_id,
        customer_name,
        segment,
        recognized_revenue
    FROM customer_2025_revenue
)
SELECT
    region,
    region_rank,
    customer_id,
    customer_name,
    segment,
    recognized_revenue
FROM ranked_customers
WHERE region_rank <= 3
ORDER BY region ASC, region_rank ASC, customer_id ASC;