# Olist E-Commerce Operations Analysis

## Project Overview
This project analyzes Olist e-commerce data to identify operational drivers of business performance and customer satisfaction. The workflow combines **Python**, **PostgreSQL**, and **Tableau** to move from raw transactional data to business-ready dashboards.

The main goals of the project are to:
- track revenue and order volume over time
- evaluate how delivery performance affects customer reviews
- identify product categories with strong revenue contribution
- highlight operational risk areas such as high delay rates or weaker customer ratings

---

## Tools Used
- **Python**: pandas for data cleaning, aggregation, and feature engineering
- **PostgreSQL**: SQL views for business logic and BI-ready modeling
- **Tableau**: dashboarding and visualization

---

## Workflow
### 1. Python Data Preparation
Raw Olist files were loaded and cleaned in Python.  
Main steps:
- checked duplicates and key IDs
- converted date columns
- aggregated order items to order level
- aggregated reviews to order level
- built a final order-level analysis table
- built an item/category-level analysis table
- engineered features such as:
  - `order_month`
  - `order_value`
  - `delivery_days`
  - `delay_days`
  - `is_delayed`

### 2. SQL Modeling
The cleaned Python outputs were imported into PostgreSQL.  
SQL was used to create BI-ready views for dashboarding and business analysis.

### 3. Tableau Dashboarding
Tableau dashboards were built on top of the SQL views to present:
- executive KPIs
- monthly business trends
- category-level performance
- category-level delay and review patterns

---

## Data Schema Summary

### Raw Source Tables
The project started from standard Olist raw tables:

- **orders**  
  Order-level transaction data including status and purchase / delivery timestamps.

- **customers**  
  Customer identifiers and location-related fields.

- **order_items**  
  Item-level order detail including product, seller, price, and freight value.

- **products**  
  Product metadata including category information.

- **order_reviews**  
  Customer review scores and review timestamps.

---

## Modeled Tables

### `public.final_orders`
Order-level analytical table created from the raw tables.

**Grain:** one row per order

**Key fields include:**
- `order_id`
- `customer_id`
- `customer_unique_id`
- `order_status`
- `order_purchase_timestamp`
- `order_delivered_customer_date`
- `order_estimated_delivery_date`
- `item_count`
- `unique_products`
- `unique_sellers`
- `review_count`
- `total_price`
- `total_freight`
- `order_value`
- `avg_review_score`
- `order_month`
- `delivery_days`
- `delay_days`
- `is_delayed`

### `public.item_details`
Item/category-level analytical table used for category analysis.

**Grain:** one row per order item

**Key fields include:**
- `order_id`
- `product_id`
- `seller_id`
- `product_category_name`
- `price`
- `freight_value`
- `order_status`
- `order_purchase_timestamp`
- `order_delivered_customer_date`
- `order_estimated_delivery_date`
- `avg_review_score`
- `order_month`
- `delay_days`
- `is_delayed`

---

## BI Views

### `bi.v_exec_kpi`
Executive summary view with top-level business KPIs.

**Main metrics:**
- total orders
- total customers
- total revenue
- average order value
- average review score
- delay rate
- average delivery days
- average delay days

### `bi.v_monthly_kpi`
Monthly trend view for core operational and revenue metrics.

**Main metrics by month:**
- total orders
- total revenue
- average order value
- average review score
- delay rate
- average delivery days
- average delay days

### `bi.v_category_performance`
Category-level view for product category comparison.

**Main metrics by category:**
- total orders
- category revenue
- average item price
- average freight value
- average review score
- delay rate
- average delay days

### Additional Views
Other supporting views were also created for category and delay analysis:
- `bi.v_delay_impact`
- `bi.v_delay_summary`
- `bi.v_category_risk`
- `bi.v_category_monthly`
- `bi.v_orders_clean`
- `bi.v_item_details_clean`

---

## Dashboards

### 1. Executive Overview
This dashboard focuses on overall business performance and customer experience.

**Includes:**
- Executive KPIs
- Monthly Revenue Trend
- Monthly Order Trend
- Review Score Trend
- Delay Rate Trend

### 2. Category Performance
This dashboard compares product categories across revenue, delay risk, and customer satisfaction.

**Includes:**
- Category Revenue
- Category Delay Rate
- Category Review Score

---

## Key Insights
- Revenue and order volume generally increased over time.
- Delivery delay is associated with weaker customer review scores.
- Some categories contribute high revenue but also show operational risk through elevated delay rates or weaker ratings.
- Executive KPI tracking and category-level comparisons help prioritize both growth and operational improvement.

---

## Project Files
Suggested project structure:

```text
olist-project/
├── README.md
├── notebooks/
│   └── olist_analysis.ipynb
├── sql/
│   └── 01_create_views.sql
├── dashboards/
│   ├── olist_dashboard.twbx
│   ├── olist_dashboard.twx
│   └── screenshots
