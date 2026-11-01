-- ============================================================
-- Library Management System : queries + relational algebra
-- Run after library_ddl.sql and library_data.sql.
-- ============================================================
USE library_db;

-- Q1. Search the catalog by title keyword (with authors)
SELECT b.isbn, b.title, b.pub_year,
       GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ') AS authors
FROM book b
JOIN book_author ba ON ba.isbn = b.isbn
JOIN author a       ON a.author_id = ba.author_id
WHERE b.title LIKE '%Database%'
GROUP BY b.isbn, b.title, b.pub_year;

-- Q2. All books written by a given author
SELECT b.title, b.pub_year
FROM book b
JOIN book_author ba ON ba.isbn = b.isbn
JOIN author a       ON a.author_id = ba.author_id
WHERE a.name = 'Abraham Silberschatz';

-- Q3. Titles with NO available copy right now
SELECT b.title
FROM book b
WHERE NOT EXISTS (
    SELECT 1 FROM book_copy bc
    WHERE bc.isbn = b.isbn AND bc.status = 'Available'
);

-- Q4. Overdue loans, worst first (uses the view)
SELECT * FROM v_overdue_loans
ORDER BY days_overdue DESC;

-- Q5. Borrowing history of one member (member 1)
SELECT b.title, l.issue_date, l.due_date, l.return_date,
       CASE WHEN l.return_date IS NULL THEN 'Out' ELSE 'Returned' END AS state
FROM loan l
JOIN book b ON b.isbn = l.isbn
WHERE l.member_id = 1
ORDER BY l.issue_date DESC;

-- Q6. Top 3 most borrowed titles
SELECT b.title, COUNT(*) AS times_issued
FROM loan l
JOIN book b ON b.isbn = l.isbn
GROUP BY b.isbn, b.title
ORDER BY times_issued DESC, b.title
LIMIT 3;

-- Q7. Members owing unpaid fines
SELECT m.member_id, m.first_name, m.last_name, SUM(f.amount) AS unpaid
FROM member m
JOIN loan l ON l.member_id = m.member_id
JOIN fine f ON f.loan_id   = l.loan_id
WHERE f.paid_status = 'Unpaid'
GROUP BY m.member_id, m.first_name, m.last_name
HAVING SUM(f.amount) > 0
ORDER BY unpaid DESC;

-- Q8. Members who have never borrowed anything
SELECT m.member_id, m.first_name, m.last_name
FROM member m
WHERE NOT EXISTS (SELECT 1 FROM loan l WHERE l.member_id = m.member_id);

-- Q9. Members who have borrowed EVERY book by Abraham Silberschatz (relational division)
SELECT m.member_id, m.first_name, m.last_name
FROM member m
WHERE NOT EXISTS (
    SELECT 1
    FROM book_author ba
    JOIN author a ON a.author_id = ba.author_id
    WHERE a.name = 'Abraham Silberschatz'
      AND NOT EXISTS (
          SELECT 1 FROM loan l
          WHERE l.member_id = m.member_id AND l.isbn = ba.isbn
      )
);

-- Q10. Members with more loans than the average member
SELECT m.member_id, m.first_name, m.last_name, COUNT(*) AS loans
FROM member m
JOIN loan l ON l.member_id = m.member_id
GROUP BY m.member_id, m.first_name, m.last_name
HAVING COUNT(*) > (
    SELECT AVG(c.n)
    FROM (SELECT COUNT(*) AS n FROM loan GROUP BY member_id) AS c
);

-- Index comparison
EXPLAIN SELECT * FROM book WHERE title = 'Sapiens';
EXPLAIN SELECT * FROM book IGNORE INDEX (idx_book_title) WHERE title = 'Sapiens';

