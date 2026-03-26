from cs50 import SQL
from flask import Flask, render_template, redirect, request

# Configure Flask app
app = Flask(__name__)

# Connect to sqlite db
db = SQL("sqlite:///task_manager.db")

@app.route("/")
def index():
    # Get all tasks from db
    rows = db.execute('SELECT * FROM "tasks";')
    return render_template("index.html", tasks=rows)