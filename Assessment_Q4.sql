-- Assessment_Q4.sql
-- Estimates Customer Lifetime Value (CLV) for each customer based on account tenure,
-- total transactions (from savings_savingsaccount), and average profit per transaction.
-- Profit per transaction is 0.1% of the transaction value (confirmed_amount).
-- CLV = (total_transactions / tenure_months) * 12 * avg_profit_per_transaction.
WITH CustomerTransactionStats AS (
  -- Step 1: Calculate total count of value-bearing deposit transactions and
  -- the average value of these transactions for each customer.
  -- Transactions are sourced from savings_savingsaccount.
  -- Transaction values (confirmed_amount) are in kobo and converted to main currency.
  SELECT 
    owner_id, 
    COUNT(id) AS total_transactions_count, 
    -- Calculate average transaction value in the main currency (kobo / 100.0).
    -- This average is based only on transactions with a positive confirmed_amount.
    AVG(confirmed_amount / 100.0) AS avg_transaction_value_main_currency 
  FROM 
    savings_savingsaccount 
  WHERE 
    confirmed_amount > 0 -- Considering only transactions that have a positive value for CLV calculations
    -- (both for the count and for the average value).
  GROUP BY 
    owner_id
) -- Step 2: For each customer, calculate tenure, total transactions, and estimate CLV.
SELECT 
  ucu.id AS customer_id, 
  -- Construct customer name from first_name and last_name.
  CONCAT(
    ucu.first_name, ' ', ucu.last_name
  ) AS name, 
  -- Calculate tenure in whole months from date_joined to current date.
  TIMESTAMPDIFF(
    MONTH, 
    ucu.date_joined, 
    CURDATE()
  ) AS tenure_months, 
  -- Total number of value-bearing deposit transactions for the customer. Defaults to 0 if none.
  COALESCE(cts.total_transactions_count, 0) AS total_transactions, 
  -- Calculate Estimated CLV, rounded to 2 decimal places.
  -- Formula: CLV = (avg_monthly_transactions) * 12 * avg_profit_per_transaction
  -- where avg_profit_per_transaction = 0.001 * avg_transaction_value_main_currency
  ROUND(
    IF(
      -- CLV is calculated only if tenure is positive (at least 1 month)
      -- AND there are positive-value transactions.
      TIMESTAMPDIFF(
        MONTH, 
        ucu.date_joined, 
        CURDATE()
      ) > 0 
      AND COALESCE(cts.total_transactions_count, 0) > 0, 
      (
        -- Avg monthly transactions: (total_transactions / tenure_months)
        -- Ensure floating point division by multiplying total_transactions by 1.0.
        (
          COALESCE(cts.total_transactions_count, 0) * 1.0 / TIMESTAMPDIFF(
            MONTH, 
            ucu.date_joined, 
            CURDATE()
          )
        ) -- Annualize monthly transactions
        * 12 -- Multiply by average profit per transaction.
        -- Avg profit per transaction = 0.1% (0.001) of avg_transaction_value_main_currency.
        -- COALESCE avg_transaction_value_main_currency to 0.0 if the customer has no transactions.
        * (
          0.001 * COALESCE(
            cts.avg_transaction_value_main_currency, 
            0.0
          )
        )
      ), 
      0.0 -- CLV is 0 if tenure is 0 months, no value-bearing transactions, or avg transaction value is 0.
      ), 
    2
  ) AS estimated_clv 
FROM 
  users_customuser ucu 
  LEFT JOIN CustomerTransactionStats cts ON ucu.id = cts.owner_id 
ORDER BY 
  estimated_clv DESC;
