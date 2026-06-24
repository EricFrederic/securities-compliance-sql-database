-- ============================================================
-- SECURITIES COMPLIANCE DATABASE
-- Author: Eric A. Frederic, MBA
-- Description: A multi-table relational database simulating a
-- securities regulatory compliance environment. Models real-world
-- workflows used by state securities bureaus and FINRA examiners
-- to track registered entities, flag suspicious transactions,
-- and manage examination caseloads.
-- ============================================================


-- ============================================================
-- SECTION 1: DATABASE CREATION
-- ============================================================

-- Check if the database exists before creating it.
-- IF NOT EXISTS prevents the "database already exists" error
-- when running this script on a machine where it was previously built.
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SecuritiesCompliance')
BEGIN
    CREATE DATABASE SecuritiesCompliance;
END
GO

USE SecuritiesCompliance;
GO


-- ============================================================
-- SECTION 2: TABLE CLEANUP AND CREATION
-- ============================================================

DROP TABLE IF EXISTS Compliance_Flags;
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Accounts;
DROP TABLE IF EXISTS Securities;
DROP TABLE IF EXISTS Examiners;
GO

-- Examiners table stores the compliance staff member assigned to oversee accounts.
-- IDENTITY(1,1) auto-generates primary keys so IDs are never manually assigned
-- cases_assigned defaults to 0 and can be updated as workload changes.

CREATE TABLE Examiners (
    examiner_id INT PRIMARY KEY IDENTITY(1,1),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    region VARCHAR(50),
    cases_assigned INT DEFAULT 0
);

-- Accounts table represents registered the financial entities examined.
-- The foreign key to Examiners enforces referential integrity. You cannot
-- assign an account to an examiner that doesn't exist in the system.
-- Status field tracks regulatory standing: Active, Suspended, Under Review.

CREATE TABLE Accounts (
    account_id INT PRIMARY KEY IDENTITY(1,1),
    client_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50),
    state VARCHAR(50),
    registration_date DATE,
    status VARCHAR(20) DEFAULT 'Active',
    examiner_id INT FOREIGN KEY REFERENCES Examiners(examiner_id)
);

-- Securities table is a reference table for the financial instruments being traded.
-- Keeping securities in a separate table avoids duplication
-- AAPL appears once here rather than repeating across thousands of transactions.

CREATE TABLE Securities (
    security_id INT PRIMARY KEY IDENTITY(1,1),
    ticker VARCHAR(10) NOT NULL,
    company_name VARCHAR(100),
    sector VARCHAR(50),
    security_type VARCHAR(50),
    exchange VARCHAR(20)
);

-- Transactions table is the core fact table of this database.
-- Foreign keys to both Accounts and Securities create a many-to-many
-- relationship resolved through this junction-style table.
-- total_value is a computed column 
-- SQL Server calculates it automatically
-- from quantity * price, ensuring it is always accurate and never manually
-- entered incorrectly. The CHECK constraint on transaction_type enforces
-- data integrity at the database level, rejecting any value other than
-- BUY or SELL before it enters the system.

CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY IDENTITY(1,1),
    account_id INT FOREIGN KEY REFERENCES Accounts(account_id),
    security_id INT FOREIGN KEY REFERENCES Securities(security_id),
    transaction_date DATE,
    transaction_type VARCHAR(10) CHECK (transaction_type IN ('BUY', 'SELL')),
    quantity INT,
    price DECIMAL(10,2),
    total_value AS (quantity * price)
);

-- Compliance_Flags table links violations back to both the account and the
-- specific transaction that triggered the flag. This dual foreign key
-- structure allows the examiners to drill from a high-level account view
-- down to the exact trade that raised concern.
-- The resolved BIT field (0 = unresolved, 1 = resolved) enables clearance
-- rate tracking, a key performance metric for any compliance program.
-- Severity CHECK constraint enforces a three-tier risk classification
-- consistent with standard regulatory examination frameworks.

CREATE TABLE Compliance_Flags (
    flag_id INT PRIMARY KEY IDENTITY(1,1),
    account_id INT FOREIGN KEY REFERENCES Accounts(account_id),
    transaction_id INT FOREIGN KEY REFERENCES Transactions(transaction_id),
    flag_date DATE,
    flag_type VARCHAR(100),
    severity VARCHAR(20) CHECK (severity IN ('Low', 'Medium', 'High')),
    resolved BIT DEFAULT 0,
    resolution_date DATE,
    examiner_id INT FOREIGN KEY REFERENCES Examiners(examiner_id)
);
GO

-- ============================================================
-- SECTION 3: DATA POPULATION
-- ============================================================

-- Populate Examiners first because Accounts references examiner_id.
-- Being a relational database, parent tables must be populated before
-- child tables to satisfy foreign key constraints.

INSERT INTO Examiners (first_name, last_name, region, cases_assigned)
VALUES
('Margaret', 'Sullivan', 'Northeast', 14),
('David', 'Chen', 'Southeast', 11),
('Patricia', 'Williams', 'Midwest', 9),
('James', 'Okafor', 'Southwest', 13),
('Rachel', 'Torres', 'West', 10);

SELECT * FROM Examiners;

-- Securities populated before Transactions for the same referential
-- integrity reason; transactions reference security_id.

INSERT INTO Securities (ticker, company_name, sector, security_type, exchange)
VALUES
('AAPL', 'Apple Inc.', 'Technology', 'Equity', 'NASDAQ'),
('JPM', 'JPMorgan Chase & Co.', 'Financial Services', 'Equity', 'NYSE'),
('XOM', 'Exxon Mobil Corporation', 'Energy', 'Equity', 'NYSE'),
('BND', 'Vanguard Total Bond Market ETF', 'Fixed Income', 'ETF', 'NASDAQ'),
('GS', 'Goldman Sachs Group Inc.', 'Financial Services', 'Equity', 'NYSE'),
('MSFT', 'Microsoft Corporation', 'Technology', 'Equity', 'NASDAQ'),
('PFE', 'Pfizer Inc.', 'Healthcare', 'Equity', 'NYSE'),
('SPY', 'SPDR S&P 500 ETF Trust', 'Diversified', 'ETF', 'NYSE'),
('BAC', 'Bank of America Corporation', 'Financial Services', 'Equity', 'NYSE'),
('CVX', 'Chevron Corporation', 'Energy', 'Equity', 'NYSE');

SELECT * FROM Securities;

-- Accounts include a mix of entity types (Broker-Dealer, Investment Adviser,
-- Hedge Fund) and statuses (Active, Suspended, Under Review) to enable
-- realistic filtering and status-based analysis in later queries.

INSERT INTO Accounts (client_name, account_type, state, registration_date, status, examiner_id)
VALUES
('Harrington Capital LLC', 'Broker-Dealer', 'New York', '2018-03-15', 'Active', 1),
('Coastal Wealth Advisors', 'Investment Adviser', 'Florida', '2019-07-22', 'Active', 2),
('Meridian Asset Management', 'Investment Adviser', 'Illinois', '2017-11-08', 'Active', 3),
('Blue Ridge Securities', 'Broker-Dealer', 'North Carolina', '2020-01-30', 'Active', 4),
('Pinnacle Fund Services', 'Hedge Fund', 'Texas', '2016-05-19', 'Active', 5),
('Atlantic Portfolio Group', 'Investment Adviser', 'New Jersey', '2021-09-12', 'Active', 1),
('Summit Trading Partners', 'Broker-Dealer', 'Connecticut', '2015-08-04', 'Active', 2),
('Lakefront Financial', 'Investment Adviser', 'Michigan', '2022-02-17', 'Active', 3),
('Desert Capital Advisors', 'Hedge Fund', 'Arizona', '2019-04-28', 'Suspended', 4),
('Pacific Crest Investments', 'Broker-Dealer', 'California', '2020-11-03', 'Active', 5),
('Northgate Securities', 'Broker-Dealer', 'Minnesota', '2018-06-14', 'Active', 1),
('Riverfront Wealth Management', 'Investment Adviser', 'Missouri', '2017-03-29', 'Active', 2),
('Keystone Fund Advisors', 'Hedge Fund', 'Pennsylvania', '2016-12-07', 'Under Review', 3),
('Bayou Asset Management', 'Investment Adviser', 'Louisiana', '2021-05-18', 'Active', 4),
('Cascade Portfolio Services', 'Broker-Dealer', 'Oregon', '2019-08-23', 'Active', 5);

SELECT * FROM Accounts;

-- 50 transactions spanning January 2023 through January 2024.
-- Transaction IDs are auto-generated and are referenced directly
-- in the Compliance_Flags inserts below, so order of insertion matters.

INSERT INTO Transactions (account_id, security_id, transaction_date, transaction_type, quantity, price)
VALUES
(1, 1, '2023-01-15', 'BUY', 500, 142.53),
(1, 5, '2023-01-22', 'BUY', 200, 354.12),
(2, 3, '2023-02-03', 'BUY', 1000, 109.87),
(2, 8, '2023-02-14', 'SELL', 750, 412.33),
(3, 2, '2023-02-28', 'BUY', 300, 138.92),
(3, 6, '2023-03-07', 'BUY', 400, 287.61),
(4, 1, '2023-03-15', 'SELL', 250, 157.43),
(4, 9, '2023-03-22', 'BUY', 600, 31.87),
(5, 5, '2023-04-04', 'BUY', 150, 398.22),
(5, 10, '2023-04-11', 'SELL', 800, 162.54),
(6, 6, '2023-04-19', 'BUY', 350, 301.44),
(6, 2, '2023-04-28', 'SELL', 200, 142.18),
(7, 8, '2023-05-03', 'BUY', 1000, 418.92),
(7, 4, '2023-05-17', 'SELL', 500, 74.33),
(8, 7, '2023-05-24', 'BUY', 400, 41.22),
(8, 3, '2023-06-02', 'BUY', 700, 112.44),
(9, 1, '2023-06-09', 'BUY', 1200, 184.33),
(9, 5, '2023-06-14', 'BUY', 300, 412.87),
(9, 9, '2023-06-21', 'SELL', 900, 28.44),
(10, 6, '2023-07-05', 'BUY', 250, 315.22),
(10, 2, '2023-07-12', 'BUY', 450, 149.87),
(11, 10, '2023-07-19', 'SELL', 600, 171.33),
(11, 7, '2023-07-26', 'BUY', 300, 38.92),
(12, 4, '2023-08-02', 'BUY', 800, 72.44),
(12, 8, '2023-08-09', 'SELL', 400, 431.22),
(13, 1, '2023-08-16', 'BUY', 2000, 178.54),
(13, 5, '2023-08-23', 'BUY', 500, 421.33),
(13, 9, '2023-08-30', 'SELL', 1500, 33.12),
(14, 3, '2023-09-06', 'BUY', 600, 118.44),
(14, 6, '2023-09-13', 'SELL', 200, 298.77),
(15, 2, '2023-09-20', 'BUY', 350, 155.33),
(15, 10, '2023-09-27', 'BUY', 700, 168.92),
(1, 7, '2023-10-04', 'SELL', 200, 44.33),
(2, 1, '2023-10-11', 'BUY', 300, 177.88),
(3, 9, '2023-10-18', 'SELL', 400, 35.44),
(4, 6, '2023-10-25', 'BUY', 500, 312.77),
(5, 3, '2023-11-01', 'BUY', 800, 107.33),
(6, 10, '2023-11-08', 'SELL', 300, 174.22),
(7, 5, '2023-11-15', 'BUY', 100, 438.91),
(8, 1, '2023-11-22', 'BUY', 450, 189.44),
(9, 4, '2023-11-29', 'SELL', 600, 71.88),
(10, 7, '2023-12-06', 'BUY', 350, 36.77),
(11, 2, '2023-12-13', 'SELL', 250, 163.44),
(12, 6, '2023-12-20', 'BUY', 400, 321.88),
(13, 10, '2023-12-27', 'BUY', 1000, 181.33),
(14, 8, '2024-01-03', 'SELL', 300, 445.22),
(15, 5, '2024-01-10', 'BUY', 200, 452.87),
(1, 9, '2024-01-17', 'BUY', 800, 37.44),
(2, 4, '2024-01-24', 'SELL', 500, 68.92),
(3, 7, '2024-01-31', 'BUY', 600, 42.33);

SELECT COUNT(*) AS total_transactions FROM Transactions;

-- Compliance flags are deliberately concentrated on accounts 9 (Desert Capital)
-- and 13 (Keystone Fund) to create realistic high-risk profiles that surface
-- clearly in later risk scoring queries. Flags reference specific transaction_ids
-- to maintain audit trail traceability from violation back to the trade.

INSERT INTO Compliance_Flags (account_id, transaction_id, flag_date, flag_type, severity, resolved, resolution_date, examiner_id)
VALUES
(9, 17, '2023-06-12', 'Excessive Trading Volume', 'High', 1, '2023-07-15', 4),
(9, 18, '2023-06-16', 'Concentrated Position Risk', 'High', 1, '2023-07-15', 4),
(9, 19, '2023-06-23', 'Rapid Buy-Sell Pattern', 'Medium', 0, NULL, 4),
(13, 26, '2023-08-18', 'Excessive Trading Volume', 'High', 0, NULL, 3),
(13, 27, '2023-08-25', 'Concentrated Position Risk', 'High', 0, NULL, 3),
(13, 28, '2023-09-01', 'Rapid Buy-Sell Pattern', 'High', 0, NULL, 3),
(5, 9, '2023-04-06', 'Large Block Trade', 'Low', 1, '2023-04-28', 5),
(5, 10, '2023-04-13', 'Short Sale Violation', 'Medium', 1, '2023-05-10', 5),
(7, 13, '2023-05-05', 'Large Block Trade', 'Low', 1, '2023-05-19', 2),
(4, 8, '2023-03-24', 'Margin Requirement Breach', 'Medium', 1, '2023-04-14', 4),
(12, 25, '2023-08-11', 'Unauthorized Trading', 'High', 0, NULL, 2),
(6, 12, '2023-04-30', 'Potential Front Running', 'High', 1, '2023-06-01', 1),
(1, 1, '2023-01-18', 'Reporting Delay', 'Low', 1, '2023-02-01', 1),
(2, 4, '2023-02-16', 'Best Execution Violation', 'Medium', 1, '2023-03-10', 2),
(15, 32, '2023-09-29', 'Reporting Delay', 'Low', 0, NULL, 5),
(11, 22, '2023-07-28', 'Margin Requirement Breach', 'Medium', 1, '2023-08-20', 1),
(3, 5, '2023-03-01', 'Best Execution Violation', 'Low', 1, '2023-03-22', 3),
(8, 15, '2023-05-26', 'Reporting Delay', 'Low', 1, '2023-06-10', 3),
(10, 20, '2023-07-07', 'Potential Front Running', 'Medium', 0, NULL, 5),
(14, 29, '2023-09-08', 'Short Sale Violation', 'Medium', 1, '2023-10-05', 4);

SELECT * FROM Compliance_Flags ORDER BY severity, resolved;


-- ============================================================
-- SECTION 4: DATABASE INTEGRITY CHECK
-- ============================================================

-- Quick row count verification across all five of our tables.
-- Running this after initial load confirms the data loaded correctly
-- and establishes a baseline for future data quality checks.
-- Using UNION ALL to combine results into a single readable output
-- is more efficient than running five separate SELECT COUNT queries.

SELECT 'Examiners' AS table_name, COUNT(*) AS row_count FROM Examiners
UNION ALL
SELECT 'Accounts', COUNT(*) FROM Accounts
UNION ALL
SELECT 'Securities', COUNT(*) FROM Securities
UNION ALL
SELECT 'Transactions', COUNT(*) FROM Transactions
UNION ALL
SELECT 'Compliance_Flags', COUNT(*) FROM Compliance_Flags;


-- ============================================================
-- SECTION 5: TIER 1 -- BASIC SELECTS AND FILTERS
-- ============================================================

-- Query 1: Active accounts only.
-- Filters out Suspended and Under Review accounts to give examiners
-- a clean view of entities in good standing. Ordering by registration_date
-- ascending surfaces the longest-tenured registrants first, which is
-- relevant for tenure-based examination scheduling.

SELECT
    account_id,
    client_name,
    account_type,
    state,
    registration_date,
    status
FROM Accounts
WHERE status = 'Active'
ORDER BY registration_date ASC;

-- Query 2: All unresolved compliance flags ordered by severity.
-- This is the daily priority queue for a compliance examiner. The
-- most serious unresolved violations appear first. Sorting secondarily
-- by flag_date ensures older unresolved flags don't get buried behind
-- newer ones of the same severity.

SELECT
    flag_id,
    account_id,
    flag_date,
    flag_type,
    severity
FROM Compliance_Flags
WHERE resolved = 0
ORDER BY severity DESC, flag_date ASC;

-- Query 3: Large BUY transactions exceeding $50,000 total value.
-- Large block trades are a common trigger for regulatory scrutiny.
-- Filtering to BUY only isolates accumulation activity which is more
-- likely to indicate position manipulation than routine selling.
-- The computed total_value column makes this filter straightforward
-- without requiring inline calculation.

SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_type,
    quantity,
    price,
    total_value
FROM Transactions
WHERE transaction_type = 'BUY'
AND total_value > 50000
ORDER BY total_value DESC;


-- ============================================================
-- SECTION 6: TIER 2 -- AGGREGATIONS AND GROUP BY
-- ============================================================

-- Query 4: Transaction volume and average deal size by account.
-- Aggregating at the account level indicates which entities trade most actively.
-- High transaction counts combined with high average 
-- values can indicate churning or excessive trading,
-- both regulatory red flags worth investigating further.

SELECT
    a.client_name,
    a.account_type,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.total_value) AS total_value,
    AVG(t.total_value) AS avg_transaction_value
FROM Accounts a
JOIN Transactions t ON a.account_id = t.account_id
GROUP BY a.client_name, a.account_type
ORDER BY total_value DESC;

-- Query 5: Compliance flag resolution rates by severity tier.
-- This query reveals a counterintuitive finding: High severity flags
-- have the lowest resolution rate (42.86%) while Low severity flags
-- resolve at 83.33%. This suggests serious violations are either more
-- complex to close, require enforcement action, or are being
-- deprioritized, all findings worth escalating to leadership.
-- The CASE WHEN pattern inside SUM() is a conditional aggregation
-- technique that avoids the need for a subquery or secondary JOIN.

SELECT
    severity,
    COUNT(*) AS total_flags,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) AS resolved_flags,
    SUM(CASE WHEN resolved = 0 THEN 1 ELSE 0 END) AS unresolved_flags,
    CAST(SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS resolution_rate_pct
FROM Compliance_Flags
GROUP BY severity
ORDER BY
    CASE severity
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
    END;

-- Query 6: Monthly transaction volume trend.
-- Breaking transaction activity into monthly bins reveals seasonal
-- patterns and unusual spikes. A sudden surge in transaction volume
-- in any given month warrants closer examination and may correlate
-- with market events or coordinated trading activity.

SELECT
    YEAR(transaction_date) AS year,
    MONTH(transaction_date) AS month,
    COUNT(*) AS transaction_count,
    SUM(total_value) AS monthly_volume
FROM Transactions
GROUP BY YEAR(transaction_date), MONTH(transaction_date)
ORDER BY year, month;


-- ============================================================
-- SECTION 7: TIER 3 -- JOINS ACROSS MULTIPLE TABLES
-- ============================================================

-- Query 7: Account overview with examiner assignment and flag count.
-- LEFT JOINs are used here intentionally. Accounts with no transactions
-- or no flags still appear in the results with zero counts rather than
-- being excluded. This ensures the full account roster is always visible
-- regardless of activity level, which is critical for an compliance examination audit.

SELECT
    a.client_name,
    a.account_type,
    a.state,
    a.status,
    e.first_name + ' ' + e.last_name AS assigned_examiner,
    e.region,
    COUNT(f.flag_id) AS total_flags
FROM Accounts a
LEFT JOIN Examiners e ON a.examiner_id = e.examiner_id
LEFT JOIN Compliance_Flags f ON a.account_id = f.account_id
GROUP BY
    a.client_name, a.account_type, a.state, a.status,
    e.first_name, e.last_name, e.region
ORDER BY total_flags DESC;

-- Query 8: Full transaction detail with account and security context.
-- Joining three tables provides the complete audit trail for every
-- trade (i.e., who made it, what they traded, when, and for how much).
-- This is the core query an examiner would run before an on-site
-- examination to review an entity's full trading history.

SELECT
    t.transaction_id,
    a.client_name,
    a.account_type,
    s.ticker,
    s.company_name,
    s.sector,
    t.transaction_date,
    t.transaction_type,
    t.quantity,
    t.price,
    t.total_value
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
JOIN Securities s ON t.security_id = s.security_id
ORDER BY t.transaction_date ASC;

-- Query 9: Full compliance flag detail joining all five tables.
-- This is the most complex JOIN in the project and the most operationally
-- valuable. It provides a complete violation record showing the flagged
-- account, the specific transaction that triggered it, the security involved,
-- and the examiner assigned to resolve it. Sorting by severity DESC and
-- resolved ASC surfaces the most urgent unresolved High severity cases first,
-- making this query directly usable as a compliance review meeting agenda.

SELECT
    f.flag_id,
    f.flag_type,
    f.severity,
    f.flag_date,
    f.resolved,
    f.resolution_date,
    a.client_name,
    a.account_type,
    a.state,
    t.transaction_type,
    t.total_value,
    s.ticker,
    s.sector,
    e.first_name + ' ' + e.last_name AS examiner
FROM Compliance_Flags f
JOIN Accounts a ON f.account_id = a.account_id
JOIN Transactions t ON f.transaction_id = t.transaction_id
JOIN Securities s ON t.security_id = s.security_id
JOIN Examiners e ON f.examiner_id = e.examiner_id
ORDER BY f.severity DESC, f.resolved ASC;


-- ============================================================
-- SECTION 8: TIER 4 -- CTEs, SUBQUERIES, AND WINDOW FUNCTIONS
-- ============================================================

-- Query 10: Accounts with above-average total transaction volume (CTE).
-- CTEs (Common Table Expressions) improve readability by breaking a
-- complex query into named, reusable steps. Here we first calculate
-- total volume per account in AccountVolume, then calculate the
-- portfolio-wide average in AverageVolume, then join them together.
-- The CROSS JOIN is appropriate here because AverageVolume returns
-- exactly one row. It applies the same average to all account rows.
-- Accounts that exceed the average warrant closer scrutiny as potential
-- outliers in trading activity.

WITH AccountVolume AS (
    SELECT
        a.account_id,
        a.client_name,
        a.account_type,
        COUNT(t.transaction_id) AS transaction_count,
        SUM(t.total_value) AS total_value
    FROM Accounts a
    JOIN Transactions t ON a.account_id = t.account_id
    GROUP BY a.account_id, a.client_name, a.account_type
),
AverageVolume AS (
    SELECT AVG(total_value) AS avg_total_value
    FROM AccountVolume
)
SELECT
    av.client_name,
    av.account_type,
    av.transaction_count,
    av.total_value,
    avo.avg_total_value,
    av.total_value - avo.avg_total_value AS variance_from_average
FROM AccountVolume av
CROSS JOIN AverageVolume avo
WHERE av.total_value > avo.avg_total_value
ORDER BY av.total_value DESC;

-- Query 11: Examiners with unresolved High severity cases (Subquery).
-- Correlated subqueries execute once per row in the outer query,
-- making them ideal for per-examiner calculations like this.
-- The same subquery appears in both the SELECT (to display the count)
-- and the WHERE (to filter to examiners who have at least one).
-- This query is a workload management tool. It identifies which
-- examiners are carrying the heaviest unresolved critical caseloads
-- and informs staffing and reassignment decisions.

SELECT
    e.first_name + ' ' + e.last_name AS examiner,
    e.region,
    e.cases_assigned,
    (
        SELECT COUNT(*)
        FROM Compliance_Flags f
        WHERE f.examiner_id = e.examiner_id
        AND f.severity = 'High'
        AND f.resolved = 0
    ) AS unresolved_high_severity_cases
FROM Examiners e
WHERE (
    SELECT COUNT(*)
    FROM Compliance_Flags f
    WHERE f.examiner_id = e.examiner_id
    AND f.severity = 'High'
    AND f.resolved = 0
) > 0
ORDER BY unresolved_high_severity_cases DESC;

-- Query 12: Transaction ranking and running total by account (Window Functions).
-- RANK() OVER PARTITION BY assigns a rank to each transaction within
-- its account, ordered by total value descending. This lets examiners
-- instantly identify each account's largest trade without losing the
-- context of all other transactions in the same result set.
-- The running total (SUM OVER with ORDER BY) accumulates transaction
-- value chronologically per account, enabling trend analysis of how
-- quickly each entity's trading activity grows over time.

SELECT
    a.client_name,
    t.transaction_date,
    t.transaction_type,
    t.total_value,
    RANK() OVER (
        PARTITION BY a.account_id
        ORDER BY t.total_value DESC
    ) AS transaction_rank,
    SUM(t.total_value) OVER (
        PARTITION BY a.account_id
        ORDER BY t.transaction_date
    ) AS running_total
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
ORDER BY a.client_name, transaction_rank;

-- Query 13: Weighted compliance risk scoring model (Window Function).
-- Rather than treating all flags equally, this query assigns weighted scores
-- reflecting real regulatory severity tiers: High = 3, Medium = 2, Low = 1.
-- RANK() OVER orders all accounts by their risk score descending,
-- producing a prioritized watchlist that examination leadership can act on.
-- Key finding: Keystone Fund Advisors (score 9) and Desert Capital Advisors
-- (score 8) rank as the highest risk entities, a result that independently
-- validates their Suspended and Under Review statuses in the Accounts table.
-- This alignment between the algorithmic risk score and human-assigned status
-- confirms the model is analytically sound and operationally meaningful.

SELECT
    a.client_name,
    a.account_type,
    a.status,
    COUNT(f.flag_id) AS total_flags,
    SUM(CASE WHEN f.severity = 'High' THEN 3
             WHEN f.severity = 'Medium' THEN 2
             WHEN f.severity = 'Low' THEN 1
             ELSE 0 END) AS risk_score,
    RANK() OVER (
        ORDER BY SUM(CASE WHEN f.severity = 'High' THEN 3
                          WHEN f.severity = 'Medium' THEN 2
                          WHEN f.severity = 'Low' THEN 1
                          ELSE 0 END) DESC
    ) AS risk_rank
FROM Accounts a
LEFT JOIN Compliance_Flags f ON a.account_id = f.account_id
GROUP BY a.client_name, a.account_type, a.status
ORDER BY risk_score DESC;