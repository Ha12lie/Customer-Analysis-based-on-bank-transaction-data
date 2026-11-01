-- fact_transaction
CREATE TABLE fact_transaction AS
SELECT t.transaction_id, t.account_id, a.customer_id,
       STR_TO_DATE(t.txn_date, '%m/%d/%Y') AS txn_date,
       t.txn_type, t.amount, t.channel, t.merchant_category,
       CASE WHEN t.txn_type IN ('Withdrawal', 'Transfer Out') THEN t.amount ELSE 0 END AS outflow_amount,
       CASE WHEN t.txn_type IN ('Deposit', 'Transfer In') THEN t.amount ELSE 0 END AS inflow_amount,
       CASE WHEN t.txn_type IN ('Withdrawal', 'Transfer Out', 'Deposit', 'Transfer In') THEN 1 ELSE 0 END AS is_engagement_transaction
FROM raw_transactions t
JOIN raw_accounts a ON t.account_id = a.account_id;

-- customer_account_type
CREATE TABLE customer_account_type AS
SELECT customer_id, account_type, COUNT(*) AS account_count,
       SUM(balance) AS account_balance
FROM raw_accounts
GROUP BY customer_id, account_type;

-- customer_card_type
CREATE TABLE customer_card_type AS
SELECT customer_id, card_type, COUNT(*) AS card_count,
       SUM(credit_limit) AS credit_limit
FROM raw_cards
GROUP BY customer_id, card_type;

-- customer_loan_type
CREATE TABLE customer_loan_type AS
SELECT customer_id, loan_type, COUNT(*) AS loan_count,
       SUM(loan_amount) AS loan_amount,
       SUM(status IN ('Defaulted', 'Written Off')) AS defaulted_or_written_off_count,
       SUM(CASE WHEN status IN ('Defaulted', 'Written Off') THEN loan_amount ELSE 0 END) AS defaulted_or_written_off_amount
FROM raw_loans
GROUP BY customer_id, loan_type;

-- customer_card_category
CREATE TABLE customer_card_category AS
SELECT c.customer_id, t.merchant_category,
       COUNT(*) AS card_transaction_count, SUM(t.amount) AS card_spend
FROM raw_card_transactions t
JOIN raw_cards c ON t.card_id = c.card_id
GROUP BY c.customer_id, t.merchant_category;

-- customer_profile
CREATE TABLE customer_profile AS
WITH
accounts AS (
    SELECT customer_id, COUNT(*) AS account_count,
           SUM(status = 'Active') AS active_account_count,
           SUM(balance) AS account_balance_total,
           SUM(CASE WHEN status = 'Active' THEN balance ELSE 0 END) AS active_account_balance
    FROM raw_accounts
    GROUP BY customer_id
),
loans AS (
    SELECT customer_id, COUNT(*) AS loan_count,
           SUM(status = 'Active') AS active_loan_count,
           SUM(status IN ('Defaulted', 'Written Off')) AS defaulted_or_written_off_loan_count,
           SUM(loan_amount) AS loan_amount_total,
           SUM(CASE WHEN status IN ('Defaulted', 'Written Off') THEN loan_amount ELSE 0 END) AS defaulted_or_written_off_loan_amount,
           AVG(interest_rate) AS average_loan_interest_rate
    FROM raw_loans
    GROUP BY customer_id
),
payments AS (
    SELECT l.customer_id, COUNT(*) AS loan_payment_count,
           SUM(p.late_payment_flag) AS late_payment_count,
           AVG(p.late_payment_flag) AS late_payment_rate,
           SUM(p.amount_paid) AS loan_amount_paid_total,
           SUM(p.principal_component) AS principal_paid_total
    FROM raw_loan_payments p
    JOIN raw_loans l ON p.loan_id = l.loan_id
    GROUP BY l.customer_id
),
cards AS (
    SELECT customer_id, COUNT(*) AS card_count,
           SUM(status = 'Active') AS active_card_count,
           SUM(credit_limit) AS credit_limit_total
    FROM raw_cards
    GROUP BY customer_id
),
card_activity AS (
    SELECT c.customer_id, COUNT(*) AS card_transaction_count,
           SUM(t.amount) AS card_spend_total,
           SUM(t.is_fraud) AS fraud_card_transaction_count,
           SUM(CASE WHEN t.is_fraud = 1 THEN t.amount ELSE 0 END) AS fraud_card_amount
    FROM raw_card_transactions t
    JOIN raw_cards c ON t.card_id = c.card_id
    GROUP BY c.customer_id
),
support AS (
    SELECT customer_id, COUNT(*) AS support_ticket_count,
           SUM(status = 'Open') AS open_ticket_count,
           AVG(satisfaction_score) AS average_satisfaction_score
    FROM raw_support_tickets
    GROUP BY customer_id
),
bank_activity AS (
    SELECT customer_id,
           SUM(is_engagement_transaction) AS bank_engagement_transaction_count,
           SUM(outflow_amount) AS bank_outflow_total,
           SUM(inflow_amount) AS bank_inflow_total,
           MAX(CASE WHEN is_engagement_transaction = 1 THEN txn_date END) AS last_bank_transaction_date
    FROM fact_transaction
    GROUP BY customer_id
),
channel_counts AS (
    SELECT customer_id, channel, COUNT(*) AS transaction_count
    FROM fact_transaction
    WHERE is_engagement_transaction = 1
    GROUP BY customer_id, channel
),
channel_rank AS (
    SELECT customer_id, channel,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_count DESC, channel) AS rn
    FROM channel_counts
),
demographics AS (
    SELECT c.*, TIMESTAMPDIFF(YEAR, date_of_birth, '2026-06-30') AS age,
           TIMESTAMPDIFF(MONTH, join_date, '2026-06-30') AS tenure_months
    FROM raw_customers c
)
SELECT c.customer_id, c.gender, c.age,
       CASE WHEN c.age < 25 THEN 'Under 25'
            WHEN c.age < 35 THEN '25-34'
            WHEN c.age < 45 THEN '35-44'
            WHEN c.age < 55 THEN '45-54' ELSE '55+' END AS age_band,
       c.city, c.state, c.occupation, c.annual_income,
       CASE WHEN c.annual_income < 500000 THEN '<500K'
            WHEN c.annual_income < 1000000 THEN '500K-<1M'
            WHEN c.annual_income < 2000000 THEN '1M-<2M'
            WHEN c.annual_income < 3000000 THEN '2M-<3M' ELSE '>=3M' END AS income_band,
       c.join_date, c.tenure_months, c.credit_score,
       CASE WHEN c.credit_score < 600 THEN 'Below 600'
            WHEN c.credit_score < 700 THEN '600-699'
            WHEN c.credit_score < 750 THEN '700-749' ELSE '750+' END AS credit_score_band,
       COALESCE(a.account_count, 0) AS account_count,
       COALESCE(a.active_account_count, 0) AS active_account_count,
       COALESCE(a.account_balance_total, 0) AS account_balance_total,
       COALESCE(a.active_account_balance, 0) AS active_account_balance,
       COALESCE(l.loan_count, 0) AS loan_count,
       COALESCE(l.active_loan_count, 0) AS active_loan_count,
       COALESCE(l.defaulted_or_written_off_loan_count, 0) AS defaulted_or_written_off_loan_count,
       COALESCE(l.loan_amount_total, 0) AS loan_amount_total,
       COALESCE(l.defaulted_or_written_off_loan_amount, 0) AS defaulted_or_written_off_loan_amount,
       l.average_loan_interest_rate,
       COALESCE(p.loan_payment_count, 0) AS loan_payment_count,
       COALESCE(p.late_payment_count, 0) AS late_payment_count,
       p.late_payment_rate,
       COALESCE(p.loan_amount_paid_total, 0) AS loan_amount_paid_total,
       COALESCE(p.principal_paid_total, 0) AS principal_paid_total,
       COALESCE(k.card_count, 0) AS card_count,
       COALESCE(k.active_card_count, 0) AS active_card_count,
       COALESCE(k.credit_limit_total, 0) AS credit_limit_total,
       COALESCE(t.card_transaction_count, 0) AS card_transaction_count,
       COALESCE(t.card_spend_total, 0) AS card_spend_total,
       COALESCE(t.fraud_card_transaction_count, 0) AS fraud_card_transaction_count,
       COALESCE(t.fraud_card_amount, 0) AS fraud_card_amount,
       COALESCE(s.support_ticket_count, 0) AS support_ticket_count,
       COALESCE(s.open_ticket_count, 0) AS open_ticket_count,
       s.average_satisfaction_score,
       COALESCE(b.bank_engagement_transaction_count, 0) AS bank_engagement_transaction_count,
       COALESCE(b.bank_outflow_total, 0) AS bank_outflow_total,
       COALESCE(b.bank_inflow_total, 0) AS bank_inflow_total,
       ch.channel AS preferred_channel, b.last_bank_transaction_date
FROM demographics c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
LEFT JOIN loans l ON c.customer_id = l.customer_id
LEFT JOIN payments p ON c.customer_id = p.customer_id
LEFT JOIN cards k ON c.customer_id = k.customer_id
LEFT JOIN card_activity t ON c.customer_id = t.customer_id
LEFT JOIN support s ON c.customer_id = s.customer_id
LEFT JOIN bank_activity b ON c.customer_id = b.customer_id
LEFT JOIN channel_rank ch ON c.customer_id = ch.customer_id AND ch.rn = 1;

-- customer_rfm
CREATE VIEW customer_activity AS
SELECT customer_id, txn_date, 'Bank' AS channel, 'Bank' AS card_type, amount
FROM fact_transaction
WHERE is_engagement_transaction = 1
UNION ALL
SELECT c.customer_id, STR_TO_DATE(t.txn_date, '%m/%d/%Y'), 'Card', c.card_type, t.amount
FROM raw_card_transactions t
JOIN raw_cards c ON t.card_id = c.card_id;

CREATE TABLE customer_rfm AS
WITH activity AS (
    SELECT customer_id, MIN(txn_date) AS first_transaction_date,
           MAX(txn_date) AS last_transaction_date,
           SUM(txn_date > '2025-06-30') AS frequency_12m,
           SUM(CASE WHEN txn_date > '2025-06-30' THEN amount ELSE 0 END) AS monetary_activity_12m,
           SUM(txn_date > '2025-06-30' AND channel = 'Bank') AS bank_count_12m,
           SUM(CASE WHEN txn_date > '2025-06-30' AND channel = 'Bank' THEN amount ELSE 0 END) AS bank_amount_12m,
           SUM(txn_date > '2025-06-30' AND channel = 'Card') AS card_count_12m,
           SUM(CASE WHEN txn_date > '2025-06-30' AND channel = 'Card' THEN amount ELSE 0 END) AS card_amount_12m
    FROM customer_activity
    WHERE txn_date <= '2026-06-30'
    GROUP BY customer_id
),
metrics AS (
    SELECT c.customer_id, c.gender, c.city, c.state, c.occupation,
           c.annual_income, c.join_date, c.credit_score,
           a.first_transaction_date, a.last_transaction_date,
           CAST('2026-06-30' AS DATE) AS observation_date,
           COALESCE(a.frequency_12m, 0) AS frequency_12m,
           COALESCE(a.monetary_activity_12m, 0) AS monetary_activity_12m,
           COALESCE(a.bank_count_12m, 0) AS bank_count_12m,
           COALESCE(a.bank_amount_12m, 0) AS bank_amount_12m,
           COALESCE(a.card_count_12m, 0) AS card_count_12m,
           COALESCE(a.card_amount_12m, 0) AS card_amount_12m,
           DATEDIFF('2026-06-30', a.last_transaction_date) AS recency_days,
           CASE WHEN a.customer_id IS NULL THEN 'Never Transacted'
                WHEN a.frequency_12m = 0 THEN 'No Activity in 12M'
                ELSE 'Activity in 12M' END AS activity_history
    FROM raw_customers c
    LEFT JOIN activity a ON c.customer_id = a.customer_id
),
tiles AS (
    SELECT customer_id, recency_days, frequency_12m, monetary_activity_12m,
           NTILE(5) OVER (ORDER BY recency_days, customer_id) AS r_tile,
           NTILE(5) OVER (ORDER BY frequency_12m, customer_id) AS f_tile,
           NTILE(5) OVER (ORDER BY monetary_activity_12m, customer_id) AS m_tile
    FROM metrics
    WHERE frequency_12m > 0
),
thresholds AS (
    SELECT
           MAX(CASE WHEN r_tile = 1 THEN recency_days END) AS r1,
           MAX(CASE WHEN r_tile = 2 THEN recency_days END) AS r2,
           MAX(CASE WHEN r_tile = 3 THEN recency_days END) AS r3,
           MAX(CASE WHEN r_tile = 4 THEN recency_days END) AS r4,
           MAX(CASE WHEN f_tile = 1 THEN frequency_12m END) AS f1,
           MAX(CASE WHEN f_tile = 2 THEN frequency_12m END) AS f2,
           MAX(CASE WHEN f_tile = 3 THEN frequency_12m END) AS f3,
           MAX(CASE WHEN f_tile = 4 THEN frequency_12m END) AS f4,
           MAX(CASE WHEN m_tile = 1 THEN monetary_activity_12m END) AS m1,
           MAX(CASE WHEN m_tile = 2 THEN monetary_activity_12m END) AS m2,
           MAX(CASE WHEN m_tile = 3 THEN monetary_activity_12m END) AS m3,
           MAX(CASE WHEN m_tile = 4 THEN monetary_activity_12m END) AS m4
    FROM tiles
),
scores AS (
    SELECT m.*,
           CASE WHEN frequency_12m = 0 THEN 1
                WHEN recency_days <= r1 THEN 5 WHEN recency_days <= r2 THEN 4
                WHEN recency_days <= r3 THEN 3 WHEN recency_days <= r4 THEN 2 ELSE 1 END AS r_score,
           CASE WHEN frequency_12m <= f1 THEN 1 WHEN frequency_12m <= f2 THEN 2
                WHEN frequency_12m <= f3 THEN 3 WHEN frequency_12m <= f4 THEN 4 ELSE 5 END AS f_score,
           CASE WHEN monetary_activity_12m <= m1 THEN 1 WHEN monetary_activity_12m <= m2 THEN 2
                WHEN monetary_activity_12m <= m3 THEN 3 WHEN monetary_activity_12m <= m4 THEN 4 ELSE 5 END AS m_score
    FROM metrics m
    CROSS JOIN thresholds
)
SELECT customer_id, gender, city, state, occupation, annual_income, join_date, credit_score,
       COALESCE(CAST(first_transaction_date AS CHAR), 'Never Transacted') AS first_transaction_date,
       COALESCE(CAST(last_transaction_date AS CHAR), 'Never Transacted') AS last_transaction_date,
       observation_date,
       CASE WHEN frequency_12m = 0 THEN 'No Activity' ELSE CAST(frequency_12m AS CHAR) END AS frequency_12m,
       CASE WHEN frequency_12m = 0 THEN 'No Activity' ELSE CAST(monetary_activity_12m AS CHAR) END AS monetary_activity_12m,
       CASE WHEN bank_count_12m = 0 THEN 'No Activity' ELSE CAST(bank_count_12m AS CHAR) END AS bank_count_12m,
       CASE WHEN bank_count_12m = 0 THEN 'No Activity' ELSE CAST(bank_amount_12m AS CHAR) END AS bank_amount_12m,
       CASE WHEN card_count_12m = 0 THEN 'No Activity' ELSE CAST(card_count_12m AS CHAR) END AS card_count_12m,
       CASE WHEN card_count_12m = 0 THEN 'No Activity' ELSE CAST(card_amount_12m AS CHAR) END AS card_amount_12m,
       COALESCE(CAST(recency_days AS CHAR), 'Never Transacted') AS recency_days,
       activity_history, r_score, f_score, m_score,
       CASE WHEN activity_history <> 'Activity in 12M' THEN activity_history
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 THEN 'Hibernating'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Low Frequency'
            ELSE 'Needs Attention' END AS rfm_segment,
       CONCAT(r_score, f_score, m_score) AS rfm_score
FROM scores;

-- churn_monthly_trend
CREATE VIEW customer_observation_months AS
SELECT DISTINCT LAST_DAY(txn_date) AS observation_date
FROM customer_activity
WHERE txn_date <= '2026-06-30';

CREATE TABLE churn_monthly_trend AS
WITH monthly_activity AS (
    SELECT customer_id, LAST_DAY(txn_date) AS observation_date,
           MAX(txn_date) AS last_transaction_date
    FROM customer_activity
    WHERE txn_date <= '2026-06-30'
    GROUP BY customer_id, LAST_DAY(txn_date)
),
recency AS (
    SELECT c.customer_id, m.observation_date,
           MAX(a.last_transaction_date) OVER (
               PARTITION BY c.customer_id ORDER BY m.observation_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS last_transaction_date
    FROM raw_customers c
    CROSS JOIN customer_observation_months m
    LEFT JOIN monthly_activity a
      ON c.customer_id = a.customer_id AND m.observation_date = a.observation_date
),
counts AS (
    SELECT observation_date,
           SUM(DATEDIFF(observation_date, last_transaction_date) <= 90) AS active_customers,
           SUM(DATEDIFF(observation_date, last_transaction_date) BETWEEN 91 AND 180) AS at_risk_customers,
           SUM(DATEDIFF(observation_date, last_transaction_date) > 180) AS churned_customers,
           SUM(last_transaction_date IS NULL) AS never_transacted_customers
    FROM recency
    GROUP BY observation_date
)
SELECT *, churned_customers / (active_customers + at_risk_customers + churned_customers) AS churn_rate
FROM counts;

-- customer monthly status
CREATE TABLE customer_monthly_status AS
WITH channel_types AS (
    SELECT DISTINCT channel, card_type FROM customer_activity
),
monthly_activity AS (
    SELECT customer_id, channel, card_type, LAST_DAY(txn_date) AS observation_date,
           MAX(txn_date) AS last_transaction_date
    FROM customer_activity
    WHERE txn_date <= '2026-06-30'
    GROUP BY customer_id, channel, card_type, LAST_DAY(txn_date)
),
recency AS (
    SELECT c.customer_id, COALESCE(NULLIF(c.state, ''), NULLIF(c.city, ''), 'Unknown') AS location,
           t.channel, t.card_type, m.observation_date,
           MAX(a.last_transaction_date) OVER (
               PARTITION BY c.customer_id, t.channel, t.card_type ORDER BY m.observation_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS last_transaction_date
    FROM raw_customers c
    CROSS JOIN channel_types t
    CROSS JOIN customer_observation_months m
    LEFT JOIN monthly_activity a
      ON c.customer_id = a.customer_id
     AND t.channel = a.channel AND t.card_type = a.card_type
     AND m.observation_date = a.observation_date
),
counts AS (
    SELECT observation_date, location, channel, card_type,
           SUM(CASE WHEN DATEDIFF(observation_date, last_transaction_date) <= 90 THEN 1 ELSE 0 END) AS active_count,
           SUM(CASE WHEN DATEDIFF(observation_date, last_transaction_date) BETWEEN 91 AND 180 THEN 1 ELSE 0 END) AS at_risk_count,
           SUM(CASE WHEN DATEDIFF(observation_date, last_transaction_date) > 180 THEN 1 ELSE 0 END) AS churned_count,
           SUM(last_transaction_date IS NULL) AS never_transacted_count
    FROM recency
    GROUP BY observation_date, location, channel, card_type
)
SELECT c.*, t.churn_rate
FROM counts c
JOIN churn_monthly_trend t ON c.observation_date = t.observation_date;
