-- C. Data Allocation Challenge
-- 1. running customer balance column that includes the impact each transaction
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

-- 2. customer balance at the end of each month
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

-- 3. minimum, average and maximum values of the running balance for each customer
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
    
-- Option 1: data is allocated based off the amount of money at the end of the previous month
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
        
-- For Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days.
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
        
-- For option 3: data is updated real-time
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