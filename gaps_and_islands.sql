--consecutive positive month-over-month percentage change
WITH monthly_sales AS (
	SELECT split_part(purchase_address, ',', 2) AS city,
	date_trunc('month', order_date) AS mon,
	SUM(quantity * price) AS monthly_sales
	FROM sales
	GROUP BY city, mon
	ORDER BY city, mon),
monthly_growth AS (
	SELECT ROW_NUMBER() OVER() AS rn, city, mon,
	round(monthly_sales / LAG(monthly_sales) OVER(PARTITION BY city ORDER BY mon) - 1, 4) AS net_change
    FROM monthly_sales),
pos_group AS (
	SELECT city, 
	(rn - ROW_NUMBER() OVER(PARTITION BY city ORDER BY mon)) AS grp,
	net_change
    FROM monthly_growth
    WHERE net_change > 0)
SELECT city
FROM pos_group
GROUP BY city, grp
HAVING count(*) >= 2;