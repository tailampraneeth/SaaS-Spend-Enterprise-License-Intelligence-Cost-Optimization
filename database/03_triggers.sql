-- ============================================================
-- SaaS-Spend Triggers
-- ============================================================

-- ============================================================
-- 1. BUDGET ENFORCEMENT TRIGGER
-- Prevents subscription insertion if it exceeds department budget
-- ============================================================
CREATE OR REPLACE FUNCTION check_budget_before_subscription()
RETURNS TRIGGER AS $$
DECLARE
    v_dept_budget DECIMAL(12,2);
    v_current_spend DECIMAL(12,2);
    v_new_cost DECIMAL(12,2);
    v_price_per_seat DECIMAL(10,2);
    v_dept_name VARCHAR(100);
BEGIN
    -- Get department budget and current spend
    SELECT budget, current_spend, dept_name
    INTO v_dept_budget, v_current_spend, v_dept_name
    FROM departments
    WHERE dept_id = NEW.dept_id;
    
    -- Get price per seat for the plan
    SELECT price_per_seat INTO v_price_per_seat
    FROM software_plans
    WHERE plan_id = NEW.plan_id;
    
    -- Calculate new subscription cost
    v_new_cost := NEW.seats_purchased * v_price_per_seat;
    
    -- Check if adding this subscription would exceed budget
    IF (v_current_spend + v_new_cost) > v_dept_budget THEN
        -- Log the budget violation attempt
        INSERT INTO audit_log (action_type, table_name, ref_id, description)
        VALUES ('BUDGET_CHECK', 'subscriptions', NEW.dept_id,
                'Budget exceeded: Dept ' || v_dept_name || 
                ' - Budget: ' || v_dept_budget || 
                ', Current: ' || v_current_spend || 
                ', Attempted: ' || v_new_cost);
        
        RAISE EXCEPTION 'Budget exceeded for department %. Budget: %, Current Spend: %, New Cost: %', 
            v_dept_name, v_dept_budget, v_current_spend, v_new_cost;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_budget
BEFORE INSERT ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION check_budget_before_subscription();

-- ============================================================
-- 2. UPDATE DEPARTMENT SPEND TRIGGER
-- Automatically updates department current_spend after subscription changes
-- ============================================================
CREATE OR REPLACE FUNCTION update_dept_spend_after_subscription()
RETURNS TRIGGER AS $$
DECLARE
    v_dept_id INTEGER;
    v_new_spend DECIMAL(12,2);
BEGIN
    -- Determine which department to update
    IF TG_OP = 'DELETE' THEN
        v_dept_id := OLD.dept_id;
    ELSE
        v_dept_id := NEW.dept_id;
    END IF;
    
    -- Recalculate department spend
    SELECT COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0)
    INTO v_new_spend
    FROM subscriptions s
    JOIN software_plans sp ON sp.plan_id = s.plan_id
    WHERE s.dept_id = v_dept_id AND s.subscription_status = 'ACTIVE';
    
    -- Update department
    UPDATE departments
    SET current_spend = v_new_spend
    WHERE dept_id = v_dept_id;
    
    -- Handle both old and new departments if subscription moved
    IF TG_OP = 'UPDATE' AND OLD.dept_id != NEW.dept_id THEN
        SELECT COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0)
        INTO v_new_spend
        FROM subscriptions s
        JOIN software_plans sp ON sp.plan_id = s.plan_id
        WHERE s.dept_id = OLD.dept_id AND s.subscription_status = 'ACTIVE';
        
        UPDATE departments
        SET current_spend = v_new_spend
        WHERE dept_id = OLD.dept_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_dept_spend_insert
AFTER INSERT ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_dept_spend_after_subscription();

CREATE TRIGGER trg_update_dept_spend_update
AFTER UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_dept_spend_after_subscription();

CREATE TRIGGER trg_update_dept_spend_delete
AFTER DELETE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_dept_spend_after_subscription();

-- ============================================================
-- 3. AUTO REVOKE LICENSES ON EMPLOYEE STATUS CHANGE
-- Automatically revokes all licenses when employee becomes INACTIVE or TRANSFERRED
-- ============================================================
CREATE OR REPLACE FUNCTION auto_revoke_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_revoked_count INTEGER;
BEGIN
    -- Only act if status changed to INACTIVE or TRANSFERRED
    IF NEW.status IN ('INACTIVE', 'TRANSFERRED') AND 
       OLD.status != NEW.status THEN
        
        -- Revoke all active licenses
        v_revoked_count := auto_revoke_employee_licenses(NEW.emp_id);
        
        -- Log the auto-revocation
        INSERT INTO audit_log (action_type, table_name, ref_id, description)
        VALUES ('UPDATE', 'employees', NEW.emp_id,
                'Employee status changed to ' || NEW.status || 
                '. Auto-revoked ' || v_revoked_count || ' license(s)');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_revoke_licenses
AFTER UPDATE OF status ON employees
FOR EACH ROW
WHEN (NEW.status IN ('INACTIVE', 'TRANSFERRED'))
EXECUTE FUNCTION auto_revoke_on_status_change();

-- ============================================================
-- 4. AUDIT LOG FOR DEPARTMENTS
-- ============================================================
CREATE OR REPLACE FUNCTION audit_departments()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (action_type, table_name, ref_id, description, new_value)
        VALUES ('INSERT', 'departments', NEW.dept_id,
                'New department created: ' || NEW.dept_name,
                'Budget: ' || NEW.budget);
                
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (action_type, table_name, ref_id, description, old_value, new_value)
        VALUES ('UPDATE', 'departments', NEW.dept_id,
                'Department updated: ' || NEW.dept_name,
                'Old budget: ' || OLD.budget,
                'New budget: ' || NEW.budget);
                
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (action_type, table_name, ref_id, description, old_value)
        VALUES ('DELETE', 'departments', OLD.dept_id,
                'Department deleted: ' || OLD.dept_name,
                'Budget: ' || OLD.budget);
        RETURN OLD;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_departments
AFTER INSERT OR UPDATE OR DELETE ON departments
FOR EACH ROW
EXECUTE FUNCTION audit_departments();

-- ============================================================
-- 5. AUDIT LOG FOR SUBSCRIPTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION audit_subscriptions()
RETURNS TRIGGER AS $$
DECLARE
    v_plan_name VARCHAR(100);
    v_dept_name VARCHAR(100);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT sp.plan_name, d.dept_name 
        INTO v_plan_name, v_dept_name
        FROM software_plans sp, departments d
        WHERE sp.plan_id = NEW.plan_id AND d.dept_id = NEW.dept_id;
        
        INSERT INTO audit_log (action_type, table_name, ref_id, description, new_value)
        VALUES ('INSERT', 'subscriptions', NEW.sub_id,
                'New subscription: ' || v_plan_name || ' for ' || v_dept_name,
                'Seats: ' || NEW.seats_purchased);
                
    ELSIF TG_OP = 'DELETE' THEN
        SELECT sp.plan_name, d.dept_name 
        INTO v_plan_name, v_dept_name
        FROM software_plans sp, departments d
        WHERE sp.plan_id = OLD.plan_id AND d.dept_id = OLD.dept_id;
        
        INSERT INTO audit_log (action_type, table_name, ref_id, description)
        VALUES ('DELETE', 'subscriptions', OLD.sub_id,
                'Subscription deleted: ' || v_plan_name || ' for ' || v_dept_name);
        RETURN OLD;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_subscriptions
AFTER INSERT OR DELETE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION audit_subscriptions();

-- ============================================================
-- 6. VALIDATE LICENSE ALLOCATION
-- Ensures seats are available before allocation
-- ============================================================
CREATE OR REPLACE FUNCTION validate_license_allocation()
RETURNS TRIGGER AS $$
DECLARE
    v_seats_purchased INTEGER;
    v_seats_used INTEGER;
BEGIN
    -- Get total seats purchased
    SELECT seats_purchased INTO v_seats_purchased
    FROM subscriptions WHERE sub_id = NEW.sub_id;
    
    -- Count currently active allocations (excluding current if update)
    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*) INTO v_seats_used
        FROM license_allocations
        WHERE sub_id = NEW.sub_id AND alloc_status = 'ACTIVE';
    ELSE
        SELECT COUNT(*) INTO v_seats_used
        FROM license_allocations
        WHERE sub_id = NEW.sub_id AND alloc_status = 'ACTIVE'
        AND alloc_id != NEW.alloc_id;
    END IF;
    
    -- Check if new allocation would exceed available seats
    IF NEW.alloc_status = 'ACTIVE' AND v_seats_used >= v_seats_purchased THEN
        RAISE EXCEPTION 'No available seats for this subscription. Purchased: %, Used: %',
            v_seats_purchased, v_seats_used;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_allocation
BEFORE INSERT OR UPDATE ON license_allocations
FOR EACH ROW
WHEN (NEW.alloc_status = 'ACTIVE')
EXECUTE FUNCTION validate_license_allocation();
