# SQL Growth & Sales Analysis — NovaMart Retail

An end-to-end SQL analysis showcasing the sales performance and growth reporting workflow for a retail chain. Built in PostgreSQL using pgAdmin.

---

## Business Context

NovaMart is a mid-size lifestyle and electronics retailer operating across 5 malls — Mall of the Emirates, Dubai Mall, Deira City Centre, Ibn Battuta, and Mirdif City Centre. The commercial and strategy team needs regular reporting on:

- Which stores are growing their revenue and market share over the year
- Which product categories are driving the most revenue and margin per store
- Which customer segments and individuals represent the highest lifetime value
- How transaction basket sizes compare across the store network
- Which stores are gaining ground and which are losing it

This is the workflow of pulling transactional sales data, cleaning it into a relational model, and answering 7 real business questions using SQL.

---

## Database Schema

The analysis is built across 4 related tables:

| Table | Description | Rows |
|---|---|---|
| `stores` | Master list of 5 store locations with size and opening date | 5 |
| `products` | Product catalogue with category, brand, and cost price | 30 |
| `customers` | Customer master with segment, emirate, and registration date | 182 |
| `sales` | Core fact table — one row per transaction with store, product, customer, quantity, unit price, discount, and date | 795 |

**Relationships:**
- `stores` → `sales` (one to many on `store_id`)
- `products` → `sales` (one to many on `product_id`)
- `customers` → `sales` (one to many on `customer_id`)

---

## Business Questions & SQL Techniques

### Q1 — Month-on-Month Sales Growth Per Store
*What are the month-on-month sales growth rates per store across 2024?*

Calculates net revenue per store per month after discounts, then uses LAG to pull the previous month's revenue into the current row. Growth rate is expressed as both an absolute AED difference and a percentage. Each month is classified as GROWTH, DECLINE, or STABLE. Uses NULLIF to guard against division by zero on the first month of the year where no previous value exists.

**Techniques:** CTE · DATE_TRUNC · SUM · LAG window function · PARTITION BY · NULLIF · CASE WHEN classification

---

### Q2 — Revenue and Margin by Product Category Per Store
*Which product categories drive the most revenue and margin per store?*

Joins sales to products to bring in cost price at the transaction level. Calculates gross revenue, discount amount, net revenue, and margin per category per store. Ranks each category within each store by both revenue and margin percentage using DENSE_RANK — so the commercial team can see whether the highest revenue categories are also the most profitable ones.

**Techniques:** Multi table JOIN · CTE · SUM · DENSE_RANK window function · PARTITION BY · Margin % calculation · NULLIF

---

### Q3 — Customer Lifetime Value Ranked by Segment
*Which customers have the highest lifetime value within each segment?*

Aggregates total net revenue and transaction count per customer across the full year. Joins to the customers table to bring in segment. Ranks customers within their segment using DENSE_RANK so Premium, Regular, and Occasional customers are benchmarked against their own peer group rather than the full customer base.

**Techniques:** CTE · JOIN with USING · SUM · COUNT · GROUP BY · DENSE_RANK window function · PARTITION BY segment

---

### Q4 — Average Basket Size Per Store with Transaction Comparison
*What is the average basket size per store and how does each transaction compare against it?*

Calculates net revenue at the transaction level in the first CTE. Uses AVG as a window function partitioned by store to place the store average alongside every individual transaction row without collapsing the data. Each transaction is then classified as OVER, UNDER, or EQUAL relative to its store average, with the AED difference shown.

**Techniques:** CTE · AVG window function · PARTITION BY · ROUND · CASE WHEN · Subquery to reference alias

---

### Q5 — Store Market Share Over the Year
*Which stores are gaining or losing internal revenue share over 2024?*

Calculates each store's monthly net revenue then uses SUM as a window function partitioned by month to get the total across all stores for that month — without a JOIN or second aggregation. Divides each store's revenue by the monthly total to produce market share percentage. LAG then compares this month's share against last month's to show directional movement.

**Techniques:** CTE · SUM window function · PARTITION BY month · LAG · Market share % calculation · NULLIF · CASE WHEN trend classification

---

### Q6 — Next Purchase Date and Days Until Customer Return
*For each transaction, what is the next purchase date for that customer and how many days until they return?*

Uses LEAD partitioned by customer_id and ordered by sale_date to look forward from each transaction to the next one by the same customer. Subtracts the current sale date from the next to produce a return gap in days. Classifies each transaction by return frequency — HIGH FREQUENCY for gaps under 14 days, SLOW RETURNER for gaps under 45 days, and LATEST ACTIVITY where no future transaction exists.

**Techniques:** CTE · LEAD window function · PARTITION BY customer · Date arithmetic · CASE WHEN frequency classification · NULL handling

---

### Q7 — Store Classification as Growth, Stable or Declining
*How should each store be classified based on its full year sales trend?*

Builds monthly net revenue per store then uses LAG to calculate the month-on-month difference for each of the 12 months. Uses filtered aggregation to count how many months each store showed positive versus negative movement. Classifies stores with 8 or more positive months as GROWTH, 8 or more negative months as DECLINING, and everything in between as STABLE — a threshold based classification that reflects the full year trend rather than any single month.

**Techniques:** Multiple CTEs · LAG window function · Filtered aggregation with FILTER (WHERE) · CASE WHEN tiering · Full year trend logic

---

## Key Findings

- **Dubai Mall** and **Mall of the Emirates** consistently generate the highest net revenue and average basket size across all 12 months — driven by Premium segment customers purchasing high ticket Laptops and Smartphones
- **Ibn Battuta** is classified as GROWTH — slow H1 with revenue accelerating significantly from July onward, reflecting a store gaining traction in its catchment area
- **Mirdif City Centre** is classified as DECLINING — strong H1 performance that deteriorated through Q3 and Q4, ending the year as the weakest store in the network
- **Laptops** is the highest margin category across all stores despite not always being the highest revenue category — the gap between revenue rank and margin rank is most visible at Deira City Centre
- **Premium segment customers** account for a disproportionate share of lifetime value relative to their count — a small group driving outsized revenue
- **Occasional customers** show the longest return gaps and cluster heavily in Q4, suggesting they are largely event-driven buyers responding to Black Friday and DSF promotions

---

## Files

```
└── solution_script.sql
```

---

## Tools Used

- **PostgreSQL** — database and query execution
- **pgAdmin 4** — query development and data import
