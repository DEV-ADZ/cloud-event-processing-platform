from flask import Flask, request, jsonify
import os
import time
import socket
from psycopg_pool import ConnectionPool
from prometheus_flask_exporter import PrometheusMetrics


app = Flask(__name__)

# Set up Prometheus metrics for the Flask app. This will monitor the app's performance and usage.
metrics = PrometheusMetrics(app)
metrics.info("app_info", "Application info", version="1.0")


# Use the hostname as the instance ID for logging purposes. 
# This is useful when running multiple instances of the app in a containerised environment.
# Allows identification of which instance is handling each request.
INSTANCE_ID = socket.gethostname()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    # changed from localhost to db, which is the hostname of the database service in Docker Compose
    "postgresql://app:apppassword@db:5432/events"
)

# Create a connection pool for the database connections. This allows for better performance and resource management.
pool = ConnectionPool(conninfo=DATABASE_URL, min_size=1, max_size=10)



# Wait for the database to be ready before starting the app. 
# This is important when running in Docker Compose, as the app may start before the database is ready.
# So it retries to connect to the database a few times with a delay in between .
def wait_for_db(max_retries=20, delay=1):
    for i in range(max_retries):
        try:
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1;")
            return
        except Exception as e:
            print(f"DB not ready yet ({i+1}/{max_retries}): {e}")
            time.sleep(delay)
    raise RuntimeError("Database not ready after retries")


# Initialize the database and create the events table if it doesn't exist
def init_db():
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id SERIAL PRIMARY KEY,
                    type TEXT NOT NULL,
                    username TEXT NOT NULL
                )
            """)
        conn.commit()

wait_for_db()
init_db() 

@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "pod": socket.gethostname()
    }), 200
    
@app.get("/ready")
def ready():
    try:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
        return jsonify({
            "ready": True,
            "pod": socket.gethostname()
        }), 200
    except Exception as e:
        return jsonify({
            "ready": False,
            "error": str(e),
            "pod": socket.gethostname()
        }), 503

@app.post("/events")
def create_event():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json()

    if "type" not in data or "user" not in data:
        return jsonify({"error": "Missing required fields: type, user"}), 400

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO events (type, username) VALUES (%s, %s) RETURNING id",
                (data["type"], data["user"])
            )
            event_id = cur.fetchone()[0]
        conn.commit()

    return jsonify({"id": event_id, "type": data["type"], "user": data["user"]}), 201

@app.get("/events")
def list_events():
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, type, username FROM events ORDER BY id ASC")
            rows = cur.fetchall()

    return jsonify([{"id": r[0], "type": r[1], "user": r[2]} for r in rows]), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)