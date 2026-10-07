-- =====================================================================
-- Olist Brazilian E-Commerce Analytics Database
-- File: 02_business_insights.sql
-- Description: Core Analytical Queries solving delivery latency, 
--              revenue at risk, seller SLA breaches, and fan-out trap.
-- =====================================================================

USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- 1. Delivery Delay Buckets vs Average Review Score & 1-Star Review %
-- Business Question: How severely do delivery delays impact customer NPS & ratings?
-- ---------------------------------------------------------------------
SELECT 
    CASE 
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 0 
            THEN '01. On-Time / Early'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 1 AND 3 
            THEN '02. Minor Delay (1-3 days)'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 4 AND 7 
            THEN '03. Moderate Delay (4-7 days)'
        ELSE '04. Severe Delay (> 7 days)'
    END AS delivery_performance_bucket,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(r.review_score), 2) AS one_star_review_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance_bucket
ORDER BY delivery_performance_bucket;


-- ---------------------------------------------------------------------
-- 2. Financial Impact of Delivery Delays (Revenue at Risk)
-- Business Question: What percentage of GMV and freight is trapped in delayed deliveries?
-- ---------------------------------------------------------------------
WITH order_financials AS (
    SELECT 
        o.order_id,
        CASE 
            WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0 
                THEN 'Delayed Delivery'
            ELSE 'On-Time / Early Delivery'
        END AS delivery_status,
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_days,
        SUM(oi.price) AS items_revenue,
        SUM(oi.freight_value) AS freight_revenue,
        SUM(oi.price + oi.freight_value) AS total_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY o.order_id, delivery_status, delay_days
)
SELECT 
    delivery_status,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_order_value), 2) AS total_revenue_brl,
    ROUND(AVG(total_order_value), 2) AS avg_order_value_aov,
    ROUND(AVG(freight_revenue), 2) AS avg_freight_cost,
    ROUND(100.0 * COUNT(order_id) / SUM(COUNT(order_id)) OVER(), 2) AS pct_of_orders,
    ROUND(100.0 * SUM(total_order_value) / SUM(SUM(total_order_value)) OVER(), 2) AS pct_of_total_revenue
FROM order_financials
GROUP BY delivery_status;


-- ---------------------------------------------------------------------
-- 3. Root Cause Analysis: Seller Dispatch SLA vs Carrier Delivery Delay
-- Business Question: Is fulfillment delay caused by seller late dispatch or carrier transit?
-- ---------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date 
             AND o.order_delivered_customer_date > o.order_estimated_delivery_date 
             THEN 'Both Seller & Carrier Delayed'
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date 
             THEN 'Seller Delayed Dispatch (SLA Breach)'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
             THEN 'Carrier Transit Delay (Logistics Failure)'
        ELSE 'On-Time Fulfillment'
    END AS fulfillment_delay_category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(100.0 * COUNT(DISTINCT o.order_id) / SUM(COUNT(DISTINCT o.order_id)) OVER(), 2) AS pct_of_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY fulfillment_delay_category
ORDER BY total_orders DESC;


-- ---------------------------------------------------------------------
-- 4. State-wise Logistics Performance & Delivery Latency Bottlenecks
-- Business Question: Which destination states have highest delivery delays & freight charges?
-- ---------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_delivered_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_actual_delivery_days,
    ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)), 1) AS avg_estimated_delivery_days,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_cost,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) 
          / COUNT(DISTINCT o.order_id), 2) AS delay_rate_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING total_delivered_orders >= 100
ORDER BY delay_rate_pct DESC;


-- ---------------------------------------------------------------------
-- 5. Handling 1-to-Many Granularity Fan-Out Trap (Items vs Payments)
-- Business Question: Calculating customer spend without cartesian duplication.
-- ---------------------------------------------------------------------
WITH order_items_agg AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS total_items_count,
        SUM(price) AS items_revenue,
        SUM(freight_value) AS total_freight,
        SUM(price + freight_value) AS order_gross_value
    FROM order_items
    GROUP BY order_id
),
order_payments_agg AS (
    SELECT 
        order_id,
        COUNT(payment_sequential) AS total_payment_splits,
        SUM(payment_value) AS total_amount_paid,
        MAX(payment_type) AS primary_payment_type,
        MAX(payment_installments) AS max_installments
    FROM order_payments
    GROUP BY order_id
)
SELECT 
    p.primary_payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(i.order_gross_value), 2) AS total_gross_merchandise_val,
    ROUND(SUM(p.total_amount_paid), 2) AS total_payment_collected,
    ROUND(AVG(i.order_gross_value), 2) AS avg_basket_size,
    ROUND(AVG(p.max_installments), 1) AS avg_installments
FROM orders o
JOIN order_items_agg i ON o.order_id = i.order_id
JOIN order_payments_agg p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.primary_payment_type
ORDER BY total_orders DESC;
