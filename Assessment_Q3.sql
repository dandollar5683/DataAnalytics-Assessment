-- Assessment_Q3.sql
-- Finds all active savings or investment plans that have had no inflow transactions for over one year (365 days).
-- "No inflow transactions for over one year" means either:
-- 1. The last inflow transaction was more than 365 days ago from the current date.
-- 2. The plan was created more than 365 days ago from the current date and has never had an inflow transaction.
-- Current Date for calculation is the date the query is run (MySQL's CURDATE()).
WITH LastInflowTransactionPerPlan AS (
  -- Step 1: Find the date of the last inflow transaction for each plan.
  -- An inflow transaction is defined as a record in savings_savingsaccount with confirmed_amount > 0.
  SELECT 
    plan_id, 
    MAX(transaction_date) AS last_inflow_tx_date 
  FROM 
    savings_savingsaccount 
  WHERE 
    confirmed_amount > 0 -- Ensures we are looking at actual inflow transactions.
  GROUP BY 
    plan_id
) -- Step 2: Select relevant plan details, calculate inactivity, and apply filters.
SELECT 
  pp.id AS plan_id, 
  -- Plan's unique identifier
  pp.owner_id, 
  -- Owner's unique identifier
  -- Determine the type of the plan (Savings or Investment).
  -- If a plan is marked as both, 'Savings' will be prioritized here.
  CASE WHEN pp.is_regular_savings = 1 THEN 'Savings' WHEN pp.is_a_fund = 1 THEN 'Investment' -- This 'ELSE' case should ideally not be reached if the WHERE clause correctly filters plan types.
  ELSE 'Unknown' END AS type, 
  -- Display the date of the last inflow transaction (if any). Cast to DATE for consistent format.
  DATE(litp.last_inflow_tx_date) AS last_transaction_date, 
  -- Calculate inactivity_days:
  -- If a last inflow transaction exists, it's the number of days from that transaction to CURDATE().
  -- If no inflow transactions ever, it's the number of days from the plan's creation date to CURDATE().
  CASE WHEN litp.last_inflow_tx_date IS NOT NULL THEN DATEDIFF(
    CURDATE(), 
    DATE(litp.last_inflow_tx_date)
  ) ELSE DATEDIFF(
    CURDATE(), 
    DATE(pp.created_on)
  ) -- pp.created_on is DATETIME, cast to DATE for DATEDIFF.
  END AS inactivity_days 
FROM 
  plans_plan pp 
  LEFT JOIN LastInflowTransactionPerPlan litp ON pp.id = litp.plan_id 
WHERE 
  -- Filter 1: Plan must be a Savings plan (is_regular_savings = 1) OR an Investment plan (is_a_fund = 1).
  (
    pp.is_regular_savings = 1 
    OR pp.is_a_fund = 1
  ) -- Filter 2: Plan must be "active".
  -- This is an assumption based on common practice: active means not archived AND not deleted.
  -- If 'status_id' in 'plans_plan' specifically denotes active plans, that condition should be used instead/additionally.
  AND pp.is_archived = 0 
  AND pp.is_deleted = 0 -- Filter 3: The plan meets the inactivity criteria (no inflow transactions for over 365 days).
  AND (
    -- Case A: The plan has had inflow transactions, but the last one was more than 365 days ago.
    (
      litp.last_inflow_tx_date IS NOT NULL 
      AND DATEDIFF(
        CURDATE(), 
        DATE(litp.last_inflow_tx_date)
      ) > 365
    ) 
    OR -- Case B: The plan has never had any inflow transactions AND it was created more than 365 days ago.
    -- This ensures new plans without transactions yet are not incorrectly flagged.
    (
      litp.last_inflow_tx_date IS NULL 
      AND DATEDIFF(
        CURDATE(), 
        DATE(pp.created_on)
      ) > 365
    )
  ) 
ORDER BY 
  inactivity_days DESC, 
  plan_id;
