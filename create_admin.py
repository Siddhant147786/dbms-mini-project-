import mysql.connector
from werkzeug.security import generate_password_hash
import getpass  # Used to hide password input

# --- IMPORTANT ---
# Make sure these database details match your app.py configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Siddhant@12',
    'database': 'faculty_feedback'
}

def create_admin():
    """Securely creates a new admin user in the database."""
    try:
        print("--- Create a New Administrator ---")
        
        # Get user input
        username = input("Enter username: ").strip()
        password = getpass.getpass("Enter password (will be hidden): ").strip()
        confirm_password = getpass.getpass("Confirm password: ").strip()
        full_name = input("Enter full name (optional): ").strip()
        email = input("Enter email (optional): ").strip()

        # Validate input
        if not username or not password:
            print("\n[Error] Username and password cannot be empty.")
            return

        if password != confirm_password:
            print("\n[Error] Passwords do not match.")
            return

        # Hash the password
        password_hash = generate_password_hash(password)

        # Connect to the database
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()

        # Insert the new admin
        query = """
            INSERT INTO admins (username, password_hash, full_name, email)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(query, (username, password_hash, full_name or None, email or None))
        
        # Commit the changes
        conn.commit()

        print(f"\n[Success] Administrator '{username}' created successfully!")

    except mysql.connector.Error as err:
        if err.errno == 1062: # Duplicate entry error
            print(f"\n[Error] An admin with the username '{username}' already exists.")
        else:
            print(f"\n[Error] A database error occurred: {err}")
    
    except Exception as e:
        print(f"\n[Error] An unexpected error occurred: {e}")

    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()

if __name__ == "__main__":
    create_admin()


