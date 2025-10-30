# app.py
from flask import Flask, request, jsonify, session
from werkzeug.security import generate_password_hash, check_password_hash
import mysql.connector
from mysql.connector import errorcode

from flask_cors import CORS
from flask import Flask, request, jsonify, session





# =========================
# Configuration
# =========================
class Config:
    SECRET_KEY = 'supersecretkey'
    DB_HOST = 'localhost'
    DB_USER = 'root'
    DB_PASSWORD = 'Siddhant@12'
    DB_NAME = 'faculty_feedback'

# =========================
# App Initialization
# =========================
app = Flask(__name__)
app.config.from_object(Config)
app.secret_key = Config.SECRET_KEY
CORS(app, supports_credentials=True)
 
# =========================
# Database Utilities
# =========================
def get_db_connection():
    try:
        conn = mysql.connector.connect(
            host=Config.DB_HOST,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD,
            database=Config.DB_NAME
        )
        return conn
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print("DB user/password error")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            print("Database does not exist")
        else:
            print(err)
        return None

def call_stored_procedure(proc_name, params):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    result = None
    try:
        cursor.callproc(proc_name, params)
        conn.commit()
        for res in cursor.stored_results():
            result = res.fetchall()
    finally:
        cursor.close()
        conn.close()
    return result

# =========================
# Student Routes
# =========================

# Registration
@app.route('/student/register', methods=['POST'])
def student_register():
    data = request.json
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')
    roll_number = data.get('roll_number')
    branch_id = data.get('branch_id')
    year_id = data.get('year_id')
    semester_id = data.get('semester_id')

    hashed_password = generate_password_hash(password)
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO students (first_name, email, password_hash, roll_number, branch_id, year_id, semester_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
        """, (name, email, hashed_password, roll_number, branch_id, year_id, semester_id))
        conn.commit()
        return jsonify({"status":"success","message":"Student registered successfully"})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)})
    finally:
        cursor.close()
        conn.close()

# Login
@app.route('/student/login', methods=['POST'])
def student_login():
    data = request.json
    roll_number = data.get('roll_number')
    password = data.get('password')
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM students WHERE roll_number=%s", (roll_number,))
    student = cursor.fetchone()
    cursor.close()
    conn.close()

    if student and check_password_hash(student['password_hash'], password):
        session['student_id'] = student['student_id']
        # The line below is the only change. We add the student's ID to the response.
        return jsonify({"status":"success", "message":"Login successful", "student_id": student['student_id']})
    
    return jsonify({"status":"error", "message":"Invalid credentials"})

# Dashboard
@app.route('/student/dashboard', methods=['GET'])
def student_dashboard():
    student_id = session.get('student_id')
    if not student_id:
        return jsonify({"status":"error","message":"Not logged in"}), 401

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT ta.assignment_id, s.code AS subject_code, s.name AS subject_name, 
               CONCAT(t.first_name,' ',COALESCE(t.last_name,'')) AS teacher_name
        FROM students st
        JOIN teacher_assignments ta 
            ON ta.branch_id=st.branch_id AND ta.year_id=st.year_id AND ta.semester_id=st.semester_id
        JOIN subjects s ON s.subject_id=ta.subject_id
        JOIN teachers t ON t.teacher_id=ta.teacher_id
        WHERE st.student_id=%s
    """, (student_id,))
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(data)

# Submit Feedback
@app.route('/student/feedback/<int:assignment_id>', methods=['POST'])
def student_feedback(assignment_id):
    student_id = session.get('student_id')
    if not student_id:
        return jsonify({"status":"error","message":"Not logged in"}), 401

    data = request.json
    rating_knowledge = data.get('rating_knowledge')
    rating_communication = data.get('rating_communication')
    rating_punctuality = data.get('rating_punctuality')
    rating_overall = data.get('rating_overall')
    comment = data.get('comment')

    try:
        call_stored_procedure('submit_feedback', (
            student_id, assignment_id, rating_knowledge, rating_communication,
            rating_punctuality, rating_overall, comment
        ))
        return jsonify({"status":"success","message":"Feedback submitted successfully"})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)})

# =========================
# Admin Routes
# =========================

# Login

@app.route('/')
def home():
    return "Faculty Feedback System Backend is running!"
 
@app.route('/admin/login', methods=['POST'])
def admin_login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM admins WHERE username=%s", (username,))
    admin = cursor.fetchone()
    cursor.close()
    conn.close()

    if admin and check_password_hash(admin['password_hash'], password):
        session['admin_id'] = admin['admin_id']
        return jsonify({"status":"success","message":"Login successful"})
    return jsonify({"status":"error","message":"Invalid credentials"})

# Dashboard: Teachers list
@app.route('/admin/dashboard', methods=['GET'])
def admin_dashboard():
    branch_id = request.args.get('branch_id')
    year_id = request.args.get('year_id')
    semester_id = request.args.get('semester_id')

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT t.teacher_id, CONCAT(t.first_name,' ',COALESCE(t.last_name,'')) AS teacher_name,
               s.subject_id, s.name AS subject_name, ts.avg_overall_rating, ts.total_feedbacks
        FROM teacher_assignments ta
        JOIN teachers t ON t.teacher_id = ta.teacher_id
        JOIN subjects s ON s.subject_id = ta.subject_id
        LEFT JOIN teacher_stats ts ON ts.teacher_id = t.teacher_id
        WHERE ta.branch_id=%s AND ta.year_id=%s AND ta.semester_id=%s
    """, (branch_id, year_id, semester_id))
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(data)

# Teacher Feedback Summary
@app.route('/admin/teacher/<int:teacher_id>/summary', methods=['GET'])
def admin_teacher_summary(teacher_id):
    branch_id = request.args.get('branch_id')
    year_id = request.args.get('year_id')
    semester_id = request.args.get('semester_id')
    summary = call_stored_procedure('generate_teacher_summary', (
        teacher_id,
        branch_id if branch_id else None,
        year_id if year_id else None,
        semester_id if semester_id else None
    ))
    return jsonify(summary)


# =========================
# API Routes for Dropdown Data
# =========================

@app.route('/api/dropdowns', methods=['GET'])
def get_dropdown_data():
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500
        
    cursor = conn.cursor(dictionary=True)
    
    # Aliasing columns (e.g., branch_id AS id) to match what the JavaScript expects
    cursor.execute("SELECT branch_id AS id, name FROM branches ORDER BY name")
    branches = cursor.fetchall()
    
    cursor.execute("SELECT year_id AS id, year_label AS label FROM academic_years ORDER BY year_id")
    years = cursor.fetchall()
    
    cursor.execute("SELECT semester_id AS id, semester_label AS label FROM semesters ORDER BY ordinal")
    semesters = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return jsonify({
        "branches": branches,
        "years": years,
        "semesters": semesters
    })


# =========================
# Run the App
# =========================
if __name__ == "__main__":
    app.run(debug=True)
