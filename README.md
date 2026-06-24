# Securities Compliance SQL Database

**Author:** Eric A. Frederic, MBA  
**Tools:** Microsoft SQL Server (T-SQL) | SSMS  
**Repository:** sql-securities-compliance-database

---

## Business Problem

State securities regulators and FINRA examiners rely on accurate, queryable data to identify high-risk entities, prioritize examination caseloads, and track compliance violations from detection through resolution. This project simulates the analytical infrastructure underlying that work: a multi-table relational database that models registered entities, trading activity, compliance flags, and examiner workloads in a realistic regulatory environment.

The database and query library were designed to answer the kinds of questions I encountered directly as a Securities Examiner at the New Hampshire Bureau of Securities Regulation:

- Which accounts pose the highest compliance risk right now?
- Which examiners are carrying unresolved high-severity caseloads?
- What does the complete audit trail look like for a flagged transaction?
- Which accounts are trading at volumes that warrant closer scrutiny?

---

## Database Schema

The database contains five tables with enforced referential integrity through foreign key relationships:

| Table | Description |
|-------|-------------|
| `Examiners` | Compliance staff assigned to oversee registered entities |
| `Accounts` | Registered financial entities (Broker-Dealers, Investment Advisers, Hedge Funds) |
| `Securities` | Reference table for traded instruments (equities, ETFs) |
| `Transactions` | Core fact table recording all buy/sell activity with a computed `total_value` column |
| `Compliance_Flags` | Violation records linking accounts, transactions, and assigned examiners |

**Design highlights:**
- Computed column (`total_value = quantity * price`) ensures mathematical accuracy at the database level
- CHECK constraints enforce data integrity on `transaction_type` (BUY/SELL) and `severity` (Low/Medium/High)
- Script is fully idempotent; it can be run any number of times and always produces a clean result
- Foreign key cascade order prevents referential integrity violations on rebuild

---

## Query Library

The project includes 13 analytical queries organized into four tiers of increasing complexity.

### Tier 1: Basic Retrieval and Filtering
- Active accounts by state
- Transactions above a dollar threshold
- Unresolved compliance flags by severity

### Tier 2: Aggregation and Grouping
- Transaction volume and count by account
- Compliance flag counts and resolution rates by examiner
- Sector-level trading activity summary

### Tier 3: Multi-Table Joins
- Full transaction detail with account and security context (3-table join)
- Complete compliance violation record joining all five tables

### Tier 4: CTEs, Subqueries, and Window Functions
- Accounts with above-average transaction volume (CTE with CROSS JOIN)
- Examiners carrying unresolved High severity caseloads (correlated subquery)
- Transaction ranking and running totals by account (RANK and SUM OVER)
- Weighted compliance risk scoring model (CASE/RANK window function)
<img width="347" height="246" alt="risk score" src="https://github.com/user-attachments/assets/51c9972b-b9c1-45ff-924d-ffac36c055f5" />
---

## Key Findings

### Query Output: Five-Table Compliance Audit Trail
(<img width="910" height="193" alt="Query 9" src="https://github.com/user-attachments/assets/e17c8374-2bf1-46e3-b290-34b1424f08f7" />
)

The five-table join surfaces the complete violation record for every flagged transaction (account identity, trade details, security information, and assigned examiner) sorted by severity and resolution status. This is the query an examiner would run before an on-site visit.

### Query Output: Transaction Ranking and Running Totals
(<img width="437" height="188" alt="Query 12" src="https://github.com/user-attachments/assets/012a3112-0352-4193-8d7f-eb7b24c72e32" />
)

RANK() OVER PARTITION BY assigns each transaction a rank within its account by dollar value, while the running total accumulates trading activity chronologically. Window functions are used here precisely because they calculate across rows without collapsing the result set the way GROUP BY would.

### Query Output: Weighted Risk Scoring Model
(<img width="410" height="190" alt="Query 13" src="https://github.com/user-attachments/assets/05d8f6c5-87a1-4de4-a33c-9dd3d0a8f683" />
)

The analytical centerpiece of the project. Rather than treating all compliance flags equally, this query assigns weighted scores reflecting regulatory severity tiers: High = 3, Medium = 2, Low = 1. The resulting risk ranking independently validates the human-assigned account statuses. Keystone Fund Advisors and Desert Capital Advisors rank as the two highest-risk entities, consistent with their Under Review and Suspended designations in the Accounts table. This alignment confirms the model is analytically sound and operationally meaningful.

---

## Limitations

| Limitation | Notes |
|------------|-------|
| Synthetic dataset | All entities, transactions, and flags are simulated. The schema and query logic reflect real regulatory workflows; the data does not. |
| Static snapshot | No temporal triggers or automated flag generation; flags are manually seeded to enable realistic query scenarios. |
| Single jurisdiction | Modeled on state-level securities regulation. Federal frameworks (SEC, FINRA) involve additional data structures not represented here. |
| No stored procedures | Queries are written as standalone scripts. Production deployment would benefit from parameterized stored procedures. |

---

## Technical Details

| Component | Detail |
|-----------|--------|
| Database | Microsoft SQL Server (ERIC_LAPTOP\SQLEXPRESS01) |
| Language | T-SQL |
| Tables | 5 |
| Records | 5 examiners, 15 accounts, 10 securities, 50 transactions, 20+ compliance flags |
| Query count | 13 analytical queries across 4 tiers |
| Advanced concepts | CTEs, correlated subqueries, window functions (RANK, SUM OVER), computed columns, CHECK constraints |

---

## Tools Used

Microsoft SQL Server | SSMS | T-SQL

---

## Background

This project was built to reflect the analytical work I performed as a Securities Examiner at the New Hampshire Bureau of Securities Regulation, where I was responsible for examining registered broker-dealers, investment advisers, and hedge funds for compliance with state and federal securities law. The database schema, query categories, and risk scoring methodology are modeled on real examination workflows.

---

*MIT License — see LICENSE for details*
