"""Library Management System - Flask + MySQL backend (Phase 4).
Run:  python app.py            (serves API + frontend on :5000)
      python app.py set-password <staff_email> <password>
"""
import os, sys, functools, secrets
from contextlib import contextmanager
from decimal import Decimal
import pymysql
from flask import Flask, jsonify, request, session, send_from_directory
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__, static_folder="static")

# ------------------------------------------------------------------ Fix #7
# Stable secret key for sessions.
# Priority: 1) SECRET_KEY env var  2) .secret_key file  3) generate & save one.
# This ensures sessions survive server restarts without requiring env var setup.
def _load_secret_key():
    env_key = os.environ.get("SECRET_KEY")
    if env_key:
        return env_key                          # env var wins (production)

    key_file = os.path.join(os.path.dirname(__file__), ".secret_key")
    if os.path.exists(key_file):
        with open(key_file, "r") as f:
            saved = f.read().strip()
            if saved:
                return saved                    # reuse previously generated key

    # First run: generate a strong key and persist it next to app.py
    new_key = secrets.token_hex(32)
    try:
        with open(key_file, "w") as f:
            f.write(new_key)
    except OSError:
        pass                                    # read-only FS; fall back gracefully
    return new_key

app.secret_key = _load_secret_key()

app.json.default = lambda o: (o.isoformat() if hasattr(o, "isoformat")
                              else float(o) if isinstance(o, Decimal) else str(o))


def db():
    """Open a fresh database connection using env vars or sensible defaults."""
    return pymysql.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        user=os.environ.get("DB_USER", "root"),
        password=os.environ.get("DB_PASSWORD", ""),
        database=os.environ.get("DB_NAME", "library_db"),
        cursorclass=pymysql.cursors.DictCursor)


@contextmanager
def tx():
    """One connection = one transaction: commit on success, rollback on error."""
    con = db()
    try:
        with con.cursor() as cur:
            yield cur
        con.commit()
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()


def q(sql, args=()):
    """Run a SELECT and return all rows as a list of dicts."""
    with tx() as cur:
        cur.execute(sql, args)
        return cur.fetchall()


def run(sql, args=()):
    """Run an INSERT/UPDATE/DELETE and return affected row count."""
    with tx() as cur:
        cur.execute(sql, args)
        return cur.rowcount


def need(role=None):
    """Decorator: require a logged-in session, optionally with a specific role."""
    def deco(f):
        @functools.wraps(f)
        def wrap(*a, **k):
            if "staff_id" not in session:
                return jsonify(error="Please log in"), 401
            if role and session.get("role") != role:
                return jsonify(error="Admins only"), 403
            return f(*a, **k)
        return wrap
    return deco


@app.errorhandler(pymysql.MySQLError)
def db_error(e):
    """Convert MySQL errors into clean JSON error responses."""
    code = e.args[0] if e.args else 0
    msg = e.args[1] if len(e.args) > 1 else str(e)
    if code == 1644:                      # SIGNAL messages from triggers/procs
        return jsonify(error=msg), 400
    if code == 1451:
        return jsonify(error="Has history and cannot be deleted. Deactivate or mark it lost instead."), 409
    if code == 1062:
        return jsonify(error="That value already exists (duplicate ISBN or email)."), 409
    if code in (3819, 4025, 1452, 1048, 1406):
        return jsonify(error="Invalid value: " + str(msg)), 400
    return jsonify(error="Database error: " + str(msg)), 500


# -------------------------------------------------- auth
@app.post("/api/login")
def login():
    d = request.json or {}
    rows = q("SELECT * FROM staff WHERE email=%s", (d.get("email", ""),))
    if not rows or not check_password_hash(rows[0]["password_hash"], d.get("password", "")):
        return jsonify(error="Wrong email or password"), 401
    s = rows[0]
    session.update(staff_id=s["staff_id"], role=s["role"], name=s["name"])
    return jsonify(name=s["name"], role=s["role"])


@app.post("/api/logout")
def logout():
    session.clear()
    return jsonify(ok=True)


@app.get("/api/me")
def me():
    if "staff_id" not in session:
        return jsonify(error="Please log in"), 401
    return jsonify(name=session["name"], role=session["role"])


# -------------------------------------------------- lookups & stats
@app.get("/api/lookups")
@need()
def lookups():
    return jsonify(
        publishers=q("SELECT publisher_id id, name FROM publisher ORDER BY name"),
        categories=q("SELECT category_id id, name FROM category ORDER BY name"),
        types=q("SELECT type_id id, type_name name FROM membership_type"))


@app.get("/api/stats")
@need()
def stats():
    r = q("""SELECT (SELECT COUNT(*) FROM book) books,
                    (SELECT COUNT(*) FROM book_copy) copies,
                    (SELECT COUNT(*) FROM member WHERE is_active) members,
                    (SELECT COUNT(*) FROM loan WHERE return_date IS NULL) open_loans,
                    (SELECT COUNT(*) FROM v_overdue_loans) overdue,
                    (SELECT COALESCE(SUM(amount),0) FROM fine WHERE paid_status='Unpaid') unpaid""")
    return jsonify(r[0])


# -------------------------------------------------- books (CRUD)
@app.get("/api/books")
@need()
def books():
    like = "%" + request.args.get("q", "") + "%"
    return jsonify(q("""
        SELECT b.isbn, b.title, b.pub_year, p.name publisher, c.name category,
          (SELECT GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ')
             FROM book_author ba JOIN author a ON a.author_id=ba.author_id WHERE ba.isbn=b.isbn) authors,
          (SELECT COUNT(*) FROM book_copy WHERE isbn=b.isbn) copies,
          (SELECT COUNT(*) FROM book_copy WHERE isbn=b.isbn AND status='Available') available
        FROM book b JOIN publisher p ON p.publisher_id=b.publisher_id
                    JOIN category c ON c.category_id=b.category_id
        WHERE b.title LIKE %s OR c.name LIKE %s OR b.isbn LIKE %s OR EXISTS (
              SELECT 1 FROM book_author ba JOIN author a ON a.author_id=ba.author_id
              WHERE ba.isbn=b.isbn AND a.name LIKE %s)
        ORDER BY b.title""", (like, like, like, like)))


@app.post("/api/books")
@need()
def add_book():
    d = request.json
    with tx() as cur:
        cur.execute("INSERT INTO book (isbn,title,pub_year,publisher_id,category_id) VALUES (%s,%s,%s,%s,%s)",
                    (d["isbn"], d["title"], d.get("pub_year") or None, d["publisher_id"], d["category_id"]))
        for name in {n.strip() for n in d.get("authors", []) if n.strip()}:
            cur.execute("SELECT author_id FROM author WHERE name=%s LIMIT 1", (name,))
            row = cur.fetchone()
            if row:
                aid = row["author_id"]
            else:
                cur.execute("INSERT INTO author (name) VALUES (%s)", (name,))
                aid = cur.lastrowid
            cur.execute("INSERT INTO book_author (isbn,author_id) VALUES (%s,%s)", (d["isbn"], aid))
        for n in range(1, int(d.get("copies", 1)) + 1):
            cur.execute("INSERT INTO book_copy (isbn,copy_no) VALUES (%s,%s)", (d["isbn"], n))
    return jsonify(ok=True), 201


@app.put("/api/books/<isbn>")
@need()
def edit_book(isbn):
    d = request.json
    run("UPDATE book SET title=COALESCE(%s,title), pub_year=COALESCE(%s,pub_year) WHERE isbn=%s",
        (d.get("title"), d.get("pub_year"), isbn))
    return jsonify(ok=True)


@app.delete("/api/books/<isbn>")
@need("Admin")
def del_book(isbn):
    run("DELETE FROM book WHERE isbn=%s", (isbn,))
    return jsonify(ok=True)


@app.post("/api/books/<isbn>/copies")
@need()
def add_copy(isbn):
    with tx() as cur:
        cur.execute("SELECT COALESCE(MAX(copy_no),0)+1 n FROM book_copy WHERE isbn=%s FOR UPDATE", (isbn,))
        n = cur.fetchone()["n"]
        cur.execute("INSERT INTO book_copy (isbn,copy_no,shelf_location) VALUES (%s,%s,%s)",
                    (isbn, n, (request.json or {}).get("shelf_location")))
    return jsonify(copy_no=n), 201


@app.get("/api/copies/available")
@need()
def avail_copies():
    return jsonify(q("""SELECT b.isbn, b.title, bc.copy_no FROM book_copy bc
                        JOIN book b ON b.isbn=bc.isbn WHERE bc.status='Available'
                        ORDER BY b.title, bc.copy_no"""))


# -------------------------------------------------- members (CRUD, soft delete)
@app.get("/api/members")
@need()
def members():
    return jsonify(q("""SELECT m.member_id, m.first_name, m.last_name, m.email, m.address,
                               m.expiry_date, m.is_active, t.type_name,
                               (SELECT COUNT(*) FROM loan l WHERE l.member_id=m.member_id AND l.return_date IS NULL) books_out
                        FROM member m JOIN membership_type t ON t.type_id=m.type_id
                        ORDER BY m.first_name"""))


@app.post("/api/members")
@need()
def add_member():
    d = request.json
    with tx() as cur:
        cur.execute("""INSERT INTO member (first_name,last_name,email,address,dob,join_date,expiry_date,type_id)
                       VALUES (%s,%s,%s,%s,%s,CURRENT_DATE,DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR),%s)""",
                    (d["first_name"], d["last_name"], d["email"], d.get("address"), d["dob"], d["type_id"]))
        mid = cur.lastrowid
        for ph in {p.strip() for p in d.get("phones", []) if p.strip()}:
            cur.execute("INSERT INTO member_phone (member_id,phone) VALUES (%s,%s)", (mid, ph))
    return jsonify(member_id=mid), 201


@app.put("/api/members/<int:mid>")
@need()
def edit_member(mid):
    d = request.json
    run("""UPDATE member SET email=COALESCE(%s,email), address=COALESCE(%s,address),
           type_id=COALESCE(%s,type_id) WHERE member_id=%s""",
        (d.get("email"), d.get("address"), d.get("type_id"), mid))
    return jsonify(ok=True)


@app.delete("/api/members/<int:mid>")
@need("Admin")
def deactivate_member(mid):
    if q("SELECT 1 FROM loan WHERE member_id=%s AND return_date IS NULL LIMIT 1", (mid,)):
        return jsonify(error="Member still has books out"), 400
    run("UPDATE member SET is_active=FALSE WHERE member_id=%s", (mid,))
    return jsonify(ok=True)


@app.get("/api/members/<int:mid>/history")
@need()
def history(mid):
    return jsonify(q("""SELECT b.title, l.issue_date, l.due_date, l.return_date
                        FROM loan l JOIN book b ON b.isbn=l.isbn
                        WHERE l.member_id=%s ORDER BY l.issue_date DESC""", (mid,)))


# -------------------------------------------------- loans
@app.get("/api/loans")
@need()
def loans():
    cond = {"open": "l.return_date IS NULL",
            "overdue": "l.return_date IS NULL AND l.due_date < CURRENT_DATE"}.get(request.args.get("state"), "1=1")
    return jsonify(q(f"""SELECT l.loan_id, b.title, l.copy_no, l.due_date, l.return_date,
                                CONCAT(m.first_name,' ',m.last_name) AS `member`
                         FROM loan l JOIN book b ON b.isbn=l.isbn
                                     JOIN `member` m ON m.member_id=l.member_id
                         WHERE {cond} ORDER BY l.due_date"""))


@app.post("/api/loans")
@need()
def issue():
    d = request.json
    run("CALL sp_issue_book(%s,%s,%s,%s)", (d["member_id"], d["isbn"], d["copy_no"], session["staff_id"]))
    return jsonify(ok=True), 201


@app.post("/api/loans/<int:lid>/return")
@need()
def give_back(lid):
    run("CALL sp_return_book(%s)", (lid,))
    return jsonify(ok=True)


@app.post("/api/loans/<int:lid>/renew")
@need()
def renew(lid):
    n = run("""UPDATE loan l JOIN member m ON m.member_id=l.member_id
               JOIN membership_type t ON t.type_id=m.type_id
               SET l.due_date = DATE_ADD(l.due_date, INTERVAL t.loan_days DAY)
               WHERE l.loan_id=%s AND l.return_date IS NULL AND l.due_date >= CURRENT_DATE
                 AND NOT EXISTS (SELECT 1 FROM reservation r WHERE r.isbn=l.isbn
                                 AND r.status='Active' AND r.member_id<>l.member_id)""", (lid,))
    if n == 0:
        return jsonify(error="Cannot renew: already returned, overdue, or reserved by someone else"), 400
    return jsonify(ok=True)


# -------------------------------------------------- fines
@app.get("/api/fines")
@need()
def fines():
    return jsonify(q("""SELECT f.fine_id, f.amount, f.paid_status, b.title,
                               CONCAT(m.first_name,' ',m.last_name) AS `member`
                        FROM fine f JOIN loan l ON l.loan_id=f.loan_id
                        JOIN book b ON b.isbn=l.isbn JOIN `member` m ON m.member_id=l.member_id
                        ORDER BY f.paid_status DESC, f.fine_id DESC"""))


@app.post("/api/fines/<int:fid>/pay")
@need()
def pay(fid):
    run("UPDATE fine SET paid_status='Paid' WHERE fine_id=%s", (fid,))
    return jsonify(ok=True)


@app.get("/")
def home():
    return send_from_directory("static", "index.html")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "set-password":
        n = run("UPDATE staff SET password_hash=%s WHERE email=%s",
                (generate_password_hash(sys.argv[3]), sys.argv[2]))
        print("Password updated" if n else "No staff member with that email")
    else:
        app.run(debug=True, port=5000)

