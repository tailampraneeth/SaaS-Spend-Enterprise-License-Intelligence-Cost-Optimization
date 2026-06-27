-- ============================================================
-- SaaS-Spend Database Schema (PostgreSQL)
-- ============================================================

-- Drop existing tables if they exist
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS license_allocations CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS software_plans CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- Drop sequences
DROP SEQUENCE IF EXISTS seq_dept;
DROP SEQUENCE IF EXISTS seq_emp;
DROP SEQUENCE IF EXISTS seq_vendor;
DROP SEQUENCE IF EXISTS seq_plan;
DROP SEQUENCE IF EXISTS seq_sub;
DROP SEQUENCE IF EXISTS seq_alloc;
DROP SEQUENCE IF EXISTS seq_audit;

-- Create sequences
CREATE SEQUENCE seq_dept START 1;
CREATE SEQUENCE seq_emp START 1;
CREATE SEQUENCE seq_vendor START 1;
CREATE SEQUENCE seq_plan START 1;
CREATE SEQUENCE seq_sub START 1;
CREATE SEQUENCE seq_alloc START 1;
CREATE SEQUENCE seq_audit START 1;

-- ============================================================
-- 1. DEPARTMENTS
-- ============================================================
CREATE TABLE departments (
    dept_id         INTEGER PRIMARY KEY DEFAULT nextval('seq_dept'),
    dept_name       VARCHAR(100) NOT NULL UNIQUE,
    location        VARCHAR(100) NOT NULL,
    budget          DECIMAL(12,2) NOT NULL CHECK (budget >= 0),
    current_spend   DECIMAL(12,2) DEFAULT 0 CHECK (current_spend >= 0),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dept_name ON departments(dept_name);

-- ============================================================
-- 2. EMPLOYEES
-- ============================================================
CREATE TABLE employees (
    emp_id          INTEGER PRIMARY KEY DEFAULT nextval('seq_emp'),
    emp_name        VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    role            VARCHAR(50) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' 
                    CHECK (status IN ('ACTIVE', 'INACTIVE', 'TRANSFERRED')),
    dept_id         INTEGER NOT NULL,
    hire_date       DATE DEFAULT CURRENT_DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) 
        REFERENCES departments(dept_id) ON DELETE CASCADE
);

CREATE INDEX idx_emp_dept ON employees(dept_id);
CREATE INDEX idx_emp_status ON employees(status);
CREATE INDEX idx_emp_email ON employees(email);

-- ============================================================
-- 3. VENDORS
-- ============================================================
CREATE TABLE vendors (
    vendor_id       INTEGER PRIMARY KEY DEFAULT nextval('seq_vendor'),
    vendor_name     VARCHAR(100) NOT NULL UNIQUE,
    website         VARCHAR(200),
    contact_email   VARCHAR(150) NOT NULL,
    support_phone   VARCHAR(20),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vendor_name ON vendors(vendor_name);

-- ============================================================
-- 4. SOFTWARE_PLANS
-- ============================================================
CREATE TABLE software_plans (
    plan_id         INTEGER PRIMARY KEY DEFAULT nextval('seq_plan'),
    plan_name       VARCHAR(100) NOT NULL,
    category        VARCHAR(50) NOT NULL 
                    CHECK (category IN ('Communication', 'Cloud', 'Productivity', 
                                       'Development', 'Analytics', 'Security', 'Other')),
    price_per_seat  DECIMAL(10,2) NOT NULL CHECK (price_per_seat >= 0),
    billing_cycle   VARCHAR(20) DEFAULT 'ANNUAL' 
                    CHECK (billing_cycle IN ('MONTHLY', 'ANNUAL')),
    vendor_id       INTEGER NOT NULL,
    features        TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_plan_vendor FOREIGN KEY (vendor_id) 
        REFERENCES vendors(vendor_id) ON DELETE CASCADE,
    CONSTRAINT uk_plan UNIQUE (vendor_id, plan_name)
);

CREATE INDEX idx_plan_vendor ON software_plans(vendor_id);
CREATE INDEX idx_plan_category ON software_plans(category);

-- ============================================================
-- 5. SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
    sub_id          INTEGER PRIMARY KEY DEFAULT nextval('seq_sub'),
    seats_purchased INTEGER NOT NULL CHECK (seats_purchased > 0),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    dept_id         INTEGER NOT NULL,
    plan_id         INTEGER NOT NULL,
    subscription_status VARCHAR(20) DEFAULT 'ACTIVE' 
                    CHECK (subscription_status IN ('ACTIVE', 'EXPIRED', 'CANCELLED')),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sub_dept FOREIGN KEY (dept_id) 
        REFERENCES departments(dept_id) ON DELETE CASCADE,
    CONSTRAINT fk_sub_plan FOREIGN KEY (plan_id) 
        REFERENCES software_plans(plan_id) ON DELETE CASCADE,
    CONSTRAINT chk_sub_dates CHECK (end_date > start_date)
);

CREATE INDEX idx_sub_dept ON subscriptions(dept_id);
CREATE INDEX idx_sub_plan ON subscriptions(plan_id);
CREATE INDEX idx_sub_dates ON subscriptions(start_date, end_date);

-- ============================================================
-- 6. LICENSE_ALLOCATIONS
-- ============================================================
CREATE TABLE license_allocations (
    alloc_id        INTEGER PRIMARY KEY DEFAULT nextval('seq_alloc'),
    emp_id          INTEGER NOT NULL,
    sub_id          INTEGER NOT NULL,
    assigned_date   DATE DEFAULT CURRENT_DATE,
    last_used_date  DATE,
    alloc_status    VARCHAR(20) DEFAULT 'ACTIVE' 
                    CHECK (alloc_status IN ('ACTIVE', 'REVOKED')),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alloc_emp FOREIGN KEY (emp_id) 
        REFERENCES employees(emp_id) ON DELETE CASCADE,
    CONSTRAINT fk_alloc_sub FOREIGN KEY (sub_id) 
        REFERENCES subscriptions(sub_id) ON DELETE CASCADE,
    CONSTRAINT uk_alloc UNIQUE (emp_id, sub_id)
);

CREATE INDEX idx_alloc_emp ON license_allocations(emp_id);
CREATE INDEX idx_alloc_sub ON license_allocations(sub_id);
CREATE INDEX idx_alloc_status ON license_allocations(alloc_status);
CREATE INDEX idx_alloc_last_used ON license_allocations(last_used_date);

-- ============================================================
-- 7. AUDIT_LOG
-- ============================================================
CREATE TABLE audit_log (
    log_id          INTEGER PRIMARY KEY DEFAULT nextval('seq_audit'),
    action_type     VARCHAR(50) NOT NULL 
                    CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE', 
                                          'ASSIGN', 'REVOKE', 'BUDGET_CHECK')),
    table_name      VARCHAR(50) NOT NULL,
    ref_id          INTEGER,
    action_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by      VARCHAR(100) DEFAULT CURRENT_USER,
    description     TEXT,
    old_value       TEXT,
    new_value       TEXT
);

CREATE INDEX idx_audit_date ON audit_log(action_date DESC);
CREATE INDEX idx_audit_type ON audit_log(action_type);
CREATE INDEX idx_audit_table ON audit_log(table_name);

-- ============================================================
-- Comments for documentation
-- ============================================================
COMMENT ON TABLE departments IS 'Organizational departments with budget tracking';
COMMENT ON TABLE employees IS 'Employee records with department assignments';
COMMENT ON TABLE vendors IS 'SaaS software vendors';
COMMENT ON TABLE software_plans IS 'Software subscription plans offered by vendors';
COMMENT ON TABLE subscriptions IS 'Active subscriptions purchased by departments';
COMMENT ON TABLE license_allocations IS 'Individual license assignments to employees';
COMMENT ON TABLE audit_log IS 'Audit trail of all system changes';
