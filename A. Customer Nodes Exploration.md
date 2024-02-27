## A. Customer Nodes Exploration

**1. How many unique nodes are there on the Data Bank system?**
```sql
SELECT 
    COUNT(DISTINCT node_id) AS number_of_nodes
FROM 
    customer_nodes;
```
**Output:**
| number_of_nodes | 
|-----------------|
| 5               |

**2. What is the number of nodes per region?**
```sql
SELECT
	cn.region_id,
    region_name,
    COUNT(node_id) AS number_of_nodes
FROM
	customer_nodes cn
INNER JOIN 
	regions r ON cn.region_id = r.region_id
GROUP BY 
	region_id, region_name
ORDER BY
	region_id ASC;
```

**Output:**
| region_id | region_name | number_of_nodes |
|-----------|-------------|-----------------|
| 1         | Australia   | 770             |
| 2         | America     | 735             |
| 3         | Africa      | 714             |
| 4         | Asia        | 665             |
| 5         | Europe      | 616             |


**3. How many customers are allocated to each region?**
```sql
SELECT
	cn.region_id,
    region_name,
    COUNT(DISTINCT customer_id) AS number_of_customers
FROM
	customer_nodes cn
INNER JOIN 
	regions r ON cn.region_id = r.region_id
GROUP BY 
	region_id,
    region_name
ORDER BY
	region_id ASC;
```

**Output:**
| region_id | region_name | number_of_customers |
|-----------|-------------|---------------------|
| 1         | Australia   | 110                 |
| 2         | America     | 105                 |
| 3         | Africa      | 102                 |
| 4         | Asia        | 95                  |
| 5         | Europe      | 88                  |

**4. How many days on average are customers reallocated to a different node?**
```sql
SELECT
	ROUND(AVG(days_difference), 2) AS average_reallocation_days
FROM 
	(SELECT 
	DATEDIFF(end_date, start_date) AS days_difference
  FROM 
	customer_nodes
WHERE 
	end_date IS NOT NULL AND end_date NOT LIKE '9999%' -- This is removing invalid dates from the data set which might be because of typing error.
    ) AS reallocation_days; -- Inner sub-query is calculating the difference between start date and end date. And then we are taking the average of those difference values to calculate average reallocation days.
```
**Output:**

| average_reallocation_days | 
|---------------------------|
| 14.63                     |

**5. What is the median, 80th, and 95th percentile for this same reallocation days metric for each region?**
```sql
WITH RankedMetrics AS ( -- Ranking the rows ordered by reallocation days and partitioned by region_id
    SELECT
        region_id,
        DATEDIFF(end_date, start_date) AS reallocation_days,
        PERCENT_RANK() OVER (PARTITION BY region_id ORDER BY DATEDIFF(end_date, start_date)) AS percentile_rank
    FROM customer_nodes
    WHERE 
		end_date IS NOT NULL AND end_date NOT LIKE '9999%'
),
Percentiles AS ( -- Classifying the rows falling into 50th, 80th and 95th percentiles and then using MAX function to pick up only those rows with the highest reallocation days becase we want the highest reallocation days which still fall into our defines category i-e median, 80th or 95th percentile.
    SELECT
        region_id,
        MAX(CASE WHEN percentile_rank <= 0.5 THEN reallocation_days END) OVER (PARTITION BY region_id) AS Median,
        MAX(CASE WHEN percentile_rank <= 0.8 THEN reallocation_days END) OVER (PARTITION BY region_id) AS _80thPercentile,
        MAX(CASE WHEN percentile_rank <= 0.95 THEN reallocation_days END) OVER (PARTITION BY region_id) AS _95thPercentile
    FROM RankedMetrics
)
SELECT 
	DISTINCT p.region_id,
    region_name,
    FIRST_VALUE(Median) OVER (PARTITION BY region_id ORDER BY Median DESC) AS Median, -- when median is ordered in descending order then it is picking last value (it'll will have a percent rank of 0.50 within specified region)
    FIRST_VALUE(_80thPercentile) OVER (PARTITION BY region_id ORDER BY _80thPercentile DESC) AS _80thPercentile, -- when 80th percentile is ordered in descending order then it is picking last value (it'll will have a percent rank of 0.80 within specified region)
    FIRST_VALUE(_95thPercentile) OVER (PARTITION BY region_id ORDER BY _95thPercentile DESC) AS _95thPercentile -- when 95th percentile is ordered in descending order then it is picking last value (it'll will have a percent rank of 0.95 within specified region)
FROM Percentiles p
INNER JOIN regions r ON p.region_id = r.region_id;
```
**Output:**

| region_id | region_name | Median | _80thPercentile | _95thPercentile |
|-----------|-------------|--------|---------------- |---------------- |
| 1         | Australia   | 15     | 23              | 28              |
| 2         | America     | 15     | 23              | 28              |
| 3         | Africa      | 15     | 24              | 28              |
| 4         | Asia        | 15     | 23              | 28              |
| 5         | Europe      | 15     | 24              | 28              |

