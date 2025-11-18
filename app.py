import os
import mysql.connector
from mysql.connector import Error
from flask import Flask, render_template, request, redirect, url_for, flash, session
from functools import wraps
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")

app = Flask(__name__, template_folder=TEMPLATE_DIR)
app.config['SECRET_KEY'] = 'a_very_secret_random_key_f0r_pr0ject'

# --- DATABASE CONFIGURATION ---
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '09102005', 
    'database': 'alumni_connect'
}

def get_db_connection():
    """Helper function to connect to the database."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

# -----------------------
# Authentication helper
# -----------------------
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash("You must be logged in to view this page.", "danger")
            return redirect(url_for('login_page'))
        return f(*args, **kwargs)
    return decorated_function

# -----------------------
# Login / Logout
# -----------------------
@app.route('/login', methods=['GET', 'POST'])
def login_page():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        user_type = request.form['user_type']  # 'student' or 'alumni'

        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor(dictionary=True) as cursor:
                    query = """
                    SELECT * FROM tblUser_Login 
                    WHERE email = %s 
                    AND password_hash = SHA2(%s, 256) 
                    AND user_type = %s
                    """
                    cursor.execute(query, (email, password, user_type))
                    user = cursor.fetchone()

                    if user:
                        session['email'] = user['email']
                        session['user_type'] = user['user_type']
                        # store the proper id (student_id / alumni_id) into session
                        if user['user_type'] == 'student':
                            session['user_id'] = user.get('student_id') or user.get('user_id')
                        else:
                            session['user_id'] = user.get('alumni_id') or user.get('user_id')

                        flash(f"Welcome back, {session['email']}!", "success")
                        if session['user_type'] == 'student':
                            return redirect(url_for('dashboard'))
                        else:
                            return redirect(url_for('alumni_dashboard'))
                    else:
                        flash("Invalid credentials. Please try again.", "danger")

            except Error as e:
                flash(f"Database error: {e}", "danger")
            finally:
                conn.close()

    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash("You have been logged out.", "success")
    return redirect(url_for('login_page'))

# -----------------------
#  Student Dashboard
# -----------------------
@app.route('/')
@login_required
def dashboard():
    """Student Dashboard."""
    if session.get('user_type') != 'student':
        return redirect(url_for('alumni_dashboard'))

    my_mentorships = []
    my_events = []
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                query_mentors = """
                SELECT A.Fname, A.Lname, A.job_title, M.status
                FROM tblMentorship M
                JOIN tblAlumni A ON M.mentor_alumni_id = A.alumni_id
                WHERE M.mentee_student_id = %s
                """
                cursor.execute(query_mentors, (session['user_id'],))
                my_mentorships = cursor.fetchall()

                query_events = """
                SELECT E.event_name, E.event_date, E.location
                FROM tblStudent_Event_Registration SER
                JOIN tblEvent E ON SER.event_id = E.event_id
                WHERE SER.student_id = %s AND E.event_date > NOW()
                ORDER BY E.event_date ASC
                """
                cursor.execute(query_events, (session['user_id'],))
                my_events = cursor.fetchall()

        except Error as e:
            flash(f"Error fetching data: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return render_template('dashboard.html', mentorships=my_mentorships, events=my_events)

# -----------------------
# Alumni list for students
# -----------------------
@app.route('/alumni')
@login_required
def alumni_list_page():
    if session.get('user_type') != 'student':
        return redirect(url_for('alumni_dashboard'))

    alumni = []
    query = """
    SELECT A.alumni_id, A.Fname, A.Lname, A.job_title, A.current_company, A.grad_year, D.dept_name
    FROM tblAlumni A
    LEFT JOIN tblDepartment D ON A.dept_id = D.dept_id
    ORDER BY A.Fname, A.Lname
    """
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                cursor.execute(query)
                alumni = cursor.fetchall()
        except Error as e:
            flash(f"Error fetching alumni: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return render_template('alumni_list.html', alumni_list=alumni)

@app.route('/mentorship/request/<string:alumni_id>')
@login_required
def request_mentorship(alumni_id):
    if session.get('user_type') != 'student':
        return redirect(url_for('alumni_dashboard'))

    query = "INSERT INTO tblMentorship (mentor_alumni_id, mentee_student_id, start_date, status) VALUES (%s, %s, %s, 'pending')"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, (alumni_id, session['user_id'], datetime.now().date()))
                conn.commit()
                flash("Mentorship request sent successfully!", "success")
        except Error as e:
            flash(f"Error sending request: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return redirect(url_for('alumni_list_page'))

# -----------------------
# Messaging
# -----------------------
@app.route('/messages/with/<string:recipient_id>/<string:recipient_type>', methods=['GET', 'POST'])
@login_required
def conversation_page(recipient_id, recipient_type):
    if request.method == 'POST':
        message_content = request.form['message_content']
        args = (session['user_id'], session['user_type'], recipient_id, recipient_type, message_content)
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cursor:
                    cursor.callproc('sp_SendMessage', args)
                    conn.commit()
                    flash("Message sent!", "success")
            except Error as e:
                flash(f"Error sending message: {getattr(e,'msg',str(e))}", "danger")
            finally:
                conn.close()
        return redirect(url_for('conversation_page', recipient_id=recipient_id, recipient_type=recipient_type))

    messages = []
    recipient_name = ""
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                if session['user_type'] == 'student' and recipient_type == 'alumni':
                    query = """
                    SELECT * FROM tblMessages 
                    WHERE (sender_student_id = %s AND recipient_alumni_id = %s) 
                       OR (sender_alumni_id = %s AND recipient_student_id = %s)
                    ORDER BY sent_at ASC
                    """
                    query_args = (session['user_id'], recipient_id, recipient_id, session['user_id'])
                    cursor.execute("SELECT CONCAT(Fname, ' ', Lname) AS name FROM tblAlumni WHERE alumni_id = %s", (recipient_id,))
                    row = cursor.fetchone()
                    recipient_name = row['name'] if row else ""

                elif session['user_type'] == 'alumni' and recipient_type == 'student':
                    query = """
                    SELECT * FROM tblMessages 
                    WHERE (sender_alumni_id = %s AND recipient_student_id = %s) 
                       OR (sender_student_id = %s AND recipient_alumni_id = %s)
                    ORDER BY sent_at ASC
                    """
                    query_args = (session['user_id'], recipient_id, recipient_id, session['user_id'])
                    cursor.execute("SELECT name FROM tblStudent WHERE student_id = %s", (recipient_id,))
                    row = cursor.fetchone()
                    recipient_name = row['name'] if row else ""
                else:
                    flash("Invalid message target.", "danger")
                    return redirect(url_for('dashboard'))

                cursor.execute(query, query_args)
                messages = cursor.fetchall()
        except Error as e:
            flash(f"Error fetching messages: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return render_template('conversation.html', 
                           messages=messages, 
                           recipient_id=recipient_id, 
                           recipient_type=recipient_type,
                           recipient_name=recipient_name)

# -----------------------
# Events (BROWSE & ANALYTICS)
# -----------------------
@app.route('/events')
@login_required
def events_list_page():
    """Shows all upcoming events. For Alumni, also shows Analytics."""
    events = []
    analytics_data = {} # To store complex query results
    
    query = """
    SELECT E.*, A.Fname AS organizer_fname, A.Lname AS organizer_lname,
           (CASE WHEN SER.student_id IS NOT NULL THEN 1 ELSE 0 END) AS is_registered
    FROM tblEvent E
    JOIN tblAlumni A ON E.organizer_alumni_id = A.alumni_id
    LEFT JOIN tblStudent_Event_Registration SER
      ON E.event_id = SER.event_id AND SER.student_id = %s
    WHERE E.event_date > NOW()
    ORDER BY E.event_date ASC
    """
    student_id_for_join = session['user_id'] if session.get('user_type') == 'student' else None

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                # 1. Standard Event List
                cursor.execute(query, (student_id_for_join,))
                events = cursor.fetchall()

                # 2. COMPLEX ANALYTICS (Only for Alumni)
                if session['user_type'] == 'alumni':
                    # A. Popular Events (Nested)
                    cursor.execute("""
                        SELECT E.event_name, E.event_date, EventRegistrationCount.num_students_registered
                        FROM tblEvent E
                        JOIN (
                            SELECT event_id, COUNT(student_id) AS num_students_registered
                            FROM tblStudent_Event_Registration
                            GROUP BY event_id
                        ) AS EventRegistrationCount ON E.event_id = EventRegistrationCount.event_id
                        WHERE EventRegistrationCount.num_students_registered > (
                            SELECT AVG(reg_count)
                            FROM (
                                SELECT COUNT(student_id) AS reg_count
                                FROM tblStudent_Event_Registration
                                GROUP BY event_id
                            ) AS AvgRegTable
                        )
                    """)
                    analytics_data['popular_events'] = cursor.fetchall()

                    # B. Event Stats (Aggregates)
                    cursor.execute("""
                        SELECT 
                            MAX(reg_count) AS max_att, 
                            MIN(reg_count) AS min_att, 
                            AVG(reg_count) AS avg_att
                        FROM (
                            SELECT COUNT(student_id) AS reg_count
                            FROM tblStudent_Event_Registration
                            GROUP BY event_id
                        ) AS EventAttendance
                    """)
                    analytics_data['event_stats'] = cursor.fetchone()

                    # C. Hiring Companies (Group By)
                    cursor.execute("""
                        SELECT company_name, COUNT(job_id) AS total_openings
                        FROM tblJob_Posting
                        GROUP BY company_name
                        ORDER BY total_openings DESC
                    """)
                    analytics_data['hiring_companies'] = cursor.fetchall()

        except Error as e:
            flash(f"Error fetching data: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    if session['user_type'] == 'student':
        return render_template('student_events.html', events_list=events)
    else:
        # Pass 'analytics' data specifically for the alumni view
        return render_template('events_list.html', events_list=events, analytics=analytics_data, user_type='alumni')

@app.route('/event/register/<int:event_id>')
@login_required
def register_for_event(event_id):
    if session.get('user_type') != 'student':
        flash("Only students can register for events.", "danger")
        return redirect(url_for('events_list_page'))

    query = "INSERT INTO tblStudent_Event_Registration (student_id, event_id) VALUES (%s, %s)"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, (session['user_id'], event_id))
                conn.commit()
                flash("Successfully registered for the event!", "success")
        except Error as e:
            flash(f"Error registering for event: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return redirect(url_for('events_list_page'))


# -----------------------
# Jobs
# -----------------------
@app.route('/job/new', methods=['GET', 'POST'])
@login_required
def create_job_page():
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        job_title = request.form['job_title']
        company_name = request.form['company_name'] 
        description = request.form['description']
        alumni_id = session['user_id']

        query = """
            INSERT INTO tblJob_Posting (job_title, company_name, description, posted_by_alumni_id) 
            VALUES (%s, %s, %s, %s)
        """
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cursor:
                    cursor.execute(query, (job_title, company_name, description, alumni_id))
                    conn.commit()
                    flash("Job posted successfully!", "success")
                    return redirect(url_for('jobs_page'))
            except Error as e:
                flash(f"Error posting job: {getattr(e,'msg',str(e))}", "danger")
            finally:
                conn.close()

    return render_template('create_job.html')

@app.route('/job/edit/<int:job_id>', methods=['GET', 'POST'])
@login_required
def edit_job(job_id):
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                if request.method == 'POST':
                    job_title = request.form['job_title']
                    company_name = request.form['company_name']
                    description = request.form['description']

                    update_query = """
                        UPDATE tblJob_Posting 
                        SET job_title = %s, company_name = %s, description = %s 
                        WHERE job_id = %s AND posted_by_alumni_id = %s
                    """
                    cursor.execute(update_query, (job_title, company_name, description, job_id, session['user_id']))
                    conn.commit()

                    if cursor.rowcount > 0:
                        flash("Job updated successfully!", "success")
                    else:
                        flash("Error: You cannot edit this job or it does not exist.", "danger")
                    
                    return redirect(url_for('jobs_page'))
                else:
                    select_query = "SELECT * FROM tblJob_Posting WHERE job_id = %s AND posted_by_alumni_id = %s"
                    cursor.execute(select_query, (job_id, session['user_id']))
                    job = cursor.fetchone()

                    if job:
                        return render_template('edit_job.html', job=job)
                    else:
                        flash("Job not found or access denied.", "danger")
                        return redirect(url_for('jobs_page'))

        except Error as e:
            flash(f"Database error: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return redirect(url_for('jobs_page'))

@app.route('/job/delete/<int:job_id>')
@login_required
def delete_job(job_id):
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                query = """
                    DELETE FROM tblJob_Posting 
                    WHERE job_id = %s AND posted_by_alumni_id = %s
                """
                cursor.execute(query, (job_id, session['user_id']))
                conn.commit()

                if cursor.rowcount > 0:
                    flash("Job deleted successfully!", "success")
                else:
                    flash("You are not allowed to delete this job.", "danger")
        except Error as e:
            flash(f"Error deleting job: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return redirect(url_for('jobs_page'))

@app.route('/jobs')
@login_required
def jobs_page():
    jobs = []
    query = "SELECT J.*, A.Fname, A.Lname FROM tblJob_Posting J JOIN tblAlumni A ON J.posted_by_alumni_id = A.alumni_id ORDER BY J.post_date DESC"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                cursor.execute(query)
                jobs = cursor.fetchall()
        except Error as e:
            flash(f"Error fetching jobs: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
            
    if session['user_type'] == 'student':
        return render_template('student_jobs.html', jobs=jobs)
    else:
        return render_template('jobs.html', jobs=jobs, user_type='alumni')

# -----------------------
# Alumni dashboard + event CRUD for alumni
# -----------------------
@app.route('/alumni/dashboard')
@login_required
def alumni_dashboard():
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    mentorships = []
    engagement_score = 0 

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                # 1. Fetch Mentorships
                query = """
                SELECT S.name, S.email, S.phone_number, S.student_id, M.status 
                FROM tblMentorship M JOIN tblStudent S ON M.mentee_student_id = S.student_id 
                WHERE M.mentor_alumni_id = %s ORDER BY M.status, S.name
                """
                cursor.execute(query, (session['user_id'],))
                mentorships = cursor.fetchall()

                # 2. Fetch Engagement Score
                cursor.execute("SELECT fn_GetAlumniEngagementScore(%s) as score", (session['user_id'],))
                result = cursor.fetchone()
                if result:
                    engagement_score = result['score']

        except Error as e:
            flash(f"Error fetching dashboard data: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
            
    return render_template('alumni_dashboard.html', mentorships=mentorships, score=engagement_score)

@app.route('/mentorship/update/<string:student_id>/<string:new_status>')
@login_required
def update_mentorship_status(student_id, new_status):
    if session.get('user_type') != 'alumni' or new_status not in ('active', 'completed'):
        flash("Invalid action.", "danger")
        return redirect(url_for('alumni_dashboard'))

    query = "UPDATE tblMentorship SET status = %s WHERE mentor_alumni_id = %s AND mentee_student_id = %s"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, (new_status, session['user_id'], student_id))
                conn.commit()
                flash(f"Mentorship status updated to {new_status}.", "success")
        except Error as e:
            flash(f"Error updating status: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return redirect(url_for('alumni_dashboard'))

# Alumni: manage events
@app.route('/alumni/events')
@login_required
def alumni_manage_events():
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    events = []
    query = "SELECT * FROM tblEvent WHERE organizer_alumni_id = %s ORDER BY event_date DESC"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                cursor.execute(query, (session['user_id'],))
                events = cursor.fetchall()
        except Error as e:
            flash(f"Error fetching your events: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return render_template('alumni_manage_events.html', events_list=events)

@app.route('/alumni/event/new', methods=['GET', 'POST'])
@login_required
def create_event_page():
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        event_name = request.form['event_name']
        event_date = request.form['event_date']
        location = request.form['location']
        description = request.form['description']
        organizer_id = session['user_id']

        query = "INSERT INTO tblEvent (event_name, event_date, location, description, organizer_alumni_id) VALUES (%s, %s, %s, %s, %s)"
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cursor:
                    cursor.execute(query, (event_name, event_date, location, description, organizer_id))
                    conn.commit()
                    flash("New event created successfully!", "success")
                    return redirect(url_for('alumni_manage_events'))
            except Error as e:
                flash(f"Error creating event: {getattr(e,'msg',str(e))}", "danger")
            finally:
                conn.close()
    return render_template('create_event.html')

@app.route('/alumni/event/edit/<int:event_id>', methods=['GET', 'POST'])
@login_required
def edit_event_page(event_id):
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        event_name = request.form['event_name']
        event_date = request.form['event_date']
        location = request.form['location']
        description = request.form['description']

        query = "UPDATE tblEvent SET event_name = %s, event_date = %s, location = %s, description = %s WHERE event_id = %s AND organizer_alumni_id = %s"
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cursor:
                    cursor.execute(query, (event_name, event_date, location, description, event_id, session['user_id']))
                    conn.commit()
                    flash("Event updated successfully!", "success")
            except Error as e:
                flash(f"Error updating event: {getattr(e,'msg',str(e))}", "danger")
            finally:
                conn.close()
        return redirect(url_for('alumni_manage_events'))

    event_data = None
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(dictionary=True) as cursor:
                query = "SELECT * FROM tblEvent WHERE event_id = %s AND organizer_alumni_id = %s"
                cursor.execute(query, (event_id, session['user_id']))
                event_data = cursor.fetchone()
        except Error as e:
            flash(f"Error fetching event data: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    if event_data:
        if event_data.get('event_date'):
            try:
                event_date_val = event_data['event_date']
                event_data['event_date_html'] = event_date_val.strftime('%Y-%m-%dT%H:%M')
            except Exception:
                event_data['event_date_html'] = event_data.get('event_date')
        return render_template('update_event.html', event=event_data)
    else:
        flash("You are not authorized to edit this event or it does not exist.", "danger")
        return redirect(url_for('alumni_manage_events'))

@app.route('/alumni/event/delete/<int:event_id>')
@login_required
def delete_event(event_id):
    if session.get('user_type') != 'alumni':
        return redirect(url_for('dashboard'))

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                query = "DELETE FROM tblEvent WHERE event_id = %s AND organizer_alumni_id = %s"
                cursor.execute(query, (event_id, session['user_id']))
                conn.commit()
                if cursor.rowcount > 0:
                    flash("Event deleted successfully.", "success")
                else:
                    flash("You are not authorized to delete this event or it does not exist.", "danger")
        except Error as e:
            flash(f"Error deleting event: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()
    return redirect(url_for('alumni_manage_events'))

# -----------------------
# Registration (public)
# -----------------------
@app.route('/register_page')
def register_page():
    return render_template('register.html')

@app.route('/register', methods=['POST'])
def register_student():
    p_student_id = request.form['student_id']
    p_name = request.form['name']
    p_enroll_year = request.form['enroll_year']
    p_email = request.form['email']
    p_phone_number = request.form['phone']
    p_dept_id = request.form['dept_id']
    p_password = request.form['password']

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                args = (p_student_id, p_name, p_enroll_year, p_email, p_phone_number, p_dept_id, p_password)
                cursor.callproc('sp_RegisterStudent', args)
                conn.commit()
                flash(f"Successfully registered student: {p_name}. You may now log in.", "success")
        except Error as e:
            flash(f"Error registering student: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return redirect(url_for('login_page'))

@app.route('/register_alumni_page')
def register_alumni_page():
    return render_template('register_alumni.html')

@app.route('/register_alumni', methods=['POST'])
def register_alumni():
    p_alumni_id = request.form['alumni_id']
    p_Fname = request.form['Fname']
    p_Lname = request.form['Lname']
    p_grad_year = request.form['grad_year']
    p_email = request.form['email']
    p_phone_number = request.form['phone_number']
    p_dept_id = request.form['dept_id']
    p_job_title = request.form['job_title']
    p_current_company = request.form['current_company']
    p_password = request.form['password']

    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                args = (p_alumni_id, p_Fname, p_Lname, p_grad_year, p_email, p_phone_number, p_dept_id, p_job_title, p_current_company, p_password)
                cursor.callproc('sp_RegisterAlumni', args)
                conn.commit()
                flash(f"Successfully registered alumnus: {p_Fname}. You may now log in.", "success")
        except Error as e:
            flash(f"Error registering alumnus: {getattr(e,'msg',str(e))}", "danger")
        finally:
            conn.close()

    return redirect(url_for('login_page'))

# -----------------------
# Run the App
# -----------------------
if __name__ == '__main__':
    app.run(debug=True)