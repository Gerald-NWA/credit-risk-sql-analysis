
  -- CHECK LOCAL_INFILE SETTING
  
SHOW VARIABLES LIKE 'local_infile';

CREATE DATABASE IF NOT EXISTS credit_risk_dataset;
USE credit_risk_dataset;

DROP TABLE IF EXISTS credit_risk;

CREATE TABLE credit_risk (
    person_age INT,
    person_income INT,
    person_home_ownership VARCHAR(20),
    person_emp_length DOUBLE NULL,
    loan_intent VARCHAR(30),
    loan_grade VARCHAR(5),
    loan_amnt INT,
    loan_int_rate DOUBLE NULL,
    loan_status INT,
    loan_percent_income DOUBLE,
    cb_person_default_on_file VARCHAR(5),
    cb_person_cred_hist_length INT
);

LOAD DATA LOCAL INFILE 'C:/Users/geral/Desktop/DSP/03. SQL/03. Abschlussprojekt/credit_risk_dataset.csv'
INTO TABLE credit_risk
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(person_age, person_income, person_home_ownership, @emp_length, 
 loan_intent, loan_grade, loan_amnt, @int_rate, loan_status, 
 loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length)
SET
    person_emp_length = NULLIF(@emp_length, ''),
    loan_int_rate = NULLIF(@int_rate, '');

   -- DATA VERIFICATION: I Checked total rows and missing values in key fields
SELECT 
    COUNT(*) AS total_records,
    SUM(CASE WHEN person_emp_length IS NULL THEN 1 ELSE 0 END) AS null_emp_length,
    SUM(CASE WHEN loan_int_rate IS NULL THEN 1 ELSE 0 END) AS null_interest_rates
FROM credit_risk;

    -- DATA QUALITY CHECKS: I did this to understand the data issues before cleaning, and also Checks for impossible values (OUTLIERS)

   /*Raw data qaulity check for (OUTLIERS)
   Identifying invalid or impossible values in the original data
   - Ages outside human limits (<=0 or >120)
   - Non positive income
   - Interest rates outside 0–100%
  */
  
SELECT 
    SUM(CASE WHEN person_age <= 0 OR person_age > 120 THEN 1 ELSE 0 END) AS raw_bad_age,
    SUM(CASE WHEN person_income <= 0 THEN 1 ELSE 0 END) AS raw_non_positive_income,
    SUM(CASE WHEN loan_int_rate < 0 OR loan_int_rate > 100 THEN 1 ELSE 0 END) AS raw_bad_interest_rate
FROM credit_risk;



   /*CLEANED DATA VALIDATION CHECK
   Confirming the cleaned dataset meets all applied rules
  */
   -- Age restricted to 18–90
   -- Income must be positive
   -- Employment length must be non negative
   -- Interest rate between 0–100
   -- Standardized home ownership categories            -Loan to income Ratio (LTI)-It tells you how big the loan is compared to the borrower’s yearly income
   -- Added LTI, Age Groups, and DTI Risk Categories    --Debt to income Ratio (DTI)-It tells you how much of a person’s monthly income is already being used to pay debts.



DROP TABLE IF EXISTS credit_risk_clean;    -- Creating a new cleaner table for better analysis 
CREATE TABLE credit_risk_clean AS
SELECT 
    person_age,         
    person_income,         
    CASE                -- with a case i'm making a decsion
        WHEN LOWER(person_home_ownership) IN ('rent', 'renter') THEN 'RENT'      -- Standardized home ownership values
        WHEN LOWER(person_home_ownership) IN ('own', 'owned') THEN 'OWN'
        WHEN LOWER(person_home_ownership) LIKE '%mortgage%' THEN 'MORTGAGE'
        ELSE person_home_ownership
    END AS person_home_ownership,

    /* Clean employment length (no negatives) */
    CASE 
        WHEN person_emp_length < 0 THEN 0
        ELSE person_emp_length
    END AS person_emp_length,

    loan_intent,
    loan_grade,
    loan_amnt,
    loan_int_rate,
    loan_status,
    loan_percent_income,
    cb_person_default_on_file,
    cb_person_cred_hist_length,

    /* FEATURE 1: Loan-to-Income Ratio (LTI) */
    (loan_amnt / person_income) AS calculated_loan_to_income,

    /* FEATURE 2: Age Group */
    CASE
        WHEN person_age < 25 THEN '18-24'
        WHEN person_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN person_age BETWEEN 35 AND 49 THEN '35-49'
        WHEN person_age BETWEEN 50 AND 64 THEN '50-64'
        ELSE '65+'
    END AS age_group,

    /* FEATURE 3: DTI Risk Category */
    CASE
        WHEN loan_percent_income < 0.2 THEN 'LOW'
        WHEN loan_percent_income BETWEEN 0.2 AND 0.4 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS dti_risk
FROM credit_risk;

SELECT COUNT(*) AS zero_income_after_cleaning
FROM credit_risk_clean
WHERE person_income = 0;

-- Duplicate record check
SELECT 
    person_age, person_income, loan_amnt, loan_int_rate, loan_intent,
    COUNT(*) AS duplicates
FROM credit_risk_clean
GROUP BY 1,2,3,4,5
HAVING COUNT(*) > 1;

SELECT 
    SUM(CASE WHEN person_age < 18 OR person_age > 90 THEN 1 ELSE 0 END) AS clean_invalid_age,
    SUM(CASE WHEN person_income <= 0 THEN 1 ELSE 0 END) AS clean_invalid_income,
    SUM(CASE WHEN loan_int_rate < 0 OR loan_int_rate > 100 THEN 1 ELSE 0 END) AS clean_invalid_interest_rate
FROM credit_risk_clean;

  -- AUDIT: Compare dataset size before and after cleaning

SELECT 'Before Cleaning' AS status, COUNT(*) AS count FROM credit_risk
UNION
SELECT 'After Cleaning' AS status, COUNT(*) AS count FROM credit_risk_clean;


   /*CORE CREDIT RISK ANALYSIS
   Default rate logic:
   loan_status = 1 → PAID
   loan_status = 0 → DEFAULT

   To calculate default rate clearly:
   DEFAULT → 1
   PAID    → 0
   using CASE inside AVG().
   */

--  RISK BY LOAN GRADE

SELECT 
    loan_grade,
    COUNT(*) AS volume,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate
FROM credit_risk_clean
GROUP BY loan_grade
ORDER BY loan_grade;


--  HOME OWNERSHIP × EMPLOYMENT TENURE

SELECT 
    person_home_ownership,
    CASE 
        WHEN person_emp_length < 2 THEN 'Junior (0-2yr)'
        ELSE 'Senior (2yr+)'
    END AS tenure,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct     -- here we are grouping by category on a broader sense, but not individually 
FROM credit_risk_clean
GROUP BY 1, 2
ORDER BY default_rate_pct DESC;


--  INCOME BRACKETS VS DEFAULT RATE

SELECT 
    CASE 
        WHEN person_income < 30000 THEN '1. Low (<30k)'
        WHEN person_income BETWEEN 30000 AND 70000 THEN '2. Mid (30-70k)'
        ELSE '3. High (>70k)'
    END AS income_segment,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct
FROM credit_risk_clean
GROUP BY 1
ORDER BY 1;

--  LOAN INTENT RISK
SELECT 
    loan_intent,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_size
FROM credit_risk_clean
GROUP BY loan_intent
ORDER BY default_rate_pct DESC;


--  AGE GROUP RISK
SELECT
    age_group,
    COUNT(*) AS total_loans,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct
FROM credit_risk_clean
GROUP BY age_group
ORDER BY default_rate_pct DESC;

-- DTI RISK CATEGORY
SELECT
    dti_risk,
    COUNT(*) AS total_loans,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_rate_pct
FROM credit_risk_clean
GROUP BY dti_risk
ORDER BY default_rate_pct DESC;

-- - Loan_grade_volume_validation
SELECT loan_grade, COUNT(*) 
FROM credit_risk_clean          -- This checks for my total loan_count to the grades 
GROUP BY loan_grade
ORDER BY COUNT(*) ASC;


  /* RISK SUMMARY VIEW
   Combines loan grade + loan intent
  */

CREATE OR REPLACE VIEW risk_summary_view AS
SELECT 
    loan_grade,
    loan_intent,
    COUNT(*) AS total_cases,
    ROUND(AVG(CASE WHEN loan_status = 0 THEN 1 ELSE 0 END) * 100, 2) AS default_pct
FROM credit_risk_clean
GROUP BY loan_grade, loan_intent
HAVING COUNT(*) >= 30;

-- QUERY THE VIEW: High-risk segments (default > 30%)
SELECT *
FROM risk_summary_view
WHERE default_pct > 30
ORDER BY default_pct DESC;

SELECT *
FROM risk_summary_view
ORDER BY default_pct DESC;


/* Key Insights:
- Lower credit grades show sharply higher default rates, confirming loan grade as the strongest risk indicator in the portfolio.
- Low income borrowers and high DTI applicants default significantly more, making financial capacity a critical approval factor.
- Renters and borrowers with short employment histories are consistently higher risk, highlighting the importance of stability indicators.
- Loan purpose influences risk, with personal, medical, and debt consolidation loans showing the highest default behavior.
- Younger borrowers default more frequently, while risk decreases with age and financial maturity.
*/

-- Recommendation:

/*A strong credit risk model for this portfolio should prioritize:
1- Loan grade         
2- Home ownership      
3- Income level
4- Employment length
5- DTI ratio  
6- Loan intent
These variables consistently explain the majority of default behavior.
*/





