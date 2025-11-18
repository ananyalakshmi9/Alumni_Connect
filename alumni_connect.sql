-- =====================================================================
-- SQL Schema and Data for the Alumni Connect Database
-- Team Members:
-- 1) Ananya Lakshmi (PES2UG23CS062)
-- 2) Ananya A C (PES2UG23CS061)
-- =====================================================================


-- Step 1: Create and select the database
CREATE DATABASE IF NOT EXISTS alumni_connect;
USE alumni_connect;

-- Step 2: Drop existing tables in reverse order of dependency
DROP TABLE IF EXISTS tblMessages;
DROP TABLE IF EXISTS tblUser_Login;
DROP TABLE IF EXISTS tblStudent_Event_Registration;
DROP TABLE IF EXISTS tblAlumni_Event_Registration;
DROP TABLE IF EXISTS tblMentorship;
DROP TABLE IF EXISTS tblJob_Posting;
DROP TABLE IF EXISTS tblEvent;
DROP TABLE IF EXISTS tblStudent;
DROP TABLE IF EXISTS tblAlumni;
DROP TABLE IF EXISTS tblDepartment;

DROP PROCEDURE IF EXISTS sp_RegisterStudent;
DROP PROCEDURE IF EXISTS sp_SendMessage;
DROP FUNCTION IF EXISTS fn_GetEventRegistrationCount;
DROP FUNCTION IF EXISTS fn_GetAlumniFullName;
DROP FUNCTION IF EXISTS fn_CheckDepartmentMatch;
DROP FUNCTION IF EXISTS fn_GetAlumniEngagementScore;


-- Step 3: Create the tables with all constraints

-- Table: tblDepartment
CREATE TABLE tblDepartment (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(255) NOT NULL UNIQUE
);

-- Table: tblAlumni
CREATE TABLE tblAlumni (
    alumni_id VARCHAR(20) PRIMARY KEY,
    Fname VARCHAR(100) NOT NULL,
    Lname VARCHAR(100) NOT NULL,
    grad_year YEAR NOT NULL CHECK (grad_year < 2025),
    phone_number VARCHAR(15),
    email VARCHAR(255) NOT NULL UNIQUE,
    job_title VARCHAR(100),
    current_company VARCHAR(100),
    dept_id INT,
    CONSTRAINT fk_alumni_department
        FOREIGN KEY (dept_id) REFERENCES tblDepartment(dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- Table: tblStudent
CREATE TABLE tblStudent (
    student_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    enroll_year YEAR NOT NULL CHECK (enroll_year > 2020),
    email VARCHAR(255) NOT NULL UNIQUE,
    phone_number VARCHAR(15),
    dept_id INT,
    CONSTRAINT fk_student_department
        FOREIGN KEY (dept_id) REFERENCES tblDepartment(dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- Table: tblUser_Login
CREATE TABLE tblUser_Login (
    login_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_type ENUM('student', 'alumni') NOT NULL,
    student_id VARCHAR(20) UNIQUE,
    alumni_id VARCHAR(20) UNIQUE,
    last_login TIMESTAMP NULL,
    CONSTRAINT fk_login_student FOREIGN KEY (student_id) REFERENCES tblStudent(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_login_alumni FOREIGN KEY (alumni_id) REFERENCES tblAlumni(alumni_id) ON DELETE CASCADE,
    CONSTRAINT chk_user_link CHECK (
        (student_id IS NOT NULL AND alumni_id IS NULL AND user_type = 'student') OR
        (alumni_id IS NOT NULL AND student_id IS NULL AND user_type = 'alumni')
    )
);

-- Table: tblEvent
CREATE TABLE tblEvent (
    event_id INT PRIMARY KEY AUTO_INCREMENT,
    event_name VARCHAR(255) NOT NULL,
    event_date DATETIME NOT NULL,
    location VARCHAR(255) NOT NULL,
    description TEXT,
    organizer_alumni_id VARCHAR(20),
    CONSTRAINT fk_event_organizer
        FOREIGN KEY (organizer_alumni_id) REFERENCES tblAlumni(alumni_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- Table: tblJob_Posting
CREATE TABLE tblJob_Posting (
    job_id INT PRIMARY KEY AUTO_INCREMENT,
    job_title VARCHAR(255) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    description TEXT,
    post_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    posted_by_alumni_id VARCHAR(20) NOT NULL,
    CONSTRAINT fk_job_alumni
        FOREIGN KEY (posted_by_alumni_id) REFERENCES tblAlumni(alumni_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: tblMentorship
CREATE TABLE tblMentorship (
    mentorship_id INT PRIMARY KEY AUTO_INCREMENT,
    start_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),
    mentor_alumni_id VARCHAR(20) NOT NULL,
    mentee_student_id VARCHAR(20) NOT NULL,
    CONSTRAINT fk_mentor_alumni
        FOREIGN KEY (mentor_alumni_id) REFERENCES tblAlumni(alumni_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_mentee_student
        FOREIGN KEY (mentee_student_id) REFERENCES tblStudent(student_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    UNIQUE (mentor_alumni_id, mentee_student_id)
);

-- Table: tblAlumni_Event_Registration
CREATE TABLE tblAlumni_Event_Registration (
    registration_id INT PRIMARY KEY AUTO_INCREMENT,
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alumni_id VARCHAR(20) NOT NULL,
    event_id INT NOT NULL,
    CONSTRAINT fk_reg_alumni
        FOREIGN KEY (alumni_id) REFERENCES tblAlumni(alumni_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_reg_alumni_event
        FOREIGN KEY (event_id) REFERENCES tblEvent(event_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    UNIQUE (alumni_id, event_id)
);

-- Table: tblStudent_Event_Registration
CREATE TABLE tblStudent_Event_Registration (
    registration_id INT PRIMARY KEY AUTO_INCREMENT,
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    student_id VARCHAR(20) NOT NULL,
    event_id INT NOT NULL,
    CONSTRAINT fk_reg_student
        FOREIGN KEY (student_id) REFERENCES tblStudent(student_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_reg_student_event
        FOREIGN KEY (event_id) REFERENCES tblEvent(event_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    UNIQUE (student_id, event_id)
);

-- Table: tblMessages
CREATE TABLE tblMessages (
    message_id INT PRIMARY KEY AUTO_INCREMENT,
    sender_alumni_id VARCHAR(20),
    sender_student_id VARCHAR(20),
    recipient_alumni_id VARCHAR(20),
    recipient_student_id VARCHAR(20),
    message_content TEXT NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_msg_sender_alumni FOREIGN KEY (sender_alumni_id) REFERENCES tblAlumni(alumni_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_sender_student FOREIGN KEY (sender_student_id) REFERENCES tblStudent(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_recipient_alumni FOREIGN KEY (recipient_alumni_id) REFERENCES tblAlumni(alumni_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_recipient_student FOREIGN KEY (recipient_student_id) REFERENCES tblStudent(student_id) ON DELETE CASCADE,
    CONSTRAINT chk_sender CHECK ((sender_alumni_id IS NOT NULL AND sender_student_id IS NULL) OR (sender_alumni_id IS NULL AND sender_student_id IS NOT NULL)),
    CONSTRAINT chk_recipient CHECK ((recipient_alumni_id IS NOT NULL AND recipient_student_id IS NULL) OR (recipient_alumni_id IS NULL AND recipient_student_id IS NOT NULL))
);

-- Step 4: Insert sample data into the tables
-- Departments
INSERT INTO tblDepartment (dept_id, dept_name) VALUES
(1, 'Computer Science & Engineering'),
(2, 'Electronics & Communication Engineering'),
(3, 'Mechanical Engineering'),
(4, 'Biotechnology'),
(5, 'Civil Engineering');

-- Alumni
INSERT INTO tblAlumni (alumni_id, Fname, Lname, grad_year, phone_number, email, job_title, current_company, dept_id) VALUES
('PES2UG19CS001', 'Rahul', 'Verma', 2023, '9876543210', 'rahul.v@example.com', 'Software Engineer II', 'Google', 1),
('PES2UG18EC002', 'Priya', 'Sharma', 2022, '9876543211', 'priya.s@example.com', 'Hardware Engineer', 'Intel', 2),
('PES2UG19ME003', 'Amit', 'Kumar', 2023, '9876543212', 'amit.k@example.com', 'Mechanical Design Engineer', 'Bosch', 3),
('PES2UG17BT004', 'Sneha', 'Patil', 2021, '9876543213', 'sneha.p@example.com', 'Research Scientist', 'Biocon', 4),
('PES2UG19CS005', 'Rohan', 'Gupta', 2023, '9876543214', 'rohan.g@example.com', 'Data Scientist', 'Amazon', 1);

-- Students
INSERT INTO tblStudent (student_id, name, enroll_year, email, phone_number, dept_id) VALUES
('PES2UG23CS061', 'Ananya A C', 2023, 'ananya.ac@pesu.pes.edu', '8765432109', 1),
('PES2UG23CS062', 'Ananya Lakshmi', 2023, 'ananya.l@pesu.pes.edu', '8765432108', 1),
('PES2UG23EC101', 'Nikhil', 2023, 'nikhil@pesu.pes.edu', '8765432107', 2),
('PES2UG22ME205', 'Megha', 2022, 'megha@pesu.pes.edu', '8765432106', 3),
('PES2UG23BT301', 'Aditya', 2023, 'aditya@pesu.pes.edu', '8765432105', 4);

-- User logins
INSERT INTO tblUser_Login (email, password_hash, user_type, alumni_id, student_id) VALUES
('rahul.v@example.com', 'hashed_password_1', 'alumni', 'PES2UG19CS001', NULL),
('priya.s@example.com', 'hashed_password_2', 'alumni', 'PES2UG18EC002', NULL),
('rohan.g@example.com', 'hashed_password_3', 'alumni', 'PES2UG19CS005', NULL),
('amit.k@example.com', 'hashed_password_4', 'alumni', 'PES2UG19ME003', NULL),
('sneha.p@example.com', 'hashed_password_5', 'alumni', 'PES2UG17BT004', NULL),
('ananya.ac@pesu.pes.edu', 'hashed_password_6', 'student', NULL, 'PES2UG23CS061'),
('ananya.l@pesu.pes.edu', 'hashed_password_7', 'student', NULL, 'PES2UG23CS062'),
('nikhil@pesu.pes.edu', 'hashed_password_8', 'student', NULL, 'PES2UG23EC101'),
('megha@pesu.pes.edu', 'hashed_password_9', 'student', NULL, 'PES2UG22ME205'),
('aditya@pesu.pes.edu', 'hashed_password_10', 'student', NULL, 'PES2UG23BT301');


-- Events
INSERT INTO tblEvent (event_id, event_name, event_date, location, description, organizer_alumni_id) VALUES
(1, 'Annual Alumni Meet 2025', '2025-11-15 18:00:00', 'PES University EC Campus Auditorium', 'A general get-together for all alumni.', 'PES2UG19CS001'),
(2, 'Tech Talk: AI in Modern Systems', '2025-10-20 11:00:00', 'MRD Auditorium, RR Campus', 'A deep dive into AI applications by Rohan Gupta.', 'PES2UG19CS005'),
(3, 'Career Guidance for Mechanical Engineers', '2025-11-05 14:00:00', 'Mechanical Dept. Seminar Hall', 'Session on career paths after graduation.', 'PES2UG19ME003'),
(4, 'Biotech Innovations Symposium', '2025-10-25 09:30:00', 'Biotechnology Department', 'Discussing the latest trends in biotech.', 'PES2UG17BT004'),
(5, 'VLSI Design Workshop', '2025-11-22 10:00:00', 'ECE Department Lab', 'A hands-on workshop on VLSI design.', 'PES2UG18EC002');

-- Job Postings
INSERT INTO tblJob_Posting (job_title, company_name, description, post_date, posted_by_alumni_id) VALUES
('Frontend Developer', 'Google', 'Looking for a skilled React developer with 2+ years of experience.', '2025-09-10', 'PES2UG19CS001'),
('Analog Design Engineer', 'Intel', 'Hiring for our new chip design team in Bengaluru.', '2025-09-08', 'PES2UG18EC002'),
('Product Manager', 'Amazon', 'Seeking a data-driven Product Manager for our AWS team.', '2025-09-11', 'PES2UG19CS005'),
('Quality Assurance Engineer', 'Bosch', 'Automotive quality assurance role for mechanical engineers.', '2025-09-05', 'PES2UG19ME003'),
('Jr. Research Associate', 'Biocon', 'Entry-level position for a motivated biotech graduate.', '2025-09-01', 'PES2UG17BT004');

-- Mentorships
INSERT INTO tblMentorship (start_date, status, mentor_alumni_id, mentee_student_id) VALUES
('2025-08-01', 'active', 'PES2UG19CS001', 'PES2UG23CS061'),
('2022-08-15', 'active', 'PES2UG19CS005', 'PES2UG23CS062'),
('2023-09-01', 'pending', 'PES2UG18EC002', 'PES2UG23EC101'),
('2022-07-20', 'completed', 'PES2UG19ME003', 'PES2UG22ME205'),
('2023-08-25', 'active', 'PES2UG17BT004', 'PES2UG23BT301');

-- Alumni Event Registrations
INSERT INTO tblAlumni_Event_Registration (alumni_id, event_id) VALUES
('PES2UG18EC002', 1),
('PES2UG19ME003', 1),
('PES2UG17BT004', 1),
('PES2UG19CS005', 3);

-- Student Event Registrations
INSERT INTO tblStudent_Event_Registration (student_id, event_id) VALUES
('PES2UG23EC101', 5),
('PES2UG22ME205', 3);

-- Messages
INSERT INTO tblMessages (sender_alumni_id, sender_student_id, recipient_alumni_id, recipient_student_id, message_content, is_read) VALUES
(NULL, 'PES2UG23CS061', 'PES2UG19CS001', NULL, 'Hello Rahul, I had a question about the upcoming mentorship session.', FALSE),
('PES2UG19CS001', NULL, NULL, 'PES2UG23CS061', 'Hi Ananya, sure. We can connect at 5 PM tomorrow to discuss.', TRUE),
(NULL, 'PES2UG23CS062', 'PES2UG19CS005', NULL, 'Hi Rohan, I am really interested in the Data Scientist role you posted. Could you share some tips?', FALSE),
('PES2UG19CS005', NULL, NULL, 'PES2UG23CS062', 'Hey Ananya, glad to hear that. Focus on your SQL and Python skills. We can talk more during our mentorship call.', FALSE),
('PES2UG18EC002', NULL, NULL, 'PES2UG23EC101', 'Hi Nikhil, your mentorship request has been accepted. Lets schedule our first meeting.', TRUE);

-- Set the delimiter for multi-line statements
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_RegisterStudent$$
DROP PROCEDURE IF EXISTS sp_RegisterAlumni$$
DROP PROCEDURE IF EXISTS sp_SendMessage$$
DROP FUNCTION IF EXISTS fn_CheckDepartmentMatch$$
DROP FUNCTION IF EXISTS fn_GetAlumniEngagementScore$$
DROP TRIGGER IF EXISTS trg_update_alumni_login_email$$
DROP TRIGGER IF EXISTS trg_update_student_login_email$$
DROP TRIGGER IF EXISTS trg_ValidateMentorshipDept$$
DROP TRIGGER IF EXISTS trg_PreventLateStudentRegistration$$
DROP TRIGGER IF EXISTS trg_PreventLateAlumniRegistration$$
DROP TRIGGER IF EXISTS trg_PreventSelfMessage$$


-- STEP 5: STORED PROCEDURES

-- Procedure 1: Register a new student
CREATE PROCEDURE sp_RegisterStudent(
    IN p_student_id VARCHAR(20),
    IN p_name VARCHAR(255),
    IN p_enroll_year YEAR,
    IN p_email VARCHAR(255),
    IN p_phone_number VARCHAR(15),
    IN p_dept_id INT,
    IN p_password VARCHAR(255)
)
BEGIN
    -- Error handling: Rollback on any SQL exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO tblStudent (student_id, name, enroll_year, email, phone_number, dept_id)
    VALUES (p_student_id, p_name, p_enroll_year, p_email, p_phone_number, p_dept_id);

    -- Insert into login table (SHA2 is a basic hash demonstration)
    INSERT INTO tblUser_Login (email, password_hash, user_type, student_id, alumni_id)
    VALUES (p_email, SHA2(p_password, 256), 'student', p_student_id, NULL);

    COMMIT;
END$$


-- Procedure 2: Register a new alumnus
CREATE PROCEDURE sp_RegisterAlumni (
    IN p_alumni_id VARCHAR(20),
    IN p_Fname VARCHAR(100),
    IN p_Lname VARCHAR(100),
    IN p_grad_year YEAR,
    IN p_email VARCHAR(255),
    IN p_phone_number VARCHAR(15),
    IN p_dept_id INT,
    IN p_job_title VARCHAR(100),
    IN p_current_company VARCHAR(100),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Insert into tblAlumni
    INSERT INTO tblAlumni (alumni_id, Fname, Lname, grad_year, email, phone_number, dept_id, job_title, current_company)
    VALUES (p_alumni_id, p_Fname, p_Lname, p_grad_year, p_email, p_phone_number, p_dept_id, p_job_title, p_current_company);

    -- 2. Insert into tblUser_Login
    INSERT INTO tblUser_Login (alumni_id, email, password_hash, user_type)
    VALUES (p_alumni_id, p_email, SHA2(p_password, 256), 'alumni');

    COMMIT;
END$$

-- Procedure 3: Send a message
CREATE PROCEDURE sp_SendMessage(
    IN p_sender_id VARCHAR(20),
    IN p_sender_type ENUM('student', 'alumni'),
    IN p_recipient_id VARCHAR(20),
    IN p_recipient_type ENUM('student', 'alumni'),
    IN p_message_content TEXT
)
BEGIN
    DECLARE v_sender_alumni_id VARCHAR(20) DEFAULT NULL;
    DECLARE v_sender_student_id VARCHAR(20) DEFAULT NULL;
    DECLARE v_recipient_alumni_id VARCHAR(20) DEFAULT NULL;
    DECLARE v_recipient_student_id VARCHAR(20) DEFAULT NULL;

    IF p_sender_type = 'student' THEN
        SET v_sender_student_id = p_sender_id;
    ELSE
        SET v_sender_alumni_id = p_sender_id;
    END IF;

    IF p_recipient_type = 'student' THEN
        SET v_recipient_student_id = p_recipient_id;
    ELSE
        SET v_recipient_alumni_id = p_recipient_id;
    END IF;

    INSERT INTO tblMessages (
        sender_alumni_id,
        sender_student_id,
        recipient_alumni_id,
        recipient_student_id,
        message_content
    )
    VALUES (
        v_sender_alumni_id,
        v_sender_student_id,
        v_recipient_alumni_id,
        v_recipient_student_id,
        p_message_content
    );
END$$


-- =====================================================================
-- STEP 6: FUNCTIONS
-- =====================================================================

-- Function 1: Check for Department Match
-- Checks if a student and alumnus are from the same department.
CREATE FUNCTION fn_CheckDepartmentMatch(
    p_student_id VARCHAR(20),
    p_alumni_id VARCHAR(20)
)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_student_dept INT;
    DECLARE v_alumni_dept INT;

    SELECT dept_id INTO v_student_dept
    FROM tblStudent
    WHERE student_id = p_student_id;

    SELECT dept_id INTO v_alumni_dept
    FROM tblAlumni
    WHERE alumni_id = p_alumni_id;

    -- Return TRUE only if both IDs are found and match
    IF v_student_dept IS NOT NULL AND v_alumni_dept IS NOT NULL AND v_student_dept = v_alumni_dept THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END$$

-- Function 2: Get Alumni Engagement Score
-- Calculates a "score" for an alumnus based on their activity (Job posts, events organized, active mentorships).
CREATE FUNCTION fn_GetAlumniEngagementScore(
    p_alumni_id VARCHAR(20)
)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_job_posts INT DEFAULT 0;
    DECLARE v_events_organized INT DEFAULT 0;
    DECLARE v_active_mentorships INT DEFAULT 0;
    DECLARE v_total_score INT DEFAULT 0;

    -- 5 points per job post
    SELECT COUNT(*) * 5 INTO v_job_posts
    FROM tblJob_Posting
    WHERE posted_by_alumni_id = p_alumni_id;

    -- 10 points per organized event
    SELECT COUNT(*) * 10 INTO v_events_organized
    FROM tblEvent
    WHERE organizer_alumni_id = p_alumni_id;

    -- 20 points per active mentorship
    SELECT COUNT(*) * 20 INTO v_active_mentorships
    FROM tblMentorship
    WHERE mentor_alumni_id = p_alumni_id AND status = 'active';

    SET v_total_score = v_job_posts + v_events_organized + v_active_mentorships;
    RETURN v_total_score;
END$$

-- STEP 7: TRIGGERS

-- Trigger 1: Update User Login on Alumni Email Change
CREATE TRIGGER trg_update_alumni_login_email
AFTER UPDATE ON tblAlumni
FOR EACH ROW
BEGIN
    IF OLD.email <> NEW.email THEN
        UPDATE tblUser_Login
        SET email = NEW.email
        WHERE alumni_id = NEW.alumni_id;
    END IF;
END$$

-- Trigger 2: Update User Login on Student Email Change
CREATE TRIGGER trg_update_student_login_email
AFTER UPDATE ON tblStudent
FOR EACH ROW
BEGIN
    IF OLD.email <> NEW.email THEN
        UPDATE tblUser_Login
        SET email = NEW.email
        WHERE student_id = NEW.student_id;
    END IF;
END$$

-- Trigger 3: Validate Mentorship Department Match
-- Uses fn_CheckDepartmentMatch to block cross-department mentorships.
CREATE TRIGGER trg_ValidateMentorshipDept
BEFORE INSERT ON tblMentorship
FOR EACH ROW
BEGIN
    IF fn_CheckDepartmentMatch(NEW.mentee_student_id, NEW.mentor_alumni_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
             SET MESSAGE_TEXT = 'Error: Mentor and mentee must be from the same department.';
    END IF;
END$$

-- Trigger 4a: Prevent Registration for Past Events (Students)
CREATE TRIGGER trg_PreventLateStudentRegistration
BEFORE INSERT ON tblStudent_Event_Registration
FOR EACH ROW
BEGIN
    DECLARE v_event_date DATETIME;
    SELECT event_date INTO v_event_date
    FROM tblEvent
    WHERE event_id = NEW.event_id;

    IF v_event_date <= NOW() THEN
        SIGNAL SQLSTATE '45000'
             SET MESSAGE_TEXT = 'Error: Cannot register for an event that has already started or passed.';
    END IF;
END$$

-- Trigger 4b: Prevent Registration for Past Events (Alumni)
CREATE TRIGGER trg_PreventLateAlumniRegistration
BEFORE INSERT ON tblAlumni_Event_Registration
FOR EACH ROW
BEGIN
    DECLARE v_event_date DATETIME;
    SELECT event_date INTO v_event_date
    FROM tblEvent
    WHERE event_id = NEW.event_id;

    IF v_event_date <= NOW() THEN
        SIGNAL SQLSTATE '45000'
             SET MESSAGE_TEXT = 'Error: Cannot register for an event that has already started or passed.';
    END IF;
END$$

-- Trigger 5: Prevent Sending a Message to Oneself
CREATE TRIGGER trg_PreventSelfMessage
BEFORE INSERT ON tblMessages
FOR EACH ROW
BEGIN
    -- Check if both sender and recipient are Alumni AND their IDs match
    IF (NEW.sender_alumni_id IS NOT NULL AND
        NEW.sender_alumni_id = NEW.recipient_alumni_id)
    -- OR check if both sender and recipient are Students AND their IDs match
    OR
        (NEW.sender_student_id IS NOT NULL AND
        NEW.sender_student_id = NEW.recipient_student_id) THEN

        SIGNAL SQLSTATE '45000'
             SET MESSAGE_TEXT = 'Error: Sender and recipient cannot be the same user.';
    END IF;
END$$

-- Reset delimiter to default
DELIMITER ;


-- ==============================================================
-- 🧩 FUNCTION TEST CASES
-- ==============================================================

-- ✅ Check if Student and Alumni are from same department (Expected: TRUE)
SELECT fn_CheckDepartmentMatch('PES2UG23CS061', 'PES2UG19CS001') AS SameDept_True;

-- ❌ Different departments (Expected: FALSE)
SELECT fn_CheckDepartmentMatch('PES2UG23CS061', 'PES2UG18EC002') AS SameDept_False;

-- ✅ Alumni Engagement Score test cases
SELECT fn_GetAlumniEngagementScore('PES2UG19CS001') AS Rahul_Score;
SELECT fn_GetAlumniEngagementScore('PES2UG19CS005') AS Rohan_Score;


-- ==============================================================
-- ⚙ STORED PROCEDURE TEST CASES
-- ==============================================================

-- ✅ Register a new student and login (sp_RegisterStudent)
CALL sp_RegisterStudent(
    'PES2UG25CS100',
    'Test Student',
    2025,
    'test.student@pes.edu',
    '9999999999',
    1,
    'password123'
);

-- 🔍 Verify new student created
SELECT * FROM tblStudent WHERE student_id = 'PES2UG25CS100';
SELECT * FROM tblUser_Login WHERE email = 'test.student@pes.edu';


-- ✅ Send messages between alumni and students (sp_SendMessage)
CALL sp_SendMessage(
    'PES2UG23CS061', 'student', 'PES2UG19CS005', 'alumni',
    'Hi Rohan, when is the next AI workshop?'
);

CALL sp_SendMessage(
    'PES2UG19CS005', 'alumni', 'PES2UG23CS061', 'student',
    'Hey Ananya, it’s on November 10th. You should join!'
);

-- 🔍 Verify latest messages
SELECT message_id, message_content, sent_at
FROM tblMessages
ORDER BY message_id DESC
LIMIT 2;


-- ==============================================================
-- ⚡ TRIGGER TEST CASES
-- NOTE: The following INSERT/UPDATE statements are expected to fail
--       (45000 error) or produce a side effect (UPDATE/INSERT).
-- ==============================================================

-- ✅ 1. trg_update_alumni_login_email (email sync check)
UPDATE tblAlumni
SET email = 'rahul.updated@example.com'
WHERE alumni_id = 'PES2UG19CS001';

-- 🔍 Check if login table updated
SELECT a.alumni_id, a.email AS alumni_email, l.email AS login_email
FROM tblAlumni a
JOIN tblUser_Login l ON a.alumni_id = l.alumni_id
WHERE a.alumni_id = 'PES2UG19CS001';

-- ❌ 3. trg_ValidateMentorshipDept (Expected Failure: Cross-department mentorship should fail)
-- Student (CS) trying to get mentor (EC)
-- INSERT INTO tblMentorship (start_date, status, mentor_alumni_id, mentee_student_id)
-- VALUES ('2025-11-01', 'pending', 'PES2UG18EC002', 'PES2UG23CS061');


-- ❌ 4a. trg_PreventLateStudentRegistration (Expected Failure: Past event)
-- INSERT INTO tblStudent_Event_Registration (student_id, event_id)
-- VALUES ('PES2UG23CS061', 2); -- Event 2 date is 2025-10-20


-- ❌ 5. trg_PreventSelfMessage (Expected Failure: Cannot message oneself)
-- INSERT INTO tblMessages (sender_student_id, recipient_student_id, message_content)
-- VALUES ('PES2UG23CS061', 'PES2UG23CS061', 'This should fail (self message test).');


-- =====================================================================
-- Complex Queries (Nested and Join Queries)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Nested Query (Subquery in WHERE clause - EXISTS)
-- Objective: Find the full name and email of all Alumni who are currently
-- mentoring at least one student.
-- ---------------------------------------------------------------------

SELECT
    A.Fname,
    A.Lname,
    A.email,
    A.grad_year
FROM
    tblAlumni A
WHERE
    EXISTS (
        SELECT 1
        FROM tblMentorship M
        WHERE M.mentor_alumni_id = A.alumni_id
    )
ORDER BY
    A.Lname;

-- ---------------------------------------------------------------------
-- Nested Query (Subquery in FROM clause - Derived Table & Scalar Subquery)
-- Objective: Find all events where the student registration count is greater
-- than the overall average registration count across all events.
-- ---------------------------------------------------------------------

SELECT
    E.event_name,
    E.event_date,
    EventRegistrationCount.num_students_registered
FROM
    tblEvent E
JOIN (
    -- Derived Table: Calculates the number of registered students for each event
    SELECT
        event_id,
        COUNT(student_id) AS num_students_registered
    FROM
        tblStudent_Event_Registration
    GROUP BY
        event_id
) AS EventRegistrationCount
ON E.event_id = EventRegistrationCount.event_id
WHERE
    EventRegistrationCount.num_students_registered > (
        -- Scalar Subquery: Calculates the overall average number of registrations
        SELECT AVG(reg_count)
        FROM (
            SELECT COUNT(student_id) AS reg_count
            FROM tblStudent_Event_Registration
            GROUP BY event_id
        ) AS AvgRegTable
    );

-- ---------------------------------------------------------------------
-- Join Query (INNER JOIN)
-- Objective: Retrieve the full names of students and the name of their
-- respective department.
-- ---------------------------------------------------------------------

SELECT
    S.name AS student_name,
    D.dept_name
FROM
    tblStudent S
INNER JOIN
    tblDepartment D ON S.dept_id = D.dept_id
ORDER BY
    D.dept_name, S.name;

-- ---------------------------------------------------------------------
-- Join Query (Multiple JOINs)
-- Objective: List all students, their mentors (alumni), and the
-- graduation year of the alumni.
-- ---------------------------------------------------------------------

SELECT
    S.name AS student_name,
    A.Fname AS mentor_first_name,
    A.Lname AS mentor_last_name,
    A.grad_year AS mentor_grad_year
FROM
    tblMentorship M
JOIN
    tblStudent S ON M.mentee_student_id = S.student_id
JOIN
    tblAlumni A ON M.mentor_alumni_id = A.alumni_id
ORDER BY
    student_name;

-- =====================================================================
-- Aggregate Queries
-- =====================================================================

-- ---------------------------------------------------------------------
-- COUNT with GROUP BY
-- Objective: Find the total number of students in each department.
-- ---------------------------------------------------------------------

SELECT
    D.dept_name,
    COUNT(S.student_id) AS total_students
FROM
    tblDepartment D
LEFT JOIN
    tblStudent S ON D.dept_id = S.dept_id
GROUP BY
    D.dept_name
ORDER BY
    total_students DESC;

-- ---------------------------------------------------------------------
-- COUNT with HAVING (Filter on Aggregated Data)
-- Objective: Find the name of the departments that have more than 1 alumnus.
-- ---------------------------------------------------------------------

SELECT
    D.dept_name,
    COUNT(A.alumni_id) AS total_alumni
FROM
    tblDepartment D
INNER JOIN
    tblAlumni A ON D.dept_id = A.dept_id
GROUP BY
    D.dept_name
HAVING
    total_alumni > 1
ORDER BY
    total_alumni DESC;

-- ---------------------------------------------------------------------
-- MAX, MIN, and AVG (Summarizing Event Attendance)
-- Objective: Calculate the maximum, minimum, and average number of
-- students registered across all events.
-- ---------------------------------------------------------------------

SELECT
    MAX(reg_count) AS max_student_attendance,
    MIN(reg_count) AS min_student_attendance,
    AVG(reg_count) AS avg_student_attendance
FROM (
    -- Subquery to count registrations for each event first
    SELECT
        COUNT(student_id) AS reg_count
    FROM
        tblStudent_Event_Registration
    GROUP BY
        event_id
) AS EventAttendance;

-- ---------------------------------------------------------------------
-- COUNT and GROUP BY (Total Job Postings by Company)
-- Objective: Calculate the total number of job openings posted
-- by each company and the most recent posting date.
-- ---------------------------------------------------------------------

SELECT
    company_name,
    COUNT(job_id) AS total_openings_posted,
    MAX(post_date) AS most_recent_posting
FROM
    tblJob_Posting
GROUP BY
    company_name
ORDER BY
    total_openings_posted DESC;