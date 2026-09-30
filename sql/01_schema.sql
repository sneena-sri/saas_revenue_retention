-- =========================================================
-- SaaS_Revenue_Retention
-- Schema: MySQL 8.0+
-- =========================================================

CREATE DATABASE IF NOT EXISTS saas_analyticsdb;
USE saas_analyticsdb;

DROP TABLE IF EXISTS subscription_events;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS plans;


-- ---------------------------------------------------------
-- customers
-- ---------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR(10) PRIMARY KEY,
    signup_date DATE NOT NULL,
    signup_month VARCHAR(7) NOT NULL,
    initial_plan VARCHAR(20) NOT NULL,
    billing_cycle ENUM('Monthly','Annual') NOT NULL,
    acquisition_channel VARCHAR(30),
    region VARCHAR(20)
);

-- ---------------------------------------------------------
-- plans
-- ---------------------------------------------------------
CREATE TABLE plans (
    plan VARCHAR(20) PRIMARY KEY,
    monthly_price_inr DECIMAL(10,2) NOT NULL,
    annual_price_inr_per_month_equiv DECIMAL(10,2) NOT NULL,
    tier_rank INT NOT NULL
);

-- ---------------------------------------------------------
-- subscription_events
-- ---------------------------------------------------------
CREATE TABLE subscription_events (
    event_id VARCHAR(10) PRIMARY KEY,
    customer_id VARCHAR(10) NOT NULL,
    event_date DATE,
    event_type ENUM('New','Upgrade','Downgrade','Churn','Reactivation') NOT NULL,
    plan_before VARCHAR(20),
    plan_after VARCHAR(20),
    mrr_amount DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_events_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);