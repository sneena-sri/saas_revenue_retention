USE saas_analyticsdb;

# 1. Build a monthly MRR waterfall: New, Expansion, Contraction, Churn, Reactivation, and Net New MRR.
WITH monthly_event AS (
    SELECT
        DATE_FORMAT(event_date, '%Y-%m') AS event_month,
        event_type,
        mrr_amount
    FROM subscription_events
    WHERE event_date IS NOT NULL
)
SELECT
    event_month,
    SUM(CASE WHEN event_type = 'New'          THEN mrr_amount ELSE 0 END) AS new_mrr,
    SUM(CASE WHEN event_type = 'Upgrade'       THEN mrr_amount ELSE 0 END) AS expansion_mrr,
    SUM(CASE WHEN event_type = 'Downgrade'     THEN mrr_amount ELSE 0 END) AS contraction_mrr,
    SUM(CASE WHEN event_type = 'Churn'         THEN mrr_amount ELSE 0 END) AS churned_mrr,
    SUM(CASE WHEN event_type = 'Reactivation'  THEN mrr_amount ELSE 0 END) AS reactivation_mrr,
    SUM(mrr_amount) AS net_new_mrr
FROM monthly_event
GROUP BY event_month
ORDER BY event_month;

# 2. Compute running Total MRR by month across the full data history.
WITH monthly_net_mrr AS (
	SELECT
		DATE_FORMAT(event_date, '%Y-%m') AS event_month,
        SUM(mrr_amount) AS net_new_mrr
	FROM subscription_events
    WHERE event_date IS NOT NULL
    GROUP BY event_month
),
monthly_mrr AS (
	SELECT
		event_month,
		net_new_mrr,
		SUM(net_new_mrr) OVER (ORDER BY event_month) AS total_mrr
	FROM monthly_net_mrr
)

SELECT
	event_month,
    net_new_mrr,
    total_mrr,
    LAG(total_mrr) OVER (ORDER BY event_month) AS prev_mrr,
    ROUND((total_mrr - LAG(total_mrr) OVER (ORDER BY event_month)) / NULLIF(LAG(total_mrr) OVER (ORDER BY event_month),0) * 100 , 2) AS mon_growing_pct
FROM monthly_mrr
ORDER BY event_month;

# 3. Calculate Net Revenue Retention (NRR) and Gross Revenue Retention (GRR) by cohort.
WITH cohort_stats AS (
	SELECT
		customer_id,
        mrr_amount AS starting_mrr,
        DATE_FORMAT(event_date, '%Y-%m') AS event_month
	FROM subscription_events
    WHERE event_type='New'
),
cohort_amt AS (
	SELECT
		cs.customer_id,
        cs.starting_mrr,
        SUM(CASE WHEN s.event_type='Upgrade' THEN s.mrr_amount ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN s.event_type='Downgrade' THEN s.mrr_amount ELSE 0 END) AS contraction_mrr,
        SUM(CASE WHEN s.event_type='Churn' THEN s.mrr_amount ELSE 0 END) AS churn_mrr
	FROM cohort_stats cs
    LEFT JOIN subscription_events s
    ON cs.customer_id = s.customer_id
    GROUP BY cs.customer_id, cs.starting_mrr
)

SELECT
	ROUND(
		SUM(starting_mrr+expansion_mrr+contraction_mrr+churn_mrr) / SUM(starting_mrr) *100
        ,1) AS nrr_pct,
	ROUND(
		SUM(starting_mrr+contraction_mrr+churn_mrr) / SUM(starting_mrr) * 100
        ,1) AS grr_pct
FROM cohort_amt;

# 4. Segment churn rate (multi-column GROUP BY)
SELECT
	c.billing_cycle,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN s.event_type='Churn' THEN c.customer_id END) AS churrned_customers,
    ROUND(
		COUNT(DISTINCT CASE WHEN s.event_type='Churn' THEN c.customer_id END) / COUNT(DISTINCT c.customer_id) * 100,
        1
	) AS churn_rate_pct
FROM customers c
LEFT JOIN subscription_events s ON c.customer_id = s.customer_id
GROUP BY c.billing_cycle
ORDER BY churn_rate_pct DESC;

# 5. Product rank / quartile example (window functions: NTILE, DENSE_RANK)
WITH customer_mrr AS (
	SELECT
		customer_id,
        SUM(mrr_amount) AS mrr_amount
	FROM subscription_events
    GROUP BY customer_id
)

SELECT
	customer_id,
    mrr_amount,
    NTILE(4) OVER (ORDER BY mrr_amount DESC) AS amt_quartile,
    DENSE_RANK() OVER (ORDER BY mrr_amount DESC) AS amt_rank
FROM customer_mrr;

# 6.  View (deliverable for 1)
CREATE VIEW mrr_monthly AS
WITH monthly_event AS (
	SELECT DATE_FORMAT(event_date, '%Y-%m') AS event_month, event_type, mrr_amount
    FROM subscription_events
    WHERE event_date IS NOT NULL
)
SELECT
    event_month,
    SUM(CASE WHEN event_type = 'New' THEN mrr_amount ELSE 0 END) AS new_mrr,
    SUM(CASE WHEN event_type = 'Upgrade' THEN mrr_amount ELSE 0 END) AS expansion_mrr,
    SUM(CASE WHEN event_type = 'Downgrade' THEN mrr_amount ELSE 0 END) AS contraction_mrr,
    SUM(CASE WHEN event_type = 'Churn' THEN mrr_amount ELSE 0 END) AS churned_mrr,
    SUM(CASE WHEN event_type = 'Reactivation' THEN mrr_amount ELSE 0 END) AS reactivation_mrr,
    SUM(mrr_amount) AS net_new_mrr
FROM monthly_event
GROUP BY event_month;

SELECT * FROM mrr_monthly
ORDER BY event_month;

# 7.  CTAS (frozen snapshot table)
CREATE TABLE mrr_monthly_summary AS
SELECT * FROM mrr_monthly;

SELECT * FROM mrr_monthly_summary;

# 8. Stored procedure (parameterized waterfall)
DELIMITER $$

CREATE PROCEDURE get_mrr(IN target_month VARCHAR(7))
BEGIN
SELECT
	DATE_FORMAT(event_date, '%Y-%m') AS event_month,
        SUM(CASE WHEN event_type = 'New' THEN mrr_amount ELSE 0 END) AS new_mrr,
        SUM(CASE WHEN event_type = 'Upgrade' THEN mrr_amount ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN event_type = 'Downgrade' THEN mrr_amount ELSE 0 END) AS contraction_mrr,
        SUM(CASE WHEN event_type = 'Churn' THEN mrr_amount ELSE 0 END) AS churned_mrr,
        SUM(CASE WHEN event_type = 'Reactivation' THEN mrr_amount ELSE 0 END) AS reactivation_mrr,
        SUM(mrr_amount) AS net_new_mrr
    FROM subscription_events
    WHERE DATE_FORMAT(event_date, '%Y-%m') = target_month
    GROUP BY event_month;
END$$

DELIMITER ;

CALL get_mrr('2025-12');