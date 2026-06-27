-- ============================================================
-- SaaS-Spend PL/pgSQL Functions
-- ============================================================

-- ============================================================
-- 1. ASSIGN LICENSE FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION assign_license(
    p_emp_id INTEGER,
    p_sub_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_emp_status VARCHAR(20);
    v_dept_id INTEGER;
    v_seats_purchased INTEGER;
    v_seats_used INTEGER;
    v_plan_name VARCHAR(100);
BEGIN
    -- Check if employee exists and is active
    SELECT status, dept_id INTO v_emp_status, v_dept_id
    FROM employees WHERE emp_id = p_emp_id;
    
    IF NOT FOUND THEN
        RETURN 'ERROR: Employee not found';
    END IF;
    
    IF v_emp_status != 'ACTIVE' THEN
        RETURN 'ERROR: Employee is not active';
    END IF;
    
    -- Check if subscription exists
    SELECT seats_purchased INTO v_seats_purchased
    FROM subscriptions WHERE sub_id = p_sub_id;
    
    IF NOT FOUND THEN
        RETURN 'ERROR: Subscription not found';
    END IF;
    
    -- Check if license already assigned
    IF EXISTS (
        SELECT 1 FROM license_allocations 
        WHERE emp_id = p_emp_id AND sub_id = p_sub_id 
        AND alloc_status = 'ACTIVE'
    ) THEN
        RETURN 'ERROR: License already assigned to this employee';
    END IF;
    
    -- Check seat availability
    SELECT COUNT(*) INTO v_seats_used
    FROM license_allocations
    WHERE sub_id = p_sub_id AND alloc_status = 'ACTIVE';
    
    IF v_seats_used >= v_seats_purchased THEN
        RETURN 'ERROR: No available seats for this subscription';
    END IF;
    
    -- Assign license
    INSERT INTO license_allocations (emp_id, sub_id, assigned_date, last_used_date, alloc_status)
    VALUES (p_emp_id, p_sub_id, CURRENT_DATE, CURRENT_DATE, 'ACTIVE');
    
    -- Get plan name for logging
    SELECT sp.plan_name INTO v_plan_name
    FROM subscriptions s
    JOIN software_plans sp ON sp.plan_id = s.plan_id
    WHERE s.sub_id = p_sub_id;
    
    -- Log action
    INSERT INTO audit_log (action_type, table_name, ref_id, description)
    VALUES ('ASSIGN', 'license_allocations', p_emp_id, 
            'License assigned: ' || v_plan_name || ' to emp_id ' || p_emp_id);
    
    RETURN 'SUCCESS: License assigned successfully';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 2. REVOKE LICENSE FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION revoke_license(
    p_emp_id INTEGER,
    p_sub_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_alloc_id INTEGER;
    v_plan_name VARCHAR(100);
BEGIN
    -- Check if allocation exists and is active
    SELECT alloc_id INTO v_alloc_id
    FROM license_allocations
    WHERE emp_id = p_emp_id AND sub_id = p_sub_id AND alloc_status = 'ACTIVE';
    
    IF NOT FOUND THEN
        RETURN 'ERROR: Active license allocation not found';
    END IF;
    
    -- Revoke license
    UPDATE license_allocations
    SET alloc_status = 'REVOKED'
    WHERE alloc_id = v_alloc_id;
    
    -- Get plan name for logging
    SELECT sp.plan_name INTO v_plan_name
    FROM subscriptions s
    JOIN software_plans sp ON sp.plan_id = s.plan_id
    WHERE s.sub_id = p_sub_id;
    
    -- Log action
    INSERT INTO audit_log (action_type, table_name, ref_id, description)
    VALUES ('REVOKE', 'license_allocations', v_alloc_id, 
            'License revoked: ' || v_plan_name || ' from emp_id ' || p_emp_id);
    
    RETURN 'SUCCESS: License revoked successfully';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3. DEPARTMENT ANNUAL SPEND FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION dept_annual_spend(p_dept_id INTEGER)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    v_total_spend DECIMAL(12,2);
BEGIN
    SELECT COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0)
    INTO v_total_spend
    FROM subscriptions s
    JOIN software_plans sp ON sp.plan_id = s.plan_id
    WHERE s.dept_id = p_dept_id AND s.subscription_status = 'ACTIVE';
    
    RETURN v_total_spend;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. IDLE LICENSE COUNT FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION idle_license_count(
    p_dept_id INTEGER DEFAULT NULL,
    p_days_threshold INTEGER DEFAULT 30
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF p_dept_id IS NULL THEN
        -- Count idle licenses across all departments
        SELECT COUNT(*)
        INTO v_count
        FROM license_allocations la
        JOIN employees e ON e.emp_id = la.emp_id
        WHERE la.alloc_status = 'ACTIVE'
        AND (la.last_used_date IS NULL 
             OR CURRENT_DATE - la.last_used_date > p_days_threshold);
    ELSE
        -- Count idle licenses for specific department
        SELECT COUNT(*)
        INTO v_count
        FROM license_allocations la
        JOIN employees e ON e.emp_id = la.emp_id
        WHERE e.dept_id = p_dept_id
        AND la.alloc_status = 'ACTIVE'
        AND (la.last_used_date IS NULL 
             OR CURRENT_DATE - la.last_used_date > p_days_threshold);
    END IF;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. UPDATE DEPARTMENT SPEND FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION update_dept_spend()
RETURNS VOID AS $$
BEGIN
    UPDATE departments d
    SET current_spend = (
        SELECT COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0)
        FROM subscriptions s
        JOIN software_plans sp ON sp.plan_id = s.plan_id
        WHERE s.dept_id = d.dept_id AND s.subscription_status = 'ACTIVE'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6. AUTO REVOKE EMPLOYEE LICENSES FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION auto_revoke_employee_licenses(p_emp_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_revoked_count INTEGER := 0;
    v_alloc RECORD;
BEGIN
    FOR v_alloc IN 
        SELECT alloc_id, sub_id 
        FROM license_allocations 
        WHERE emp_id = p_emp_id AND alloc_status = 'ACTIVE'
    LOOP
        UPDATE license_allocations
        SET alloc_status = 'REVOKED'
        WHERE alloc_id = v_alloc.alloc_id;
        
        v_revoked_count := v_revoked_count + 1;
        
        INSERT INTO audit_log (action_type, table_name, ref_id, description)
        VALUES ('REVOKE', 'license_allocations', v_alloc.alloc_id,
                'Auto-revoked due to employee status change (emp_id: ' || p_emp_id || ')');
    END LOOP;
    
    RETURN v_revoked_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. SUBSCRIPTION COST FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION subscription_annual_cost(p_sub_id INTEGER)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    v_cost DECIMAL(12,2);
BEGIN
    SELECT s.seats_purchased * sp.price_per_seat
    INTO v_cost
    FROM subscriptions s
    JOIN software_plans sp ON sp.plan_id = s.plan_id
    WHERE s.sub_id = p_sub_id;
    
    RETURN COALESCE(v_cost, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. AVAILABLE SEATS FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION available_seats(p_sub_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_seats_purchased INTEGER;
    v_seats_used INTEGER;
BEGIN
    SELECT seats_purchased INTO v_seats_purchased
    FROM subscriptions WHERE sub_id = p_sub_id;
    
    SELECT COUNT(*) INTO v_seats_used
    FROM license_allocations
    WHERE sub_id = p_sub_id AND alloc_status = 'ACTIVE';
    
    RETURN COALESCE(v_seats_purchased, 0) - COALESCE(v_seats_used, 0);
END;
$$ LANGUAGE plpgsql;
