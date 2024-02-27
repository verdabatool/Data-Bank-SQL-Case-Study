## B. Customer Transactions
**1. What is the unique count and total amount for each transaction type?**
```sql
SELECT
	txn_type,
    COUNT(customer_id) AS number_of_customers,
    SUM(txn_amount) AS total_amount
FROM
	customer_transactions
GROUP BY 
	txn_type;
```

**Output:**

| txn_type   | number_of_customers | total_amount |
|------------|---------------------|--------------|
| deposit    | 2671                | 1359168      |
| withdrawal | 1580                | 793003       |
| purchase   | 1617                | 806537       |


**2. What is the average total historical deposit counts and amounts for all customers?**

```sql
SELECT
    txn_type,
    AVG(deposit_count) AS average_deposit_count,
    AVG(deposit_amount) AS average_deposit_amount
FROM (
	SELECT 
		customer_id,
		txn_type,
		COUNT(*) AS deposit_count,
		SUM(txn_amount) AS deposit_amount
	FROM 
		customer_transactions
	WHERE
		txn_type = 'deposit'
	GROUP BY
		customer_id, txn_type
        ) deposits
GROUP BY
	txn_type;
```

**Output:**

| txn_type | average_deposit_count | average_deposit_amount |
|----------|-----------------------|------------------------|
| deposit  | 5.3420                | 2718.3360              |


**3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?**

```sql
WITH TransactionsCount AS ( -- It is counting the number of transactions made my each customer per month for each category
    SELECT
        customer_id,
        DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
        COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_count,
        COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_count,
        COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_count
    FROM 
        customer_transactions
    GROUP BY
        customer_id,
        DATE_FORMAT(txn_date, '%Y-%m')
	 ORDER BY
		customer_id ASC
)
SELECT 
    txn_month,
    COUNT(customer_id) AS customers_meeting_criteria
FROM
    TransactionsCount
WHERE 
    deposit_count > 1 AND (purchase_count >= 1 OR withdrawal_count >= 1) -- counting customers who made more than one deposit and at least one purchase or at least one withdrawal in a single month.
GROUP BY
    txn_month
ORDER BY
    txn_month ASC;
```

**Output:**

| txn_month | customers_meeting_criteria |
|-----------|----------------------------|
| 2020-01   | 168                        |
| 2020-02   | 181                        |
| 2020-03   | 192                        |
| 2020-04   | 70                         |


**4. What is the closing balance for each customer at the end of the month?**

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

Please note that this output is limited to save the space.
**5. What is the percentage of customers who increase their closing balance by more than 5%?**

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
ClosingBalance AS ( -- It is calculating closing balance
	SELECT
		customer_id,
		txn_month,
		SUM(total_balance) OVER (PARTITION BY customer_id ORDER BY txn_month ASC) AS closing_balance
	FROM
		MonthlyTotal
    ),
PreviousMonthClosing AS ( -- It is calculating the closing balance for previous month
    SELECT
        customer_id,
        txn_month,
        closing_balance,
        LAG(closing_balance, 1) OVER (PARTITION BY customer_id ORDER BY txn_month) AS last_month_closing_balance
    FROM
        ClosingBalance
),
PercentageIncrease AS (
	SELECT
		customer_id,
		txn_month,
		closing_balance,
		last_month_closing_balance,
		CASE
			WHEN last_month_closing_balance IS NULL OR last_month_closing_balance = 0 THEN NULL
			ELSE (closing_balance - last_month_closing_balance) / last_month_closing_balance * 100
		END AS percentage_increase
	FROM
		PreviousMonthClosing
	)
SELECT 
    ROUND(COUNT(DISTINCT customer_id) / (SELECT (COUNT(DISTINCT customer_id)) FROM customer_transactions) * 100, 2) AS percentage_of_customers
FROM
	PercentageIncrease
WHERE 
percentage_increase >= 5.00;
```

**Output:**

| percentage_of_customers |
|-------------------------|
| 76                      |
