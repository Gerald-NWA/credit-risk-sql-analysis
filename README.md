# Credit Risk Analysis Using SQL

SQL-based analysis of 32,581 loan applications to identify 
the key drivers of loan default and support smarter lending decisions.

## Key Findings
- Loan grade is the strongest predictor — Grade G borrowers default at **98.4%** vs just **9.96%** for Grade A
- High-DTI applicants default at **74%** — nearly 3× the Low-DTI rate of 13%
- Low-income borrowers default at **47%** vs **11%** for high-income earners
- Renters with short employment tenure show the highest ownership-based risk at **35–41%**
- Venture and Education loans carry the highest intent-based default risk

## Recommendations
1. Prioritise loan grade in every approval decision
2. Apply stricter DTI and income verification checks
3. Weight home ownership and employment stability in risk scoring
4. Apply closer scrutiny to Venture and Education loan applications
5. Adjust lending thresholds by age group — younger borrowers carry higher risk

## Tools Used
- MySQL / SQL
- MySQL Workbench

## Dataset
- 32,581 loan applications, 12 raw features
- Source: Credit Risk Dataset (available on Kaggle)

## Files
- `Credit_risk_analysis.sql` — Full SQL pipeline: import, cleaning, feature engineering, risk analysis
- `Credit_Risk_Analysis_Updated.pptx` — Presentation with real query outputs and charts.

- ## How to Run
1. Download `credit_risk_dataset.csv` from Kaggle
2. Open `Credit_risk_analysis.sql` in MySQL Workbench
3. Update the file path in the `LOAD DATA LOCAL INFILE` line to match 
   your local machine before running
4. Run the script top to bottom
