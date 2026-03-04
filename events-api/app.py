from flask import Flask, request, jsonify

app = Flask(__name__)

# In-memory storage for Day 1 (will become SQLite on Day 2)
EVENTS = []

@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200

@app.post("/events")
def create_event():
    # Ensure client sent JSON
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json()

    # Basic validation (Day 1 level)
    if not isinstance(data, dict):
        return jsonify({"error": "JSON body must be an object"}), 400

    # Add a simple server-side id
    event_id = len(EVENTS) + 1
    data["id"] = event_id

    EVENTS.append(data)
    return jsonify(data), 201

@app.get("/events")
def list_events():
    return jsonify(EVENTS), 200

if __name__ == "__main__":
    # host=0.0.0.0 makes it reachable from outside the machine later (docker/k8s)
    app.run(host="0.0.0.0", port=5000, debug=True)