--========================================================--
-- 8️  PRODUCT PERFORMANCE & LIFECYCLE ANALYSIS
--========================================================--
--  Objective:
-- Evaluate each product's performance, sales history, and lifecycle metrics
-- including recency, lifespan, total orders, and revenue classification.

--========================================================--
-- Step 1: Create Base Query
-- Join Fact and Dimension tables to collect all necessary product attributes
--========================================================--
CREATE VIEW report_products AS
WITH case_query AS (
SELECT 
f.order_number,
f.order_date,
f.customer_key,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
),
product_aggreagtion AS (
SELECT
product_key,
product_name,
subcategory,
category,
cost,
MAX(order_date) as last_sale_date,
DATEDIFF(month,MIN(order_Date),Max(order_date)) AS lifespan,
count(DISTINCT order_number) as total_order,
sum(sales_amount) as total_sales,
count(DISTINCT customer_key) as total_customers,
sum(quantity) as total_quantity
FROM case_query
GROUP BY product_key,product_name,subcategory,category,cost
)
SELECT 
product_key,
product_name,
subcategory,
category,
cost,
last_sale_date,
lifespan,
total_order,
total_sales,
total_customers,
total_quantity,
DATEDIFF(month,last_sale_date,GETDATE()) as recency_in_months,
CASE WHEN total_sales > 50000 THEN 'High_Performer'
	 WHEN total_sales < 50000 THEN 'Mid_range'
	 ELSE 'Low_Performer'
END AS product_segment,
-- Compute average order value (AVO)
CASE WHEN total_order = 0 THEN 0
	 ELSE total_sales / total_order
END AS Avg__order_revenue,
-- Compute average monthly spend
CASE WHEN lifespan = 0 THEN 0
	 ELSE total_sales / lifespan
END AS avg_monthly_revenue
FROM product_aggreagtion
