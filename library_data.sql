-- ============================================================
-- Library Management System : Bulk Sample Data
-- Fix #4 & #5: Safe to run or re-run at any time.
--   Uses explicit primary keys and safe cleanup so that IDs
--   never shift and foreign key constraints never fail.
-- Fix #6: Includes pre-hashed passwords for all staff
--   (Admin: admin123 | Librarians: ritu123, sameer123).
-- ============================================================
USE library_db;

-- ------------------------------------------------------------
-- Safe cleanup: delete in reverse-dependency order
-- ------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM fine;
DELETE FROM reservation;
DELETE FROM loan;
DELETE FROM member_phone;
DELETE FROM member;
DELETE FROM book_copy;
DELETE FROM book_author;
DELETE FROM book;
DELETE FROM staff;
DELETE FROM author;
DELETE FROM category;
DELETE FROM publisher;
DELETE FROM membership_type;
SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------
-- 1. Membership Types
-- ------------------------------------------------------------
INSERT INTO membership_type (type_id, type_name, max_books, loan_days, fine_per_day) VALUES
 (1, 'Student', 3, 14, 2.00),
 (2, 'Faculty', 6, 30, 1.00);

-- ------------------------------------------------------------
-- 2. Publishers (1 to 5)
-- ------------------------------------------------------------
INSERT INTO publisher (publisher_id, name, email) VALUES
 (1, 'Pearson',        'contact@pearson.example'),
 (2, 'McGraw Hill',    'info@mcgrawhill.example'),
 (3, 'MIT Press',       'press@mit.example'),
 (4, 'Penguin Books',   'info@penguin.example'),
 (5, 'Bharati Bhawan',  'sales@bharati.example');

-- ------------------------------------------------------------
-- 3. Categories (1 to 5)
-- ------------------------------------------------------------
INSERT INTO category (category_id, name) VALUES
 (1, 'Computer Science'),
 (2, 'Mathematics'),
 (3, 'Fiction'),
 (4, 'Physics'),
 (5, 'History');

-- ------------------------------------------------------------
-- 4. Authors (1 to 14)
-- ------------------------------------------------------------
INSERT INTO author (author_id, name) VALUES
 (1,  'Abraham Silberschatz'),
 (2,  'Henry F. Korth'),
 (3,  'S. Sudarshan'),
 (4,  'Thomas H. Cormen'),
 (5,  'Ramez Elmasri'),
 (6,  'Andrew S. Tanenbaum'),
 (7,  'Herbert Schildt'),
 (8,  'H. C. Verma'),
 (9,  'Yuval Noah Harari'),
 (10, 'George Orwell'),
 (11, 'Kenneth H. Rosen'),
 (12, 'Erwin Kreyszig'),
 (13, 'Peter B. Galvin'),
 (14, 'Greg Gagne');

-- ------------------------------------------------------------
-- 5. Staff (with pre-hashed passwords for instant login)
--    admin@library.example  -> admin123
--    ritu@library.example   -> ritu123
--    sameer@library.example -> sameer123
-- ------------------------------------------------------------
INSERT INTO staff (staff_id, name, email, role, password_hash) VALUES
 (1, 'Admin User',    'admin@library.example',  'Admin',     'scrypt:32768:8:1$7bgArTJAA1eypqoE$90ef7a9fda5175280eb2d4a81e005857fcd93c90a15dd8139ce0fb9615fecef61de105bc1e8f43ec23240652bdd41da2a47d8052ee6b7ce0fcd115d0db748403'),
 (2, 'Ritu Malhotra', 'ritu@library.example',   'Librarian', 'scrypt:32768:8:1$ab9OMaJcJd3PVHJw$be43288e2e3b44c9819bcb92b35d0e28a9e8130c3dc2d3c573893d4c5080d7f34f4722d761991294508ed83ed774ac02764a6d686c4fee332599a713aea784e0'),
 (3, 'Sameer Khan',   'sameer@library.example', 'Librarian', 'scrypt:32768:8:1$4rt6aBbwt6OvcUBB$d41dde9fad272d49f53d363bdbee39b3b4d44f680a72da62749ff6d39c962fcf394bf3708fff1640859caea6b2c7496d94e74e4e1ae5522f2aa21f02fc66a337');

-- ------------------------------------------------------------
-- 6. Books (11 titles)
-- ------------------------------------------------------------
INSERT INTO book (isbn, title, pub_year, publisher_id, category_id) VALUES
 ('9780078022159', 'Database System Concepts',                 2019, 2, 1),
 ('9780262046305', 'Introduction to Algorithms',               2022, 3, 1),
 ('9780133970777', 'Fundamentals of Database Systems',         2015, 1, 1),
 ('9780000000041', 'Operating System Concepts',                2018, 2, 1),
 ('9780000000052', 'Computer Networks',                        2010, 1, 1),
 ('9780000000063', 'Discrete Mathematics and Its Applications',2018, 2, 2),
 ('9780000000074', 'Advanced Engineering Mathematics',        2011, 1, 2),
 ('9780000000085', 'Concepts of Physics',                     2017, 5, 4),
 ('9780000000096', 'Sapiens',                                 2015, 4, 5),
 ('9780000000107', 'Nineteen Eighty-Four',                    1949, 4, 3),
 ('9780000000118', 'Java: The Complete Reference',            2021, 2, 1);

-- ------------------------------------------------------------
-- 7. Book Authors (Junction table)
-- ------------------------------------------------------------
INSERT INTO book_author (isbn, author_id) VALUES
 ('9780078022159', 1), ('9780078022159', 2), ('9780078022159', 3),
 ('9780262046305', 4),
 ('9780133970777', 5),
 ('9780000000041', 1), ('9780000000041', 13), ('9780000000041', 14),
 ('9780000000052', 6),
 ('9780000000063', 11),
 ('9780000000074', 12),
 ('9780000000085', 8),
 ('9780000000096', 9),
 ('9780000000107', 10),
 ('9780000000118', 7);

-- ------------------------------------------------------------
-- 8. Book Copies (all initially Available)
-- ------------------------------------------------------------
INSERT INTO book_copy (isbn, copy_no, status, shelf_location) VALUES
 ('9780078022159', 1, 'Available', 'CS-A1'),
 ('9780078022159', 2, 'Available', 'CS-A1'),
 ('9780262046305', 1, 'Available', 'CS-B2'),
 ('9780262046305', 2, 'Available', 'CS-B2'),
 ('9780133970777', 1, 'Available', 'CS-A3'),
 ('9780000000041', 1, 'Available', 'CS-C1'),
 ('9780000000041', 2, 'Available', 'CS-C1'),
 ('9780000000041', 3, 'Available', 'CS-C1'),
 ('9780000000052', 1, 'Available', 'CS-C2'),
 ('9780000000052', 2, 'Available', 'CS-C2'),
 ('9780000000063', 1, 'Available', 'MA-A1'),
 ('9780000000063', 2, 'Available', 'MA-A1'),
 ('9780000000074', 1, 'Available', 'MA-A2'),
 ('9780000000074', 2, 'Available', 'MA-A2'),
 ('9780000000085', 1, 'Available', 'PH-A1'),
 ('9780000000085', 2, 'Available', 'PH-A1'),
 ('9780000000096', 1, 'Available', 'HI-A1'),
 ('9780000000096', 2, 'Available', 'HI-A1'),
 ('9780000000107', 1, 'Available', 'FI-A1'),
 ('9780000000107', 2, 'Available', 'FI-A1'),
 ('9780000000118', 1, 'Available', 'CS-C3'),
 ('9780000000118', 2, 'Available', 'CS-C3');

-- ------------------------------------------------------------
-- 9. Members (1 to 10)
-- ------------------------------------------------------------
INSERT INTO member (member_id, first_name, last_name, email, address, dob, join_date, expiry_date, is_active, type_id) VALUES
 (1,  'Aarav',  'Sharma', 'aarav@example.com',  'Dwarka, Delhi',      '2005-03-14', '2026-01-01', '2027-01-01', TRUE,  1),
 (2,  'Neha',   'Verma',  'neha@example.com',   'Uttam Nagar, Delhi', '2004-11-02', '2026-01-01', '2027-01-01', TRUE,  1),
 (3,  'Rohan',  'Mehta',  'rohan@example.com',  'Janakpuri, Delhi',   '2005-06-21', '2026-01-01', '2027-01-01', TRUE,  1),
 (4,  'Priya',  'Singh',  'priya@example.com',  'Dwarka, Delhi',      '2004-09-10', '2026-01-01', '2027-01-01', TRUE,  1),
 (5,  'Karan',  'Gupta',  'karan@example.com',  'Uttam Nagar, Delhi', '2005-01-30', '2026-01-01', '2027-01-01', TRUE,  1),
 (6,  'Anil',   'Kapoor', 'anil.k@example.com', 'Rohini, Delhi',      '1980-04-12', '2025-06-01', '2027-06-01', TRUE,  2),
 (7,  'Sunita', 'Iyer',   'sunita@example.com', 'Pitampura, Delhi',   '1985-12-05', '2025-06-01', '2027-06-01', TRUE,  2),
 (8,  'Simran', 'Kaur',   'simran@example.com', 'Vikaspuri, Delhi',   '2005-08-17', '2026-01-01', '2027-01-01', TRUE,  1),
 (9,  'Aditya', 'Rao',    'aditya@example.com', 'Najafgarh, Delhi',   '2004-02-25', '2026-01-01', '2027-01-01', TRUE,  1),
 (10, 'Vikram', 'Joshi',  'vikram@example.com', 'Palam, Delhi',       '2002-10-08', '2023-01-01', '2024-12-31', FALSE, 1);

-- ------------------------------------------------------------
-- 10. Member Phones
-- ------------------------------------------------------------
INSERT INTO member_phone (member_id, phone) VALUES
 (1, '9000000001'), (1, '9000000002'), (2, '9000000003'),
 (3, '9000000004'), (4, '9000000005'), (4, '9000000006'),
 (5, '9000000007'), (6, '9000000008'), (7, '9000000009'),
 (8, '9000000010'), (9, '9000000011');

-- ------------------------------------------------------------
-- 11. Circulation (Loans 1 to 16)
--     Loans are inserted in exact chronological order per copy:
--     INSERT triggers trg_loan_after_insert (copy -> Issued).
--     UPDATE return_date triggers trg_loan_after_return (copy -> Available, fine raised).
-- ------------------------------------------------------------

-- Loan 1: on time
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (1, '9780078022159', 1, 1, 1, DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 16 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 20 DAY) WHERE loan_id = 1;

-- Loan 2: 6 days late -> fine 12
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (2, '9780262046305', 1, 1, 2, DATE_SUB(CURRENT_DATE, INTERVAL 25 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 11 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 5 DAY) WHERE loan_id = 2;

-- Loan 3: on time (same copy as loan 1, after return)
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (3, '9780078022159', 1, 2, 1, DATE_SUB(CURRENT_DATE, INTERVAL 18 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 4 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 10 DAY) WHERE loan_id = 3;

-- Loan 4: 6 days late -> fine 12
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (4, '9780000000041', 1, 3, 2, DATE_SUB(CURRENT_DATE, INTERVAL 40 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 26 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 20 DAY) WHERE loan_id = 4;

-- Loan 5: on time
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (5, '9780000000052', 1, 4, 3, DATE_SUB(CURRENT_DATE, INTERVAL 12 DAY), DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 3 DAY) WHERE loan_id = 5;

-- Loan 6: faculty, 5 days late -> fine 5
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (6, '9780000000074', 1, 6, 1, DATE_SUB(CURRENT_DATE, INTERVAL 50 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 20 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 15 DAY) WHERE loan_id = 6;

-- Loan 7: 13 days late -> fine 26
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (7, '9780000000085', 1, 5, 2, DATE_SUB(CURRENT_DATE, INTERVAL 35 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 21 DAY));
UPDATE loan SET return_date = DATE_SUB(CURRENT_DATE, INTERVAL 8 DAY) WHERE loan_id = 7;

-- Loans 8-11: currently out, not yet due
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (8,  '9780000000096', 1, 2, 1, DATE_SUB(CURRENT_DATE, INTERVAL 5 DAY),  DATE_ADD(CURRENT_DATE, INTERVAL 9 DAY)),
 (9,  '9780078022159', 2, 3, 3, DATE_SUB(CURRENT_DATE, INTERVAL 3 DAY),  DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY)),
 (10, '9780000000118', 1, 7, 2, DATE_SUB(CURRENT_DATE, INTERVAL 10 DAY), DATE_ADD(CURRENT_DATE, INTERVAL 20 DAY)),
 (11, '9780000000041', 2, 7, 1, DATE_SUB(CURRENT_DATE, INTERVAL 8 DAY),  DATE_ADD(CURRENT_DATE, INTERVAL 22 DAY));

-- Loans 12-15: currently out and overdue
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (12, '9780262046305', 2, 4, 3, DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 16 DAY)),
 (13, '9780000000107', 1, 8, 1, DATE_SUB(CURRENT_DATE, INTERVAL 25 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 11 DAY)),
 (14, '9780133970777', 1, 9, 2, DATE_SUB(CURRENT_DATE, INTERVAL 20 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 6 DAY)),
 (15, '9780000000063', 1, 1, 3, DATE_SUB(CURRENT_DATE, INTERVAL 22 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 8 DAY));

-- Loan 16: recent open loan
INSERT INTO loan (loan_id, isbn, copy_no, member_id, staff_id, issue_date, due_date) VALUES
 (16, '9780000000085', 2, 8, 1, DATE_SUB(CURRENT_DATE, INTERVAL 2 DAY), DATE_ADD(CURRENT_DATE, INTERVAL 12 DAY));

-- Mark some fines as Paid
UPDATE fine SET paid_status = 'Paid' WHERE loan_id IN (2, 6);

-- Set status for lost copy and reserved copy
UPDATE book_copy SET status = 'Lost'     WHERE isbn = '9780000000107' AND copy_no = 2;
UPDATE book_copy SET status = 'Reserved' WHERE isbn = '9780000000096' AND copy_no = 2;

-- ------------------------------------------------------------
-- 12. Reservations
-- ------------------------------------------------------------
INSERT INTO reservation (member_id, isbn, reserved_on, status) VALUES
 (3, '9780000000107', DATE_SUB(CURRENT_DATE, INTERVAL 4 DAY),  'Active'),
 (5, '9780133970777', DATE_SUB(CURRENT_DATE, INTERVAL 2 DAY),  'Active'),
 (6, '9780000000096', DATE_SUB(CURRENT_DATE, INTERVAL 9 DAY),  'Fulfilled'),
 (9, '9780078022159', DATE_SUB(CURRENT_DATE, INTERVAL 15 DAY), 'Cancelled');
