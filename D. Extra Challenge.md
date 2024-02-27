### D. Extra Challenge

Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?

#### Special notes:
- Data Bank wants an initial calculation which does not allow for compounding interest, however they may also be interested in a daily compounding interest calculation so you can try to perform this calculation if you have the stamina!

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
    ),
RunningTotal AS (
	SELECT
		customer_id,
        txn_date,
        _transaction,
        SUM(_transaction) OVER (PARTITION BY customer_id ORDER BY txn_date ASC) AS running_total
	FROM 
		transactions_impact
        ),
DailyInterest AS (
	SELECT
		*,
       (running_total * 0.06) / 365 AS daily_interest
	FROM
		RunningTotal
         )
SELECT
	DATE_FORMAT(txn_date, '%Y-%m') AS txn_month,
    ROUND(SUM(CASE WHEN daily_interest < 0 THEN 0 ELSE daily_interest END),2) AS data_required_per_month
FROM
	DailyInterest
GROUP BY
	DATE_FORMAT(txn_date, '%Y-%m')
ORDER BY 
	DATE_FORMAT(txn_date, '%Y-%m') ASC;
```

**Output:**

| txn_month | data_required_per_month |
|-----------|-------------------------|
| 2020-01   | 118.02                  |
| 2020-02   | 157.75                  |
| 2020-03   | 153.65                  |
| 2020-04   | 67.83                   |
