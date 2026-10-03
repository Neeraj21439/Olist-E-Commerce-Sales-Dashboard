SELECT 'customers' AS tbl, COUNT(*) FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers;

-- Q1. Mahine-wise revenue aur orders
select
	date_trunc('month', o.order_purchase_timestamp)::date AS month,
	count(distinct o.order_id) as total_order,
	round(sum(oi.price), 2) as revenue
from orders o
join order_items oi on o.order_id = oi.order_id
where order_status = 'delivered'
group by month
order by month;

-- Q2. Top 10 categories revenue ke hisaab se
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    ROUND(SUM(oi.price), 2) AS revenue,
    COUNT(*) AS items_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;	


-- Q3. State-wise orders aur revenue
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue DESC;

-- Q4. Delivery time aur late deliveries
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400)::numeric, 1) AS avg_delivery_days,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_percent
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- Q5. Category-wise average review score
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    ROUND(AVG(r.review_score), 2) AS avg_review,
    COUNT(*) AS reviews
FROM order_reviews r
JOIN order_items oi ON r.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY 1
HAVING COUNT(*) > 100
ORDER BY avg_review DESC;





WITH state_category AS (
    SELECT
        c.customer_state,
        COALESCE(t.product_category_name_english, p.product_category_name) AS category,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY 1, 2
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY customer_state ORDER BY revenue DESC) AS rnk
    FROM state_category
)
SELECT customer_state, category, ROUND(revenue, 2) AS revenue
FROM ranked
WHERE rnk <= 3
ORDER BY customer_state, rnk;
