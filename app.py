from cs50 import SQL
from flask import Flask, render_template, redirect, request, jsonify

# Configure Flask app
app = Flask(__name__)

# Connect to sqlite db
db = SQL("sqlite:///task_manager.db")

@app.route("/")
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
    return render_template("index.html", tasks=rows)

@app.route("/create", methods=["POST"])
def create_task():
    # Can only reach this route via POST - form submission

    # Parse form data as json
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
            except ValueError:
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
def delete():
    # User can only reach this route via POST - form submission

    # Validate id
    id = request.form.get("id")
    try:
        id = int(id)
    except ValueError:
        return redirect("/")
    
    # Update tasks which are blocked by given task id - blocked by NULL
    db.execute('UPDATE "tasks" SET "blocked_by"=? WHERE "blocked_by"=?;', None, id)

    # Delete given task from db
    db.execute('DELETE FROM "tasks" WHERE "id"=?;', id)

    return redirect("/")

@app.route("/update", methods=["POST"])
def update():
    # User can only reach this route via POST

    # Validate form submitted
    id = request.form.get("id")
    title = request.form.get("title")
    description = request.form.get("description")
    due_date = request.form.get("due_date")

    # Minimal validation, since html forms will be replaced by Flutter
    if not id or not title or not description or not due_date:
        return redirect("/")
    
    status = request.form.get("status")
    if not status or status not in ["to-do", "in progress", "done"]:
        return redirect("/")
    
    #TODO: Validate blocked by id later
    blocked_by = request.form.get("blocked_by")

    # Update db
    db.execute('UPDATE "tasks" SET "title"=?, "description"=?, "due_date"=?, "status"=?, "blocked_by"=? WHERE "id"=?;',
               title, description, due_date, status, int(blocked_by) if blocked_by else None, id)
    
    return redirect("/")



    
