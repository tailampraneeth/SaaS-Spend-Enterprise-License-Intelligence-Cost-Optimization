-- ============================================================
-- SaaS-Spend Views
-- ============================================================

-- ============================================================
-- 1. DEPARTMENT SPEND VIEW
-- ============================================================
CREATE OR REPLACE VIEW dept_spend_view AS
SELECT 
    d.dept_id,
    d.dept_name,
    d.location,
    d.budget,
    d.current_spend,
    ROUND((d.current_spend / NULLIF(d.budget, 0) * 100), 2) AS spend_pct,
    (d.budget - d.current_spend) AS remaining_budget,
    COUNT(DISTINCT e.emp_id) AS employee_count,
    COUNT(DISTINCT s.sub_id) AS subscription_count
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id AND e.status = 'ACTIVE'
LEFT JOIN subscriptions s ON s.dept_id = d.dept_id AND s.subscription_status = 'ACTIVE'
GROUP BY d.dept_id, d.dept_name, d.location, d.budget, d.current_spend;

-- ============================================================
-- 2. VENDOR COST VIEW
-- ============================================================
CREATE OR REPLACE VIEW vendor_cost_view AS
SELECT 
    v.vendor_id,
    v.vendor_name,
    v.website,
    v.contact_email,

    COUNT(DISTINCT sp.plan_id) AS total_plans,
    COUNT(DISTINCT s.sub_id) AS active_subscriptions,

    -- FIXED: no duplication + correct annual conversion
    COALESCE((
        SELECT SUM(
            s2.seats_purchased * 
            CASE 
                WHEN sp2.billing_cycle = 'MONTHLY' THEN sp2.price_per_seat * 12
                ELSE sp2.price_per_seat
            END
        )
        FROM subscriptions s2
        JOIN software_plans sp2 ON s2.plan_id = sp2.plan_id
        WHERE sp2.vendor_id = v.vendor_id
          AND s2.subscription_status = 'ACTIVE'
    ), 0) AS total_annual_cost,

    COALESCE(SUM(s.seats_purchased), 0) AS total_seats_purchased,

    COUNT(DISTINCT 
        CASE WHEN la.alloc_status = 'ACTIVE' THEN la.alloc_id END
    ) AS active_licenses

FROM vendors v
LEFT JOIN software_plans sp ON sp.vendor_id = v.vendor_id
LEFT JOIN subscriptions s 
    ON s.plan_id = sp.plan_id 
   AND s.subscription_status = 'ACTIVE'
LEFT JOIN license_allocations la 
    ON la.sub_id = s.sub_id

GROUP BY v.vendor_id, v.vendor_name, v.website, v.contact_email;

-- ============================================================
-- 3. IDLE LICENSE VIEW
-- ============================================================
CREATE OR REPLACE VIEW idle_license_view AS
SELECT 
    la.alloc_id,
    e.emp_id,
    e.emp_name,
    e.email,
    d.dept_name,
    sp.plan_name,
    v.vendor_name,
    sp.price_per_seat AS monthly_cost,
    la.assigned_date,
    la.last_used_date,
    CASE 
        WHEN la.last_used_date IS NULL THEN CURRENT_DATE - la.assigned_date
        ELSE CURRENT_DATE - la.last_used_date
    END AS days_idle
FROM license_allocations la
JOIN employees e ON e.emp_id = la.emp_id
JOIN departments d ON d.dept_id = e.dept_id
JOIN subscriptions s ON s.sub_id = la.sub_id
JOIN software_plans sp ON sp.plan_id = s.plan_id
JOIN vendors v ON v.vendor_id = sp.vendor_id
WHERE la.alloc_status = 'ACTIVE'
AND (
    -- If never used, only idle if assigned more than 30 days ago
    (la.last_used_date IS NULL AND CURRENT_DATE - la.assigned_date > 30)
    OR 
    -- If used before, only idle if last use was more than 30 days ago
    (la.last_used_date IS NOT NULL AND CURRENT_DATE - la.last_used_date > 30)
)
ORDER BY days_idle DESC;

-- ============================================================
-- 4. ALLOCATION REPORT VIEW
-- ============================================================
CREATE OR REPLACE VIEW allocation_report_view AS
SELECT 
    la.alloc_id,
    la.emp_id,
    e.emp_name,
    e.email,
    e.role,
    e.status AS emp_status,
    d.dept_id,
    d.dept_name,
    la.sub_id,
    sp.plan_id,
    sp.plan_name,
    sp.category,
    v.vendor_id,
    v.vendor_name,
    sp.price_per_seat AS monthly_cost,
    la.assigned_date,
    la.last_used_date,
    la.alloc_status,
    CASE 
        WHEN la.last_used_date IS NULL THEN CURRENT_DATE - la.assigned_date
        ELSE CURRENT_DATE - la.last_used_date
    END AS days_idle,
    s.start_date AS sub_start_date,
    s.end_date AS sub_end_date
FROM license_allocations la
JOIN employees e ON e.emp_id = la.emp_id
JOIN departments d ON d.dept_id = e.dept_id
JOIN subscriptions s ON s.sub_id = la.sub_id
JOIN software_plans sp ON sp.plan_id = s.plan_id
JOIN vendors v ON v.vendor_id = sp.vendor_id;

-- ============================================================
-- 5. SUBSCRIPTION UTILIZATION VIEW
-- ============================================================
CREATE OR REPLACE VIEW subscription_utilization_view AS
SELECT 
    s.sub_id,
    d.dept_name,
    sp.plan_name,
    v.vendor_name,
    sp.category,
    s.seats_purchased,
    COUNT(CASE WHEN la.alloc_status = 'ACTIVE' THEN 1 END) AS seats_used,
    (s.seats_purchased - COUNT(CASE WHEN la.alloc_status = 'ACTIVE' THEN 1 END)) AS seats_available,
    ROUND(
        (COUNT(CASE WHEN la.alloc_status = 'ACTIVE' THEN 1 END)::DECIMAL / 
         NULLIF(s.seats_purchased, 0) * 100), 2
    ) AS utilization_pct,
    (s.seats_purchased * sp.price_per_seat) AS total_cost,
    (COUNT(CASE WHEN la.alloc_status = 'ACTIVE' THEN 1 END) * sp.price_per_seat) AS utilized_cost,
    s.start_date,
    s.end_date,
    s.subscription_status
FROM subscriptions s
JOIN departments d ON d.dept_id = s.dept_id
JOIN software_plans sp ON sp.plan_id = s.plan_id
JOIN vendors v ON v.vendor_id = sp.vendor_id
LEFT JOIN license_allocations la ON la.sub_id = s.sub_id
GROUP BY 
    s.sub_id, d.dept_name, sp.plan_name, v.vendor_name, sp.category,
    s.seats_purchased, sp.price_per_seat, s.start_date, s.end_date, s.subscription_status;

-- ============================================================
-- 6. CATEGORY SPEND VIEW
-- ============================================================
CREATE OR REPLACE VIEW category_spend_view AS
SELECT 
    sp.category,
    COUNT(DISTINCT sp.plan_id) AS total_plans,
    COUNT(DISTINCT s.sub_id) AS active_subscriptions,
    COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0) AS total_annual_cost,
    COALESCE(SUM(s.seats_purchased), 0) AS total_seats,
    COUNT(CASE WHEN la.alloc_status = 'ACTIVE' THEN 1 END) AS active_allocations
FROM software_plans sp
LEFT JOIN subscriptions s ON s.plan_id = sp.plan_id AND s.subscription_status = 'ACTIVE'
LEFT JOIN license_allocations la ON la.sub_id = s.sub_id
GROUP BY sp.category
ORDER BY total_annual_cost DESC;
