-- Assessment_Q2.sql
-- Calculates the average number of transactions per customer per month and categorizes them
-- into High, Medium, or Low frequency groups.
WITH MonthlyTransactionCountsPerCustomer AS (
  -- Step 1: Calculate the number of transactions for each customer for each month they had activity.
  -- 'Activity' is defined by having records in the savings_savingsaccount table.
  SELECT 
    owner_id, 
    YEAR(transaction_date) AS tx_year, 
    MONTH(transaction_date) AS tx_month, 
    -- COUNT(id) counts the number of deposit transactions in that month for that customer.
    -- 'id' is the primary key of savings_savingsaccount.
    COUNT(id) AS monthly_tx_count 
  FROM 
    savings_savingsaccount 
  GROUP BY 
    owner_id, 
    tx_year, 
    tx_month
), 
AverageMonthlyTransactionsPerCustomer AS (
  -- Step 2: For each customer who had transactions, calculate their average number of transactions
  -- across the months they were active.
  -- Casting monthly_tx_count to a decimal type before AVG ensures floating point arithmetic.
  SELECT 
    owner_id, 
    AVG(
      CAST(
        monthly_tx_count AS DECIMAL(10, 2)
      )
    ) AS avg_tx_per_month_for_customer 
  FROM 
    MonthlyTransactionCountsPerCustomer 
  GROUP BY 
    owner_id
), 
CustomersWithCategory AS (
  -- Step 3: Include all customers from the users_customuser table.
  -- For those with transaction activity, use their calculated average monthly transactions.
  -- For those with no transactions, their average is considered 0.
  -- Then, assign a frequency category based on this average.
  SELECT 
    ucu.id AS owner_id, 
    -- Use COALESCE to set avg monthly transactions to 0.0 for customers with no prior transactions.
    COALESCE(
      amtpc.avg_tx_per_month_for_customer, 
      0.0
    ) AS final_avg_tx_per_month, 
    CASE WHEN COALESCE(
      amtpc.avg_tx_per_month_for_customer, 
      0.0
    ) >= 10 THEN 'High Frequency' -- Catches averages from 3.0 up to (but not including) 10.0
    WHEN COALESCE(
      amtpc.avg_tx_per_month_for_customer, 
      0.0
    ) >= 3 THEN 'Medium Frequency' -- Catches averages less than 3.0 (e.g., 0, 1.5, 2.9)
    ELSE 'Low Frequency' END AS frequency_category 
  FROM 
    users_customuser ucu 
    LEFT JOIN AverageMonthlyTransactionsPerCustomer amtpc ON ucu.id = amtpc.owner_id
) -- Step 4: Final aggregation to get the count of customers in each category
-- and the overall average of 'average monthly transactions' for customers in that category.
SELECT 
  cwc.frequency_category, 
  COUNT(cwc.owner_id) AS customer_count, 
  -- Calculate the average of the individual customer averages for the category,
  -- rounded to one decimal place as per the expected output (e.g., 15.2, 5.5).
  ROUND(
    AVG(cwc.final_avg_tx_per_month), 
    1
  ) AS avg_transactions_per_month 
FROM 
  CustomersWithCategory cwc 
GROUP BY 
  cwc.frequency_category 
ORDER BY 
  -- Order the results to match the example output (High, Medium, Low).
  CASE cwc.frequency_category WHEN 'High Frequency' THEN 1 WHEN 'Medium Frequency' THEN 2 WHEN 'Low Frequency' THEN 3 ELSE 4 -- Fallback, should not be reached with the defined categories
  END;
