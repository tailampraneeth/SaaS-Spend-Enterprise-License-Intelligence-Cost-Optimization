# SaaS·Spend — License Intelligence

A full-stack SaaS spend management system built to track, analyze, and optimize software license usage across an organization. Designed as a portfolio/resume project with a strong emphasis on **PostgreSQL DBMS** — including normalized schema design, PL/pgSQL stored functions, triggers, and analytical views.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Database | PostgreSQL (schema, functions, triggers, views) |
| Backend | Python · Flask · psycopg2 |
| Frontend | Vanilla HTML/CSS/JavaScript (single-page app) |

---

## Features

### Dashboard
- Live KPIs: total annual spend, budget utilization %, active subscriptions, idle license count
- Top spending departments
- Spend breakdown by software category

### Departments
- Create, update, and delete departments with budget tracking
- Real-time `current_spend` updated automatically via triggers

### Employees
- Full employee lifecycle management (Active / Inactive / Transferred)
- Status changes automatically revoke all associated licenses (trigger-enforced)

### Subscriptions
- Department-level SaaS subscriptions with seat counts and billing cycle tracking
- Budget enforcement trigger blocks subscriptions that would exceed a department's budget

### License Allocations
- Assign and revoke individual employee licenses
- Seat availability enforced at DB level before any allocation
- Idle license detection (unused for 30+ days)

### Vendors & Plans
- Vendor catalog with contact details
- Software plan registry with per-seat pricing and category classification

### Reports
- **Idle Licenses** — licenses unused for 30+ days, sorted by days idle
- **Department Spend** — budget vs. actual spend with utilization percentages
- **Vendor Spend** — total annual cost per vendor across all active subscriptions
- **Subscription Utilization** — seats purchased vs. seats used per subscription

### Audit Log
- Immutable log of every INSERT, UPDATE, DELETE, ASSIGN, REVOKE, and BUDGET_CHECK event across the system

---

## Database Design

The PostgreSQL layer is the core of this project. All business logic lives in the database.

### Schema (7 tables)

```
departments ──< employees ──< license_allocations >── subscriptions >── software_plans >── vendors
                                                                              │
                                                                          audit_log
```

| Table | Purpose |
|---|---|
| `departments` | Organizational units with budget + current_spend |
| `employees` | Staff records linked to a department |
| `vendors` | SaaS software vendors |
| `software_plans` | Plans offered by vendors (price per seat, billing cycle, category) |
| `subscriptions` | Department-level plan purchases (seats, date range, status) |
| `license_allocations` | Individual seat assignments to employees |
| `audit_log` | Full audit trail of all system events |

Custom sequences (`seq_dept`, `seq_emp`, etc.) are used instead of `SERIAL` for explicit control over ID generation.

### Stored Functions (PL/pgSQL)

| Function | Description |
|---|---|
| `assign_license(emp_id, sub_id)` | Validates and assigns a license; logs the event |
| `revoke_license(emp_id, sub_id)` | Revokes an active license; logs the event |
| `dept_annual_spend(dept_id)` | Calculates total active spend for a department |
| `idle_license_count(dept_id, days)` | Counts licenses unused beyond a threshold |
| `update_dept_spend()` | Bulk recalculates `current_spend` for all departments |
| `auto_revoke_employee_licenses(emp_id)` | Revokes all licenses for a given employee |
| `subscription_annual_cost(sub_id)` | Returns the annualized cost of a subscription |
| `available_seats(sub_id)` | Returns remaining unallocated seats |

### Triggers

| Trigger | Event | Behavior |
|---|---|---|
| `trg_check_budget` | BEFORE INSERT on `subscriptions` | Blocks insert if it would exceed department budget |
| `trg_update_dept_spend_*` | AFTER INSERT/UPDATE/DELETE on `subscriptions` | Recalculates `current_spend` on the affected department |
| `trg_auto_revoke_licenses` | AFTER UPDATE on `employees.status` | Auto-revokes all licenses when an employee goes INACTIVE or TRANSFERRED |
| `trg_validate_allocation` | BEFORE INSERT/UPDATE on `license_allocations` | Enforces seat capacity limits |
| `trg_audit_departments` | AFTER INSERT/UPDATE/DELETE on `departments` | Writes to audit log |
| `trg_audit_subscriptions` | AFTER INSERT/DELETE on `subscriptions` | Writes to audit log |

### Views

| View | Purpose |
|---|---|
| `dept_spend_view` | Budget vs. spend with employee and subscription counts |
| `vendor_cost_view` | Aggregated annual cost per vendor |
| `idle_license_view` | Active licenses unused for 30+ days |
| `allocation_report_view` | Full join across employees, licenses, plans, and vendors |
| `subscription_utilization_view` | Seats purchased vs. used per subscription |
| `category_spend_view` | Spend aggregated by software category |

---

## REST API Endpoints

| Method | Route | Description |
|---|---|---|
| GET | `/api/dashboard` | Aggregated KPIs for the dashboard |
| GET/POST | `/api/departments` | List or create departments |
| PUT/DELETE | `/api/departments/<id>` | Update or delete a department |
| GET/POST | `/api/employees` | List or create employees |
| PUT | `/api/employees/<id>` | Update employee details |
| PUT | `/api/employees/<id>/status` | Change employee status (triggers auto-revoke) |
| DELETE | `/api/employees/<id>` | Delete an employee |
| GET | `/api/vendors` | List all vendors |
| GET | `/api/plans` | List software plans |
| GET/POST | `/api/subscriptions` | List or create subscriptions |
| DELETE | `/api/subscriptions/<id>` | Cancel a subscription |
| GET | `/api/licenses` | List license allocations |
| POST | `/api/licenses/assign` | Assign a license to an employee |
| POST | `/api/licenses/revoke` | Revoke a license from an employee |
| GET | `/api/reports/idle` | Idle license report |
| GET | `/api/reports/dept-spend` | Department spend report |
| GET | `/api/reports/vendor-spend` | Vendor cost report |
| GET | `/api/reports/utilization` | Subscription utilization report |
| GET | `/api/audit` | Audit log |
| GET | `/api/counts` | Entity counts for the UI |
| GET | `/api/health` | Health check |

---

## Project Structure

```
saas_spend/
├── backend/
│   ├── app.py              # Flask REST API
│   └── requirements.txt
├── database/
│   ├── 01_schema.sql       # Tables, sequences, indexes
│   ├── 02_functions.sql    # PL/pgSQL stored functions
│   ├── 03_triggers.sql     # Trigger functions and bindings
│   ├── 04_views.sql        # Analytical views
│   └── 05_sample_data.sql  # Seed data for testing
└── frontend/
    └── index.html          # Single-page frontend (HTML/CSS/JS)
```

---

## Getting Started

### Prerequisites
- PostgreSQL 14+
- Python 3.10+

### Database Setup

```bash
psql -U postgres -c "CREATE DATABASE saas_spend;"
psql -U postgres -d saas_spend -f database/01_schema.sql
psql -U postgres -d saas_spend -f database/02_functions.sql
psql -U postgres -d saas_spend -f database/03_triggers.sql
psql -U postgres -d saas_spend -f database/04_views.sql
psql -U postgres -d saas_spend -f database/05_sample_data.sql
```

### Backend Setup

```bash
cd backend
pip install -r requirements.txt
python app.py
```

The API runs on `http://localhost:5000`.

### Frontend

Open `frontend/index.html` directly in a browser. The page connects to the Flask API at `localhost:5000`.

---

## Key DBMS Concepts Demonstrated

- **Normalization** — 3NF relational schema with proper foreign keys and constraints
- **Custom sequences** — Explicit ID generation via `CREATE SEQUENCE`
- **CHECK constraints** — Enum-like validation on status, category, and billing cycle columns
- **Stored procedures** — Business logic encapsulated in PL/pgSQL functions
- **Triggers** — Cascading side effects (spend recalculation, auto-revoke, budget guard, audit trail)
- **Views** — Reusable query abstractions for reporting and the API layer
- **Indexes** — Covering indexes on all foreign keys and frequently filtered columns
- **Audit logging** — Append-only log table capturing old/new values for every state change
- **Transaction safety** — All writes go through functions or direct parameterized queries via psycopg2

---

## License

Praneeth
