# Reading Room — Library Management System (DBMS Project)

A complete, production-grade Library Management System built with a normalized relational MySQL database (3NF/BCNF), a Flask REST backend, and a modern web interface.

---

## 🌟 Key Features

- **Relational Schema (13 Tables in 3NF/BCNF):** Complete coverage of books, authors, publishers, copies, members, loans, fines, and reservations.
- **Business Integrity via Triggers:**
  - `trg_loan_before_insert`: Enforces borrow limits, active membership verification, and prevents borrowing unavailable copies.
  - `trg_loan_after_insert`: Automatically transitions copy status from `Available` to `Issued`.
  - `trg_loan_after_return`: Automatically frees copies on check-in and calculates dynamic late fees based on member category (`Student` vs `Faculty`).
- **Transactional Procedures:** `sp_issue_book` and `sp_return_book` with concurrency locking (`SELECT ... FOR UPDATE`).
- **Role-Based Access Control (RBAC):**
  - **Librarian:** Catalog browsing, book issuing, loan renewal, check-in, and fine settlement.
  - **Administrator:** Full privileges including catalog deletions and member deactivation.
- **Automated Verification:** Comprehensive test suite with 38 passing unit/integration tests (`test_api.py`).

---

## 🚀 Quick Setup Guide (For Friends & Contributors)

### 1. Prerequisites
- **Git** installed on your system.
- **Python 3.10+**
- **MySQL Server 8.0+** (or MariaDB / XAMPP) running on `localhost:3306`.

---

### 2. Clone the Repository
```bash
git clone <YOUR-GITHUB-REPO-URL>
cd "DBMS Project"
```

---

### 3. Database & App Setup

#### Windows (One-Click)
Simply double-click:
```bat
setup.bat
```
This automatically finds your MySQL installation, loads the schema and sample data, installs dependencies, and creates staff accounts.

#### Manual Setup
1. **Load SQL Files:**
   ```bash
   mysql -u root -p < library_ddl.sql
   mysql -u root -p < library_data.sql
   ```
2. **Install Python Packages:**
   ```bash
   cd library_app
   pip install -r requirements.txt
   ```
3. **Start the Web Desk:**
   ```bash
   python app.py
   ```
4. **Open in Browser:** [http://localhost:5000](http://localhost:5000)

---

## 🔐 Default Credentials

| Role | Email | Password |
| :--- | :--- | :--- |
| **Administrator** | `admin@library.example` | `admin123` |
| **Librarian** | `ritu@library.example` | `ritu123` |
| **Librarian** | `sameer@library.example` | `sameer123` |

---

## 🧪 Running the Automated Test Suite

To verify that all 20 API endpoints and database triggers are 100% operational:
```bash
python test_api.py
```
*(All 38 test assertions will run and report status).*

---

## 📁 Project Structure

```
.
├── library_ddl.sql           # Complete schema, triggers, views, and procedures (CLI)
├── library_ddl_workbench.sql # Workbench-friendly DDL without DELIMITER
├── library_data.sql          # Seed dataset with 11 books, 10 members, 16 loans
├── library_queries.sql       # Complex DBMS queries (Division, Group By, Indexes)
├── test_api.py               # 38-case API & database test suite
├── setup.bat                 # One-click Windows setup script
├── start_mysql.bat           # Quick launcher for local MySQL instance
└── library_app/
    ├── app.py                # Flask application & 20 REST endpoints
    ├── requirements.txt      # Python dependencies
    └── static/
        └── index.html        # Single-page web desk interface
```
