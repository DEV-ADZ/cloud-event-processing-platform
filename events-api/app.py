from flask import Flask, request, jsonify
import sqlite3

app = Flask(__name__)

def get_db_connection():
    conn = sqlite3.connect("events.db")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            user TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()

init_db()

@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200

@app.post("/events")
def create_event():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json()

    if "type" not in data or "user" not in data:
        return jsonify({"error": "Missing required fields"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO events (type, user) VALUES (?, ?)",
        (data["type"], data["user"])
    )
    conn.commit()

    event_id = cursor.lastrowid
    conn.close()

    return jsonify({
        "id": event_id,
        "type": data["type"],
        "user": data["user"]
    }), 201

@app.get("/events")
def list_events():
    conn = get_db_connection()
    events = conn.execute("SELECT * FROM events").fetchall()
    conn.close()

    return jsonify([dict(event) for event in events]), 200
if __name__ == "__main__":
  
    app.run(host="0.0.0.0", port=5000, debug=True)