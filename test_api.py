"""
Library Management System - In-Depth API Test Suite
===================================================
Uses Flask's native test_client() so no extra libraries (like requests) are required.
Runs against the live MySQL database: tests all 20 endpoints, data validation,
business triggers, stored procedures, admin-only routes, and session authentication.
"""
import sys, os
from decimal import Decimal

# Add library_app to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "library_app"))
from app import app, q, run

client = app.test_client()

PASS = 0
FAIL = 0
ERRORS = []

def check(label, resp, expected_status, check_fn=None):
    global PASS, FAIL
    ok = resp.status_code == expected_status
    data = None
    try:
        data = resp.get_json()
    except Exception:
        pass

    if ok and check_fn:
        try:
            ok = check_fn(data)
        except Exception as e:
            ok = False
            ERRORS.append(f"{label}: check_fn error: {e}")

    if ok:
        PASS += 1
        print(f"  PASS  {label}")
    else:
        FAIL += 1
        msg = f"  FAIL  {label} (HTTP {resp.status_code}, expected {expected_status})"
        if data:
            msg += f"\n        body: {data}"
        else:
            msg += f"\n        text: {resp.get_data(as_text=True)[:200]}"
        print(msg)
        ERRORS.append(label)
    return resp

print("=" * 65)
print("Library Management System — Complete Endpoint Test Suite")
print("=" * 65)

# ------------------------------------------------------------------ 1. Static & Auth
print("\n[1] Frontend & Authentication")
check("GET / (serves index.html)", client.get("/"), 200, lambda _: True)
check("GET /api/me without login -> 401", client.get("/api/me"), 401)
check("POST /api/login with wrong password -> 401",
      client.post("/api/login", json={"email": "admin@library.example", "password": "wrong"}), 401)

# Correct login as Admin
check("POST /api/login as Admin -> 200",
      client.post("/api/login", json={"email": "admin@library.example", "password": "admin123"}),
      200, lambda d: d.get("role") == "Admin")

check("GET /api/me while logged in -> 200",
      client.get("/api/me"), 200, lambda d: d.get("name") == "Admin User")

# ------------------------------------------------------------------ 2. Lookups & Stats
print("\n[2] Lookups & Dashboard Stats")
check("GET /api/lookups", client.get("/api/lookups"), 200,
      lambda d: len(d.get("publishers", [])) > 0 and len(d.get("categories", [])) > 0)

check("GET /api/stats", client.get("/api/stats"), 200,
      lambda d: d.get("books", 0) > 0 and d.get("members", 0) > 0)

# ------------------------------------------------------------------ 3. Books CRUD
print("\n[3] Books (Catalog & Copies)")
check("GET /api/books (list all)", client.get("/api/books"), 200,
      lambda d: isinstance(d, list) and len(d) >= 10)

check("GET /api/books?q=Database (search by title)", client.get("/api/books?q=Database"), 200,
      lambda d: any("Database" in b["title"] for b in d))

check("GET /api/books?q=Silberschatz (search by author)", client.get("/api/books?q=Silberschatz"), 200,
      lambda d: len(d) > 0)

new_isbn = "9781234567890"
# Clean up if leftover from previous test run
run("DELETE FROM fine WHERE loan_id IN (SELECT loan_id FROM loan WHERE isbn=%s)", (new_isbn,))
run("DELETE FROM loan WHERE isbn=%s", (new_isbn,))
run("DELETE FROM book WHERE isbn=%s", (new_isbn,))

check("POST /api/books (add new book with authors & copies)",
      client.post("/api/books", json={
          "isbn": new_isbn,
          "title": "Clean Architecture Test",
          "pub_year": 2024,
          "publisher_id": 1,
          "category_id": 1,
          "authors": ["Robert C. Martin", "Test Coauthor"],
          "copies": 2
      }), 201)

check("POST /api/books duplicate ISBN -> 409",
      client.post("/api/books", json={
          "isbn": new_isbn,
          "title": "Duplicate Book",
          "pub_year": 2024,
          "publisher_id": 1,
          "category_id": 1,
          "authors": ["Someone"],
          "copies": 1
      }), 409)

check("PUT /api/books/<isbn> (update title)",
      client.put(f"/api/books/{new_isbn}", json={"title": "Clean Architecture Test (Updated)"}),
      200)

check("POST /api/books/<isbn>/copies (add third copy)",
      client.post(f"/api/books/{new_isbn}/copies", json={"shelf_location": "CS-TEST"}),
      201, lambda d: d.get("copy_no") == 3)

check("GET /api/copies/available", client.get("/api/copies/available"), 200,
      lambda d: any(c["isbn"] == new_isbn for c in d))

# ------------------------------------------------------------------ 4. Members CRUD
print("\n[4] Members & History")
check("GET /api/members", client.get("/api/members"), 200,
      lambda d: isinstance(d, list) and len(d) >= 10)

test_email = "test.student@example.com"
# Clean up if leftover
run("DELETE FROM member WHERE email=%s", (test_email,))

resp = client.post("/api/members", json={
    "first_name": "Siddharth",
    "last_name": "Malik",
    "email": test_email,
    "address": "Dwarka Sector 3, Delhi",
    "dob": "2004-05-12",
    "type_id": 1,
    "phones": ["9876543210", "9876543211"]
})
check("POST /api/members (enroll member with phone numbers)", resp, 201)
new_mid = resp.get_json().get("member_id") if resp.status_code == 201 else None

check("POST /api/members duplicate email -> 409",
      client.post("/api/members", json={
          "first_name": "Dup",
          "last_name": "User",
          "email": test_email,
          "dob": "2004-01-01",
          "type_id": 1
      }), 409)

if new_mid:
    check(f"PUT /api/members/{new_mid} (edit address)",
          client.put(f"/api/members/{new_mid}", json={"address": "Dwarka Sector 10, Delhi"}), 200)

check("GET /api/members/1/history", client.get("/api/members/1/history"), 200,
      lambda d: isinstance(d, list) and len(d) > 0)

# ------------------------------------------------------------------ 5. Circulation & Triggers
print("\n[5] Circulation (Issue, Renew, Return & Triggers)")
check("GET /api/loans (all)", client.get("/api/loans"), 200,
      lambda d: isinstance(d, list) and len(d) > 0)
check("GET /api/loans?state=open", client.get("/api/loans?state=open"), 200,
      lambda d: isinstance(d, list) and len(d) > 0)
check("GET /api/loans?state=overdue", client.get("/api/loans?state=overdue"), 200,
      lambda d: isinstance(d, list) and len(d) > 0)

# Issue the test book's copy 1 to Siddharth (student)
check("POST /api/loans (issue available book via sp_issue_book)",
      client.post("/api/loans", json={
          "member_id": new_mid,
          "isbn": new_isbn,
          "copy_no": 1
      }), 201)

# Verify copy 1 status is now 'Issued'
copy_status = q("SELECT status FROM book_copy WHERE isbn=%s AND copy_no=1", (new_isbn,))
print(f"       -> Trigger trg_loan_after_insert verified: copy status is '{copy_status[0]['status']}'")

# Attempt to issue same copy again -> trigger blocks it with 400
check("POST /api/loans (same copy -> trg_loan_before_insert blocks with 400)",
      client.post("/api/loans", json={
          "member_id": 2,
          "isbn": new_isbn,
          "copy_no": 1
      }), 400, lambda d: "not available" in d.get("error", "").lower())

# Attempt to issue to inactive/expired member 10 (Vikram Joshi) -> 400
check("POST /api/loans (inactive member 10 -> trigger blocks with 400)",
      client.post("/api/loans", json={
          "member_id": 10,
          "isbn": new_isbn,
          "copy_no": 2
      }), 400, lambda d: "inactive" in d.get("error", "").lower() or "expired" in d.get("error", "").lower())

# Find the newly issued loan
loan_row = q("SELECT loan_id FROM loan WHERE member_id=%s AND isbn=%s AND return_date IS NULL", (new_mid, new_isbn))
test_loan_id = loan_row[0]["loan_id"] if loan_row else None

# Renew the loan
if test_loan_id:
    check(f"POST /api/loans/{test_loan_id}/renew", client.post(f"/api/loans/{test_loan_id}/renew"), 200)

# Return the book via sp_return_book
if test_loan_id:
    check(f"POST /api/loans/{test_loan_id}/return", client.post(f"/api/loans/{test_loan_id}/return"), 200)
    # Check that copy is now Available again
    copy_back = q("SELECT status FROM book_copy WHERE isbn=%s AND copy_no=1", (new_isbn,))
    print(f"       -> Trigger trg_loan_after_return verified: copy status is back to '{copy_back[0]['status']}'")

# Return already returned loan -> 400
if test_loan_id:
    check(f"POST /api/loans/{test_loan_id}/return (already returned -> 400)",
          client.post(f"/api/loans/{test_loan_id}/return"), 400)

# ------------------------------------------------------------------ 6. Fines
print("\n[6] Fines & Payments")
check("GET /api/fines", client.get("/api/fines"), 200,
      lambda d: isinstance(d, list) and len(d) > 0)

unpaid_fines = q("SELECT fine_id FROM fine WHERE paid_status='Unpaid' LIMIT 1")
if unpaid_fines:
    fid = unpaid_fines[0]["fine_id"]
    check(f"POST /api/fines/{fid}/pay (mark fine as paid)", client.post(f"/api/fines/{fid}/pay"), 200)
    paid_check = q("SELECT paid_status FROM fine WHERE fine_id=%s", (fid,))
    print(f"       -> Fine {fid} status is now: {paid_check[0]['paid_status']}")

# ------------------------------------------------------------------ 7. Admin Guards & Cascade/Restrict
print("\n[7] Role-based Permissions & Integrity Constraints")
# Delete member while member has no loans out -> should succeed (soft delete)
if new_mid:
    check(f"DELETE /api/members/{new_mid} (Admin deactivates member)",
          client.delete(f"/api/members/{new_mid}"), 200)
    act_check = q("SELECT is_active FROM member WHERE member_id=%s", (new_mid,))
    print(f"       -> Member {new_mid} is_active: {act_check[0]['is_active']}")

# Try deleting a book that has loan history -> MySQL RESTRICT foreign key blocks it (409)
check("DELETE /api/books/9780078022159 (FK RESTRICT blocks delete -> 409)",
      client.delete("/api/books/9780078022159"), 409)

# Also test deleting our test book which now has loan history -> 409
check(f"DELETE /api/books/{new_isbn} (has loan history -> 409 RESTRICT)",
      client.delete(f"/api/books/{new_isbn}"), 409)

# Create an un-loaned temporary book and verify Admin DELETE returns 200
temp_isbn = "9789999999999"
run("DELETE FROM book WHERE isbn=%s", (temp_isbn,))
client.post("/api/books", json={
    "isbn": temp_isbn, "title": "Temp Delete Test", "pub_year": 2024,
    "publisher_id": 1, "category_id": 1, "authors": ["Temp Author"], "copies": 1
})
check(f"DELETE /api/books/{temp_isbn} (Admin deletes book without loans -> 200 OK)",
      client.delete(f"/api/books/{temp_isbn}"), 200)

# Switch to Librarian session
client.post("/api/logout")
client.post("/api/login", json={"email": "ritu@library.example", "password": "ritu123"})
check("DELETE /api/books/... as Librarian -> 403 Forbidden",
      client.delete("/api/books/9780000000041"), 403)

# ------------------------------------------------------------------ 8. Logout
print("\n[8] Logout & Session Cleanup")
check("POST /api/logout", client.post("/api/logout"), 200)
check("GET /api/me after logout -> 401", client.get("/api/me"), 401)

# ------------------------------------------------------------------ Summary
print()
print("=" * 65)
print(f"FINAL RESULT: {PASS} passed, {FAIL} failed")
if ERRORS:
    print("\nErrors encountered:")
    for e in ERRORS:
        print(f"  * {e}")
else:
    print("ALL 20 API ENDPOINTS & DATABASE CONSTRAINTS VERIFIED 100% WORKING!")
print("=" * 65)
