from flask import Flask, request, jsonify
import os
import psycopg

app = Flask(__name__)


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://app:apppassword@localhost:5432/events"
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