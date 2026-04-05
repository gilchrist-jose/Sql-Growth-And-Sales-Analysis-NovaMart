Schema - 

CREATE TABLE stores (
	store_id INT NOT NULL PRIMARY KEY,
	store_name VARCHAR(50) NOT NULL,
	"location" VARCHAR(50) NOT NULL,
	size_sqft INT NOT NULL CHECK (size_sqft > 0),
	opening_date DATE NOT NULL
);

CREATE TABLE products (
	product_id INT NOT NULL PRIMARY KEY,
	product_name VARCHAR(200) NOT NULL,
	category VARCHAR(50) NOT NULL,
	brand VARCHAR(50) NOT NULL,
	cost_price NUMERIC(10,2) NOT NULL CHECK (cost_price > 0)
);

CREATE TABLE customers (
	customer_id INT NOT NULL PRIMARY KEY,
	customer_name VARCHAR(100) NOT NULL,
	segment VARCHAR(50) NOT NULL CHECK (segment IN ('Premium','Regular','Occasional')),
	emirate VARCHAR(50) NOT NULL CHECK (emirate IN ('Dubai','Abu Dhabi','Sharjah','RAK','Ajman')),
	registration_date DATE NOT NULL
);

CREATE TABLE sales (
	sale_id INT NOT NULL PRIMARY KEY,
	store_id INT NOT NULL REFERENCES stores(store_id),
	product_id INT NOT NULL REFERENCES products(product_id),
	customer_id INT NOT NULL REFERENCES customers(customer_id),
	quantity INT NOT NULL CHECK (quantity > 0),
	unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
	discount_pct NUMERIC(5,2) NOT NULL,
	sale_date DATE NOT NULL
);










---- What are the month-on-month sales growth rates per store? ----


WITH the_net_revenue AS (
SELECT
	TO_CHAR(sale_date,'YYYY-MM') AS "month",
	store_id,
	product_id,
	quantity,
	unit_price,
	discount_pct,
	(unit_price * quantity) AS gross_revenue,
	(ROUND((discount_pct/100.0) * (unit_price * quantity),2)) AS discount_amount,
	(ROUND((unit_price * quantity) - ((discount_pct/100.0) * (unit_price * quantity)),2)) AS net_revenue
FROM sales
),
the_mom_difference AS (
SELECT 
	store_id,
	"month",
	SUM(net_revenue) AS total_net_revenue,
	LAG(SUM(net_revenue)) OVER(PARTITION BY store_id ORDER BY "month") AS last_month_total_net_revenue
FROM the_net_revenue
GROUP BY store_id,"month"
)
SELECT 
	store_id,
	"month",
	total_net_revenue,
	last_month_total_net_revenue,
	total_net_revenue - last_month_total_net_revenue AS mom_difference,
	ROUND((total_net_revenue - last_month_total_net_revenue)*100.00/NULLIF(last_month_total_net_revenue,0),2) AS pct_difference,
	CASE
		WHEN ROUND((total_net_revenue - last_month_total_net_revenue)*100.00/NULLIF(last_month_total_net_revenue,0),2) > 0 THEN '▲ GROWTH'
		WHEN ROUND((total_net_revenue - last_month_total_net_revenue)*100.00/NULLIF(last_month_total_net_revenue,0),2) < 0 THEN '▼ DECLINE'
		ELSE '- STABLE'
	END AS trend_status	
FROM the_mom_difference
ORDER BY store_id,"month";


---- Which product categories drive the most revenue and margin per store? ----

WITH transaction_details AS (
SELECT 
	sale_id,
	s.store_id,
	p.product_id,
	p.category,
	s.quantity,
	s.unit_price,
	p.cost_price,
	(s.quantity * p.cost_price) AS total_cost_price,
	(s.quantity * s.unit_price) AS gross_revenue,
	(ROUND((discount_pct/100.0) * (unit_price * quantity),2)) AS discount_amount,
	(ROUND((unit_price * quantity) - ((discount_pct/100.0) * (unit_price * quantity)),2)) AS net_revenue
FROM sales AS s
JOIN products AS p
ON s.product_id = p.product_id
),
category_store_summary AS (
SELECT 
	store_id,
	category,
	SUM(net_revenue) AS revenue,
	SUM(total_cost_price) AS costing,
	SUM(net_revenue) - SUM(total_cost_price) AS margin
FROM transaction_details
GROUP BY store_id, category
)
SELECT 
	store_id,
	category,
	revenue,
	DENSE_RANK() OVER(PARTITION BY store_id ORDER BY revenue DESC) AS revenue_ranking,
	costing,
	margin,
	ROUND((margin/NULLIF(revenue,0)*100.00),2) AS margin_pct,
	DENSE_RANK() OVER(PARTITION BY store_id ORDER BY (margin/NULLIF(revenue,0)*100.00) DESC) AS margin_ranking
FROM category_store_summary
ORDER BY store_id, margin_ranking;


---- Rank customers by lifetime value within each customer segment ----

WITH part_1 AS (
SELECT
	sale_id,
	customer_id,
	quantity,
	unit_price,
	(quantity * unit_price) AS gross_revenue,
	ROUND((discount_pct/100.00)*NULLIF((quantity * unit_price),0),2) AS discount_amount,
	(quantity * unit_price) - ROUND((discount_pct/100.00)*NULLIF((quantity * unit_price),0),2) AS net_revenue
FROM sales
),
part2 AS (
SELECT
	c.customer_id,
	c.customer_name,
	COUNT(*) AS total_orders,
	c.segment,
	SUM(net_revenue) AS total_revenue
FROM part_1 AS p1
JOIN customers AS c
USING (customer_id)
GROUP BY c.customer_id, c.customer_name, c.segment
)
SELECT
	customer_id,
	customer_name,
	total_orders,
	segment,
	total_revenue,
	DENSE_RANK() OVER(PARTITION BY segment ORDER BY total_revenue DESC) AS ltv_rank
FROM part2
ORDER BY segment;


---- What is the average basket size per store and how does each transaction compare? ----

WITH part1 AS (
SELECT
	sale_id,
	store_id,
	(quantity * unit_price) - ROUND((discount_pct/100.00)*NULLIF((quantity * unit_price),0),2) AS net_revenue
FROM sales
)
SELECT
	sale_id,
	store_id,
	net_revenue,
	ROUND(AVG(net_revenue) OVER(PARTITION BY store_id),2) AS aov,
	CASE
		WHEN ROUND(AVG(net_revenue) OVER(PARTITION BY store_id),2) > net_revenue THEN 'UNDER'
		WHEN ROUND(AVG(net_revenue) OVER(PARTITION BY store_id),2) < net_revenue THEN 'OVER'
		ELSE 'EQUAL'
	END AS vs_aov	
FROM part1
ORDER BY store_id, net_revenue DESC;


---- Which stores are gaining or losing market share over the year? ----

WITH monthly_net_revenue AS (
SELECT 
	store_id,
	TO_CHAR(sale_date,'YYYY-MM') AS "month",
	SUM(ROUND((quantity * unit_price) - ((discount_pct/100.00) * (quantity * unit_price)),2)) AS store_net_revenue
FROM sales
GROUP BY store_id,"month"
),
storewise_share AS (
SELECT
	store_id,
	"month",
	store_net_revenue,
	SUM(store_net_revenue) OVER(PARTITION BY "month") AS monthwise_net_revenue,
	ROUND((store_net_revenue/SUM(store_net_revenue) OVER(PARTITION BY "month"))*100.0,2) AS share_pct
FROM monthly_net_revenue
),
monthly_trend AS (
SELECT 
	store_id,
	"month",
	monthwise_net_revenue,
	share_pct,
	(share_pct - LAG(share_pct) OVER(PARTITION BY store_id ORDER BY "month")) AS trend
FROM storewise_share
)
SELECT
	store_id,
	"month",
	monthwise_net_revenue,
	share_pct,
	trend,
	CASE 
		WHEN trend > 0 THEN 'UPWARDS'
		WHEN trend < 0 THEN 'DOWNWARDS'
		ELSE 'STABLE'
	END AS verdict	
FROM monthly_trend
ORDER BY store_id, "month";


---- For each transaction, what is the next purchase date for that customer and how many days until they return? ----

WITH customer_journey AS (
SELECT 
	sale_id,
	customer_id,
	customer_name,
	sale_date,
	LEAD(sale_date) OVER(PARTITION BY customer_id ORDER BY sale_date) AS next_sale_date,
	LEAD(sale_date) OVER(PARTITION BY customer_id ORDER BY sale_date) - sale_date AS gap
FROM sales
JOIN customers
USING (customer_id)
)
SELECT 
	sale_id,
	customer_id,
	customer_name,
	sale_date,
	next_sale_date,
	gap,
	CASE
    	WHEN gap IS NULL THEN 'LATEST ACTIVITY'
    	WHEN gap <= 14 THEN 'HIGH FREQUENCY'
   		WHEN gap <= 45 THEN 'SLOW RETURNER'
    	ELSE 'REGULAR'
	END AS frequency_band
FROM customer_journey
ORDER BY customer_id, sale_date;


---- Classify stores as Growth, Stable, or Declining based on sales trend ----

WITH part1 AS (
SELECT 
	store_id,
	TO_CHAR(sale_date,'YYYY-MM') AS "month",
	(ROUND((unit_price * quantity) - ((discount_pct/100.0) * (unit_price * quantity)),2)) AS net_revenue
FROM sales
),
part2 AS (
SELECT
	store_id,
	"month",
	SUM(net_revenue) AS monthly_revenue
FROM part1
GROUP BY store_id,"month"
ORDER BY store_id,"month"
),
part3 AS (
SELECT
	store_id,
	"month",
	monthly_revenue,
	LAG(monthly_revenue) OVER(PARTITION BY store_id ORDER BY "month") AS last_month_revenue,
	monthly_revenue - LAG(monthly_revenue) OVER(PARTITION BY store_id ORDER BY "month") AS difference
FROM part2
),
part4 AS (
SELECT 
	store_id,
	COUNT(CASE WHEN difference > 0 THEN 1 END) AS positive_months,
	COUNT(CASE WHEN difference < 0 THEN 1 END) AS negative_months,
	COUNT(CASE WHEN difference = 0 THEN 1 END) AS stable_months
FROM part3
GROUP BY store_id
)
SELECT
	store_id,
	positive_months,
	negative_months,
	stable_months,
	CASE
		WHEN positive_months >= 8 THEN 'GROWTH'
        WHEN negative_months >= 8 THEN 'DECLINING'
		WHEN positive_months > 4 AND negative_months > 4 THEN 'VOLATILE'
		ELSE'STABLE'
	END AS store_classification	
FROM part4;


