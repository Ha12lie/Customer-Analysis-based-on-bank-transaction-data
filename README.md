# Bank Customer Analytics Dashboard

This project analyzes bank customers, accounts, transactions, cards, loans, loan repayments, branches, employees, and customer support records. Power BI is used to present customer profiles, product usage, transaction behavior, RFM segmentation, risk indicators, and customer churn trends.

The repository includes the source data, processed analytical datasets, SQL preparation logic, the Power BI source file, and a PDF export of the dashboard.

## View the Dashboard Online

Open the public Power BI report here:

**[Open the Power BI Dashboard](https://app.powerbi.com/view?r=eyJrIjoiYTcxYjUzNGYtNWNiNi00MmFhLWJmZmItZTA5YjA4ODM0ODAyIiwidCI6ImY1NmU1MzRlLTk3ZmQtNDQ3My1iNzcxLTI0ZjM0Y2I4OGEwMCIsImMiOjEwfQ%3D%3D)**

The link is intended for public viewing. Confirm that the report and underlying data meet your organization’s data-sharing and privacy requirements before distributing it externally.

## Analysis Areas

- **Customer overview:** Demographics, location, occupation, income, credit score, join date, and relationship tenure.
- **Accounts and products:** Account counts and balances, card types and credit limits, loan types, loan amounts, and loan status.
- **Transactions and channels:** Bank inflows, outflows, transaction frequency, preferred channels, and card spending categories.
- **Customer RFM:** Recency, Frequency, and Monetary activity scores and customer segments.
- **Churn trends:** Monthly Active, At Risk, Churned, and Never Transacted customer counts and churn rate.
- **Risk and service:** Late payments, defaulted or written-off loans, fraud-flagged card transactions, support tickets, and satisfaction scores.

## Project Structure

```text
.
├── raw data/                         # Source CSV files
├── processed data/                   # Analytical datasets used by the dashboard
├── docs/
│   ├── data_dictionary.md            # Field definitions for all datasets
│   └── dataset_generation_methodology.md  # Transformation logic and metric definitions
├── data preparation for dashboard.sql # SQL preparation and aggregation logic
├── Customer Analysis based on bank transaction data.pbix  # Power BI source file
├── Customer Analysis based on bank transaction data.pdf   # PDF dashboard export
└── README.md
```

## Dataset Overview

### Raw Data

| Dataset | Rows | Description |
| --- | ---: | --- |
| `customers.csv` | 60,000 | Customer master data |
| `accounts.csv` | 95,000 | Bank accounts |
| `transactions.csv` | 1,048,575 | Bank transactions |
| `cards.csv` | 65,000 | Issued bank cards |
| `card_transactions.csv` | 1,048,575 | Card transactions |
| `loans.csv` | 22,000 | Loans |
| `loan_payments.csv` | 600,000 | Loan repayments |
| `support_tickets.csv` | 25,000 | Customer support records |
| `branches.csv` | 150 | Branch information |
| `employees.csv` | 1,800 | Employee information |

### Processed Data

| Dataset | Rows | Purpose |
| --- | ---: | --- |
| `fact_transaction.csv` | 2,000,000 | Bank transaction fact table joined to account owners |
| `customer_profile.csv` | 60,000 | One consolidated profile row per customer |
| `customer_rfm.csv` | 60,000 | RFM metrics, scores, and customer segments |
| `churn_monthly_trend.csv` | 102 | Monthly activity and churn trend |
| `customer monthly status.csv` | 6,120 | Customer status by month, location, channel, and card type |
| `customer_account_type.csv` | 75,159 | Customer account-type summary |
| `customer_card_type.csv` | 53,428 | Customer card-type summary |
| `customer_loan_type.csv` | 21,355 | Customer loan-type summary |
| `customer_card_category.csv` | 543,395 | Customer card-spending category summary |

For complete field definitions, keys, relationships, and business meanings, see [`docs/data_dictionary.md`](docs/data_dictionary.md).

## Metric Definitions

- RFM metrics, customer age, and customer tenure use **June 30, 2026** as the reference date.
- The RFM 12-month window covers **July 1, 2025 through June 30, 2026**, inclusive.
- Churn status is based on days since the most recent qualifying activity: `Active` = 0–90 days, `At Risk` = 91–180 days, `Churned` = more than 180 days, and `Never Transacted` = no historical qualifying activity.
- Churn rate = `Churned / (Active + At Risk + Churned)`. Never Transacted customers are excluded from the denominator.
- RFM Monetary Activity combines bank inflows, bank outflows, and card activity amounts. It measures gross activity and does not represent revenue, profit, or net cash flow.
- Bank transactions are linked to customers through `account_id`, card transactions through `card_id`, and loan repayments through `loan_id`.

## Data Preparation and Reproduction

The SQL file uses MySQL-style syntax and documents the preparation logic for the transaction fact table, customer profile, RFM analysis, and churn trend. The existing CSV exports can be loaded directly into Power BI or used for further analysis. To regenerate the datasets, configure the corresponding raw tables and execute [`data preparation for dashboard.sql`](<data preparation for dashboard.sql>).

For transformation details, field definitions, and interpretation limits, see [`docs/dataset_generation_methodology.md`](docs/dataset_generation_methodology.md). The available raw bank transaction and card transaction files each contain 1,048,575 rows, while the existing `fact_transaction.csv` contains 2,000,000 rows. Therefore, using only the raw files in this repository may not reproduce every value in the existing processed exports. The SQL documentation is a readable reconstruction of the transformation approach rather than a verified copy of the original generation program.

## Related Files

- [`Customer Analysis based on bank transaction data.pbix`](<Customer Analysis based on bank transaction data.pbix>) — Power BI Desktop source file.
- [`Customer Analysis based on bank transaction data.pdf`](<Customer Analysis based on bank transaction data.pdf>) — PDF export of the dashboard.
- [`docs/data_dictionary.md`](docs/data_dictionary.md) — Data dictionary.
- [`docs/dataset_generation_methodology.md`](docs/dataset_generation_methodology.md) — Dataset generation and metric methodology.
- [`data preparation for dashboard.sql`](<data preparation for dashboard.sql>) — SQL preparation logic.

## Notes

The source data does not specify a currency for monetary fields. Amounts should therefore be interpreted in the source data units. Behavioral churn, RFM At Risk, and the source-system product status `Active` represent different business concepts and should not be used interchangeably.
