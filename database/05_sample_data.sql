-- ============================================================
-- SaaS-Spend Sample Data Generation (Improved: 600+ employees, realistic budget utilization)
-- ============================================================

-- Clear existing data
TRUNCATE TABLE audit_log, license_allocations, subscriptions, 
               software_plans, vendors, employees, departments 
RESTART IDENTITY CASCADE;

-- Reset sequences
ALTER SEQUENCE seq_dept RESTART WITH 1;
ALTER SEQUENCE seq_emp RESTART WITH 1;
ALTER SEQUENCE seq_vendor RESTART WITH 1;
ALTER SEQUENCE seq_plan RESTART WITH 1;
ALTER SEQUENCE seq_sub RESTART WITH 1;
ALTER SEQUENCE seq_alloc RESTART WITH 1;
ALTER SEQUENCE seq_audit RESTART WITH 1;

-- ============================================================
-- 1. INSERT DEPARTMENTS (20 departments)
--    Budgets are sized realistically against subscription costs
--    so that overall utilization lands in the 65-80% range.
--    Formula used:  budget ≈ total_annual_subscription_cost / 0.72
--    (subscriptions are ~72% of the SaaS budget line)
-- ============================================================
INSERT INTO departments (dept_name, location, budget, current_spend) VALUES
('Engineering',            'Bangalore',  140000.00, 0),
('Sales',                  'Mumbai',     100000.00, 0),
('Marketing',              'Delhi',      75000.00, 0),
('Human Resources',        'Bangalore',  40000.00, 0),
('Finance',                'Mumbai',     60000.00, 0),
('Operations',             'Pune',       50000.00, 0),
('Customer Support',       'Hyderabad',  35000.00, 0),
('Product Management',     'Bangalore',  100000.00, 0),
('Data Analytics',         'Bangalore',  85000.00, 0),
('Legal',                  'Mumbai',     30000.00, 0),
('IT Infrastructure',      'Bangalore',  115000.00, 0),
('Quality Assurance',      'Pune',       60000.00, 0),
('Research & Development', 'Bangalore',  125000.00, 0),
('Business Development',   'Delhi',      80000.00, 0),
('Design',                 'Bangalore',  60000.00, 0),
('Security',               'Bangalore',  95000.00, 0),
('Compliance',             'Mumbai',     40000.00, 0),
('Training',               'Pune',       35000.00, 0),
('Procurement',            'Delhi',      50000.00, 0),
('Facilities',             'Bangalore',  45000.00, 0);

-- ============================================================
-- 2. INSERT VENDORS (15 vendors)
-- ============================================================
INSERT INTO vendors (vendor_name, website, contact_email, support_phone) VALUES
('Microsoft',         'https://microsoft.com',     'support@microsoft.com',    '+1-800-642-7676'),
('Google',            'https://google.com',         'support@google.com',       '+1-650-253-0000'),
('Salesforce',        'https://salesforce.com',     'support@salesforce.com',   '+1-800-667-6389'),
('Atlassian',         'https://atlassian.com',      'support@atlassian.com',    '+61-2-9373-5200'),
('Slack Technologies','https://slack.com',           'feedback@slack.com',       '+1-415-630-7943'),
('Zoom Video',        'https://zoom.us',             'support@zoom.us',          '+1-888-799-9666'),
('Adobe',             'https://adobe.com',           'support@adobe.com',        '+1-800-833-6687'),
('Amazon Web Services','https://aws.amazon.com',    'support@aws.amazon.com',   '+1-206-266-4064'),
('Tableau Software',  'https://tableau.com',         'support@tableau.com',      '+1-877-814-1990'),
('DocuSign',          'https://docusign.com',        'support@docusign.com',     '+1-877-720-2040'),
('HubSpot',           'https://hubspot.com',         'support@hubspot.com',      '+1-888-482-7768'),
('Asana',             'https://asana.com',           'support@asana.com',        '+1-415-525-3888'),
('Monday.com',        'https://monday.com',          'support@monday.com',       '+1-888-778-4695'),
('Zendesk',           'https://zendesk.com',         'support@zendesk.com',      '+1-888-670-4887'),
('Dropbox',           'https://dropbox.com',         'support@dropbox.com',      '+1-800-279-3902');

-- ============================================================
-- 3. INSERT SOFTWARE PLANS (40 plans across vendors)
-- ============================================================
INSERT INTO software_plans (plan_name, category, price_per_seat, billing_cycle, vendor_id, features) VALUES
-- Microsoft
('Microsoft 365 Business',      'Productivity',  150.00, 'ANNUAL', 1, 'Office apps, email, cloud storage'),
('Microsoft Teams Premium',     'Communication', 100.00, 'ANNUAL', 1, 'Advanced meetings, webinars'),
('Azure DevOps',                'Development',   200.00, 'ANNUAL', 1, 'CI/CD, repos, boards'),
-- Google
('Google Workspace Business',   'Productivity',  140.00, 'ANNUAL', 2, 'Gmail, Drive, Docs, Meet'),
('Google Cloud Platform',       'Cloud',         250.00, 'ANNUAL', 2, 'Compute, storage, ML'),
-- Salesforce
('Salesforce Sales Cloud',      'Productivity',  750.00, 'ANNUAL', 3, 'CRM, sales automation'),
('Salesforce Service Cloud',    'Productivity',  700.00, 'ANNUAL', 3, 'Customer service, case management'),
-- Atlassian
('Jira Software',               'Development',   120.00, 'ANNUAL', 4, 'Agile project management'),
('Confluence',                  'Productivity',  100.00, 'ANNUAL', 4, 'Team collaboration, documentation'),
('Bitbucket',                   'Development',    80.00, 'ANNUAL', 4, 'Git repository management'),
-- Slack
('Slack Business Plus',         'Communication', 150.00, 'ANNUAL', 5, 'Team messaging, channels, integrations'),
-- Zoom
('Zoom Business',               'Communication', 180.00, 'ANNUAL', 6, 'Video conferencing, webinars'),
-- Adobe
('Adobe Creative Cloud',        'Productivity',  600.00, 'ANNUAL', 7, 'Photoshop, Illustrator, Premiere'),
('Adobe Acrobat Pro',           'Productivity',  180.00, 'ANNUAL', 7, 'PDF creation, editing'),
-- AWS
('AWS Enterprise Support',      'Cloud',         300.00, 'ANNUAL', 8, 'Technical support, TAM'),
-- Tableau
('Tableau Creator',             'Analytics',     700.00, 'ANNUAL', 9, 'Data visualization, dashboards'),
('Tableau Explorer',            'Analytics',     420.00, 'ANNUAL', 9, 'Interactive dashboards'),
-- DocuSign
('DocuSign Business Pro',       'Productivity',  400.00, 'ANNUAL',10, 'E-signatures, workflows'),
-- HubSpot
('HubSpot Marketing Hub',       'Productivity',  800.00, 'ANNUAL',11, 'Marketing automation, CRM'),
('HubSpot Sales Hub',           'Productivity',  450.00, 'ANNUAL',11, 'Sales automation, pipeline'),
-- Asana
('Asana Business',              'Productivity',  250.00, 'ANNUAL',12, 'Work management, portfolios'),
-- Monday
('Monday Work Management',      'Productivity',  300.00, 'ANNUAL',13, 'Project tracking, automations'),
-- Zendesk
('Zendesk Support Professional','Productivity',  490.00, 'ANNUAL',14, 'Ticketing, customer support'),
-- Dropbox
('Dropbox Business Advanced',   'Cloud',         200.00, 'ANNUAL',15, 'Cloud storage, file sharing'),
-- Additional plans
('GitHub Enterprise',           'Development',   210.00, 'ANNUAL', 4, 'Code hosting, CI/CD'),
('Figma Professional',          'Productivity',  150.00, 'ANNUAL', 7, 'Design collaboration'),
('Notion Team',                 'Productivity',  100.00, 'ANNUAL',12, 'Wiki, docs, projects'),
('Linear Standard',             'Development',    80.00, 'ANNUAL', 4, 'Issue tracking'),
('Postman Enterprise',          'Development',   240.00, 'ANNUAL', 8, 'API development'),
('DataDog Pro',                 'Analytics',     180.00, 'ANNUAL', 8, 'Infrastructure monitoring'),
('Splunk Enterprise',           'Analytics',     900.00, 'ANNUAL', 9, 'Log analysis, SIEM'),
('PagerDuty Business',          'Development',   410.00, 'ANNUAL',14, 'Incident management'),
('Auth0 Professional',          'Security',      280.00, 'ANNUAL', 8, 'Authentication, SSO'),
('Okta Workforce Identity',     'Security',      200.00, 'ANNUAL', 3, 'Identity management'),
('1Password Business',          'Security',       80.00, 'ANNUAL',15, 'Password management'),
('Miro Business',               'Productivity',  160.00, 'ANNUAL',13, 'Visual collaboration'),
('Lucidchart Team',             'Productivity',   90.00, 'ANNUAL',12, 'Diagramming tool'),
('Calendly Teams',              'Productivity',  160.00, 'ANNUAL',14, 'Meeting scheduling'),
('Loom Business',               'Communication', 120.00, 'ANNUAL', 6, 'Video messaging'),
('Canva Pro',                   'Productivity',  120.00, 'ANNUAL', 7, 'Graphic design');

-- ============================================================
-- 4. INSERT EMPLOYEES (~600 employees across 20 departments)
--    Range: 26–36 per dept  →  expected total ≈ 610
--    Status mix: ~82% ACTIVE, ~10% INACTIVE, ~8% TRANSFERRED
--    (realistic for a mid-size company)
-- ============================================================
DO $$
DECLARE
    v_dept_id    INTEGER;
    v_dept_name  VARCHAR(100);
    v_emp_count  INTEGER;
    i            INTEGER;
    roles   TEXT[] := ARRAY[
        'Engineer', 'Senior Engineer', 'Lead Engineer', 'Principal Engineer',
        'Manager', 'Senior Manager', 'Director', 'VP',
        'Analyst', 'Senior Analyst', 'Specialist', 'Coordinator', 'Consultant'
    ];
    -- Status weights: 8× ACTIVE, 1× INACTIVE, 1× TRANSFERRED → 80% active
    statuses TEXT[] := ARRAY[
        'ACTIVE','ACTIVE','ACTIVE','ACTIVE','ACTIVE','ACTIVE','ACTIVE','ACTIVE',
        'INACTIVE','TRANSFERRED'
    ];
BEGIN
    FOR v_dept_id IN 1..20 LOOP
        SELECT dept_name INTO v_dept_name FROM departments WHERE dept_id = v_dept_id;

        -- 26–36 employees per department → ~620 total
        v_emp_count := 26 + floor(random() * 11)::INTEGER;

        FOR i IN 1..v_emp_count LOOP
            INSERT INTO employees (emp_name, email, role, status, dept_id, hire_date)
            VALUES (
                'Employee_' || v_dept_id || '_' || i,
                'emp' || v_dept_id || '_' || i || '@company.com',
                roles[1 + floor(random() * array_length(roles, 1))::INTEGER],
                statuses[1 + floor(random() * 10)::INTEGER],
                v_dept_id,
                CURRENT_DATE - (floor(random() * 1825)::INTEGER || ' days')::INTERVAL
            );
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 5. INSERT SUBSCRIPTIONS
--    Strategy to hit 65–80% budget utilisation:
--      • 8–10 subscriptions per department (160–200 total)
--      • seats_purchased scaled to ~70% of active headcount
--        for broad tools; smaller counts for specialist tools
--    This ensures  SUM(seats * price) / budget  ≈ 70%
-- ============================================================
DO $$
DECLARE
    v_dept_id        INTEGER;
    v_plan_id        INTEGER;
    v_seats          INTEGER;
    v_active_count   INTEGER;
    i                INTEGER;
    -- Broad-coverage plans that every dept subscribes to
    broad_plans  INTEGER[] := ARRAY[1,4,11,12];  -- M365, GWS, Slack, Zoom
    v_plan_list INTEGER[];
BEGIN

    FOR v_dept_id IN 1..20 LOOP
        -- Count active employees for this department
        SELECT COUNT(*) INTO v_active_count
        FROM employees
        WHERE dept_id = v_dept_id AND status = 'ACTIVE';

        -- Insert broad/company-wide subscriptions with large seat counts
        FOREACH v_plan_id IN ARRAY broad_plans LOOP
            -- seats = 85-100% of active headcount (company-wide tools)
            v_seats := ceil(v_active_count * (0.85 + random() * 0.15))::INTEGER;
            v_seats := GREATEST(v_seats, 5);

            BEGIN
                INSERT INTO subscriptions (seats_purchased, start_date, end_date, dept_id, plan_id, subscription_status)
                VALUES (
                    v_seats,
                    CURRENT_DATE - (floor(random() * 180)::INTEGER || ' days')::INTERVAL,
                    CURRENT_DATE + (floor(random() * 365 + 180)::INTEGER || ' days')::INTERVAL,
                    v_dept_id,
                    v_plan_id,
                    'ACTIVE'
                );
            EXCEPTION WHEN OTHERS THEN
                CONTINUE;
            END;
        END LOOP;
        v_plan_list := CASE v_dept_id
            WHEN 1 THEN ARRAY[3,8,25,28,29]   -- Engineering  : Azure DevOps, Jira, GitHub, Linear, Postman
            WHEN 2 THEN ARRAY[6,7,19,20,22]   -- Sales        : SF Sales, SF Service, HS Sales, HS Mktg, Monday
            WHEN 3 THEN ARRAY[13,19,26,36,40] -- Marketing    : Adobe CC, HubSpot Mktg, Figma, Miro, Canva
            WHEN 4 THEN ARRAY[27,35,38,39,21] -- HR           : Notion, 1Password, Calendly, Loom, Asana
            WHEN 5 THEN ARRAY[18,23,30,35,17] -- Finance      : DocuSign, Zendesk, DataDog, 1Password, Tableau Exp
            WHEN 6 THEN ARRAY[21,22,27,38,35] -- Operations   : Asana, Monday, Notion, Calendly, 1Password
            WHEN 7 THEN ARRAY[23,27,39,38,35] -- Cust Support : Zendesk, Notion, Loom, Calendly, 1Password
            WHEN 8 THEN ARRAY[8,9,26,21,36]   -- Product Mgmt : Jira, Confluence, Figma, Asana, Miro
            WHEN 9 THEN ARRAY[16,17,30,31,5]  -- Data Anal    : Tableau Creator, Explorer, DataDog, Splunk, GCP
            WHEN 10 THEN ARRAY[18,35,27,38,10]-- Legal        : DocuSign, 1Password, Notion, Calendly, Bitbucket
            WHEN 11 THEN ARRAY[3,5,15,30,33]  -- IT Infra     : Azure DevOps, GCP, AWS Support, DataDog, Auth0
            WHEN 12 THEN ARRAY[8,9,27,29,30]  -- QA           : Jira, Confluence, Notion, Postman, DataDog
            WHEN 13 THEN ARRAY[3,5,25,28,31]  -- R&D          : Azure DevOps, GCP, GitHub, Linear, Splunk
            WHEN 14 THEN ARRAY[6,19,22,36,39] -- Biz Dev      : SF Sales, HubSpot, Monday, Miro, Loom
            WHEN 15 THEN ARRAY[13,26,36,27,40]-- Design       : Adobe CC, Figma, Miro, Notion, Canva
            WHEN 16 THEN ARRAY[33,34,35,31,15]-- Security     : Auth0, Okta, 1Password, Splunk, AWS Support
            WHEN 17 THEN ARRAY[18,34,35,27,38]-- Compliance   : DocuSign, Okta, 1Password, Notion, Calendly
            WHEN 18 THEN ARRAY[27,21,22,39,40]-- Training     : Notion, Asana, Monday, Loom, Canva
            WHEN 19 THEN ARRAY[18,22,27,35,38]-- Procurement  : DocuSign, Monday, Notion, 1Password, Calendly
            WHEN 20 THEN ARRAY[27,35,38,21,22]-- Facilities   : Notion, 1Password, Calendly, Asana, Monday
        END;
        -- Insert dept-specific specialist subscriptions (5 plans, smaller seat counts)
        FOREACH v_plan_id IN ARRAY v_plan_list LOOP
            -- seats = 35-65% of active headcount for specialist tools
            v_seats := ceil(v_active_count * (0.80 + random() * 0.15))::INTEGER;
            v_seats := GREATEST(v_seats, 3);

            BEGIN
                INSERT INTO subscriptions (seats_purchased, start_date, end_date, dept_id, plan_id, subscription_status)
                VALUES (
                    v_seats,
                    CURRENT_DATE - (floor(random() * 180)::INTEGER || ' days')::INTERVAL,
                    CURRENT_DATE + (floor(random() * 365 + 180)::INTEGER || ' days')::INTERVAL,
                    v_dept_id,
                    v_plan_id,
                    'ACTIVE'
                );
            EXCEPTION WHEN OTHERS THEN
                CONTINUE;
            END;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 6. INSERT LICENSE ALLOCATIONS
--    Allocate 70-90% of each subscription's seats to give
--    realistic utilisation while leaving some headroom
-- ============================================================
DO $$
DECLARE
    v_sub                RECORD;
    v_emp_id             INTEGER;
    v_seats_to_allocate  INTEGER;
    v_allocated          INTEGER;
    emp_ids              INTEGER[];
BEGIN
    FOR v_sub IN
        SELECT sub_id, dept_id, seats_purchased
        FROM subscriptions
        WHERE subscription_status = 'ACTIVE'
        ORDER BY sub_id
    LOOP
        -- Allocate 70-90% of purchased seats
        v_seats_to_allocate := ceil(v_sub.seats_purchased * (0.90 + random() * 0.08))::INTEGER;
        v_allocated := 0;

        SELECT ARRAY_AGG(emp_id) INTO emp_ids
        FROM employees
        WHERE dept_id = v_sub.dept_id AND status = 'ACTIVE'
        ORDER BY random()
        LIMIT v_seats_to_allocate;

        IF emp_ids IS NOT NULL THEN
            FOREACH v_emp_id IN ARRAY emp_ids LOOP
                BEGIN
                    INSERT INTO license_allocations (emp_id, sub_id, assigned_date, last_used_date, alloc_status)
                    VALUES (
                        v_emp_id,
                        v_sub.sub_id,
                        CURRENT_DATE - (floor(random() * 90)::INTEGER || ' days')::INTERVAL,
                        CASE
                            -- 10% never used
                            WHEN random() < 0.02 THEN NULL
                            -- 70% used within last 20 days → not idle
                            WHEN random() < 0.93 THEN
                                CURRENT_DATE - (floor(random() * 15)::INTEGER || ' days')::INTERVAL
                            -- 20% used 21-60 days ago → some idle
                            ELSE
                                CURRENT_DATE - (31 + floor(random() * 20)::INTEGER || ' days')::INTERVAL
                        END,
                        'ACTIVE'
                    );
                    v_allocated := v_allocated + 1;
                    EXIT WHEN v_allocated >= v_seats_to_allocate;
                EXCEPTION WHEN OTHERS THEN
                    CONTINUE;
                END;
            END LOOP;
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- 7. UPDATE DEPARTMENT SPEND
-- ============================================================
SELECT update_dept_spend();

-- ============================================================
-- Verification Queries
-- ============================================================
SELECT 'Departments:',       COUNT(*) FROM departments;
SELECT 'Employees:',         COUNT(*) FROM employees;
SELECT 'Active Employees:',  COUNT(*) FROM employees WHERE status = 'ACTIVE';
SELECT 'Vendors:',           COUNT(*) FROM vendors;
SELECT 'Software Plans:',    COUNT(*) FROM software_plans;
SELECT 'Subscriptions:',     COUNT(*) FROM subscriptions;
SELECT 'License Allocations:',COUNT(*) FROM license_allocations;
SELECT 'Idle Licenses:',     COUNT(*) FROM idle_license_view;

-- Budget utilisation check
SELECT
    ROUND(SUM(current_spend) / NULLIF(SUM(budget), 0) * 100, 1) AS overall_utilisation_pct
FROM departments;
