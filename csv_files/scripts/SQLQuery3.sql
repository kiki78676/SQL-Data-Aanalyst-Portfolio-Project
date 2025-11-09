--========================================================--
-- 1️  SALES TRENDS OVER TIME (MONTHLY & YEARLY ANALYSIS)
--========================================================--

-- Monthly Trends

SELECT 
YEAR(order_date) as order_year,
MONTH(order_date) as order_months,
sum(sales_amount) as total_sales,
count(DISTINCT customer_key) as total_coustomer,
sum(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date),MONTH(order_date)
ORDER BY YEAR(order_date),MONTH(order_date)

-- Monthly Trends (Using DATETRUNC)
SELECT 
DATETRUNC(month,order_date) as order_date,
sum(sales_amount) as total_sales,
count(DISTINCT customer_key) as total_coustomer,
sum(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
ORDER BY DATETRUNC(month,order_date)

-- Yearly Trends
SELECT 
DATETRUNC(year,order_date) as order_date,
sum(sales_amount) as total_sales,
count(DISTINCT customer_key) as total_coustomer,
sum(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year,order_date)
ORDER BY DATETRUNC(year,order_date)

--Cumulative Analysis --
--calculate the total sales per months and the running
--total of sales over time

--========================================================--
-- 2️  CUMULATIVE SALES ANALYSIS (RUNNING TOTAL)
--========================================================--

-- Monthly Cumulative Sales
SELECT 
order_date,
total_sales,
sum(total_sales) OVER (ORDER BY order_date) as cumulative
FROM (
SELECT 
DATETRUNC(month,order_date) as order_date,
sum(sales_amount) as total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
) t
--calculate the total sales per months and the running
--total of sales over time
-- Yearly Cumulative Sales
SELECT
order_date,
total_sales,
sum(total_sales) OVER (ORDER BY order_date) as cumulative
FROM (
SELECT 
DATETRUNC(year,order_date) as order_date,
sum(sales_amount) as total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year,order_date)
) t

--calculate the the moving average price
--of price over time

--========================================================--
-- 3️  MOVING AVERAGE ANALYSIS (PRICE OVER TIME)
--========================================================--

SELECT order_date,
avg_price,
AVG(avg_price) OVER (ORDER BY order_date) as moving_average
FROM(
SELECT 
DATETRUNC(month,order_date) AS order_date,
AVG(price) as avg_price
FROM gold.fact_sales
WHERE order_date is NOT NULL
GROUP BY DATETRUNC(month,order_date)
)t

--Performace Analysis --
--========================================================--
-- 4️  PERFORMANCE ANALYSIS (BY PRODUCT AND YEAR)
--========================================================--

;WITH yearly_product_sales AS (
SELECT 
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
order_year,
product_name,
current_total_sales,
AVG(current_total_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_total_sales - AVG(current_total_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_total_sales - AVG(current_total_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
	 WHEN current_total_sales - AVG(current_total_sales) OVER (PARTITION BY product_name)< 0 THEN 'Below Averagae'
	 ELSE 'Average'
END average_change,
LAG(current_total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_sales,
current_total_sales - LAG(current_total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_prevyear,
CASE WHEN current_total_sales - LAG(current_total_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	 WHEN current_total_sales - LAG(current_total_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	 ELSE 'No Change'
END py_change
FROM yearly_product_sales
ORDER BY product_name,order_year

--PART TO WHOLE ANALYSIS
--WHICH categories contribute the most to overall sales?
--========================================================--
-- 5️  PART-TO-WHOLE ANALYSIS (CATEGORY CONTRIBUTION)
--========================================================--

;WITH category_sales AS (
SELECT 
p.category,
sum(f.sales_amount) as total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
on f.product_key = p.product_key
GROUP BY category
)
SELECT 
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100,2),'%') AS percentage_of_total
FROM category_sales
ORDER BY percentage_of_total DESC

--Data Segmentation
--Segment products into cost ranges and
--count how many products falls into each segment

--========================================================--
-- 6️  DATA SEGMENTATION (PRODUCT & CUSTOMER SEGMENTS)
--========================================================--

-- A. Product Cost Range Segmentation

;WITH product_segment AS (
SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'ABOVE 1000'
END cost_range
FROM gold.dim_products
)
SELECT 
cost_range,
count(product_key) as total_products
FROM product_segment
GROUP BY cost_range
ORDER by total_products DESC

-- B. Customer Spending Segmentation

; WITH category_table AS (
SELECT 
c.customer_key,
CONCAT(sum(f.sales_amount),'$') AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month,MIN(order_date),MAX(order_date)) AS lifespan,
CASE WHEN DATEDIFF(month,MIN(order_date),MAX(order_date)) >= 12 AND CONCAT(sum(f.sales_amount),'$') > '5000$' THEN 'VIP'
     WHEN DATEDIFF(month,MIN(order_date),MAX(order_date)) >= 12 AND CONCAT(sum(f.sales_amount),'$') <= '5000$' THEN 'REGULAR'
	 ELSE 'NEW'
	 END AS Category
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)
SELECT Category AS customer_segment,
COUNT(customer_key) AS total_customers
FROM category_table
GROUP BY category
ORDER BY total_customers
