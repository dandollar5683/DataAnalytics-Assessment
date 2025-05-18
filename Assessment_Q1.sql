-- Assessment_Q1.sql
-- Identifies customers with at least one funded savings plan AND one funded investment plan,
-- sorted by their total deposits.
WITH FundedPlansInfo AS (
  -- This CTE identifies all unique plans that have received at least one funding deposit.
  -- It marks whether a plan is a savings or an investment plan.
  SELECT 
    DISTINCT pp.owner_id, 
    pp.id AS plan_id, 
    -- Flag for savings plan based on the 'is_regular_savings' column in plans_plan
    CASE WHEN pp.is_regular_savings = 1 THEN 1 ELSE 0 END AS is_savings_plan_flag, 
    -- Flag for investment plan based on the 'is_a_fund' column in plans_plan
    CASE WHEN pp.is_a_fund = 1 THEN 1 ELSE 0 END AS is_investment_plan_flag 
  FROM 
    plans_plan pp 
    JOIN savings_savingsaccount ssa ON pp.id = ssa.plan_id 
  WHERE 
    ssa.confirmed_amount > 0 -- A plan is considered "funded" if it has at least one deposit with a positive confirmed amount.
    ), 
CustomerPlanCounts AS (
  -- This CTE counts the number of distinct funded savings plans and distinct funded investment plans for each customer.
  SELECT 
    fpi.owner_id, 
    -- Counts distinct savings plans for the owner
    COUNT(
      DISTINCT CASE WHEN fpi.is_savings_plan_flag = 1 THEN fpi.plan_id ELSE NULL END
    ) AS savings_count, 
    -- Counts distinct investment plans for the owner
    COUNT(
      DISTINCT CASE WHEN fpi.is_investment_plan_flag = 1 THEN fpi.plan_id ELSE NULL END
    ) AS investment_count 
  FROM 
    FundedPlansInfo fpi 
  GROUP BY 
    fpi.owner_id
), 
EligibleCustomers AS (
  -- This CTE filters for customers who meet the criteria of having at least one funded savings plan AND at least one funded investment plan.
  SELECT 
    cpc.owner_id, 
    cpc.savings_count, 
    cpc.investment_count 
  FROM 
    CustomerPlanCounts cpc 
  WHERE 
    cpc.savings_count >= 1 
    AND cpc.investment_count >= 1
), 
CustomerTotalDeposits AS (
  -- This CTE calculates the total sum of deposits for each customer.
  -- Deposits are converted from kobo to the main currency unit by dividing by 100.0.
  SELECT 
    ssa.owner_id, 
    SUM(ssa.confirmed_amount / 100.0) AS total_deposits 
  FROM 
    savings_savingsaccount ssa 
  WHERE 
    ssa.confirmed_amount > 0 -- Considers only positive deposit amounts
  GROUP BY 
    ssa.owner_id
) -- Final SELECT statement to retrieve the required information for the report.
-- It joins the eligible customers with their details (name) from users_customuser
-- and their total deposits.
-- The results are ordered by total_deposits in descending order to show high-value customers first.
SELECT 
  uc.id AS owner_id, 
  -- Customer's unique identifier
  -- MODIFIED LINE: Concatenate first_name and last_name for the customer's full name
  CONCAT(uc.first_name, ' ', uc.last_name) AS name, 
  ec.savings_count, 
  -- Count of funded savings plans
  ec.investment_count, 
  -- Count of funded investment plans
  ctd.total_deposits -- Total deposits made by the customer
FROM 
  EligibleCustomers ec 
  JOIN users_customuser uc ON ec.owner_id = uc.id 
  JOIN CustomerTotalDeposits ctd ON ec.owner_id = ctd.owner_id 
ORDER BY 
  ctd.total_deposits DESC;
