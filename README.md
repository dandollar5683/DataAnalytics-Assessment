# DataAnalytics-Assessment

# Data Analytics SQL Assessment

This repository contains the SQL solutions for the Data Analyst Assessment. Each question is addressed in a separate `.sql` file, and this README provides explanations for the approach taken for each question, as well as a summary of challenges encountered.

## Per-Question Explanations

### Question 1: High-Value Customers with Multiple Products (`Assessment_Q1.sql`)

* **Goal:** Identify customers who have at least one funded savings plan AND one funded investment plan, ordered by their total deposits.
* **Approach:**
    1.  **`FundedPlansInfo` CTE:** Identified all unique plans (both savings and investment types) for each customer that had at least one "funding" transaction. A plan was considered "funded" if it had a corresponding record in `savings_savingsaccount` with `confirmed_amount > 0`. Savings plans were identified by `plans_plan.is_regular_savings = 1` and investment plans by `plans_plan.is_a_fund = 1`.
    2.  **`CustomerPlanCounts` CTE:** Aggregated the data from `FundedPlansInfo` to count the number of distinct funded savings plans and distinct funded investment plans for each customer.
    3.  **`EligibleCustomers` CTE:** Filtered customers from `CustomerPlanCounts` who had `savings_count >= 1` AND `investment_count >= 1`.
    4.  **`CustomerTotalDeposits` CTE:** Calculated the sum of all `confirmed_amount` (converted from kobo to the main currency unit by dividing by 100.0) from `savings_savingsaccount` for each customer.
    5.  **Final Query:** Joined `EligibleCustomers` with `users_customuser` (to retrieve customer names, concatenating `first_name` and `last_name` as the `name` column was empty) and `CustomerTotalDeposits`. The results were ordered by `total_deposits` in descending order.

### Question 2: Transaction Frequency Analysis (`Assessment_Q2.sql`)

* **Goal:** Calculate the average number of transactions (from `savings_savingsaccount`) per customer per month and categorize customers into "High," "Medium," or "Low" frequency segments.
* **Approach:**
    1.  **`MonthlyTransactionCountsPerCustomer` CTE:** For each customer, counted the number of transactions (`savings_savingsaccount` records) for each distinct year and month they had activity.
    2.  **`AverageMonthlyTransactionsPerCustomer` CTE:** Calculated each customer's average number of transactions across the months they were active (i.e., the average of their monthly counts from the previous CTE).
    3.  **`CustomersWithCategory` CTE:**
        * Performed a `LEFT JOIN` from `users_customuser` to `AverageMonthlyTransactionsPerCustomer` to include all customers. Customers with no transactions had their average monthly transactions set to 0 using `COALESCE`.
        * Assigned a `frequency_category` ("High Frequency", "Medium Frequency", "Low Frequency") to each customer based on their calculated average monthly transactions, using the specified thresholds (≥10 for High, 3-9 for Medium, ≤2 for Low, interpreted as `<3` for averages).
    4.  **Final Query:** Grouped customers by `frequency_category` to:
        * Count the number of customers in each category (`customer_count`).
        * Calculate the overall average of the individual customer average monthly transactions for that category (`avg_transactions_per_month`), rounded to one decimal place.
        * Results were ordered by category (High, Medium, Low).

### Question 3: Account Inactivity Alert (`Assessment_Q3.sql`)

* **Goal:** Find all active savings or investment plans that have had no inflow transactions for over one year (365 days).
* **Approach:**
    1.  **`LastInflowTransactionPerPlan` CTE:** Determined the most recent `transaction_date` for each `plan_id` from `savings_savingsaccount`, considering only "inflow transactions" (where `confirmed_amount > 0`).
    2.  **Final Query:**
        * Joined `plans_plan` with the `LastInflowTransactionPerPlan` CTE.
        * Identified plan `type` as "Savings" (`is_regular_savings = 1`) or "Investment" (`is_a_fund = 1`).
        * Calculated `inactivity_days` using `DATEDIFF(CURDATE(), last_transaction_date)`. If a plan never had an inflow transaction, `inactivity_days` was calculated as `DATEDIFF(CURDATE(), plan_creation_date)`.
        * **Filtering Criteria:**
            * Plan type must be Savings or Investment.
            * Plan must be "active," which was assumed to mean `is_archived = 0` AND `is_deleted = 0` in the `plans_plan` table, due to lack of specific `status_id` definitions.
            * The plan met the inactivity condition:
                * Either its last inflow transaction was more than 365 days ago.
                * Or, it never had an inflow transaction AND was created more than 365 days ago (to avoid flagging new, untransacted plans).
        * Results were ordered by `inactivity_days` descending.

### Question 4: Customer Lifetime Value (CLV) Estimation (`Assessment_Q4.sql`)

* **Goal:** Estimate CLV for each customer based on account tenure, total transaction count (from `savings_savingsaccount`), and a simplified profit model.
* **Approach:**
    1.  **`CustomerTransactionStats` CTE:** For each customer:
        * Calculated `total_transactions_count` by counting records in `savings_savingsaccount` where `confirmed_amount > 0`.
        * Calculated `avg_transaction_value_main_currency` by averaging `confirmed_amount / 100.0` (kobo to main currency) for these positive-value transactions.
    2.  **Final Query:**
        * Retrieved customer details from `users_customuser` (concatenating `first_name` and `last_name` for `name`).
        * `LEFT JOIN`ed with `CustomerTransactionStats`.
        * Calculated `tenure_months` using `TIMESTAMPDIFF(MONTH, ucu.date_joined, CURDATE())`.
        * Displayed `total_transactions` (from CTE, or 0 if none).
        * **Estimated CLV Calculation:**
            * Used the formula: `CLV = (total_transactions / tenure_months) * 12 * avg_profit_per_transaction`.
            * `avg_profit_per_transaction` was defined as `0.1% * avg_transaction_value_main_currency` (i.e., `0.001 * COALESCE(cts.avg_transaction_value_main_currency, 0.0)`).
            * Handled edge cases: If `tenure_months` was 0 or `total_transactions` was 0, CLV was set to 0.0. This also implicitly handles cases where `avg_transaction_value_main_currency` is 0.
            * The final CLV was rounded to two decimal places.
        * Results were ordered by `estimated_clv` in descending order.

## Challenges Encountered and Resolutions

* **Understanding Table Structures and Fields:** Initially, it was important to carefully review the provided `CREATE TABLE` statements to understand column names, data types, primary/foreign keys, and potential `NULL` values. This was crucial for writing correct `JOIN` conditions and selecting appropriate fields.
* **Interpreting Business Logic:**
    * **"Funded Plan" (Q1):** Interpreted as a plan with at least one deposit transaction (`confirmed_amount > 0`) in `savings_savingsaccount`.
    * **"Active Account/Plan" (Q3):** Without explicit documentation for `status_id` in `plans_plan`, "active" was assumed to mean plans where `is_archived = 0` AND `is_deleted = 0`. This is a common convention but relies on an assumption.
    * **"Inflow Transaction" (Q3):** Consistently interpreted as a transaction in `savings_savingsaccount` with `confirmed_amount > 0`.
    * **"Transaction" for Frequency (Q2) and CLV (Q4):** Based on the tables provided for each question, these were scoped to records in `savings_savingsaccount`. For Q4 (CLV), specifically focused on transactions with `confirmed_amount > 0` as profit is derived from value.
    * **CLV Profit Model (Q4):** The "profit_per_transaction is 0.1% of the transaction value" was translated into `avg_profit_per_transaction = 0.001 * AVG(transaction_value_in_main_currency)`.
* **Date and Time Calculations:**
    * Used `DATEDIFF(CURDATE(), date_column)` for calculating differences in days (Q3).
    * Used `TIMESTAMPDIFF(MONTH, start_date, end_date)` for calculating differences in months (Q4 tenure).
    * Used `YEAR()` and `MONTH()` functions for grouping transactions by month (Q2).
    * Awareness that `CURDATE()` makes results time-sensitive for Q3 inactivity calculation; example output values would differ.
* **Handling Kobo Amounts:** All monetary `amount` fields were specified as being in kobo. Calculations involving these amounts (total deposits, average transaction value, CLV) required division by 100.0 to convert to the main currency unit and ensure decimal arithmetic.
* **Avoiding Division by Zero / NULL Issues:**
    * In Q4 CLV calculation, if `tenure_months` was 0, the CLV was explicitly set to 0 to prevent division by zero. `COALESCE` was used to handle potential `NULL`s from aggregations (e.g., for users with no transactions) to ensure calculations defaulted to 0 where appropriate.
* **Customer Name Concatenation (Q1, Q4):** A specific challenge was the user clarification that the `name` column in `users_customuser` was empty. The solution was to use `CONCAT(first_name, ' ', last_name)` to generate the customer's full name.
* **Category Boundary Conditions (Q2):** Carefully defined the conditions for transaction frequency categories (High, Medium, Low) to correctly handle floating-point average values and ensure all values fell into a category as per the definitions (e.g., "3-9" meant `>=3 AND <10`).
* **Query Readability and Structure:** Used Common Table Expressions (CTEs) extensively to break down complex logic into manageable steps, improving readability and maintainability of the SQL queries, as per assessment guidelines. Added comments to explain key sections.
* **Ensuring All Users/Plans were Considered:** Used `LEFT JOIN` appropriately (e.g., in Q2 and Q4 when starting from `users_customuser`) to ensure all customers were included in the analysis, even if they had no corresponding transaction records.
