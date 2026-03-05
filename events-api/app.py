from flask import Flask, request, jsonify
import os
import psycopg
import time

app = Flask(__name__)



# Wait for the database to be ready before starting the app. 
# This is important when running in Docker Compose, as the app may start before the database is ready.
# So it retries to connect to the database a few times with a delay in between .
def wait_for_db(max_retries=20, delay=1):
    for i in range(max_retries):
        try:
            with get_db_connection() as conn:
                return
        except Exception as e:
            print(f"DB not ready yet ({i+1}/{max_retries}): {e}")
            time.sleep(delay)
    raise RuntimeError("Database not ready after retries")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    # changed from localhost to db, which is the hostname of the database service in Docker Compose
    "postgresql://app:apppassword@db:5432/events"
)


def get_db_connection():
    return psycopg.connect(DATABASE_URL)

# Initialize the database and create the events table if it doesn't exist
def init_db():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id SERIAL PRIMARY KEY,
                    type TEXT NOT NULL,
                    username TEXT NOT NULL
                )
            """)
            
wait_for_db()
init_db()

# Health check endpoint
@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200

# Endpoint to create a new event
@app.post("/events")
def create_event():

    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json()

    if "type" not in data or "user" not in data:
        return jsonify({"error": "Missing required fields"}), 400

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO events (type, username) VALUES (%s, %s) RETURNING id",
                (data["type"], data["user"])
            )
            event_id = cur.fetchone()[0]

    return jsonify({
        "id": event_id,
        "type": data["type"],
        "user": data["user"]
    }), 201


# Endpoint to list all events
@app.get("/events")
def list_events():

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, type, username FROM events")
            rows = cur.fetchall()

    return jsonify([
        {"id": r[0], "type": r[1], "user": r[2]}
        for r in rows
    ]), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)