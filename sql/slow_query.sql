-- Task 5 / q4: this query is correct but slow on large data.
-- Rewrite it to return the SAME result more efficiently and explain what you changed in docs/q4_notes.md.
-- Table names refer to the clean tables you created; adapt names and syntax to your database.
-- Business question: for customers that have at least one delivered order, show their
-- 2025 order count, 2025 gross sales (quantity * unit_price) and last order date, best customers first.

SELECT c.customer_id,
       c.customer_name,
       (SELECT COUNT(*)
          FROM orders o1
         WHERE o1.customer_id = c.customer_id
           AND o1.status = 'delivered'
           AND o1.order_date >= '2025-01-01') AS orders_2025,
       (SELECT SUM(l.quantity * l.unit_price)
          FROM orders o2
          JOIN order_lines l ON l.order_id = o2.order_id
         WHERE o2.customer_id = c.customer_id
           AND o2.status = 'delivered'
           AND o2.order_date >= '2025-01-01') AS gross_sales_2025,
       (SELECT MAX(o3.order_date)
          FROM orders o3
         WHERE o3.customer_id = c.customer_id
           AND o3.status = 'delivered') AS last_delivered_order_date
  FROM customers c
 WHERE c.customer_id IN (SELECT customer_id FROM orders WHERE status = 'delivered')
 ORDER BY gross_sales_2025 DESC;
