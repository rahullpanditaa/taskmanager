from cs50 import SQL
from flask import Flask, render_template, redirect, request

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

    # Validate title, description, due_date
    title = request.form.get("title")
    description = request.form.get("description")
    due_date = request.form.get("due_date")
    blocked_by = request.form.get("blocked_by")
    if not title or description or due_date:
        return redirect("/")

    # Insert task into db
    if blocked_by:
        blocked_by = int(blocked_by)
    db.execute('INSERT INTO "tasks" ("title", "description", "due_date", "status", "blocked_by") VALUES (?, ?, ?, ?, ?);',
               title, description, due_date, "to-do", blocked_by if blocked_by else None)
    
    return redirect("/")
