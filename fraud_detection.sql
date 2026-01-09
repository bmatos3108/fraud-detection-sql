-- ============================================================================
-- FINANCIAL FRAUD DETECTION SYSTEM
-- Author: Sofia Herrmann
-- Description: Advanced SQL-based fraud detection using pattern recognition,
--              anomaly detection, and behavioral analysis
-- Skills: Window Functions, CTEs, Complex JOINs, Statistical Analysis
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATABASE SETUP & SAMPLE DATA
-- ============================================================================

CREATE DATABASE fraud_detection;
USE fraud_detection;

-- Customer accounts table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    account_number VARCHAR(20) UNIQUE,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    country VARCHAR(50),
    account_created_date DATE,
    risk_score INT DEFAULT 0
);

-- Transactions table
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY,
    customer_id INT,
    transaction_date TIMESTAMP,
    transaction_type VARCHAR(20), -- 'Purchase', 'ATM', 'Transfer', 'Online'
    amount DECIMAL(10, 2),
    merchant_name VARCHAR(100),
    merchant_category VARCHAR(50),
    location_city VARCHAR(50),
    location_country VARCHAR(50),
    device_id VARCHAR(50),
    ip_address VARCHAR(45),
    is_flagged BOOLEAN DEFAULT FALSE,
    fraud_reason VARCHAR(200),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Known fraud cases (for training/validation)
CREATE TABLE fraud_cases (
    case_id INT PRIMARY KEY,
    transaction_id INT,
    fraud_type VARCHAR(50),
    confirmed_date DATE,
    loss_amount DECIMAL(10, 2),
    investigation_notes TEXT,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
);

-- Insert sample customers
INSERT INTO customers VALUES
(1, 'ACC001', 'Emma Schmidt', 'emma.s@email.com', '+49-160-1234567', 'Hauptstr 10', 'Hamburg', 'Germany', '2020-01-15', 0),
(2, 'ACC002', 'Liam Mueller', 'liam.m@email.com', '+49-170-2345678', 'Berliner Str 25', 'Berlin', 'Germany', '2021-03-20', 0),
(3, 'ACC003', 'Sophie Weber', 'sophie.w@email.com', '+49-151-3456789', 'Kölner Weg 5', 'Cologne', 'Germany', '2019-06-10', 0),
(4, 'ACC004', 'Noah Fischer', 'noah.f@email.com', '+49-162-4567890', 'Münchner Pl 15', 'Munich', 'Germany', '2022-02-28', 0),
(5, 'ACC005', 'Mia Becker', 'mia.b@email.com', '+49-172-5678901', 'Frankfurter Allee 30', 'Frankfurt', 'Germany', '2020-11-05', 0);

-- Insert sample transactions (mix of normal and suspicious)
INSERT INTO transactions VALUES
-- Normal transactions for Emma
(1, 1, '2024-01-10 14:30:00', 'Purchase', 45.99, 'Rewe Supermarkt', 'Groceries', 'Hamburg', 'Germany', 'DEVICE001', '85.214.132.117', FALSE, NULL),
(2, 1, '2024-01-11 09:15:00', 'Purchase', 89.50, 'Zalando', 'Clothing', 'Hamburg', 'Germany', 'DEVICE001', '85.214.132.117', FALSE, NULL),
(3, 1, '2024-01-12 19:45:00', 'ATM', 200.00, 'Sparkasse ATM', 'Cash Withdrawal', 'Hamburg', 'Germany', 'ATM001', NULL, FALSE, NULL),

-- FRAUD PATTERN 1: Rapid succession purchases in different countries (Emma - compromised card)
(4, 1, '2024-01-15 02:30:00', 'Purchase', 1299.99, 'Electronics Shop', 'Electronics', 'London', 'UK', 'DEVICE999', '82.45.123.98', FALSE, NULL),
(5, 1, '2024-01-15 02:35:00', 'Purchase', 899.99, 'Luxury Store', 'Jewelry', 'Paris', 'France', 'DEVICE888', '78.123.45.67', FALSE, NULL),
(6, 1, '2024-01-15 02:42:00', 'Online', 2499.99, 'Amazon.com', 'Electronics', 'Amsterdam', 'Netherlands', 'DEVICE777', '94.211.87.45', FALSE, NULL),

-- Normal transactions for Liam
(7, 2, '2024-01-10 12:00:00', 'Purchase', 25.50, 'Starbucks', 'Food', 'Berlin', 'Germany', 'DEVICE002', '77.180.252.13', FALSE, NULL),
(8, 2, '2024-01-11 18:30:00', 'Purchase', 65.00, 'Restaurant Berlin', 'Dining', 'Berlin', 'Germany', 'DEVICE002', '77.180.252.13', FALSE, NULL),

-- FRAUD PATTERN 2: Round number transactions (Liam - account takeover)
(9, 2, '2024-01-16 03:15:00', 'Transfer', 5000.00, 'International Transfer', 'Transfer', 'Berlin', 'Germany', 'DEVICE666', '203.45.67.89', FALSE, NULL),
(10, 2, '2024-01-16 03:18:00', 'Transfer', 3000.00, 'International Transfer', 'Transfer', 'Berlin', 'Germany', 'DEVICE666', '203.45.67.89', FALSE, NULL),
(11, 2, '2024-01-16 03:22:00', 'Transfer', 2000.00, 'International Transfer', 'Transfer', 'Berlin', 'Germany', 'DEVICE666', '203.45.67.89', FALSE, NULL),

-- Normal transactions for Sophie
(12, 3, '2024-01-10 10:30:00', 'Purchase', 55.00, 'DM Drogerie', 'Personal Care', 'Cologne', 'Germany', 'DEVICE003', '46.114.6.78', FALSE, NULL),
(13, 3, '2024-01-12 15:45:00', 'Purchase', 120.00, 'MediaMarkt', 'Electronics', 'Cologne', 'Germany', 'DEVICE003', '46.114.6.78', FALSE, NULL),

-- FRAUD PATTERN 3: Unusual time and amount (Sophie - stolen card)
(14, 3, '2024-01-17 03:00:00', 'Purchase', 3999.99, 'Luxury Electronics', 'Electronics', 'Dubai', 'UAE', 'DEVICE555', '185.27.134.24', FALSE, NULL),
(15, 3, '2024-01-17 03:05:00', 'ATM', 1000.00, 'ATM Dubai', 'Cash Withdrawal', 'Dubai', 'UAE', 'ATM999', NULL, FALSE, NULL),

-- Normal transactions for Noah
(16, 4, '2024-01-10 16:00:00', 'Purchase', 35.00, 'Shell Station', 'Gas', 'Munich', 'Germany', 'DEVICE004', '93.211.165.42', FALSE, NULL),
(17, 4, '2024-01-13 11:30:00', 'Online', 79.99, 'Amazon.de', 'Books', 'Munich', 'Germany', 'DEVICE004', '93.211.165.42', FALSE, NULL),

-- FRAUD PATTERN 4: Multiple failed attempts then success (Noah - card testing)
(18, 4, '2024-01-18 01:00:00', 'Purchase', 1.00, 'Test Merchant', 'Online', 'Unknown', 'Russia', 'DEVICE444', '91.213.8.252', FALSE, NULL),
(19, 4, '2024-01-18 01:02:00', 'Purchase', 2.00, 'Test Merchant', 'Online', 'Unknown', 'Russia', 'DEVICE444', '91.213.8.252', FALSE, NULL),
(20, 4, '2024-01-18 01:05:00', 'Purchase', 1899.99, 'Online Store', 'Electronics', 'Unknown', 'Russia', 'DEVICE444', '91.213.8.252', FALSE, NULL),

-- Normal transactions for Mia
(21, 5, '2024-01-10 13:00:00', 'Purchase', 42.00, 'Edeka', 'Groceries', 'Frankfurt', 'Germany', 'DEVICE005', '84.159.92.31', FALSE, NULL),
(22, 5, '2024-01-14 17:00:00', 'Purchase', 150.00, 'H&M', 'Clothing', 'Frankfurt', 'Germany', 'DEVICE005', '84.159.92.31', FALSE, NULL);


-- ============================================================================
-- SECTION 2: FRAUD DETECTION QUERIES - RULE-BASED DETECTION
-- ============================================================================

-- QUERY 1: Detect Rapid Succession Transactions (Velocity Check)
-- Business Rule: More than 3 transactions within 1 hour in different countries = FRAUD
-- ============================================================================
WITH transaction_intervals AS (
    SELECT 
        t1.transaction_id,
        t1.customer_id,
        t1.transaction_date,
        t1.amount,
        t1.location_country,
        t1.merchant_name,
        COUNT(t2.transaction_id) AS txn_count_1hour,
        COUNT(DISTINCT t2.location_country) AS countries_visited
    FROM transactions t1
    LEFT JOIN transactions t2 
        ON t1.customer_id = t2.customer_id
        AND t2.transaction_date BETWEEN t1.transaction_date - INTERVAL '1 hour' 
                                    AND t1.transaction_date
    GROUP BY t1.transaction_id, t1.customer_id, t1.transaction_date, 
             t1.amount, t1.location_country, t1.merchant_name
)
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    amount,
    location_country,
    merchant_name,
    txn_count_1hour,
    countries_visited,
    'VELOCITY: Multiple countries in 1 hour' AS fraud_type,
    'HIGH' AS risk_level
FROM transaction_intervals
WHERE countries_visited > 2 
  AND txn_count_1hour > 2
ORDER BY transaction_date;


-- QUERY 2: Detect Unusual Transaction Amounts (Statistical Anomaly)
-- Business Rule: Transaction > 3 standard deviations from customer's average = SUSPICIOUS
-- ============================================================================
WITH customer_stats AS (
    SELECT 
        customer_id,
        AVG(amount) AS avg_amount,
        STDDEV(amount) AS stddev_amount,
        COUNT(*) AS transaction_count
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY customer_id
    HAVING COUNT(*) >= 5  -- Only for customers with sufficient history
),
anomalies AS (
    SELECT 
        t.transaction_id,
        t.customer_id,
        t.transaction_date,
        t.amount,
        t.merchant_name,
        t.location_country,
        cs.avg_amount,
        cs.stddev_amount,
        ROUND((t.amount - cs.avg_amount) / NULLIF(cs.stddev_amount, 0), 2) AS z_score
    FROM transactions t
    JOIN customer_stats cs ON t.customer_id = cs.customer_id
)
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    amount,
    merchant_name,
    location_country,
    ROUND(avg_amount, 2) AS customer_avg,
    ROUND(stddev_amount, 2) AS customer_stddev,
    z_score,
    'ANOMALY: Amount exceeds 3 standard deviations' AS fraud_type,
    CASE 
        WHEN ABS(z_score) > 5 THEN 'CRITICAL'
        WHEN ABS(z_score) > 3 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS risk_level
FROM anomalies
WHERE ABS(z_score) > 3
ORDER BY ABS(z_score) DESC;


-- QUERY 3: Detect Late Night High-Value Transactions
-- Business Rule: Transactions over €1000 between 11PM-5AM in unusual locations = SUSPICIOUS
-- ============================================================================
WITH customer_usual_locations AS (
    SELECT 
        customer_id,
        location_country,
        location_city,
        COUNT(*) AS visit_count
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '180 days'
    GROUP BY customer_id, location_country, location_city
    HAVING COUNT(*) >= 3  -- Location visited at least 3 times = "usual"
)
SELECT 
    t.transaction_id,
    t.customer_id,
    t.transaction_date,
    EXTRACT(HOUR FROM t.transaction_date) AS hour_of_day,
    t.amount,
    t.merchant_name,
    t.location_city,
    t.location_country,
    CASE 
        WHEN ul.customer_id IS NULL THEN 'NEW LOCATION'
        ELSE 'KNOWN LOCATION'
    END AS location_status,
    'TIME: High-value transaction at unusual hour in new location' AS fraud_type,
    'HIGH' AS risk_level
FROM transactions t
LEFT JOIN customer_usual_locations ul 
    ON t.customer_id = ul.customer_id 
    AND t.location_country = ul.location_country
WHERE t.amount > 1000
  AND EXTRACT(HOUR FROM t.transaction_date) BETWEEN 23 AND 5
  AND ul.customer_id IS NULL  -- Not a usual location
ORDER BY t.transaction_date DESC;


-- QUERY 4: Detect Round Number Fraud Pattern
-- Business Rule: Multiple round-number transactions (testing stolen cards)
-- ============================================================================
WITH round_number_txns AS (
    SELECT 
        customer_id,
        transaction_id,
        transaction_date,
        amount,
        merchant_name,
        location_country,
        CASE 
            WHEN amount % 1000 = 0 THEN 'Round to 1000'
            WHEN amount % 100 = 0 THEN 'Round to 100'
            WHEN amount % 10 = 0 THEN 'Round to 10'
        END AS round_type,
        COUNT(*) OVER (
            PARTITION BY customer_id 
            ORDER BY transaction_date 
            RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND CURRENT ROW
        ) AS round_txn_count_24h
    FROM transactions
    WHERE amount % 10 = 0  -- All round numbers
)
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    amount,
    merchant_name,
    location_country,
    round_type,
    round_txn_count_24h,
    'PATTERN: Multiple round-number transactions' AS fraud_type,
    CASE 
        WHEN round_txn_count_24h >= 3 AND round_type = 'Round to 1000' THEN 'CRITICAL'
        WHEN round_txn_count_24h >= 3 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS risk_level
FROM round_number_txns
WHERE round_txn_count_24h >= 2
  AND amount > 500
ORDER BY round_txn_count_24h DESC, transaction_date;


-- QUERY 5: Detect Card Testing Pattern (Small then Large)
-- Business Rule: Small test transactions followed by large purchase = FRAUD
-- ============================================================================
WITH ordered_transactions AS (
    SELECT 
        transaction_id,
        customer_id,
        transaction_date,
        amount,
        merchant_name,
        location_country,
        LAG(amount, 1) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_amount_1,
        LAG(amount, 2) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_amount_2,
        LAG(transaction_date, 1) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_date_1
    FROM transactions
)
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    amount AS large_purchase,
    prev_amount_1,
    prev_amount_2,
    merchant_name,
    location_country,
    EXTRACT(EPOCH FROM (transaction_date - prev_date_1))/60 AS minutes_since_last,
    'TESTING: Small test transactions followed by large purchase' AS fraud_type,
    'CRITICAL' AS risk_level
FROM ordered_transactions
WHERE amount > 1000  -- Large purchase
  AND prev_amount_1 < 10  -- Previous transaction was small
  AND prev_amount_2 < 10  -- Transaction before that was also small
  AND EXTRACT(EPOCH FROM (transaction_date - prev_date_1))/60 < 30  -- Within 30 minutes
ORDER BY transaction_date DESC;


-- ============================================================================
-- SECTION 3: COMPREHENSIVE FRAUD RISK SCORING
-- ============================================================================

-- QUERY 6: Calculate Overall Fraud Risk Score for Each Transaction
-- Combines multiple risk factors into a single score
-- ============================================================================
WITH risk_factors AS (
    SELECT 
        t.transaction_id,
        t.customer_id,
        t.transaction_date,
        t.amount,
        t.merchant_name,
        t.location_country,
        
        -- Factor 1: High amount (20 points if > 3x customer average)
        CASE 
            WHEN t.amount > (SELECT AVG(amount) * 3 FROM transactions t2 
                           WHERE t2.customer_id = t.customer_id) 
            THEN 20 ELSE 0 
        END AS high_amount_score,
        
        -- Factor 2: Unusual time (15 points for late night 11PM-5AM)
        CASE 
            WHEN EXTRACT(HOUR FROM t.transaction_date) BETWEEN 23 AND 5 
            THEN 15 ELSE 0 
        END AS unusual_time_score,
        
        -- Factor 3: New location (25 points)
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM transactions t2 
                WHERE t2.customer_id = t.customer_id 
                  AND t2.location_country = t.location_country 
                  AND t2.transaction_id < t.transaction_id
                  AND t2.transaction_date >= t.transaction_date - INTERVAL '180 days'
            ) THEN 25 ELSE 0 
        END AS new_location_score,
        
        -- Factor 4: High velocity (20 points if > 3 txns in 1 hour)
        CASE 
            WHEN (SELECT COUNT(*) FROM transactions t2 
                  WHERE t2.customer_id = t.customer_id 
                    AND t2.transaction_date BETWEEN t.transaction_date - INTERVAL '1 hour' 
                                                AND t.transaction_date) > 3 
            THEN 20 ELSE 0 
        END AS velocity_score,
        
        -- Factor 5: Round number (10 points)
        CASE 
            WHEN t.amount % 100 = 0 AND t.amount >= 1000 
            THEN 10 ELSE 0 
        END AS round_number_score,
        
        -- Factor 6: Foreign country (10 points if not Germany)
        CASE 
            WHEN t.location_country != (SELECT country FROM customers WHERE customer_id = t.customer_id) 
            THEN 10 ELSE 0 
        END AS foreign_country_score
        
    FROM transactions t
)
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    amount,
    merchant_name,
    location_country,
    (high_amount_score + unusual_time_score + new_location_score + 
     velocity_score + round_number_score + foreign_country_score) AS total_risk_score,
    CASE 
        WHEN (high_amount_score + unusual_time_score + new_location_score + 
              velocity_score + round_number_score + foreign_country_score) >= 60 THEN 'CRITICAL - Block Transaction'
        WHEN (high_amount_score + unusual_time_score + new_location_score + 
              velocity_score + round_number_score + foreign_country_score) >= 40 THEN 'HIGH - Manual Review Required'
        WHEN (high_amount_score + unusual_time_score + new_location_score + 
              velocity_score + round_number_score + foreign_country_score) >= 20 THEN 'MEDIUM - Monitor'
        ELSE 'LOW - Approve'
    END AS risk_classification,
    CONCAT(
        CASE WHEN high_amount_score > 0 THEN 'High Amount | ' ELSE '' END,
        CASE WHEN unusual_time_score > 0 THEN 'Unusual Time | ' ELSE '' END,
        CASE WHEN new_location_score > 0 THEN 'New Location | ' ELSE '' END,
        CASE WHEN velocity_score > 0 THEN 'High Velocity | ' ELSE '' END,
        CASE WHEN round_number_score > 0 THEN 'Round Number | ' ELSE '' END,
        CASE WHEN foreign_country_score > 0 THEN 'Foreign Country | ' ELSE '' END
    ) AS risk_reasons
FROM risk_factors
WHERE (high_amount_score + unusual_time_score + new_location_score + 
       velocity_score + round_number_score + foreign_country_score) > 0
ORDER BY total_risk_score DESC, transaction_date DESC;


-- ============================================================================
-- SECTION 4: FRAUD INVESTIGATION & REPORTING
-- ============================================================================

-- QUERY 7: Customer Fraud Summary Report
-- Shows comprehensive fraud activity by customer
-- ============================================================================
WITH customer_fraud_metrics AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.account_number,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        SUM(t.amount) AS total_transaction_value,
        COUNT(DISTINCT CASE WHEN t.is_flagged THEN t.transaction_id END) AS flagged_count,
        SUM(CASE WHEN t.is_flagged THEN t.amount ELSE 0 END) AS flagged_amount,
        COUNT(DISTINCT fc.case_id) AS confirmed_fraud_cases,
        COALESCE(SUM(fc.loss_amount), 0) AS total_fraud_loss,
        ROUND(
            COUNT(DISTINCT CASE WHEN t.is_flagged THEN t.transaction_id END) * 100.0 / 
            NULLIF(COUNT(DISTINCT t.transaction_id), 0), 2
        ) AS fraud_rate_percent
    FROM customers c
    LEFT JOIN transactions t ON c.customer_id = t.customer_id
    LEFT JOIN fraud_cases fc ON t.transaction_id = fc.transaction_id
    GROUP BY c.customer_id, c.customer_name, c.account_number
)
SELECT 
    customer_id,
    customer_name,
    account_number,
    total_transactions,
    ROUND(total_transaction_value, 2) AS total_value,
    flagged_count,
    ROUND(flagged_amount, 2) AS flagged_value,
    confirmed_fraud_cases,
    ROUND(total_fraud_loss, 2) AS fraud_loss,
    fraud_rate_percent,
    CASE 
        WHEN fraud_rate_percent > 20 THEN 'High Risk - Review Account'
        WHEN fraud_rate_percent > 10 THEN 'Medium Risk - Monitor'
        WHEN fraud_rate_percent > 0 THEN 'Low Risk'
        ELSE 'No Fraud History'
    END AS customer_risk_category
FROM customer_fraud_metrics
WHERE total_transactions > 0
ORDER BY fraud_rate_percent DESC, total_fraud_loss DESC;


-- ============================================================================
-- KEY INSIGHTS & BUSINESS RECOMMENDATIONS
-- ============================================================================

/*
FRAUD PATTERNS IDENTIFIED:

1. VELOCITY ATTACKS (Query 1)
   - Multiple transactions in different countries within 1 hour
   - Recommendation: Implement real-time geolocation checks
   
2. STATISTICAL ANOMALIES (Query 2)
   - Transactions 3+ standard deviations from customer average
   - Recommendation: Set dynamic transaction limits based on customer behavior
   
3. TIME-BASED FRAUD (Query 3)
   - High-value purchases during late night hours (11PM-5AM)
   - Recommendation: Additional authentication for late-night high-value transactions
   
4. ROUND NUMBER PATTERN (Query 4)
   - Multiple round-number transactions indicate card testing
   - Recommendation: Flag accounts with 2+ round-number transactions in 24 hours
   
5. CARD TESTING (Query 5)
   - Small transactions followed by large purchase within 30 minutes
   - Recommendation: Automatic block if pattern detected
   
6. COMPREHENSIVE RISK SCORING (Query 6)
   - Multi-factor risk assessment combining all patterns
   - Recommendation: Auto-block transactions scoring > 60 points

PREVENTION STRATEGIES:
- Real-time transaction monitoring
- Machine learning model training on confirmed fraud cases
- Customer behavior profiling
- Geographic velocity checks
- Device fingerprinting
- 2FA for high-risk transactions
*/
