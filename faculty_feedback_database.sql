-- Faculty Feedback System
-- Complete MySQL database script: DDL, DML (sample data), DCL, triggers, stored procedures, example queries
-- Normalized to 3NF. Designed for integration with Flask/Django.

/*
Structure summary (tables):
- branches
- academic_years
- semesters
- subjects
- teachers
- students
- admins
- teacher_assignments   -- which teacher teaches which subject to which branch/year/semester
- feedbacks             -- ratings and optional comments submitted by students
- teacher_stats         -- cached aggregate values for quick admin queries (avg_rating, total_feedbacks)

Advanced features included:
- triggers to keep teacher_stats updated
- stored procedures for submitting feedback and generating summary reports
- example window-function queries to rank teachers
- DCL commands to create a DB user and grant privileges

Notes:
- Ratings are constrained 1..5 (integers). You can add more rating aspects if required.
- Unique constraints prevent duplicate feedback submissions for same student-assignment.
*/

-- 1) Create database
CREATE DATABASE IF NOT EXISTS faculty_feedback CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE faculty_feedback;

-- 2) Lookup tables
CREATE TABLE branches (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE academic_years (
    year_id INT AUTO_INCREMENT PRIMARY KEY,
    year_label VARCHAR(20) NOT NULL UNIQUE, -- e.g. '1', '2', '3', '4' or 'First Year'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE semesters (
    semester_id INT AUTO_INCREMENT PRIMARY KEY,
    semester_label VARCHAR(20) NOT NULL UNIQUE, -- e.g. 'Sem 1', 'Sem 2'
    ordinal TINYINT NOT NULL, -- numeric ordering
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE subjects (
    subject_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(150) NOT NULL,
    credits TINYINT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(code)
) ENGINE=InnoDB;

-- 3) People: teachers, students, admins
CREATE TABLE teachers (
    teacher_id INT AUTO_INCREMENT PRIMARY KEY,
    staff_number VARCHAR(30) NOT NULL UNIQUE,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) DEFAULT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(30) DEFAULT NULL,
    department VARCHAR(100) DEFAULT NULL,
    hire_date DATE DEFAULT NULL,
    -- Cached aggregates updated by trigger
    avg_rating DECIMAL(3,2) DEFAULT 0.00,
    total_feedbacks INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    roll_number VARCHAR(50) NOT NULL UNIQUE,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) DEFAULT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(30) DEFAULT NULL,
    password_hash VARCHAR(255) NOT NULL, -- application handles hashing
    branch_id INT NOT NULL,
    year_id INT NOT NULL,
    semester_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (year_id) REFERENCES academic_years(year_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (semester_id) REFERENCES semesters(semester_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE admins (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) DEFAULT NULL,
    email VARCHAR(150) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4) Assignment: which teacher teaches which subject to which branch/year/semester
-- This links subject + teacher + branch + year + semester. Normalized and flexible (multiple teachers per subject allowed)
CREATE TABLE teacher_assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    teacher_id INT NOT NULL,
    subject_id INT NOT NULL,
    branch_id INT NOT NULL,
    year_id INT NOT NULL,
    semester_id INT NOT NULL,
    academic_session VARCHAR(20) DEFAULT NULL, -- e.g., '2024-25'
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (teacher_id, subject_id, branch_id, year_id, semester_id, academic_session),
    FOREIGN KEY (teacher_id) REFERENCES teachers(teacher_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (year_id) REFERENCES academic_years(year_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (semester_id) REFERENCES semesters(semester_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5) Feedback table
-- Store ratings (1-5) and optional comments. Add a uniqueness rule to prevent duplicate feedback per student+assignment
CREATE TABLE feedbacks (
    feedback_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    -- Rating aspects: knowledge, communication, punctuality, overall
    rating_knowledge TINYINT NOT NULL CHECK (rating_knowledge BETWEEN 1 AND 5),
    rating_communication TINYINT NOT NULL CHECK (rating_communication BETWEEN 1 AND 5),
    rating_punctuality TINYINT NOT NULL CHECK (rating_punctuality BETWEEN 1 AND 5),
    rating_overall TINYINT NOT NULL CHECK (rating_overall BETWEEN 1 AND 5),
    comment TEXT DEFAULT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent VARCHAR(255) DEFAULT NULL,
    UNIQUE (assignment_id, student_id),
    FOREIGN KEY (assignment_id) REFERENCES teacher_assignments(assignment_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 6) Teacher stats: cached values to speed up admin analytics (kept in sync with triggers)
CREATE TABLE teacher_stats (
    teacher_id INT PRIMARY KEY,
    avg_overall_rating DECIMAL(3,2) DEFAULT 0.00,
    avg_knowledge DECIMAL(3,2) DEFAULT 0.00,
    avg_communication DECIMAL(3,2) DEFAULT 0.00,
    avg_punctuality DECIMAL(3,2) DEFAULT 0.00,
    total_feedbacks INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (teacher_id) REFERENCES teachers(teacher_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Initialize teacher_stats for existing teachers (will be filled by trigger or manual script)

-- =========================
-- Sample data (DML):
-- =========================

-- branches
INSERT INTO branches (code, name) VALUES
('CSE','Computer Science & Engineering'),
('ECE','Electronics & Communication'),
('ME','Mechanical Engineering');

-- academic_years
INSERT INTO academic_years (year_label) VALUES ('1'), ('2'), ('3'), ('4');

-- semesters
INSERT INTO semesters (semester_label, ordinal) VALUES
('Sem 1',1),('Sem 2',2),('Sem 3',3),('Sem 4',4),('Sem 5',5),('Sem 6',6),('Sem 7',7),('Sem 8',8);

-- subjects
INSERT INTO subjects (code, name, credits) VALUES
('CS101','Data Structures',4),
('CS102','Discrete Mathematics',3),
('CS201','Operating Systems',4),
('EC101','Signals and Systems',4),
('ME101','Engineering Mechanics',3);

-- teachers
INSERT INTO teachers (staff_number, first_name, last_name, email, department, hire_date) VALUES
('T1001','Amit','Sharma','amit.sharma@example.edu','CSE','2015-07-10'),
('T1002','Rita','Patel','rita.patel@example.edu','CSE','2018-02-15'),
('T1003','Suresh','Kumar','suresh.kumar@example.edu','ECE','2012-09-01');

-- students (password_hash placeholders; in production use bcrypt/argon2 hashed values)
INSERT INTO students (roll_number, first_name, last_name, email, password_hash, branch_id, year_id, semester_id) VALUES
('CSE1/001','Anika','Verma','anika.verma@student.edu','$2y$12$examplehash1',1,1,1),
('CSE1/002','Rahul','Desai','rahul.desai@student.edu','$2y$12$examplehash2',1,1,1),
('CSE3/012','Meera','Iyer','meera.iyer@student.edu','$2y$12$examplehash3',1,3,5);

-- admins
INSERT INTO admins (username, password_hash, full_name, email) VALUES
('admin1','$2y$12$adminhash','Principal Office','principal@example.edu');

-- teacher_assignments
INSERT INTO teacher_assignments (teacher_id, subject_id, branch_id, year_id, semester_id, academic_session, is_active) VALUES
(1,1,1,1,1,'2025-26',1), -- Amit teaches Data Structures to CSE 1 Sem1
(2,2,1,1,1,'2025-26',1), -- Rita teaches Discrete Math
(1,3,1,3,5,'2025-26',1), -- Amit teaches OS to CSE 3 Sem5
(3,4,2,1,1,'2025-26',1); -- Suresh teaches Signals to ECE 1 Sem1

-- Feedback sample (some entries)
INSERT INTO feedbacks (assignment_id, student_id, rating_knowledge, rating_communication, rating_punctuality, rating_overall, comment) VALUES
(1,1,5,5,5,5,'Excellent teaching.'),
(1,2,4,4,5,4,'Good but can use more examples.'),
(3,3,5,4,4,5,'Clear explanations.');

-- Initialize teacher_stats based on current feedbacks
INSERT INTO teacher_stats (teacher_id, avg_overall_rating, avg_knowledge, avg_communication, avg_punctuality, total_feedbacks)
SELECT t.teacher_id,
       COALESCE(ROUND(AVG(f.rating_overall),2),0.00) as avg_overall,
       COALESCE(ROUND(AVG(f.rating_knowledge),2),0.00) as avg_knowledge,
       COALESCE(ROUND(AVG(f.rating_communication),2),0.00) as avg_communication,
       COALESCE(ROUND(AVG(f.rating_punctuality),2),0.00) as avg_punctuality,
       COUNT(f.feedback_id) as total_feedbacks
FROM teachers t
LEFT JOIN teacher_assignments ta ON ta.teacher_id = t.teacher_id
LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
GROUP BY t.teacher_id;

-- =========================
-- DCL: create DB user and grant privileges
-- (Run as root/admin on MySQL server)
-- CREATE USER 'ff_user'@'localhost' IDENTIFIED BY 'strong_password_here';
-- GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE ON faculty_feedback.* TO 'ff_user'@'localhost';
-- FLUSH PRIVILEGES;

-- =========================
-- Triggers: keep teacher_stats up-to-date
-- Trigger after INSERT on feedbacks: recalc aggregates for the teacher
DELIMITER $$
CREATE TRIGGER trg_after_feedback_insert
AFTER INSERT ON feedbacks
FOR EACH ROW
BEGIN
    DECLARE t_id INT;
    -- find teacher_id for this assignment
    SELECT teacher_id INTO t_id FROM teacher_assignments WHERE assignment_id = NEW.assignment_id;

    IF t_id IS NOT NULL THEN
        -- Recompute aggregates and upsert into teacher_stats
        INSERT INTO teacher_stats (teacher_id, avg_overall_rating, avg_knowledge, avg_communication, avg_punctuality, total_feedbacks)
        SELECT t.teacher_id,
               COALESCE(ROUND(AVG(f.rating_overall),2),0.00),
               COALESCE(ROUND(AVG(f.rating_knowledge),2),0.00),
               COALESCE(ROUND(AVG(f.rating_communication),2),0.00),
               COALESCE(ROUND(AVG(f.rating_punctuality),2),0.00),
               COUNT(f.feedback_id)
        FROM teachers t
        JOIN teacher_assignments ta ON ta.teacher_id = t.teacher_id
        LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
        WHERE t.teacher_id = t_id
        GROUP BY t.teacher_id
        ON DUPLICATE KEY UPDATE
            avg_overall_rating = VALUES(avg_overall_rating),
            avg_knowledge = VALUES(avg_knowledge),
            avg_communication = VALUES(avg_communication),
            avg_punctuality = VALUES(avg_punctuality),
            total_feedbacks = VALUES(total_feedbacks),
            last_updated = CURRENT_TIMESTAMP;

        -- Also update teachers table cached fields (optional)
        UPDATE teachers tr
        JOIN teacher_stats ts ON ts.teacher_id = tr.teacher_id
        SET tr.avg_rating = ts.avg_overall_rating, tr.total_feedbacks = ts.total_feedbacks
        WHERE tr.teacher_id = t_id;
    END IF;
END$$

-- Trigger after DELETE on feedbacks: update stats
CREATE TRIGGER trg_after_feedback_delete
AFTER DELETE ON feedbacks
FOR EACH ROW
BEGIN
    DECLARE t_id INT;
    SELECT teacher_id INTO t_id FROM teacher_assignments WHERE assignment_id = OLD.assignment_id;
    IF t_id IS NOT NULL THEN
        INSERT INTO teacher_stats (teacher_id, avg_overall_rating, avg_knowledge, avg_communication, avg_punctuality, total_feedbacks)
        SELECT t.teacher_id,
               COALESCE(ROUND(AVG(f.rating_overall),2),0.00),
               COALESCE(ROUND(AVG(f.rating_knowledge),2),0.00),
               COALESCE(ROUND(AVG(f.rating_communication),2),0.00),
               COALESCE(ROUND(AVG(f.rating_punctuality),2),0.00),
               COUNT(f.feedback_id)
        FROM teachers t
        JOIN teacher_assignments ta ON ta.teacher_id = t.teacher_id
        LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
        WHERE t.teacher_id = t_id
        GROUP BY t.teacher_id
        ON DUPLICATE KEY UPDATE
            avg_overall_rating = VALUES(avg_overall_rating),
            avg_knowledge = VALUES(avg_knowledge),
            avg_communication = VALUES(avg_communication),
            avg_punctuality = VALUES(avg_punctuality),
            total_feedbacks = VALUES(total_feedbacks),
            last_updated = CURRENT_TIMESTAMP;

        UPDATE teachers tr
        JOIN teacher_stats ts ON ts.teacher_id = tr.teacher_id
        SET tr.avg_rating = ts.avg_overall_rating, tr.total_feedbacks = ts.total_feedbacks
        WHERE tr.teacher_id = t_id;
    END IF;
END$$

-- Trigger after UPDATE on feedbacks: update stats (if ratings changed)
CREATE TRIGGER trg_after_feedback_update
AFTER UPDATE ON feedbacks
FOR EACH ROW
BEGIN
    DECLARE t_id INT;
    SELECT teacher_id INTO t_id FROM teacher_assignments WHERE assignment_id = NEW.assignment_id;
    IF t_id IS NOT NULL THEN
        INSERT INTO teacher_stats (teacher_id, avg_overall_rating, avg_knowledge, avg_communication, avg_punctuality, total_feedbacks)
        SELECT t.teacher_id,
               COALESCE(ROUND(AVG(f.rating_overall),2),0.00),
               COALESCE(ROUND(AVG(f.rating_knowledge),2),0.00),
               COALESCE(ROUND(AVG(f.rating_communication),2),0.00),
               COALESCE(ROUND(AVG(f.rating_punctuality),2),0.00),
               COUNT(f.feedback_id)
        FROM teachers t
        JOIN teacher_assignments ta ON ta.teacher_id = t.teacher_id
        LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
        WHERE t.teacher_id = t_id
        GROUP BY t.teacher_id
        ON DUPLICATE KEY UPDATE
            avg_overall_rating = VALUES(avg_overall_rating),
            avg_knowledge = VALUES(avg_knowledge),
            avg_communication = VALUES(avg_communication),
            avg_punctuality = VALUES(avg_punctuality),
            total_feedbacks = VALUES(total_feedbacks),
            last_updated = CURRENT_TIMESTAMP;

        UPDATE teachers tr
        JOIN teacher_stats ts ON ts.teacher_id = tr.teacher_id
        SET tr.avg_rating = ts.avg_overall_rating, tr.total_feedbacks = ts.total_feedbacks
        WHERE tr.teacher_id = t_id;
    END IF;
END$$
DELIMITER ;

-- =========================
-- Stored Procedures
-- 1) submit_feedback: inserts feedback after checking duplicates and returns a status
DELIMITER $$
CREATE PROCEDURE submit_feedback(
    IN p_student_id INT,
    IN p_assignment_id INT,
    IN p_rating_knowledge TINYINT,
    IN p_rating_communication TINYINT,
    IN p_rating_punctuality TINYINT,
    IN p_rating_overall TINYINT,
    IN p_comment TEXT
)
BEGIN
    DECLARE existing_count INT DEFAULT 0;
    SELECT COUNT(1) INTO existing_count FROM feedbacks
    WHERE student_id = p_student_id AND assignment_id = p_assignment_id;

    IF existing_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Feedback already submitted by this student for this assignment.';
    ELSE
        INSERT INTO feedbacks (assignment_id, student_id, rating_knowledge, rating_communication, rating_punctuality, rating_overall, comment)
        VALUES (p_assignment_id, p_student_id, p_rating_knowledge, p_rating_communication, p_rating_punctuality, p_rating_overall, p_comment);
    END IF;
END$$
DELIMITER ;

-- 2) generate_teacher_summary: returns summary (avg ratings, counts) for a given teacher across the DB or filtered by branch/year/semester
-- Usage: CALL generate_teacher_summary(teacher_id, branch_id or NULL, year_id or NULL, semester_id or NULL);
DELIMITER $$
CREATE PROCEDURE generate_teacher_summary(
    IN p_teacher_id INT,
    IN p_branch_id INT,
    IN p_year_id INT,
    IN p_semester_id INT
)
BEGIN
    SELECT t.teacher_id, t.first_name, t.last_name,
           COUNT(f.feedback_id) AS total_feedbacks,
           ROUND(AVG(f.rating_overall),2) AS avg_overall,
           ROUND(AVG(f.rating_knowledge),2) AS avg_knowledge,
           ROUND(AVG(f.rating_communication),2) AS avg_communication,
           ROUND(AVG(f.rating_punctuality),2) AS avg_punctuality
    FROM teachers t
    JOIN teacher_assignments ta ON ta.teacher_id = t.teacher_id
    LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
    WHERE t.teacher_id = p_teacher_id
      AND (p_branch_id IS NULL OR ta.branch_id = p_branch_id)
      AND (p_year_id IS NULL OR ta.year_id = p_year_id)
      AND (p_semester_id IS NULL OR ta.semester_id = p_semester_id)
    GROUP BY t.teacher_id;
END$$
DELIMITER ;

-- =========================
-- DQL Examples (queries)
-- 1) Students: list teachers teaching to a student's branch/year/semester, along with subject
-- Replace :student_id with actual id
-- Example (student with ID 1):
SELECT ta.assignment_id, s.code AS subject_code, s.name AS subject_name, t.teacher_id, CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS teacher_name, ta.academic_session
FROM students st
JOIN teacher_assignments ta ON ta.branch_id = st.branch_id AND ta.year_id = st.year_id AND ta.semester_id = st.semester_id
JOIN subjects s ON s.subject_id = ta.subject_id
JOIN teachers t ON t.teacher_id = ta.teacher_id
WHERE st.student_id = 1 AND st.student_id IS NOT NULL;

-- 2) Admin: select branch->year->semester and list teachers & their aggregated ratings for that selection
-- Example: branch_id=1, year_id=1, semester_id=1
SELECT t.teacher_id, CONCAT(t.first_name,' ',COALESCE(t.last_name,'')) AS teacher_name,
       s.subject_id, s.code, s.name AS subject_name,
       ts.avg_overall_rating, ts.total_feedbacks
FROM teacher_assignments ta
JOIN teachers t ON t.teacher_id = ta.teacher_id
JOIN subjects s ON s.subject_id = ta.subject_id
LEFT JOIN teacher_stats ts ON ts.teacher_id = t.teacher_id
WHERE ta.branch_id = 1 AND ta.year_id = 1 AND ta.semester_id = 1
ORDER BY ts.avg_overall_rating DESC;

-- 3) Admin analytics: top 10 teachers overall by avg rating
SELECT t.teacher_id, CONCAT(t.first_name,' ',COALESCE(t.last_name,'')) AS teacher_name, ts.avg_overall_rating, ts.total_feedbacks
FROM teacher_stats ts
JOIN teachers t ON t.teacher_id = ts.teacher_id
WHERE ts.total_feedbacks > 0
ORDER BY ts.avg_overall_rating DESC, ts.total_feedbacks DESC
LIMIT 10;

-- 4) Window function: ranking teachers by average rating per branch/year/semester
-- This query computes avg per teacher per selection and provides rank using window function
SELECT
    branch_id, year_id, semester_id, teacher_id, teacher_name, avg_overall,
    RANK() OVER (PARTITION BY branch_id, year_id, semester_id ORDER BY avg_overall DESC) AS rank_in_group
FROM (
    SELECT ta.branch_id, ta.year_id, ta.semester_id, t.teacher_id, CONCAT(t.first_name,' ',COALESCE(t.last_name,'')) AS teacher_name,
           ROUND(AVG(f.rating_overall),2) AS avg_overall
    FROM teacher_assignments ta
    JOIN teachers t ON t.teacher_id = ta.teacher_id
    LEFT JOIN feedbacks f ON f.assignment_id = ta.assignment_id
    GROUP BY ta.branch_id, ta.year_id, ta.semester_id, t.teacher_id
) sub
ORDER BY branch_id, year_id, semester_id, avg_overall DESC;

-- 5) Example: Student submitting feedback via stored procedure
-- CALL submit_feedback(1, 1, 5, 5, 5, 5, 'Great class');

-- 6) Admin: summary report for a teacher
-- CALL generate_teacher_summary(1, NULL, NULL, NULL);

-- =========================
-- Explanations (brief):
-- Why each table exists and columns chosen:
-- branches: stores academic branches (CSE, ECE...). Used for grouping students and assignments.
-- academic_years: stores year groups (1..4). Keeps year as normalized table.
-- semesters: stores semester meta-data, allows mapping assignments and students to a semester.
-- subjects: canonical list of subjects (code, name, credits). Reused across branches/years if needed.
-- teachers: teacher master record, includes cached avg_rating & total_feedbacks for quick display.
-- students: student accounts. Stores branch/year/semester to determine which assignments they see.
-- admins: admin accounts for system management.
-- teacher_assignments: bridge table mapping teacher->subject->branch->year->semester (+ session). This allows many-to-many relationships and multiple teachers per subject.
-- feedbacks: stores each student's feedback for a particular teacher assignment (ratings + optional comment). Unique constraint prevents duplicates.
-- teacher_stats: separate aggregated table to store computed averages and counts. Updated by triggers for fast analytics.

-- How relationships are defined:
-- students -> branches,academic_years,semesters by foreign keys.
-- teacher_assignments references teachers, subjects, branches, academic_years, semesters.
-- feedbacks references teacher_assignments and students.
-- teacher_stats references teachers.

-- How triggers/stored procedures and window functions work:
-- Triggers: After insert/update/delete on feedbacks, triggers recompute aggregates for the concerned teacher by aggregating feedbacks across all assignments belonging to that teacher and upsert into teacher_stats. This keeps cached values fresh for admin dashboards.
-- Stored Procedure submit_feedback: centralizes logic for adding feedback; checks for duplicate submissions and inserts new feedback. In production you may extend it to verify that the student is actually enrolled in that assignment before allowing insert.
-- Stored Procedure generate_teacher_summary: produces consolidated stats for a teacher, optionally filtered by branch/year/semester.
-- Window Function example: uses RANK() OVER (PARTITION BY ...) to compute rankings of teachers within each branch/year/semester grouping based on average overall ratings.

-- Notes for integration:
-- Passwords should be stored hashed in the application layer (bcrypt/argon2). The DB stores the hash only.
-- Use parameterized queries from your Python backend to avoid SQL injection. CALL stored procedures using prepared statements.
-- For additional scalability, move heavy analytics to periodic batch jobs or materialized tables and keep triggers to cheap updates only.

-- End of script

