BEGIN;

CREATE SCHEMA IF NOT EXISTS bi;

-- 1) Clean order-level view for BI
CREATE OR REPLACE VIEW bi.v_orders_clean AS
SELECT
    fo.order_id,
    fo.customer_id,
    fo.customer_unique_id,
    fo.order_status,

    CAST(fo.order_purchase_timestamp AS timestamp) AS order_purchase_timestamp,
    CAST(fo.order_delivered_customer_date AS timestamp) AS order_delivered_customer_date,
    CAST(fo.order_estimated_delivery_date AS timestamp) AS order_estimated_delivery_date,

    TO_CHAR(CAST(fo.order_purchase_timestamp AS timestamp), 'YYYY-MM') AS order_month,
    DATE_TRUNC('month', CAST(fo.order_purchase_timestamp AS timestamp))::date AS order_month_start,

    fo.item_count,
    fo.unique_products,
    fo.unique_sellers,
    fo.review_count,

    COALESCE(fo.total_price, 0) AS total_price,
    COALESCE(fo.total_freight, 0) AS total_freight,
    COALESCE(fo.order_value, COALESCE(fo.total_price, 0) + COALESCE(fo.total_freight, 0)) AS order_value,

    fo.avg_review_score,
    fo.delivery_days,
    fo.delay_days,

    CASE
        WHEN LOWER(COALESCE(CAST(fo.is_delayed AS text), 'false')) IN ('true', 't', '1', 'yes', 'y') THEN 1
        WHEN COALESCE(fo.delay_days, 0) > 0 THEN 1
        ELSE 0
    END AS is_delayed_flag,

    CASE
        WHEN fo.delay_days IS NULL THEN 'Unknown'
        WHEN fo.delay_days <= 0 THEN 'On time / early'
        WHEN fo.delay_days BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN fo.delay_days BETWEEN 4 AND 7 THEN '4-7 days late'
        WHEN fo.delay_days BETWEEN 8 AND 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket

FROM public.final_orders fo;


-- 2) Clean item/category-level view for BI
CREATE OR REPLACE VIEW bi.v_item_details_clean AS
SELECT
    id.order_id,
    id.product_id,
    id.seller_id,
    id.product_category_name,
    id.order_status,

    CAST(id.order_purchase_timestamp AS timestamp) AS order_purchase_timestamp,
    CAST(id.order_delivered_customer_date AS timestamp) AS order_delivered_customer_date,
    CAST(id.order_estimated_delivery_date AS timestamp) AS order_estimated_delivery_date,

    TO_CHAR(CAST(id.order_purchase_timestamp AS timestamp), 'YYYY-MM') AS order_month,
    DATE_TRUNC('month', CAST(id.order_purchase_timestamp AS timestamp))::date AS order_month_start,

    COALESCE(id.price, 0) AS price,
    COALESCE(id.freight_value, 0) AS freight_value,
    COALESCE(id.avg_review_score, NULL) AS avg_review_score,
    id.delay_days,

    CASE
        WHEN LOWER(COALESCE(CAST(id.is_delayed AS text), 'false')) IN ('true', 't', '1', 'yes', 'y') THEN 1
        WHEN COALESCE(id.delay_days, 0) > 0 THEN 1
        ELSE 0
    END AS is_delayed_flag

FROM public.item_details id;


-- 3) Executive KPI view (single row)
CREATE OR REPLACE VIEW bi.v_exec_kpi AS
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS total_customers,
    SUM(order_value) AS total_revenue,
    AVG(order_value) AS avg_order_value,
    AVG(avg_review_score) AS avg_review_score,
    AVG(is_delayed_flag::numeric) AS delay_rate,
    AVG(delivery_days) AS avg_delivery_days,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_orders_clean;


-- 4) Monthly KPI trend
CREATE OR REPLACE VIEW bi.v_monthly_kpi AS
SELECT
    order_month,
    order_month_start,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_revenue,
    AVG(order_value) AS avg_order_value,
    AVG(avg_review_score) AS avg_review_score,
    AVG(is_delayed_flag::numeric) AS delay_rate,
    AVG(delivery_days) AS avg_delivery_days,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_orders_clean
GROUP BY order_month, order_month_start
ORDER BY order_month_start;


-- 5) Delay impact on customer satisfaction
CREATE OR REPLACE VIEW bi.v_delay_impact AS
SELECT
    delay_bucket,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_revenue,
    AVG(order_value) AS avg_order_value,
    AVG(avg_review_score) AS avg_review_score,
    AVG(delivery_days) AS avg_delivery_days,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_orders_clean
GROUP BY delay_bucket;


-- 6) Delay vs on-time summary
CREATE OR REPLACE VIEW bi.v_delay_summary AS
SELECT
    is_delayed_flag,
    CASE
        WHEN is_delayed_flag = 1 THEN 'Delayed'
        ELSE 'On time / early'
    END AS delivery_status,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_revenue,
    AVG(order_value) AS avg_order_value,
    AVG(avg_review_score) AS avg_review_score,
    AVG(delivery_days) AS avg_delivery_days,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_orders_clean
GROUP BY is_delayed_flag;


-- 7) Category performance
CREATE OR REPLACE VIEW bi.v_category_performance AS
SELECT
    COALESCE(product_category_name, 'Unknown') AS product_category_name,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(price) AS category_revenue,
    AVG(price) AS avg_item_price,
    AVG(freight_value) AS avg_freight_value,
    AVG(avg_review_score) AS avg_review_score,
    AVG(is_delayed_flag::numeric) AS delay_rate,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_item_details_clean
GROUP BY COALESCE(product_category_name, 'Unknown');


-- 8) High-risk categories (bigger categories only)
CREATE OR REPLACE VIEW bi.v_category_risk AS
SELECT
    COALESCE(product_category_name, 'Unknown') AS product_category_name,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(price) AS category_revenue,
    AVG(avg_review_score) AS avg_review_score,
    AVG(is_delayed_flag::numeric) AS delay_rate,
    AVG(delay_days) AS avg_delay_days
FROM bi.v_item_details_clean
GROUP BY COALESCE(product_category_name, 'Unknown')
HAVING COUNT(DISTINCT order_id) >= 100;


-- 9) Monthly category trend for Tableau drilldown
CREATE OR REPLACE VIEW bi.v_category_monthly AS
SELECT
    order_month,
    order_month_start,
    COALESCE(product_category_name, 'Unknown') AS product_category_name,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(price) AS category_revenue,
    AVG(avg_review_score) AS avg_review_score,
    AVG(is_delayed_flag::numeric) AS delay_rate
FROM bi.v_item_details_clean
GROUP BY
    order_month,
    order_month_start,
    COALESCE(product_category_name, 'Unknown');


COMMIT;

SELECT * FROM bi.v_exec_kpi;

SELECT * 
FROM bi.v_monthly_kpi
ORDER BY order_month_start;

SELECT *
FROM bi.v_category_performance
ORDER BY category_revenue DESC
LIMIT 15;
