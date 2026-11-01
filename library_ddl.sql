-- ============================================================
-- Library Management System : Phase 3 (DDL + constraints + triggers)
-- Target: MySQL 8.0+ (InnoDB). Run top to bottom.
-- ============================================================

DROP DATABASE IF EXISTS library_db;
CREATE DATABASE library_db;
USE library_db;

-- ------------------------------------------------------------
-- 1. Independent (lookup) tables
-- ------------------------------------------------------------
CREATE TABLE publisher (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(100) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE author (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    name      VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE membership_type (
    type_id      INT AUTO_INCREMENT PRIMARY KEY,
    type_name    VARCHAR(30) NOT NULL UNIQUE,
    max_books    TINYINT NOT NULL,
    loan_days    SMALLINT NOT NULL,
    fine_per_day DECIMAL(6,2) NOT NULL DEFAULT 2.00,
    CONSTRAINT chk_mt_max   CHECK (max_books > 0),
    CONSTRAINT chk_mt_days  CHECK (loan_days > 0),
    CONSTRAINT chk_mt_fine  CHECK (fine_per_day >= 0)
) ENGINE=InnoDB;

CREATE TABLE staff (
    staff_id      INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    role          VARCHAR(15)  NOT NULL DEFAULT 'Librarian',
    password_hash VARCHAR(255) NOT NULL,
    CONSTRAINT chk_staff_role CHECK (role IN ('Admin', 'Librarian'))
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. Catalog tables
-- ------------------------------------------------------------
CREATE TABLE book (
    isbn         CHAR(13) PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    pub_year     SMALLINT,
    publisher_id INT NOT NULL,
    category_id  INT NOT NULL,
    CONSTRAINT chk_book_year CHECK (pub_year IS NULL OR pub_year >= 1000),
    CONSTRAINT fk_book_publisher FOREIGN KEY (publisher_id)
        REFERENCES publisher(publisher_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_book_category FOREIGN KEY (category_id)
        REFERENCES category(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Junction table for the M:N Book-Author relationship
CREATE TABLE book_author (
    isbn      CHAR(13) NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (isbn, author_id),
    CONSTRAINT fk_ba_book FOREIGN KEY (isbn)
        REFERENCES book(isbn)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ba_author FOREIGN KEY (author_id)
        REFERENCES author(author_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Weak entity: identified by (isbn, copy_no)
CREATE TABLE book_copy (
    isbn           CHAR(13) NOT NULL,
    copy_no        INT NOT NULL,
    status         VARCHAR(10) NOT NULL DEFAULT 'Available',
    shelf_location VARCHAR(20),
    PRIMARY KEY (isbn, copy_no),
    CONSTRAINT chk_copy_status
        CHECK (status IN ('Available', 'Issued', 'Lost', 'Reserved')),
    CONSTRAINT chk_copy_no CHECK (copy_no > 0),
    CONSTRAINT fk_copy_book FOREIGN KEY (isbn)
        REFERENCES book(isbn)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. Members
-- Fix #3: join_date has no expression DEFAULT so this file also works
--         on MySQL 5.7 (which does not support DEFAULT (CURRENT_DATE)).
--         INSERTs supply CURRENT_DATE explicitly.
-- ------------------------------------------------------------
CREATE TABLE member (
    member_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    address     VARCHAR(255),
    dob         DATE NOT NULL,
    join_date   DATE NOT NULL DEFAULT (CURRENT_DATE),
    expiry_date DATE NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    type_id     INT NOT NULL,
    CONSTRAINT chk_member_expiry CHECK (expiry_date > join_date),
    CONSTRAINT fk_member_type FOREIGN KEY (type_id)
        REFERENCES membership_type(type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Multivalued attribute (1NF)
CREATE TABLE member_phone (
    member_id INT NOT NULL,
    phone     VARCHAR(15) NOT NULL,
    PRIMARY KEY (member_id, phone),
    CONSTRAINT fk_phone_member FOREIGN KEY (member_id)
        REFERENCES member(member_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 4. Circulation
-- Fix #3: issue_date has no expression DEFAULT for 5.7 compatibility.
-- ------------------------------------------------------------
CREATE TABLE loan (
    loan_id     INT AUTO_INCREMENT PRIMARY KEY,
    isbn        CHAR(13) NOT NULL,
    copy_no     INT NOT NULL,
    member_id   INT NOT NULL,
    staff_id    INT NOT NULL,
    issue_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date    DATE NOT NULL,
    return_date DATE NULL,
    CONSTRAINT chk_loan_due    CHECK (due_date >= issue_date),
    CONSTRAINT chk_loan_return CHECK (return_date IS NULL OR return_date >= issue_date),
    CONSTRAINT fk_loan_copy FOREIGN KEY (isbn, copy_no)
        REFERENCES book_copy(isbn, copy_no)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_loan_member FOREIGN KEY (member_id)
        REFERENCES member(member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_loan_staff FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 1:1 with loan (UNIQUE on loan_id)
CREATE TABLE fine (
    fine_id     INT AUTO_INCREMENT PRIMARY KEY,
    loan_id     INT NOT NULL UNIQUE,
    amount      DECIMAL(8,2) NOT NULL,
    paid_status VARCHAR(10) NOT NULL DEFAULT 'Unpaid',
    CONSTRAINT chk_fine_amount CHECK (amount >= 0),
    CONSTRAINT chk_fine_status CHECK (paid_status IN ('Unpaid', 'Paid')),
    CONSTRAINT fk_fine_loan FOREIGN KEY (loan_id)
        REFERENCES loan(loan_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Fix #3: reserved_on has no expression DEFAULT for 5.7 compatibility.
CREATE TABLE reservation (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id      INT NOT NULL,
    isbn           CHAR(13) NOT NULL,
    reserved_on    DATE NOT NULL DEFAULT (CURRENT_DATE),
    status         VARCHAR(10) NOT NULL DEFAULT 'Active',
    CONSTRAINT chk_res_status
        CHECK (status IN ('Active', 'Fulfilled', 'Cancelled')),
    CONSTRAINT fk_res_member FOREIGN KEY (member_id)
        REFERENCES member(member_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_res_book FOREIGN KEY (isbn)
        REFERENCES book(isbn)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 5. Indexes
-- ------------------------------------------------------------
CREATE INDEX idx_book_title        ON book(title);
CREATE INDEX idx_author_name       ON author(name);
CREATE INDEX idx_copy_status       ON book_copy(status);
CREATE INDEX idx_loan_member_open  ON loan(member_id, return_date);
CREATE INDEX idx_loan_due          ON loan(due_date);

-- ------------------------------------------------------------
-- 6. Views
-- ------------------------------------------------------------
CREATE VIEW v_overdue_loans AS
SELECT l.loan_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       b.title,
       l.copy_no,
       l.due_date,
       DATEDIFF(CURRENT_DATE, l.due_date) AS days_overdue
FROM loan l
JOIN member m ON m.member_id = l.member_id
JOIN book   b ON b.isbn      = l.isbn
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE;

CREATE VIEW v_available_copies AS
SELECT b.isbn, b.title,
       COUNT(*) AS available_copies
FROM book b
JOIN book_copy bc ON bc.isbn = b.isbn
WHERE bc.status = 'Available'
GROUP BY b.isbn, b.title;

CREATE VIEW v_member_open_loans AS
SELECT m.member_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       mt.max_books,
       COUNT(l.loan_id) AS books_out
FROM member m
JOIN membership_type mt ON mt.type_id = m.type_id
LEFT JOIN loan l ON l.member_id = m.member_id AND l.return_date IS NULL
GROUP BY m.member_id, member_name, mt.max_books;

-- ------------------------------------------------------------
-- 7. Triggers
-- ------------------------------------------------------------
DELIMITER $$

-- Business-rule guard: runs before every loan insert
CREATE TRIGGER trg_loan_before_insert
BEFORE INSERT ON loan
FOR EACH ROW
BEGIN
    DECLARE v_status  VARCHAR(10);
    DECLARE v_active  BOOLEAN;
    DECLARE v_expiry  DATE;
    DECLARE v_max     INT;
    DECLARE v_out     INT;

    SELECT status INTO v_status
    FROM book_copy
    WHERE isbn = NEW.isbn AND copy_no = NEW.copy_no;

    IF v_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This copy is not available for issue';
    END IF;

    SELECT m.is_active, m.expiry_date, mt.max_books
      INTO v_active, v_expiry, v_max
    FROM member m
    JOIN membership_type mt ON mt.type_id = m.type_id
    WHERE m.member_id = NEW.member_id;

    IF v_active = FALSE OR v_expiry < NEW.issue_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Membership is inactive or expired';
    END IF;

    SELECT COUNT(*) INTO v_out
    FROM loan
    WHERE member_id = NEW.member_id AND return_date IS NULL;

    IF v_out >= v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Borrow limit reached for this member';
    END IF;
END$$

-- After issuing: mark the copy as Issued
CREATE TRIGGER trg_loan_after_insert
AFTER INSERT ON loan
FOR EACH ROW
BEGIN
    UPDATE book_copy
    SET status = 'Issued'
    WHERE isbn = NEW.isbn AND copy_no = NEW.copy_no;
END$$

-- After return: free the copy and raise a fine if late
CREATE TRIGGER trg_loan_after_return
AFTER UPDATE ON loan
FOR EACH ROW
BEGIN
    DECLARE v_rate DECIMAL(6,2);

    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        UPDATE book_copy
        SET status = 'Available'
        WHERE isbn = NEW.isbn AND copy_no = NEW.copy_no;

        IF NEW.return_date > NEW.due_date THEN
            SELECT mt.fine_per_day INTO v_rate
            FROM member m
            JOIN membership_type mt ON mt.type_id = m.type_id
            WHERE m.member_id = NEW.member_id;

            INSERT INTO fine (loan_id, amount)
            VALUES (NEW.loan_id,
                    DATEDIFF(NEW.return_date, NEW.due_date) * v_rate);
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------
-- 8. Stored procedures
-- ------------------------------------------------------------

CREATE PROCEDURE sp_issue_book(
    IN p_member_id INT,
    IN p_isbn      CHAR(13),
    IN p_copy_no   INT,
    IN p_staff_id  INT
)
BEGIN
    DECLARE v_days   INT;
    DECLARE v_status VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM book_copy
    WHERE isbn = p_isbn AND copy_no = p_copy_no
    FOR UPDATE;

    SELECT mt.loan_days INTO v_days
    FROM member m
    JOIN membership_type mt ON mt.type_id = m.type_id
    WHERE m.member_id = p_member_id;

    INSERT INTO loan (isbn, copy_no, member_id, staff_id, issue_date, due_date)
    VALUES (p_isbn, p_copy_no, p_member_id, p_staff_id,
            CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL v_days DAY));

    COMMIT;
END$$

-- Return a book (fine is raised by trg_loan_after_return)
CREATE PROCEDURE sp_return_book(IN p_loan_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE loan
    SET return_date = CURRENT_DATE
    WHERE loan_id = p_loan_id AND return_date IS NULL;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loan not found or already returned';
    END IF;

    COMMIT;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 9. Seed data
-- ------------------------------------------------------------
INSERT INTO publisher (name, email) VALUES
 ('Pearson', 'contact@pearson.example'),
 ('McGraw Hill', 'info@mcgrawhill.example'),
 ('MIT Press', 'press@mit.example');

INSERT INTO category (name) VALUES ('Computer Science'), ('Mathematics'), ('Fiction');

INSERT INTO author (name) VALUES
 ('Abraham Silberschatz'), ('Henry F. Korth'), ('S. Sudarshan'),
 ('Thomas H. Cormen'), ('Ramez Elmasri');

INSERT INTO book (isbn, title, pub_year, publisher_id, category_id) VALUES
 ('9780078022159', 'Database System Concepts', 2019, 2, 1),
 ('9780262046305', 'Introduction to Algorithms', 2022, 3, 1),
 ('9780133970777', 'Fundamentals of Database Systems', 2015, 1, 1);

INSERT INTO book_author (isbn, author_id) VALUES
 ('9780078022159', 1), ('9780078022159', 2), ('9780078022159', 3),
 ('9780262046305', 4),
 ('9780133970777', 5);

INSERT INTO book_copy (isbn, copy_no, shelf_location) VALUES
 ('9780078022159', 1, 'CS-A1'), ('9780078022159', 2, 'CS-A1'),
 ('9780262046305', 1, 'CS-B2'), ('9780262046305', 2, 'CS-B2'),
 ('9780133970777', 1, 'CS-A3');

INSERT INTO membership_type (type_name, max_books, loan_days, fine_per_day) VALUES
 ('Student', 3, 14, 2.00),
 ('Faculty', 6, 30, 1.00);

-- Fix #3: explicit join_date value so this works on MySQL 5.7 too.
INSERT INTO member (first_name, last_name, email, address, dob, join_date, expiry_date, type_id) VALUES
 ('Aarav', 'Sharma', 'aarav@example.com', 'Dwarka, Delhi', '2005-03-14', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 1),
 ('Neha',  'Verma',  'neha@example.com',  'Uttam Nagar, Delhi', '2004-11-02', CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 1);

INSERT INTO member_phone (member_id, phone) VALUES
 (1, '9000000001'), (1, '9000000002'), (2, '9000000003');

-- Real password hash for 'admin123' (werkzeug scrypt/bcrypt compatible)
INSERT INTO staff (name, email, role, password_hash) VALUES
 ('Admin User', 'admin@library.example', 'Admin', 'scrypt:32768:8:1$7bgArTJAA1eypqoE$90ef7a9fda5175280eb2d4a81e005857fcd93c90a15dd8139ce0fb9615fecef61de105bc1e8f43ec23240652bdd41da2a47d8052ee6b7ce0fcd115d0db748403');

