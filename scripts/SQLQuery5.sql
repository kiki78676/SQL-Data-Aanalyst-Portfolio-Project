

--GROUP customers into three segments based on their spending behaviour
-- VIP: at least 12 months of history and spending more than $5000
-- Regular : at least 12 months of history but spending less than 5000$
-- New : lifespan less than 12 months


--========================================================--
-- 7️  CUSTOMER REPORTING DASHBOARD (RFM & LIFESPAN)
--========================================================--
-- CUSTOMER REPORTING
CREATE VIEW report_customers AS
WITH base_query AS (
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name,' ',c.last_name) as customer_name,
DATEDIFF(year,c.birthdate,GETDATE()) AS Age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
On f.customer_key = c.customer_key
WHERE f.order_date IS NOT NULL
),customer_aggregation AS (
SELECT 
customer_key,
customer_number,
customer_name,
Age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) as total_sales,
sum(quantity) as total_quantity,
COUNT(DISTINCT product_key) as total_products,
MAX(order_date) AS last_order,
DATEDIFF(month,MIN(order_date),MAX(order_date)) AS lifespan
FROM base_query
GROUP BY customer_key,customer_number,customer_name,age
)
SELECT
customer_key,
customer_number,
customer_name,
Age,
CASE WHEN age < 20 THEN 'Under 20'
	 WHEN age between 20 and 29 THEN '20-29'
	 WHEN age between 30 and 39 THEN '30-39'
	 WHEN age between 40 and 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
     WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'REGULAR'
	 ELSE 'NEW'
	 END customer_segment,
last_order,
DATEDIFF(month,last_order,GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_products,
lifespan,
-- Compute average order value (AVO)
CASE WHEN total_orders = 0 THEN 0
	 ELSE total_sales / total_orders
END AS avg_order_value,
-- Compute average monthly spend
CASE WHEN lifespan = 0 THEN 0
	 ELSE total_sales / lifespan
END AS avg_monthly_spending
FROM customer_aggregation

