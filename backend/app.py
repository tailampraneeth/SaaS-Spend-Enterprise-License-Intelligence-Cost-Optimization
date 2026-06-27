import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, jsonify, request
from flask_cors import CORS
from decimal import Decimal
from datetime import date, datetime
import json

app = Flask(__name__)
CORS(app)

# Database connection config
DB_CONFIG = {
    'host': 'localhost',
    'database': 'saas_spend',
    'user': 'postgres',
    'password': 'student'  
}

# Custom JSON encoder to handle Decimal and date types
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        return super().default(obj)

app.json_encoder = CustomJSONEncoder

def get_db():
    """Get database connection"""
    return psycopg2.connect(**DB_CONFIG)

def safe_float(value, default=0.0):
    """Safely convert to float"""
    try:
        return float(value) if value is not None else default
    except (ValueError, TypeError):
        return default

def safe_int(value, default=0):
    """Safely convert to int"""
    try:
        return int(value) if value is not None else default
    except (ValueError, TypeError):
        return default

# ============================================================
# DASHBOARD
# ============================================================
@app.route('/api/dashboard', methods=['GET'])
def get_dashboard():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Total spend across all departments
        cur.execute("SELECT COALESCE(SUM(current_spend), 0) as total_annual_spend FROM departments")
        total_annual_spend = safe_float(cur.fetchone()['total_annual_spend'])
        
        # Total budget
        cur.execute("SELECT COALESCE(SUM(budget), 0) as total_budget FROM departments")
        total_budget = safe_float(cur.fetchone()['total_budget'])
        
        # Active subscriptions count
        cur.execute("SELECT COUNT(*) as count FROM subscriptions WHERE subscription_status = 'ACTIVE'")
        active_subscriptions = safe_int(cur.fetchone()['count'])
        
        # Total departments count
        cur.execute("SELECT COUNT(*) as count FROM departments")
        total_departments = safe_int(cur.fetchone()['count'])
        
        # Active employees count
        cur.execute("SELECT COUNT(*) as count FROM employees WHERE status = 'ACTIVE'")
        active_employees = safe_int(cur.fetchone()['count'])
        
        # Idle licenses (last 30 days)
        cur.execute("SELECT COUNT(*) as count FROM idle_license_view")
        idle_licenses = safe_int(cur.fetchone()['count'])
        
        # Budget utilization percentage
        budget_utilization = 0
        if total_budget > 0:
            budget_utilization = round((total_annual_spend / total_budget) * 100, 1)
        
        # Top spending departments
        cur.execute("""
            SELECT dept_name, current_spend, budget
            FROM departments
            ORDER BY current_spend DESC
            LIMIT 5
        """)
        top_departments = []
        for row in cur.fetchall():
            top_departments.append({
                'dept_name': row['dept_name'],
                'current_spend': safe_float(row['current_spend']),
                'budget': safe_float(row['budget'])
            })
        
        # Category breakdown - map total_annual_cost to spend
        cur.execute("""
            SELECT 
                category,
                COALESCE(SUM(s.seats_purchased * sp.price_per_seat), 0) AS spend
            FROM software_plans sp
            LEFT JOIN subscriptions s ON s.plan_id = sp.plan_id AND s.subscription_status = 'ACTIVE'
            GROUP BY sp.category
            ORDER BY spend DESC
            LIMIT 5
        """)
        category_breakdown = []
        for row in cur.fetchall():
            category_breakdown.append({
                'category': row['category'],
                'spend': safe_float(row['spend'])
            })
        
        cur.close()
        conn.close()
        
        return jsonify({
            'total_annual_spend': total_annual_spend,
            'total_budget': total_budget,
            'active_subscriptions': active_subscriptions,
            'total_subscriptions': active_subscriptions,  # Frontend uses both
            'total_departments': total_departments,
            'active_employees': active_employees,
            'idle_licenses': idle_licenses,
            'budget_utilization': budget_utilization,
            'top_departments': top_departments,
            'category_breakdown': category_breakdown
        })
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# DEPARTMENTS
# ============================================================
@app.route('/api/departments', methods=['GET'])
def get_departments():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM dept_spend_view ORDER BY dept_name")
        departments = []
        for row in cur.fetchall():
            departments.append({
                'dept_id': safe_int(row.get('dept_id')),
                'dept_name': row.get('dept_name', ''),
                'location': row.get('location', ''),
                'budget': safe_float(row.get('budget')),
                'current_spend': safe_float(row.get('current_spend')),
                'spend_pct': safe_float(row.get('spend_pct')),
                'remaining_budget': safe_float(row.get('remaining_budget')),
                'employee_count': safe_int(row.get('employee_count')),
                'subscription_count': safe_int(row.get('subscription_count'))
            })
        cur.close()
        conn.close()
        return jsonify(departments)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/departments', methods=['POST'])
def create_department():
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO departments (dept_name, location, budget, current_spend)
            VALUES (%s, %s, %s, 0)
            RETURNING dept_id
        """, (data['dept_name'], data['location'], data['budget']))
        
        dept_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Department created', 'dept_id': dept_id, 'status': 'success'}), 201
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/departments/<int:dept_id>', methods=['PUT'])
def update_department(dept_id):
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE departments
            SET dept_name = %s, location = %s, budget = %s
            WHERE dept_id = %s
        """, (data['dept_name'], data['location'], data['budget'], dept_id))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Department updated'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/departments/<int:dept_id>', methods=['DELETE'])
def delete_department(dept_id):
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("DELETE FROM departments WHERE dept_id = %s", (dept_id,))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Department deleted'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# EMPLOYEES
# ============================================================
@app.route('/api/employees', methods=['GET'])
def get_employees():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        dept_id = request.args.get('dept_id')
        if dept_id:
            cur.execute("""
                SELECT e.*, d.dept_name,
                       (SELECT COUNT(*) FROM license_allocations la 
                        WHERE la.emp_id = e.emp_id AND la.alloc_status = 'ACTIVE') as active_licenses
                FROM employees e
                JOIN departments d ON d.dept_id = e.dept_id
                WHERE e.dept_id = %s
                ORDER BY e.emp_name
            """, (dept_id,))
        else:
            cur.execute("""
                SELECT e.*, d.dept_name,
                       (SELECT COUNT(*) FROM license_allocations la 
                        WHERE la.emp_id = e.emp_id AND la.alloc_status = 'ACTIVE') as active_licenses
                FROM employees e
                JOIN departments d ON d.dept_id = e.dept_id
                ORDER BY e.emp_name
            """)
        
        employees = []
        for row in cur.fetchall():
            employees.append({
                'emp_id': safe_int(row.get('emp_id')),
                'emp_name': row.get('emp_name', ''),
                'email': row.get('email', ''),
                'role': row.get('role', ''),
                'status': row.get('status', ''),
                'dept_id': safe_int(row.get('dept_id')),
                'dept_name': row.get('dept_name', ''),
                'hire_date': row.get('hire_date').isoformat() if row.get('hire_date') else None,
                'active_licenses': safe_int(row.get('active_licenses'))
            })
        
        cur.close()
        conn.close()
        return jsonify(employees)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/employees', methods=['POST'])
def create_employee():
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO employees (emp_name, email, role, status, dept_id, hire_date)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING emp_id
        """, (data['emp_name'], data['email'], data['role'], 
              data.get('status', 'ACTIVE'), data['dept_id'], 
              data.get('hire_date', date.today())))
        
        emp_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Employee created', 'emp_id': emp_id, 'status': 'success'}), 201
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/employees/<int:emp_id>', methods=['PUT'])
def update_employee(emp_id):
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE employees
            SET emp_name = %s, email = %s, role = %s, status = %s, dept_id = %s
            WHERE emp_id = %s
        """, (data['emp_name'], data['email'], data['role'], 
              data['status'], data['dept_id'], emp_id))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Employee updated'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/employees/<int:emp_id>/status', methods=['PUT'])
def update_employee_status(emp_id):
    conn = None
    try:
        data = request.json
        new_status = data.get('status')
        new_dept_id = data.get('new_dept_id')  # Optional: only required for TRANSFERRED

        conn = get_db()
        cur = conn.cursor()

        # If transferring, validate and update dept_id as well
        if new_status == 'TRANSFERRED':
            if not new_dept_id:
                return jsonify({'error': 'new_dept_id is required when transferring an employee', 'status': 'error'}), 400

            # Validate that the department exists
            cur.execute("SELECT dept_id FROM departments WHERE dept_id = %s", (new_dept_id,))
            if not cur.fetchone():
                return jsonify({'error': f'Department ID {new_dept_id} does not exist', 'status': 'error'}), 400

            cur.execute("""
                UPDATE employees
                SET status = %s, dept_id = %s
                WHERE emp_id = %s
            """, (new_status, new_dept_id, emp_id))
        else:
            cur.execute("""
                UPDATE employees
                SET status = %s
                WHERE emp_id = %s
            """, (new_status, emp_id))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({'message': 'Employee status updated', 'status': 'success'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e), 'status': 'error'}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/employees/<int:emp_id>', methods=['DELETE'])
def delete_employee(emp_id):
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("DELETE FROM employees WHERE emp_id = %s", (emp_id,))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Employee deleted'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# VENDORS
# ============================================================
@app.route('/api/vendors', methods=['GET'])
def get_vendors():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM vendor_cost_view ORDER BY vendor_name")
        vendors = []
        for row in cur.fetchall():
            vendors.append({
                'vendor_id': safe_int(row.get('vendor_id')),
                'vendor_name': row.get('vendor_name', ''),
                'website': row.get('website', ''),
                'contact_email': row.get('contact_email', ''),
                'total_plans': safe_int(row.get('total_plans')),
                'active_subscriptions': safe_int(row.get('active_subscriptions')),
                'total_annual_cost': safe_float(row.get('total_annual_cost')),
                'total_seats_purchased': safe_int(row.get('total_seats_purchased')),
                'active_licenses': safe_int(row.get('active_licenses'))
            })
        cur.close()
        conn.close()
        return jsonify(vendors)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# SOFTWARE PLANS
# ============================================================
@app.route('/api/plans', methods=['GET'])
def get_plans():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT sp.*, v.vendor_name
            FROM software_plans sp
            JOIN vendors v ON v.vendor_id = sp.vendor_id
            ORDER BY sp.plan_name
        """)
        
        plans = []
        for row in cur.fetchall():
            plans.append({
                'plan_id': safe_int(row.get('plan_id')),
                'plan_name': row.get('plan_name', ''),
                'category': row.get('category', ''),
                'price_per_seat': safe_float(row.get('price_per_seat')),
                'billing_cycle': row.get('billing_cycle', ''),
                'vendor_id': safe_int(row.get('vendor_id')),
                'vendor_name': row.get('vendor_name', ''),
                'features': row.get('features', '')
            })
        cur.close()
        conn.close()
        return jsonify(plans)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============================================================
# SUBSCRIPTIONS
# ============================================================
@app.route('/api/subscriptions', methods=['GET'])
def get_subscriptions():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM subscription_utilization_view ORDER BY dept_name, plan_name")
        subscriptions = []
        for row in cur.fetchall():
            subscriptions.append({
                'sub_id': safe_int(row.get('sub_id')),
                'dept_name': row.get('dept_name', ''),
                'plan_name': row.get('plan_name', ''),
                'vendor_name': row.get('vendor_name', ''),
                'category': row.get('category', ''),
                'seats_purchased': safe_int(row.get('seats_purchased')),
                'seats_used': safe_int(row.get('seats_used')),
                'seats_available': safe_int(row.get('seats_available')),
                'utilization_pct': safe_float(row.get('utilization_pct')),
                'total_cost': safe_float(row.get('total_cost')),
                'annual_cost': safe_float(row.get('total_cost')),  # alias: seats_purchased * price_per_seat
                'utilized_cost': safe_float(row.get('utilized_cost')),
                'start_date': row.get('start_date').isoformat() if row.get('start_date') else None,
                'end_date': row.get('end_date').isoformat() if row.get('end_date') else None,
                'subscription_status': row.get('subscription_status', '')
            })
        cur.close()
        conn.close()
        return jsonify(subscriptions)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/subscriptions', methods=['POST'])
def create_subscription():
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO subscriptions (seats_purchased, start_date, end_date, dept_id, plan_id, subscription_status)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING sub_id
        """, (data['seats_purchased'], data['start_date'], data['end_date'],
              data['dept_id'], data['plan_id'], data.get('subscription_status', 'ACTIVE')))
        
        sub_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Subscription created', 'sub_id': sub_id, 'status': 'success'}), 201
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/subscriptions/<int:sub_id>', methods=['DELETE'])
def delete_subscription(sub_id):
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute("DELETE FROM subscriptions WHERE sub_id = %s", (sub_id,))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Subscription deleted'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# LICENSE ALLOCATIONS
# ============================================================
@app.route('/api/licenses', methods=['GET'])
def get_allocations():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM allocation_report_view ORDER BY emp_name, plan_name")
        allocations = []
        for row in cur.fetchall():
            allocations.append({
                'alloc_id': safe_int(row.get('alloc_id')),
                'emp_id': safe_int(row.get('emp_id')),
                'emp_name': row.get('emp_name', ''),
                'email': row.get('email', ''),
                'role': row.get('role', ''),
                'emp_status': row.get('emp_status', ''),
                'dept_id': safe_int(row.get('dept_id')),
                'dept_name': row.get('dept_name', ''),
                'sub_id': safe_int(row.get('sub_id')),
                'plan_id': safe_int(row.get('plan_id')),
                'plan_name': row.get('plan_name', ''),
                'category': row.get('category', ''),
                'vendor_id': safe_int(row.get('vendor_id')),
                'vendor_name': row.get('vendor_name', ''),
                'monthly_cost': safe_float(row.get('monthly_cost')),
                'assigned_date': row.get('assigned_date').isoformat() if row.get('assigned_date') else None,
                'last_used_date': row.get('last_used_date').isoformat() if row.get('last_used_date') else None,
                'alloc_status': row.get('alloc_status', ''),
                'days_idle': safe_int(row.get('days_idle')),
                'sub_start_date': row.get('sub_start_date').isoformat() if row.get('sub_start_date') else None,
                'sub_end_date': row.get('sub_end_date').isoformat() if row.get('sub_end_date') else None
            })
        cur.close()
        conn.close()
        return jsonify(allocations)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/licenses/assign', methods=['POST'])
def assign_license():
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        # Call the assign_license function
        cur.execute("SELECT assign_license(%s, %s)", (data['emp_id'], data['sub_id']))
        result = cur.fetchone()[0]
        
        if result.startswith('ERROR'):
            conn.rollback()
            return jsonify({'error': result}), 400
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': result, 'status': 'success'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/licenses/revoke', methods=['POST'])
def revoke_license():
    conn = None
    try:
        data = request.json
        conn = get_db()
        cur = conn.cursor()
        
        # Call the revoke_license function
        cur.execute("SELECT revoke_license(%s, %s)", (data['emp_id'], data['sub_id']))
        result = cur.fetchone()[0]
        
        if result.startswith('ERROR'):
            conn.rollback()
            return jsonify({'error': result}), 400
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': result, 'status': 'success'})
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# REPORTS
# ============================================================
@app.route('/api/reports/idle', methods=['GET'])
def get_idle_licenses():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM idle_license_view ORDER BY days_idle DESC")
        idle_licenses = []
        for row in cur.fetchall():
            idle_licenses.append({
                'alloc_id': safe_int(row.get('alloc_id')),
                'emp_id': safe_int(row.get('emp_id')),
                'emp_name': row.get('emp_name', ''),
                'email': row.get('email', ''),
                'dept_name': row.get('dept_name', ''),
                'plan_name': row.get('plan_name', ''),
                'vendor_name': row.get('vendor_name', ''),
                'monthly_cost': safe_float(row.get('monthly_cost')),
                'assigned_date': row.get('assigned_date').isoformat() if row.get('assigned_date') else None,
                'last_used_date': row.get('last_used_date').isoformat() if row.get('last_used_date') else None,
                'days_idle': safe_int(row.get('days_idle'))
            })
        cur.close()
        conn.close()
        return jsonify(idle_licenses)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/reports/dept-spend', methods=['GET'])
def get_department_spend():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM dept_spend_view ORDER BY current_spend DESC")
        dept_spend = []
        for row in cur.fetchall():
            dept_spend.append({
                'dept_id': safe_int(row.get('dept_id')),
                'dept_name': row.get('dept_name', ''),
                'location': row.get('location', ''),
                'budget': safe_float(row.get('budget')),
                'current_spend': safe_float(row.get('current_spend')),
                'spend_pct': safe_float(row.get('spend_pct')),
                'remaining_budget': safe_float(row.get('remaining_budget')),
                'employee_count': safe_int(row.get('employee_count')),
                'subscription_count': safe_int(row.get('subscription_count'))
            })
        cur.close()
        conn.close()
        return jsonify(dept_spend)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/reports/vendor-spend', methods=['GET'])
def get_vendor_costs():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM vendor_cost_view ORDER BY total_annual_cost DESC")
        vendor_costs = []
        for row in cur.fetchall():
            vendor_costs.append({
                'vendor_id': safe_int(row.get('vendor_id')),
                'vendor_name': row.get('vendor_name', ''),
                'website': row.get('website', ''),
                'contact_email': row.get('contact_email', ''),
                'total_plans': safe_int(row.get('total_plans')),
                'active_subscriptions': safe_int(row.get('active_subscriptions')),
                'total_annual_cost': safe_float(row.get('total_annual_cost')),
                'total_seats_purchased': safe_int(row.get('total_seats_purchased')),
                'active_licenses': safe_int(row.get('active_licenses'))
            })
        cur.close()
        conn.close()
        return jsonify(vendor_costs)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/reports/utilization', methods=['GET'])
def get_utilization():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM subscription_utilization_view ORDER BY utilization_pct ASC")
        utilization = []
        for row in cur.fetchall():
            utilization.append({
                'sub_id': safe_int(row.get('sub_id')),
                'dept_name': row.get('dept_name', ''),
                'plan_name': row.get('plan_name', ''),
                'vendor_name': row.get('vendor_name', ''),
                'category': row.get('category', ''),
                'seats_purchased': safe_int(row.get('seats_purchased')),
                'seats_used': safe_int(row.get('seats_used')),
                'seats_available': safe_int(row.get('seats_available')),
                'utilization_pct': safe_float(row.get('utilization_pct')),
                'total_cost': safe_float(row.get('total_cost')),
                'utilized_cost': safe_float(row.get('utilized_cost')),
                'annual_cost': safe_float(row.get('total_cost')),  # alias: seats_purchased * price_per_seat
                'start_date': row.get('start_date').isoformat() if row.get('start_date') else None,
                'end_date': row.get('end_date').isoformat() if row.get('end_date') else None,
                'subscription_status': row.get('subscription_status', '')
            })
        cur.close()
        conn.close()
        return jsonify(utilization)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

# ============================================================
# AUDIT LOG
# ============================================================
@app.route('/api/audit', methods=['GET'])
def get_audit_log():
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM audit_log
            ORDER BY action_date DESC
            LIMIT 100
        """)
        
        logs = []
        for row in cur.fetchall():
            logs.append({
                'log_id': safe_int(row.get('log_id')),
                'action_type': row.get('action_type', ''),
                'table_name': row.get('table_name', ''),
                'ref_id': safe_int(row.get('ref_id')),
                'action_date': row.get('action_date').isoformat() if row.get('action_date') else None,
                'changed_by': row.get('changed_by', ''),
                'description': row.get('description', ''),
                'old_value': row.get('old_value', ''),
                'new_value': row.get('new_value', '')
            })
        cur.close()
        conn.close()
        return jsonify(logs)
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/counts', methods=['GET'])
def get_counts():
    """Returns summary counts for Employees, Subscriptions, and License Allocations pages."""
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("SELECT COUNT(*) AS total FROM employees")
        total_employees = safe_int(cur.fetchone()['total'])

        cur.execute("SELECT COUNT(*) AS total FROM employees WHERE status = 'ACTIVE'")
        active_employees = safe_int(cur.fetchone()['total'])

        cur.execute("SELECT COUNT(*) AS total FROM subscriptions WHERE subscription_status = 'ACTIVE'")
        total_subscriptions = safe_int(cur.fetchone()['total'])

        cur.execute("SELECT COUNT(*) AS total FROM license_allocations")
        total_licenses = safe_int(cur.fetchone()['total'])

        cur.execute("SELECT COUNT(*) AS total FROM license_allocations WHERE alloc_status = 'ACTIVE'")
        active_licenses = safe_int(cur.fetchone()['total'])

        cur.close()
        conn.close()
        return jsonify({
            'total_employees': total_employees,
            'active_employees': active_employees,
            'total_subscriptions': total_subscriptions,
            'total_licenses': total_licenses,
            'active_licenses': active_licenses
        })
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()


@app.route('/api/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(debug=True, port=5000)
