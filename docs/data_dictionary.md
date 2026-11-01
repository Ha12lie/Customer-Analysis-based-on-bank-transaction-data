<a id="top"></a>

Bank customer analytics

# Data Dictionary

A field reference for all 19 CSV datasets in the raw and processed data folders, covering 187 field occurrences. Each dataset section preserves the original column names and column order.

<a id="conventions"></a>

## How to read this dictionary

Types describe the logical meaning of CSV values, not a database schema declaration. Integer IDs are join keys, not measures. Decimal amounts retain the source currency units; the files do not identify a currency. Rates are decimal fractions unless explicitly labeled as percentages. Counts and amounts in different datasets may refer to different time windows.

Raw columns are defined from their headers and recorded values. Derived definitions follow `raw_to_processed.sql`. That SQL reconstructs the intended transformations; it is not verified original generation code. Existing processed exports may differ because of source coverage or undocumented original rules. The SQL has not been executed for this documentation.

Date values appear as YYYY-MM-DD in most raw master files and as M/D/YYYY in raw bank transactions, raw card transactions and support tickets. Some processed fields use M/D/YYYY. RFM exports deliberately mix dates or numbers with the text labels `No Activity` and `Never Transacted`. Blank cells represent unavailable values; they should not automatically become zero.

The source column names `card type` and `Platfrom` are preserved exactly. Dataset names below refer to CSV files; SQL source tables use the prefix `raw_`, and `customer monthly status.csv` maps to `customer_monthly_status`.

## Dataset contents

1. [raw/customers.csv](#dataset-0)
2. [raw/accounts.csv](#dataset-1)
3. [raw/branches.csv](#dataset-2)
4. [raw/transactions.csv](#dataset-3)
5. [raw/cards.csv](#dataset-4)
6. [raw/card_transactions.csv](#dataset-5)
7. [raw/loans.csv](#dataset-6)
8. [raw/loan_payments.csv](#dataset-7)
9. [raw/support_tickets.csv](#dataset-8)
10. [raw/employees.csv](#dataset-9)
11. [processed data/fact_transaction.csv](#dataset-10)
12. [processed data/customer_account_type.csv](#dataset-11)
13. [processed data/customer_card_type.csv](#dataset-12)
14. [processed data/customer_loan_type.csv](#dataset-13)
15. [processed data/customer_card_category.csv](#dataset-14)
16. [processed data/customer_profile.csv](#dataset-15)
17. [processed data/customer_rfm.csv](#dataset-16)
18. [processed data/churn_monthly_trend.csv](#dataset-17)
19. [processed data/customer monthly status.csv](#dataset-18)

## Dataset inventory

| Dataset | Rows | Fields | Row meaning |
| --- | --- | --- | --- |
| raw/customers.csv | 60,000 | 12 | One row per customer; key customer_id. |
| raw/accounts.csv | 95,000 | 7 | One row per bank account; key account_id. |
| raw/branches.csv | 150 | 6 | One row per branch; key branch_id. |
| raw/transactions.csv | 1,048,575 | 7 | One row per bank transaction; key transaction_id. |
| raw/cards.csv | 65,000 | 8 | One row per issued card; key card_id. |
| raw/card_transactions.csv | 1,048,575 | 7 | One row per card transaction; key card_txn_id. |
| raw/loans.csv | 22,000 | 9 | One row per loan; key loan_id. |
| raw/loan_payments.csv | 600,000 | 7 | One row per payment; key payment_id. |
| raw/support_tickets.csv | 25,000 | 7 | One row per support ticket record; no ticket identifier is supplied. |
| raw/employees.csv | 1,800 | 6 | One row per employee; key employee_id. |
| processed data/fact_transaction.csv | 2,000,000 | 11 | One row per bank transaction matched to an account; key transaction_id. |
| processed data/customer_account_type.csv | 75,159 | 4 | One row per customer_id and account_type; composite key. |
| processed data/customer_card_type.csv | 53,428 | 4 | One row per customer_id and card_type; composite key. |
| processed data/customer_loan_type.csv | 21,355 | 6 | One row per customer_id and loan_type; composite key. |
| processed data/customer_card_category.csv | 543,395 | 4 | One row per customer_id and merchant_category; composite key. |
| processed data/customer_profile.csv | 60,000 | 43 | One row per customer; key customer_id. |
| processed data/customer_rfm.csv | 60,000 | 24 | One row per customer at the fixed observation date; key customer_id. |
| processed data/churn_monthly_trend.csv | 102 | 6 | One row per month-end observation date; key observation_date. |
| processed data/customer monthly status.csv | 6,120 | 9 | One row per observation_date, location, channel and card_type; composite key. |

## Relationships and interpretation

`customers.customer_id` links to accounts, cards, loans and support tickets. Bank transactions reach customers through accounts. Card transactions reach customers through cards. Loan payments reach customers through loans. Branches link to accounts, loans and employees by `branch_id`. The supplied transformations do not use employees or branches to derive the four main analytical outputs.

Product detail summaries include only customer and product combinations present in the source. Customer profile and RFM instead begin with the complete customer list. Card ownership follows `cards.customer_id`; bank transaction ownership follows `accounts.customer_id`. The transformations do not force these owners to agree through `cards.account_id`.

<a id="dataset-0"></a>

## raw/customers.csv

One row per customer; key customer_id. 60,000 rows and 12 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Unique customer identifier and parent key for customer relationships. |
| `name` | Text | Customer full name. |
| `gender` | Text | Recorded gender: Male, Female or Other. |
| `date_of_birth` | Date | Customer birth date; source format YYYY-MM-DD. |
| `city` | Text | Customer residential city. |
| `state` | Text | Customer residential state; used as the first choice for location in the monthly status summary. |
| `phone` | Text | Customer telephone number. Treat as text to preserve its identifier format. |
| `email` | Text | Customer email address. |
| `occupation` | Text | Recorded occupation: Retired, Salaried - Government, Salaried - Private, Freelancer, Self Employed, Business Owner or Student. |
| `annual_income` | Decimal amount | Recorded annual customer income; currency is not specified in the source. |
| `join_date` | Date | Date the customer joined the bank; source format YYYY-MM-DD. |
| `credit_score` | Integer score | Recorded customer credit score; distinct from the derived RFM scores. |

[Back to contents](#top)

<a id="dataset-1"></a>

## raw/accounts.csv

One row per bank account; key account_id. 95,000 rows and 7 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `account_id` | Integer ID | Unique bank account identifier; parent key for bank transactions. |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `branch_id` | Integer ID | Branch identifier; joins to raw/branches.csv.branch_id. |
| `account_type` | Text | Account product: Current, Savings, Salary, Fixed Deposit or NRI. |
| `balance` | Decimal amount | Recorded account balance at the source snapshot; not a transaction amount. |
| `open_date` | Date | Account opening date; source format YYYY-MM-DD. |
| `status` | Text | Recorded account status: Active, Dormant or Closed. |

[Back to contents](#top)

<a id="dataset-2"></a>

## raw/branches.csv

One row per branch; key branch_id. 150 rows and 6 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `branch_id` | Integer ID | Unique branch identifier. |
| `branch_name` | Text | Recorded branch name. |
| `city` | Text | Branch city, not the customer residential city. |
| `state` | Text | Branch state, not the customer residential state. |
| `opened_date` | Date | Branch opening date; source format YYYY-MM-DD. |
| `ifsc_code` | Text | Recorded Indian Financial System Code for the branch; preserve as text. |

[Back to contents](#top)

<a id="dataset-3"></a>

## raw/transactions.csv

One row per bank transaction; key transaction_id. 1,048,575 rows and 7 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `transaction_id` | Integer ID | Unique bank transaction identifier. |
| `account_id` | Integer ID | Bank account used for the transaction; joins to raw/accounts.csv.account_id. |
| `txn_date` | Date | Bank transaction date. Source CSV uses M/D/YYYY; parse as a date, not as text. |
| `txn_type` | Text | Deposit, Withdrawal, Transfer Out, Transfer In, Fee Debit or Interest Credit. |
| `amount` | Decimal amount | Recorded transaction amount; movement direction is derived from txn_type. |
| `channel` | Text | Operational transaction channel: Online Banking, Mobile App, UPI, Branch, POS or ATM. |
| `merchant_category` | Text | Merchant or transaction classification, such as Groceries, Education, ATM Withdrawal, Salary Credit or Fund Transfer; not limited to retail purchases. |

[Back to contents](#top)

<a id="dataset-4"></a>

## raw/cards.csv

One row per issued card; key card_id. 65,000 rows and 8 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `card_id` | Integer ID | Unique card identifier; parent key for card transactions. |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `account_id` | Integer ID | Recorded linked bank account identifier; joins to raw/accounts.csv.account_id. Card activity is attributed using cards.customer_id. |
| `card_type` | Text | Debit, Credit - Classic, Credit - Gold or Credit - Platinum. |
| `issue_date` | Date | Card issue date; source format YYYY-MM-DD. |
| `expiry_date` | Date | Card expiry date; source format YYYY-MM-DD. |
| `credit_limit` | Decimal amount | Recorded card limit. Preserve source values, including limits recorded against Debit cards. |
| `status` | Text | Recorded card status: Active, Expired or Blocked. |

[Back to contents](#top)

<a id="dataset-5"></a>

## raw/card_transactions.csv

One row per card transaction; key card_txn_id. 1,048,575 rows and 7 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `card_txn_id` | Integer ID | Unique card transaction identifier; belongs to a different identifier domain from bank transaction_id. |
| `card_id` | Integer ID | Card used for the transaction; joins to raw/cards.csv.card_id. |
| `txn_date` | Date | Card transaction date. Source CSV uses M/D/YYYY; parse as a date, not as text. |
| `merchant_category` | Text | Merchant or transaction classification, such as Groceries, Education, ATM Withdrawal, Salary Credit or Fund Transfer; not limited to retail purchases. |
| `amount` | Decimal amount | Recorded card transaction amount, used as gross card activity or spend. |
| `is_fraud` | Binary flag | Fraud indicator: 1 means flagged as fraud; 0 means not flagged. |
| `card type` | Text | Source card type label, including a literal space in the column name. Debit, Credit - Classic, Credit - Gold or Credit - Platinum. The SQL uses cards.card_type after joining on card_id. |

[Back to contents](#top)

<a id="dataset-6"></a>

## raw/loans.csv

One row per loan; key loan_id. 22,000 rows and 9 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `loan_id` | Integer ID | Unique loan identifier; parent key for loan payments. |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `branch_id` | Integer ID | Issuing or servicing branch identifier; joins to raw/branches.csv.branch_id. |
| `loan_type` | Text | Auto Loan, Education Loan, Gold Loan, Home Loan, Personal Loan or Business Loan. |
| `loan_amount` | Decimal amount | Recorded loan principal amount; not remaining principal or outstanding balance. |
| `interest_rate` | Decimal percent | Recorded loan interest rate in percentage points, for example 9.54 means 9.54%. The source does not explicitly state the rate period. |
| `term_months` | Integer months | Contractual loan term in months. |
| `start_date` | Date | Loan start date; source format YYYY-MM-DD. |
| `status` | Text | Recorded loan status: Active, Defaulted, Closed or Written Off. |

[Back to contents](#top)

<a id="dataset-7"></a>

## raw/loan_payments.csv

One row per payment; key payment_id. 600,000 rows and 7 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `payment_id` | Integer ID | Unique loan payment identifier. |
| `loan_id` | Integer ID | Loan receiving the payment; joins to raw/loans.csv.loan_id. |
| `payment_date` | Date | Loan payment date; source format YYYY-MM-DD. |
| `amount_paid` | Decimal amount | Total recorded amount paid for this payment. |
| `principal_component` | Decimal amount | Portion of the payment attributed to principal. |
| `interest_component` | Decimal amount | Portion of the payment attributed to interest. |
| `late_payment_flag` | Binary flag | Late payment indicator: 1 means late; 0 means not late. |

[Back to contents](#top)

<a id="dataset-8"></a>

## raw/support_tickets.csv

One row per support ticket record; no ticket identifier is supplied. 25,000 rows and 7 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `issue_type` | Text | Reported support issue, such as App Login Issue, Card Blocked, KYC Update, Interest Query, Cheque Bounce, Account Statement, Net Banking Issue, Loan Query, Wrong Debit or Fraud Report. |
| `date_opened` | Date | Ticket opening date. Source CSV uses M/D/YYYY; parse as a date, not as text. |
| `date_resolved` | Date | Ticket resolution date, where recorded. Source CSV uses M/D/YYYY; parse as a date, not as text. |
| `status` | Text | Recorded ticket status: Resolved, Open or Escalated. |
| `satisfaction_score` | Integer score | Recorded satisfaction rating on a 1 to 5 scale; higher values indicate greater satisfaction. |
| `Platfrom` | Text | Source platform label; preserve the original misspelling and capitalization. Values: Bank, Debit, Credit - Classic, Credit - Gold or Credit - Platinum. |

[Back to contents](#top)

<a id="dataset-9"></a>

## raw/employees.csv

One row per employee; key employee_id. 1,800 rows and 6 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `employee_id` | Integer ID | Unique employee identifier. |
| `name` | Text | Employee full name. |
| `branch_id` | Integer ID | Employee branch identifier; joins to raw/branches.csv.branch_id. |
| `role` | Text | Customer Service, Relationship Manager, Loan Officer, Branch Manager, Teller or Compliance Officer. |
| `hire_date` | Date | Employee hire date; source format YYYY-MM-DD. |
| `salary` | Decimal amount | Recorded employee salary; currency and payment period are not specified. |

[Back to contents](#top)

<a id="dataset-10"></a>

## processed data/fact_transaction.csv

One row per bank transaction matched to an account; key transaction_id. 2,000,000 rows and 11 fields.

Contains bank transactions only. Fees and interest remain in the table but contribute zero to both derived flow columns.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `transaction_id` | Integer ID | Copied from transactions.transaction_id. |
| `account_id` | Integer ID | Copied from transactions.account_id; used to join the account owner. |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `txn_date` | Date | transactions.txn_date parsed from M/D/YYYY; exported as YYYY-MM-DD. |
| `txn_type` | Text | Bank transaction type copied from transactions.txn_type. |
| `amount` | Decimal amount | Original bank transaction amount; retained for every transaction type. |
| `channel` | Text | Original operational channel from transactions.channel, such as UPI or POS. |
| `merchant_category` | Text | Original transaction classification from transactions.merchant_category. |
| `outflow_amount` | Decimal amount | amount for Withdrawal or Transfer Out; 0 for every other transaction type. |
| `inflow_amount` | Decimal amount | amount for Deposit or Transfer In; 0 for every other transaction type. |
| `is_engagement_transaction` | Binary flag | 1 for Deposit, Withdrawal, Transfer In or Transfer Out; 0 for Interest Credit or Fee Debit. |

[Back to contents](#top)

<a id="dataset-11"></a>

## processed data/customer_account_type.csv

One row per customer_id and account_type; composite key. 75,159 rows and 4 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `account_type` | Text | Account product from accounts.account_type. |
| `account_count` | Integer count | Number of account records for this customer and account type, including all account statuses. |
| `account_balance` | Decimal amount | Sum of accounts.balance for this customer and account type, including all account statuses. |

[Back to contents](#top)

<a id="dataset-12"></a>

## processed data/customer_card_type.csv

One row per customer_id and card_type; composite key. 53,428 rows and 4 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `card_type` | Text | Card product from cards.card_type. Debit, Credit - Classic, Credit - Gold or Credit - Platinum. |
| `card_count` | Integer count | Number of card records for this customer and card type, including all card statuses. |
| `credit_limit` | Decimal amount | Sum of recorded cards.credit_limit for this customer and card type, including Debit card values and all statuses. |

[Back to contents](#top)

<a id="dataset-13"></a>

## processed data/customer_loan_type.csv

One row per customer_id and loan_type; composite key. 21,355 rows and 6 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `loan_type` | Text | Loan product from loans.loan_type. |
| `loan_count` | Integer count | Number of loan records for this customer and loan type, including all loan statuses. |
| `loan_amount` | Decimal amount | Sum of loans.loan_amount for this customer and loan type. |
| `defaulted_or_written_off_count` | Integer count | Number of loans with status Defaulted or Written Off for this customer and loan type. |
| `defaulted_or_written_off_amount` | Decimal amount | Sum of original loan_amount for loans with status Defaulted or Written Off; not realized credit loss or remaining unpaid balance. |

[Back to contents](#top)

<a id="dataset-14"></a>

## processed data/customer_card_category.csv

One row per customer_id and merchant_category; composite key. 543,395 rows and 4 fields.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `merchant_category` | Text | Card transaction classification from card_transactions.merchant_category. |
| `card_transaction_count` | Integer count | Number of card transactions in this category, attributed through card_transactions.card_id to cards.customer_id. |
| `card_spend` | Decimal amount | Sum of card transaction amount in this category; includes fraud-flagged transactions and all supplied dates. |

[Back to contents](#top)

<a id="dataset-15"></a>

## processed data/customer_profile.csv

One row per customer; key customer_id. 60,000 rows and 43 fields.

The SQL retains all customers through left joins. Missing counts and totals become 0; unavailable averages, rates, preferred channel and last bank date remain null. Age and tenure use 2026-06-30; activity aggregates use all supplied records without a date filter.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `gender` | Text | Copied from customers.gender. |
| `age` | Integer years | Completed years from date_of_birth to 2026-06-30 using TIMESTAMPDIFF(YEAR). |
| `age_band` | Text | Age groups: Under 25; 25-34; 35-44; 45-54; 55+. |
| `city` | Text | Customer residential city from customers.city. |
| `state` | Text | Customer residential state from customers.state. |
| `occupation` | Text | Copied from customers.occupation. |
| `annual_income` | Decimal amount | Copied from customers.annual_income. |
| `income_band` | Text | Annual income groups: <500K; 500K-<1M; 1M-<2M; 2M-<3M; >=3M. K = 1,000 and M = 1,000,000 in source currency units. |
| `join_date` | Date | Copied from customers.join_date; exported in M/D/YYYY format. |
| `tenure_months` | Integer months | Completed months from join_date to 2026-06-30 using TIMESTAMPDIFF(MONTH). |
| `credit_score` | Integer score | Copied from customers.credit_score. |
| `credit_score_band` | Text | Below 600; 600-699; 700-749; 750+. |
| `account_count` | Integer count | Count of all customer accounts, regardless of status. |
| `active_account_count` | Integer count | Count of customer accounts with status Active. |
| `account_balance_total` | Decimal amount | Sum of balance across all customer accounts, regardless of status. |
| `active_account_balance` | Decimal amount | Sum of balance for customer accounts with status Active only. |
| `loan_count` | Integer count | Count of all customer loans, regardless of status. |
| `active_loan_count` | Integer count | Count of customer loans with status Active. |
| `defaulted_or_written_off_loan_count` | Integer count | Count of customer loans with status Defaulted or Written Off. |
| `loan_amount_total` | Decimal amount | Sum of original loan_amount across all customer loans, regardless of status. |
| `defaulted_or_written_off_loan_amount` | Decimal amount | Sum of original loan_amount for loans with status Defaulted or Written Off. |
| `average_loan_interest_rate` | Decimal percent | Unweighted average of loans.interest_rate across customer loans; blank when no loan rate is available. |
| `loan_payment_count` | Integer count | Count of loan payment records after joining payments to loans by loan_id and grouping by loans.customer_id. |
| `late_payment_count` | Integer count | Sum of late_payment_flag across the customer loan payment records. |
| `late_payment_rate` | Decimal ratio | Average late_payment_flag; late payment count divided by payment count when all flags are present. Blank when no payment record exists. |
| `loan_amount_paid_total` | Decimal amount | Sum of loan_payments.amount_paid across all customer loan payments. |
| `principal_paid_total` | Decimal amount | Sum of loan_payments.principal_component across all customer loan payments. |
| `card_count` | Integer count | Count of all customer cards, regardless of status. |
| `active_card_count` | Integer count | Count of customer cards with status Active. |
| `credit_limit_total` | Decimal amount | Sum of credit_limit across all customer cards; includes recorded Debit card limits and all statuses. |
| `card_transaction_count` | Integer count | Count of all customer card transaction records, attributed using cards.customer_id. |
| `card_spend_total` | Decimal amount | Sum of amount across all customer card transactions, including fraud-flagged activity. |
| `fraud_card_transaction_count` | Integer count | Sum of is_fraud across the customer card transactions. |
| `fraud_card_amount` | Decimal amount | Sum of card transaction amount where is_fraud = 1. |
| `support_ticket_count` | Integer count | Count of all customer support ticket records, including all statuses. |
| `open_ticket_count` | Integer count | Count of customer support tickets with status exactly Open; excludes Escalated. |
| `average_satisfaction_score` | Decimal score | Arithmetic average of non-null satisfaction_score for the customer; blank when no score is available. |
| `bank_engagement_transaction_count` | Integer count | Sum of fact_transaction.is_engagement_transaction across all supplied bank transaction dates. |
| `bank_outflow_total` | Decimal amount | Sum of fact_transaction.outflow_amount: Withdrawal and Transfer Out amounts only. |
| `bank_inflow_total` | Decimal amount | Sum of fact_transaction.inflow_amount: Deposit and Transfer In amounts only. |
| `preferred_channel` | Text | Operational bank channel with the highest engagement transaction count; ties are resolved by channel ascending under the SQL collation. Blank if no engagement transaction exists. |
| `last_bank_transaction_date` | Date | Latest bank engagement transaction date; ignores fees and interest. Blank when no engagement transaction exists; exported in M/D/YYYY format. |

[Back to contents](#top)

<a id="dataset-16"></a>

## processed data/customer_rfm.csv

One row per customer at the fixed observation date; key customer_id. 60,000 rows and 24 fields.

Qualifying activity combines bank engagement events with all card transactions using UNION ALL. Numeric metrics and dates containing No Activity or Never Transacted are mixed-type CSV fields. Scoring rules describe raw_to_processed.sql; they are a reconstruction, not verified original pipeline code.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `customer_id` | Integer ID | Customer identifier; joins to raw/customers.csv.customer_id. |
| `gender` | Text | Copied from customers.gender. |
| `city` | Text | Customer residential city from customers.city. |
| `state` | Text | Customer residential state from customers.state. |
| `occupation` | Text | Copied from customers.occupation. |
| `annual_income` | Decimal amount | Copied from customers.annual_income. |
| `join_date` | Date | Copied from customers.join_date; exported as YYYY-MM-DD. |
| `credit_score` | Integer score | Copied from customers.credit_score. |
| `first_transaction_date` | Date or text | Earliest qualifying bank engagement or card transaction on or before the observation date; Never Transacted if none exists. |
| `last_transaction_date` | Date or text | Latest qualifying bank engagement or card transaction on or before the observation date; Never Transacted if none exists. |
| `observation_date` | Date | Fixed RFM reference date: 2026-06-30. |
| `frequency_12m` | Count or text | Count of qualifying bank engagement and card transactions from 2025-07-01 through 2026-06-30 inclusive; No Activity when 0. |
| `monetary_activity_12m` | Amount or text | Sum of qualifying bank and card amount in the 12-month window; No Activity when combined frequency is 0. Measures gross activity, not profit or net spending. |
| `bank_count_12m` | Count or text | Count of bank engagement transactions in the 12-month window; No Activity when 0. |
| `bank_amount_12m` | Amount or text | Sum of bank engagement amount in the 12-month window; No Activity when bank_count_12m is 0. |
| `card_count_12m` | Count or text | Count of card transactions in the 12-month window; No Activity when 0. |
| `card_amount_12m` | Amount or text | Sum of card transaction amount in the 12-month window, including fraud-flagged records; No Activity when card_count_12m is 0. |
| `recency_days` | Integer days or text | DATEDIFF(observation_date, last_transaction_date); Never Transacted if no qualifying transaction exists. |
| `activity_history` | Text | Never Transacted if no historical qualifying event exists; No Activity in 12M if historical events exist but none in the window; otherwise Activity in 12M. |
| `r_score` | Integer 1 to 5 | Recency score from quintile cutoffs among customers with positive 12-month frequency; lower recency gives a higher score. No 12-month activity gives 1. |
| `f_score` | Integer 1 to 5 | Frequency score from quintile cutoffs among customers with positive 12-month frequency; higher frequency gives a higher score. Zero frequency gives 1 in the supplied model. |
| `m_score` | Integer 1 to 5 | Monetary activity score from quintile cutoffs among customers with positive 12-month frequency; higher amount gives a higher score. Zero activity gives 1 in the supplied model. |
| `rfm_segment` | Text | First matching segment: historical inactivity label; Champions (R>=4, F>=4, M>=4); Loyal Customers (F>=4, M>=3); At Risk (R<=2, F>=3); Hibernating (R<=2); Recent Low Frequency (R>=4, F<=2); otherwise Needs Attention. |
| `rfm_score` | Three digit code | Concatenation of r_score, f_score and m_score in that order, for example 445. A code, not the sum or product of the scores. |

[Back to contents](#top)

<a id="dataset-17"></a>

## processed data/churn_monthly_trend.csv

One row per month-end observation date; key observation_date. 102 rows and 6 fields.

Behavioral inactivity status, not account closure. The SQL crosses the full customer list with all observed months, without restricting months to join_date. Customers can return from churned to active after a new transaction.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `observation_date` | Date | Month-end date at which activity status is evaluated; supplied output spans 2018-01-31 through 2026-06-30. |
| `active_customers` | Integer count | Customers whose latest qualifying bank or card event is 0 to 90 days before the observation date, inclusive. |
| `at_risk_customers` | Integer count | Customers whose latest qualifying event is 91 to 180 days before the observation date, inclusive. |
| `churned_customers` | Integer count | Customers whose latest qualifying event is more than 180 days before the observation date. |
| `never_transacted_customers` | Integer count | Customers with no qualifying event on or before the observation date. |
| `churn_rate` | Decimal ratio | churned_customers / (active_customers + at_risk_customers + churned_customers). Never-transacted customers are excluded from the denominator; decimal fraction, not percentage points. |

[Back to contents](#top)

<a id="dataset-18"></a>

## processed data/customer monthly status.csv

One row per observation_date, location, channel and card_type; composite key. 6,120 rows and 9 fields.

A customer can appear once in each channel/card-type group per month. Do not sum the groups to obtain unique overall customer counts, and do not sum the repeated churn_rate values.

| Variable | Logical type | Definition and source or calculation |
| --- | --- | --- |
| `observation_date` | Date | Month-end observation date used for status classification. |
| `location` | Text | Customer state when nonblank; otherwise customer city; otherwise Unknown. This is customer location, not branch location. |
| `channel` | Text | Broad activity source: Bank or Card. Different from operational fact_transaction.channel such as UPI or POS. |
| `card_type` | Text | Bank for bank events; otherwise the card product from cards.card_type: Debit or one of the credit card tiers. |
| `active_count` | Integer count | Customers with a qualifying event in this channel and card type in the previous 0 to 90 days, inclusive. |
| `at_risk_count` | Integer count | Customers whose latest qualifying event in this channel and card type is 91 to 180 days old. |
| `churned_count` | Integer count | Customers whose latest qualifying event in this channel and card type is more than 180 days old. |
| `never_transacted_count` | Integer count | Customers with no qualifying event in this channel and card type by the observation date; includes customers who have never held that card product. |
| `churn_rate` | Decimal ratio | Overall customer churn rate for this month, copied from churn_monthly_trend; repeated across locations and channel/card-type groups. Not the churn rate of this individual row. |

[Back to contents](#top)

Coverage was checked against every CSV header. Repeated field names are documented separately for each dataset because their grain, date scope or meaning can differ.
