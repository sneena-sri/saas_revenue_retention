USE saas_analyticsdb;

SELECT COUNT(*) AS cus_count
FROM customers;

SELECT COUNT(*) AS plan_count
FROM plans;

SELECT COUNT(*) AS event_count
FROM subscription_events;

select * from customers;
select * from plans;
select * from subscription_events;

# Data Quality Audit
# 1. Check for orphan customers
SELECT e.*
FROM subscription_events e
LEFT JOIN customers c
    ON e.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

# 2. Check duplicate event IDs
SELECT
    event_id,
    COUNT(*) AS duplicate_count
FROM subscription_events
GROUP BY event_id
HAVING COUNT(*) > 1;

# 3.Check missing values
SELECT
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(event_date IS NULL) AS missing_event_date,
    SUM(event_type IS NULL) AS missing_event_type,
    SUM(mrr_amount IS NULL) AS missing_mrr
FROM subscription_events;

# 4.Check the event types
SELECT
    event_type,
    COUNT(*) AS event_count
FROM subscription_events
GROUP BY event_type
ORDER BY event_count DESC;


