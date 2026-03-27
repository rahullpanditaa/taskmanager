from cs50 import SQL
from flask import Flask, request, jsonify

# Configure Flask app
app = Flask(__name__)

# Connect to sqlite db
db = SQL("sqlite:///task_manager.db")

@app.route("/tasks")
def index():
    # Get all tasks from db
    rows = db.execute("""
                    SELECT
                        t.id,
                      t.title,
                      t.description,
                      t.due_date,
                      t.status,
                      t.blocked_by,
                      b.title AS blocked_by_title
                    FROM tasks t
                    LEFT JOIN tasks b
                    ON t.blocked_by = b.id;
                      """)
    return jsonify(rows), 200

@app.route("/create", methods=["POST"])
def create_task():
    # Can only reach this route via POST

    # Parse data as json
    if request.is_json:
        # Get json data -> dict
        data: dict = request.get_json()

        # Validate form input
        title = data.get("title")
        description = data.get("description")
        due_date = data.get("due_date")
        blocked_by = data.get("blocked_by")

        # Validate title, description, due_date
        if not title or not description or not due_date:
            return jsonify({"error": "Invalid input"}), 400
        
        # Validate blocked by
        if blocked_by:
            try:
                blocked_by = int(blocked_by)
            except (ValueError, TypeError):
                return jsonify({"error": "Invalid blocked_by"}), 400
        else:
            blocked_by = None

        # Insert into db
        id = db.execute('INSERT INTO "tasks" ("title", "description", "due_date", "status", "blocked_by") VALUES (?, ?, ?, ?, ?);',
               title, description, due_date, "to-do", blocked_by)
        
        # return response
        return jsonify({
            "id": id,
            "title": title,
            "description": description,
            "due_date": due_date,
            "status": "to-do",
            "blocked_by": blocked_by
        }), 201
    else:
        return jsonify({"error": "Content-Type must be application/json"}), 415

@app.route("/delete", methods=["POST"])
def delete_task():
    # User can only reach this route via POST

    if request.is_json:
        data: dict = request.get_json()

        # Validate id
        id = data.get("id")
        try:
            id = int(id)
        except (ValueError, TypeError):
            return jsonify({"error": "Invalid task id"}), 400
        
        # Update tasks which are blocked by given task id - set blocked by to NULL
        db.execute('UPDATE "tasks" SET "blocked_by"=? WHERE "blocked_by"=?;', None, id)

        # Delete task from db
        rows = db.execute('DELETE FROM "tasks" WHERE "id"=?;', id)
        
        # If no rows were deleted
        if rows == 0:
            return jsonify({"error": "Task not found"}), 404
        
        # return response
        return jsonify({"message": "Task deleted"}), 200
    
    else:
        return jsonify({"error": "Content-Type must be application/json"}), 415

@app.route("/update", methods=["POST"])
def update_task():
    # User can only reach this route via POST

    if request.is_json:
        data: dict = request.get_json()

        # Validate id
        id = data.get("id")
        try:
            id = int(id)
        except (ValueError, TypeError):
            return jsonify({"error": "Invalid task id"}), 400
        
        # Validate other fields
        title = data.get("title")
        description = data.get("description")
        due_date = data.get("due_date")

        if not title or not description or not due_date:
            return jsonify({"error": "Missing fields"}), 400
        
        # Validate status
        status = data.get("status")
        if status not in ["to-do", "in progress", "done"]:
            return jsonify({"error": "Invalid status"}), 400
        
        # Validate blocked by
        blocked_by = data.get("blocked_by")
        if blocked_by:
            try:
                blocked_by = int(blocked_by)
            except (ValueError, TypeError):
                return jsonify({"error": "Invalid blocked_by"}), 400
        else:
            blocked_by = None
        
        # Update db
        rows = db.execute('UPDATE "tasks" SET "title"=?, "description"=?, "due_date"=?, "status"=?, "blocked_by"=? WHERE "id"=?;',
                            title, description, due_date, status, blocked_by, id)

        # If no rows were updated
        if rows == 0:
            return jsonify({"error": "Task not found"}), 404
        
        # return updated task json
        return jsonify({
            "id": id,
            "title": title,
            "description": description,
            "due_date": due_date,
            "status": status,
            "blocked_by": blocked_by
        }), 200
    else:
        return jsonify({"error": "Content-Type must be application/json"}), 415