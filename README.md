# Task Manager App

## 📌 Overview

A full-stack task management application built with:

* **Backend**: Python (Flask)
* **Frontend**: Flutter (Dart)

The app allows users to create, view, update, and delete tasks, with additional features like search, filtering, dependency tracking, and UI-based state handling.

---

## 🚀 Features

### Core Features

* Create, Read, Update, Delete (CRUD) tasks
* Each task contains:

  * Title
  * Description
  * Due Date
  * Status (To-Do, In Progress, Done)
  * Blocked By (optional dependency)

### UI / UX Features

* Search tasks by title
* Filter tasks by status
* Highlight matching search text
* Debounced search (300ms delay)
* Visual indication for blocked tasks (greyed out)

### State Handling

* Draft persistence for task creation
* Loading indicators with simulated delay (2 seconds)
* Prevention of duplicate submissions

---

## 🧱 Project Structure

```
repo/
  backend/
    app.py
    task_manager.db
    schema/
  frontend/
    task_manager/
      lib/
      pubspec.yaml
```

---

## ⚙️ Setup Instructions

### 1. Clone the repository

```
git clone <your-repo-url>
cd <repo-name>
```

---

### 2. Backend Setup (Flask)

```
cd backend
python3 -m venv .venv
source .venv/bin/activate   
pip install -r requirements.txt
```

Run the server:

```
flask run --debug
```

The backend will run at:

```
http://localhost:5000
```

---

### 3. Frontend Setup (Flutter)

```
cd frontend/task_manager
flutter pub get
```

Run the app (web):

```
flutter run -d chrome
```

---

## 🧪 API Endpoints

* `GET /tasks` → Fetch all tasks
* `POST /create` → Create a task
* `POST /update` → Update a task
* `POST /delete` → Delete a task

All endpoints accept and return JSON.

---

## 🧩 Track Selection

**Track A: Full Stack**

* Backend implemented using Flask
* Frontend implemented using Flutter

---

## ⭐ Stretch Goal

**Debounced Autocomplete Search with Highlighting**

* Search input is debounced (300ms)
* Matching text in task titles is highlighted in the UI

---

## 🤖 AI Usage Report

### Tools Used

* ChatGPT

---

### Frontend (Flutter + Dart)

I used AI as a learning and implementation aid.

AI helped with:

* Understanding Flutter widget structure
* Implementing UI components (forms, dialogs, lists)
* Managing state (`setState`, async handling)

---

## 📝 Notes

* The `blocked_by` feature is implemented with:

  * Foreign key constraints in the database
  * UI dropdown selection in Flutter
  * Visual distinction for blocked tasks


---

## ✅ Summary

This project demonstrates:

* Full-stack development
* REST API design
* UI/UX considerations
* State management in Flutter
* Clean separation of concerns

---
