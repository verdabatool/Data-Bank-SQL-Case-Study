### C. Data Allocation Challenge

To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

- **Option 1:** data is allocated based on the amount of money at the end of the previous month
- **Option 2:** data is allocated on the average amount of money kept in the account in the previous 30 days
- **Option 3:** data is updated real-time

For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

- running customer balance column that includes the impact of each transaction
- customer balance at the end of each month
- minimum, average, and maximum values of the running balance for each customer

Using all of the data available - how much data would have been required for each option on a monthly basis?


- **running customer balance column that includes the impact of each transaction**
  
Here in this query, we are allocating purchases and withdrawal as negative while deposits as positive.

```sql
WITH transactions_impact AS (
	SELECT
		*,
	CASE 
		WHEN txn_type = 'purchase' OR txn_type = 'withdrawal' THEN txn_amount * -1
		ELSE
			txn_amount
		END AS _transaction
	FROM
		customer_transactions
	ORDER BY customer_id
    )
	SELECT
		customer_id,
        txn_date,
        _transaction,
        SUM(_transaction) OVER (PARTITION BY customer_id ORDER BY txn_date ASC) AS running_total
	FROM 
		transactions_impact;
```

**Output:**
| customer_id | txn_date   | _transaction | running_total |
|-------------|------------|--------------|---------------|
| 1           | 2020-01-02 | 312          | 312           |
| 1           | 2020-03-05 | -612         | -300          |
| 1           | 2020-03-17 | 324          | 24            |
| 1           | 2020-03-19 | -664         | -640          |
| 2           | 2020-01-03 | 549          | 549           |
| 2           | 2020-03-04 | 61           | 610           |
| 3           | 2020-01-27 | 144          | 144           |
| 3           | 2020-02-22 | -965         | -821          |
| 3           | 2020-03-05 | -213         | -1034         |
| 3           | 2020-03-19 | -188         | -1222         |
| 3           | 2020-04-12 | 493          | -729          |

Please note that this output is limited to save up on space.

- **customer balance at the end of each month**
  
```sql
WITH impact AS ( -- It is factoring in the impact of purchase, withdrawal and deposit
	SELECT
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
		CASE
			WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE txn_amount * -1 
            END AS impact_of_transactions
	FROM
		customer_transactions
	GROUP BY
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m'),
        impact_of_transactions
	ORDER BY customer_id ASC
    ),
MonthlyTotal AS ( -- It is calculating the total balance per month
	SELECT 
		customer_id,
		txn_month,
		SUM(impact_of_transactions) AS total_balance
	FROM
		impact
	GROUP BY
		customer_id,
		txn_month
	ORDER BY customer_id ASC
		)
SELECT
	customer_id,
	txn_month,
	SUM(total_balance) OVER (PARTITION BY customer_id ORDER BY txn_month ASC) AS closing_balance
	FROM
		MonthlyTotal;
```

**Output:** 
| customer_id | txn_month | closing_balance |
|-------------|-----------|-----------------|
| 1           | 2020-01   | 312             |
| 1           | 2020-03   | -640            |
| 2           | 2020-01   | 549             |
| 2           | 2020-03   | 610             |
| 3           | 2020-01   | 144             |
| 3           | 2020-02   | -821            |
| 3           | 2020-03   | -1222           |
| 3           | 2020-04   | -729            |

Please note that this output is limited to save up on space.

- **minimum, average, and maximum values of the running balance for each customer**

```sql
WITH transactions_impact AS (
	SELECT
		*,
	CASE 
		WHEN txn_type = 'purchase' OR txn_type = 'withdrawal' THEN txn_amount * -1
		ELSE
			txn_amount
		END AS impact
	FROM
		customer_transactions
    ),
RunningTotal AS (
	SELECT
		*,
        SUM(impact) OVER (PARTITION BY customer_id ORDER BY txn_date ASC) AS running_total
	FROM 
		transactions_impact
	)
SELECT
	customer_id,
	MIN(running_total) AS miminum_running_balance,
    MAX(running_total) AS maximum_running_balance,
    ROUND(AVG(running_total),1) AS average_running_balance
FROM 
	RunningTotal
GROUP BY
	customer_id;
```

**Output:**
| customer_id | minimum_running_balance | maximum_running_balance | average_running_balance |
|-------------|-------------------------|-------------------------|------------------------|
| 1           | -640                    | 312                     | -151.0                 |
| 2           | 549                     | 610                     | 579.5                  |
| 3           | -1222                   | 144                     | -732.4                 |
| 4           | 458                     | 848                     | 653.7                  |
| 5           | -2413                   | 1780                    | -135.5                 |
| 6           | -552                    | 2197                    | 624.0                  |
| 7           | 887                     | 3539                    | 2268.7                 |

Please note that this output is limited to save up on space.

Using all of the data available - how much data would have been required for each option on a monthly basis?

- **Option 1: Data is allocated based on the amount of money at the end of the previous month**
```sql
WITH impact AS ( -- It is factoring in the impact of purchase, withdrawal and deposit
	SELECT
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
		CASE
			WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE txn_amount * -1 
            END AS impact_of_transactions
	FROM
		customer_transactions
	GROUP BY
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m'),
        impact_of_transactions
	ORDER BY customer_id ASC
    ),
MonthlyTotal AS ( -- It is calculating the total balance per month
	SELECT 
		customer_id,
		txn_month,
		SUM(impact_of_transactions) AS total_balance
	FROM
		impact
	GROUP BY
		customer_id,
		txn_month
	ORDER BY customer_id ASC
		),
ClosingBalance AS ( -- It is calculating current month closing balance
	SELECT
		customer_id,
		txn_month,
		SUM(total_balance) OVER (PARTITION BY customer_id, txn_month ORDER BY txn_month ASC) AS current_month_closing_balance
	FROM
		MonthlyTotal
     ),
PreviousMonthClosing AS ( -- It is calculating the closing balance for previous month
    SELECT
        customer_id,
        txn_month,
        current_month_closing_balance,
        LAG(current_month_closing_balance, 1, current_month_closing_balance) OVER (PARTITION BY customer_id ORDER BY txn_month) AS last_month_closing_balance
    FROM
        ClosingBalance
        )
	SELECT
		txn_month,
	SUM(CASE
		WHEN last_month_closing_balance < 0 THEN 0
        ELSE last_month_closing_balance
	END) AS data_needed_per_month
	FROM 
		PreviousMonthClosing
	GROUP BY
		txn_month
	ORDER BY 
		txn_month ASC;
```

**Output:**
| txn_month | data_needed_per_month |
|-----------|-----------------------|
| 2020-01   | 234940                |
| 2020-02   | 211924                |
| 2020-03   | 142858                |
| 2020-04   | 91765                 |


- **Option 2: Data is allocated on the average amount of money kept in the account in the previous 30 days**

```sql
WITH impact AS ( -- It is factoring in the impact of purchase, withdrawal and deposit
	SELECT
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
		CASE
			WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE txn_amount * -1 
            END AS impact_of_transactions
	FROM
		customer_transactions
	GROUP BY
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m'),
        impact_of_transactions
	ORDER BY customer_id ASC
    ),
MonthlyTotal AS ( -- It is calculating the total balance per month
	SELECT 
		customer_id,
		txn_month,
		SUM(impact_of_transactions) AS total_balance
	FROM
		impact
	GROUP BY
		customer_id,
		txn_month
	ORDER BY customer_id ASC
		),
ClosingBalance AS ( -- It is calculating current month closing balance
	SELECT
		customer_id,
		txn_month,
		SUM(total_balance) OVER (PARTITION BY customer_id, txn_month ORDER BY txn_month ASC) AS current_month_closing_balance
	FROM
		MonthlyTotal
     ),
PreviousMonthClosing AS ( -- It is calculating the closing balance for previous month
    SELECT
        customer_id,
        txn_month,
        current_month_closing_balance,
        LAG(current_month_closing_balance, 1, current_month_closing_balance) OVER (PARTITION BY customer_id ORDER BY txn_month) AS last_month_closing_balance
    FROM
        ClosingBalance
        )
	SELECT
		txn_month,
	ROUND(AVG(CASE
		WHEN last_month_closing_balance < 0 THEN 0
        ELSE last_month_closing_balance
	END), 2) AS data_needed_per_month
	FROM 
		PreviousMonthClosing
	GROUP BY
		txn_month
	ORDER BY 
		txn_month ASC;
```

**Output:**

| txn_month | data_needed_per_month |
|-----------|-----------------------|
| 2020-01   | 469.88                |
| 2020-02   | 465.77                |
| 2020-03   | 313.29                |
| 2020-04   | 296.97                |


- **Option 3: Data is updated real-time**

```sql
WITH transactions_impact AS (
	SELECT
		*,
	CASE 
		WHEN txn_type = 'purchase' OR txn_type = 'withdrawal' THEN txn_amount * -1
		ELSE
			txn_amount
		END AS txn_impact
	FROM
		customer_transactions
	ORDER BY customer_id
    ),
RunningTotal AS (
	SELECT
		customer_id,
        txn_date,
        txn_impact,
        SUM(txn_impact) OVER (PARTITION BY customer_id ORDER BY txn_date ASC) AS running_total
	FROM 
		transactions_impact
	),
RealTimeDataRequirement AS (
	SELECT
		customer_id,
		DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
		running_total,
		CASE WHEN running_total < 0 THEN 0 ELSE running_total
		END AS required_data
	FROM
		RunningTotal
		)
	SELECT
		txn_month,
        SUM(required_data) AS data_needed_per_month
	FROM
		RealTimeDataRequirement
	GROUP BY
		txn_month
	ORDER BY txn_month ASC;
```

**Output:**

| txn_month | data_needed_per_month |
|-----------|-----------------------|
| 2020-01   | 717947                |
| 2020-02   | 959673                |
| 2020-03   | 934717                |
| 2020-04   | 412635                |

