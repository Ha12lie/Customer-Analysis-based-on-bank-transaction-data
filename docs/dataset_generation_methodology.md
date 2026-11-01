<a id="top"></a>

Bank customer analytics

# Dataset Generation Methodology

The four analytical datasets serve different purposes. The transaction fact table standardizes bank events, the customer profile consolidates customer attributes and product activity, RFM segments recent engagement, and the monthly churn trend tracks inactivity over time.

This document explains the transformation model in `raw_to_processed.sql`, including its joins, time windows and business rules. It documents the reconstructed SQL logic rather than claiming to reproduce an independently verified original pipeline.

1. [Shared model and reference dates](#model)
2. [Fact transaction](#fact)
3. [Customer profile](#profile)
4. [Customer RFM](#rfm)
5. [Churn monthly trend](#churn)
6. [Reproduction and interpretation limits](#limits)

<a id="model"></a>

## Shared model and reference dates

Customer ownership is established through the appropriate product table. Bank transactions join to accounts on `account_id`, card transactions join to cards on `card_id`, and loan payments join to loans on `loan_id`. Each product table then supplies `customer_id`. Joining on the product identifier preserves the intended transaction owner without relying on names or location.

The SQL fixes the RFM observation date and the age and tenure reference date at **June 30, 2026**. The RFM window is **July 1, 2025 through June 30, 2026**, inclusive. Churn uses successive month-end observation dates through June 30, 2026. Profile product totals, payments and activity summaries use all supplied records; the SQL does not apply an observation-date filter to those aggregates.

The main dependency path is `raw transactions + raw accounts → fact_transaction`. The profile uses this fact table alongside separate product and service aggregates. RFM and churn use a shared activity view that combines qualifying bank events with card events. No SQL statements are executed as part of this documentation.

<a id="fact"></a>

## Fact transaction

### Purpose and row meaning

`fact_transaction` is the reusable bank transaction layer. Each row represents one source bank transaction matched to an account. It retains the transaction identifier, account, date, type, amount, operational channel and merchant category, and adds customer ownership and three analytical fields.

### Connect transactions to customers

Join `raw_transactions` to `raw_accounts` using `account_id`, and take `customer_id` from the account. The inner join means a transaction without a matching account is not retained. Parse the source `txn_date` from M/D/YYYY into a date so later comparisons and month grouping use chronological order.

### Separate customer activity from automatic entries

Keep every transaction type in the fact table, but mark only deposits, withdrawals and transfers as engagement. Interest and fees remain available as source records while contributing zero to the analytical inflow and outflow measures.

| Transaction type | Outflow amount | Inflow amount | Engagement flag |
| --- | --- | --- | --- |
| Withdrawal or Transfer Out | Original amount | 0 | 1 |
| Deposit or Transfer In | 0 | Original amount | 1 |
| Fee Debit or Interest Credit | 0 | 0 | 0 |

For example, a withdrawal of 500 becomes an outflow of 500 and an engagement flag of 1. An interest credit of 20 keeps its original amount but has inflow 0, outflow 0 and engagement flag 0. Therefore, these flow columns measure the selected engagement flows; they do not reconcile every change in account balance.

The fact table contains bank events only. Card events enter the combined activity view separately and are not inserted into this bank fact table.

<a id="profile"></a>

## Customer profile

### Purpose and row meaning

`customer_profile` produces one row for every customer. It combines demographic characteristics, product ownership, loan repayment behavior, card activity, support experience and bank engagement in a single customer-level table.

### Aggregate each source before combining it

First build a separate customer-level summary for accounts, loans, payments, cards, card transactions, support tickets and bank transactions. Only then join these summaries to the customer master. This is the central design choice: directly joining several one-to-many sources would multiply rows. A customer with two accounts and three cards could otherwise produce six joined rows before transactions or payments are even considered, inflating balances and counts.

Use `LEFT JOIN` from the customer master to each summary so customers without a particular product remain in the output. Missing product counts and additive totals become zero. Unavailable averages, late payment rates, preferred channels and last bank transaction dates remain null because no observation is different from a measured value of zero.

### Demographics and product summaries

Calculate age as completed years from birth to June 30, 2026, and tenure as completed months from joining to that date. Group age into Under 25, 25–34, 35–44, 45–54 and 55+. Group annual income at 500,000, 1,000,000, 2,000,000 and 3,000,000 source currency units. Group credit scores into Below 600, 600–699, 700–749 and 750+.

For accounts, calculate total account count and balance, then calculate a second count and balance using only status Active. For loans, calculate total and active counts, total original loan amount, the count and amount of Defaulted or Written Off loans, and the unweighted average interest rate. The default-related amount is the sum of original loan amounts for those statuses; it is not a calculated loss or remaining unpaid balance.

### Repayments and card behavior

Attribute loan payments to customers through the loan table. Count payment records, sum late flags, total amount paid and principal paid, and average the late flag. With complete binary flags, this average equals late payments divided by total payments. A customer with 2 late payments out of 32 has a late payment rate of 0.0625, or 6.25%.

For cards, summarize total cards, active cards and recorded credit limits. Separately summarize card transaction count and spend, plus fraud-flagged count and amount. Fraud-flagged events remain in total card activity and are also reported in the fraud measures. Recorded limits on Debit cards are retained rather than replaced with zero.

### Support and bank engagement

Count all support ticket records, count only status Open in `open_ticket_count`, and average available satisfaction scores. Escalated tickets contribute to total ticket count but not to the exact Open count.

From the bank fact table, sum engagement flags and the derived inflow and outflow amounts. The last bank date is the latest engagement date, excluding fee and interest events. To select the preferred channel, count engagement transactions by customer and operational channel, rank counts from highest to lowest, and choose rank 1. Channel ascending provides the tie-break under the database collation.

<a id="rfm"></a>

## Customer RFM

### Build a common activity history

`customer_rfm` has one row per customer at June 30, 2026. Combine bank engagement transactions from the fact table with all card transactions using `UNION ALL`. Each event carries a customer, date, amount and broad source label, Bank or Card. Card type comes from the cards master. Keep separate events even when their dates and amounts match; no cross-source deduplication rule is defined.

The combined amount is a measure of gross financial activity. It includes bank inflows as well as outflows and card amounts. It is not revenue, profit, net cash flow or retail spending, and linked bank and card events may represent different records related to the same economic activity.

### Calculate the three metrics

Use all qualifying history on or before the observation date to find each customer’s first and last transaction dates. Use only the 12-month window for frequency and monetary activity. Calculate bank-only and card-only counts and amounts alongside the combined measures.

Recency = observation date − latest qualifying transaction date<br>Frequency = number of qualifying events in the 12-month window<br>Monetary activity = sum of qualifying event amounts in the 12-month window

A customer with a last event on June 19, 2026 has recency 11 days. If the customer has 5 bank events and 6 card events in the window, frequency is 11. Bank amount plus card amount gives the combined monetary activity for that window.

### Distinguish historical inactivity

Assign Never Transacted when no qualifying event exists by the observation date. Assign No Activity in 12M when the customer has historical qualifying activity but none in the recent window. Otherwise assign Activity in 12M. A customer can have an old last transaction date even when current 12-month frequency is zero.

### Assign scores from one to five

Use customers with positive 12-month frequency as the scoring population. For recency, frequency and monetary activity separately, sort the metric and divide the population into five ordered groups with `NTILE(5)`; customer ID breaks ordering ties. Take the maximum metric in groups 1 through 4 as the four cutoffs, then score every customer by comparing the metric with those cutoffs.

Recency runs in reverse: the smallest recency values receive score 5 and the largest receive score 1. Frequency and monetary activity run in the usual direction: the smallest values receive score 1 and the largest receive score 5. Customers with no recent activity receive the baseline score of 1 for each metric in this model.

Because cutoffs are applied to metric values, customers tied at a cutoff receive the same final score. Final score groups therefore need not contain exactly 20% of customers. Cutoffs are calculated from the available input rather than fixed permanently, so reduced or changed input can change the scores.

### Apply the segment rules in order

The first matching rule determines the segment. Order matters because a customer can satisfy more than one numerical condition.

| Order | Condition | Segment |
| --- | --- | --- |
| 1 | No qualifying historical transaction | Never Transacted |
| 2 | Historical activity, but none in the last 12 months | No Activity in 12M |
| 3 | R ≥ 4, F ≥ 4 and M ≥ 4 | Champions |
| 4 | F ≥ 4 and M ≥ 3 | Loyal Customers |
| 5 | R ≤ 2 and F ≥ 3 | At Risk |
| 6 | R ≤ 2 | Hibernating |
| 7 | R ≥ 4 and F ≤ 2 | Recent Low Frequency |
| 8 | All remaining combinations | Needs Attention |

Concatenate R, F and M to produce the three-digit `rfm_score`. For example, scores 4, 4 and 5 produce 445 and the Champions segment. The combined code is not a total score. Before export, replace missing-history dates and recency with Never Transacted and zero-activity window measures with No Activity. These labels make the CSV readable but mean those columns must be converted back to numeric or date values before subsequent calculations.

<a id="churn"></a>

## Churn monthly trend

### Define churn as inactivity at month end

`churn_monthly_trend` contains one row per observation month. It measures the number of customers currently in each activity state. It does not count account closures, cancellations or only customers who newly became inactive that month.

### Find the latest known event without using future activity

Use the same combined bank engagement and card activity history as RFM. Extract the distinct month-end dates represented in that history through June 30, 2026, and cross join them with the full customer list. This gives a customer-month row even when no event occurs in a particular month.

Within each customer and event month, keep the latest transaction date. Left join that monthly activity onto the customer-month grid. Then calculate a running maximum transaction date by customer, ordered by observation month, using a window from the first row through the current row. This carries the latest known event forward through inactive months without looking at future events.

The supplied month series is continuous. Because the SQL derives months from observed events rather than a dedicated calendar, an entirely event-free month across the whole input would be absent. The grid includes all customers in all observation months, even before their recorded join dates; it is a fixed customer population rather than a historical joined-customer cohort.

### Classify customers and aggregate

| Status | Rule at the observation date |
| --- | --- |
| Active | Latest qualifying event is 0 to 90 days old, inclusive. |
| At risk | Latest qualifying event is 91 to 180 days old, inclusive. |
| Churned | Latest qualifying event is more than 180 days old. |
| Never transacted | No qualifying event exists on or before the observation date. |

Each customer occupies exactly one of these states in each observation month. Count the four states by observation date. A new transaction can move a previously churned customer back to active, so churned customer count is not a permanently accumulating total.

Churn rate = churned customers ÷ (active customers + at-risk customers + churned customers)

Never-transacted customers are excluded from the denominator because they have not established qualifying activity. The rate is stored as a decimal fraction. For June 30, 2026, the supplied output has 41,364 active, 7,100 at risk, 7,321 churned and 4,215 never transacted. The denominator is 55,785 and the churn rate is approximately 0.131236, or 13.12%. These are values from the existing export, not a rerun result from the available raw files.

### Relationship to the monthly status breakdown

The separate `customer monthly status.csv` repeats the recency approach for each customer, broad channel and card type, then aggregates by month, customer location, channel and card type. Its `churn_rate` is the overall monthly customer rate copied from `churn_monthly_trend`, not a segment-specific rate. A customer can appear in several channel/card-type groups, so summing those group counts does not reproduce the unique overall customer population.

<a id="limits"></a>

## Reproduction and interpretation limits

The available raw bank transaction file contains 1,048,575 data rows and the raw card transaction file also contains 1,048,575. The existing bank fact export contains 2,000,000 rows. The present raw files therefore do not contain all transaction records represented by the existing processed outputs. This affects counts, sums, transaction dates, RFM cutoffs, segment membership and churn measures.

The supplied SQL is a readable reconstruction of the transformation approach. The original generation script is not available, so its exact quantile algorithm, any undocumented filters and other implementation details are not established. The data dictionary describes the reconstructed rules and identifies the mixed-type fields in the current exports; it should not be read as proof of exact reproduction.

Snapshot product statuses and balances are used as recorded, without reconstructing their historical changes. Age and tenure have a fixed reference date, while profile activity totals cover all supplied records. RFM and churn use explicit date cutoffs. These differences in scope are intentional in the supplied SQL and should remain visible when comparing metrics across datasets.

Behavioral churn, RFM At Risk and product status Active describe different concepts. Churn uses fixed inactivity-day thresholds. RFM uses relative scores within a recent-activity population. Product status is a source-system attribute. None should be substituted for another without changing the business definition.

Companion reference: Data Dictionary. Transformation reference: raw_to_processed.sql. Source coverage: all CSV headers in raw and processed data.
