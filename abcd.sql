-- Create Database
CREATE DATABASE library_management;
\c library_management;

-- Create Tables
CREATE TABLE Authors (
    AuthorID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    BirthDate DATE,
    Nationality VARCHAR(50)
);

CREATE TABLE Books (
    BookID SERIAL PRIMARY KEY,
    Title VARCHAR(200) NOT NULL,
    AuthorID INT REFERENCES Authors(AuthorID) ON DELETE CASCADE,
    Genre VARCHAR(50),
    PublishedYear INT CHECK (PublishedYear > 0),
    TotalCopies INT DEFAULT 1 CHECK (TotalCopies >= 0),
    AvailableCopies INT DEFAULT 1 CHECK (AvailableCopies >= 0)
);

CREATE TABLE Members (
    MemberID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    PhoneNumber VARCHAR(15),
    MembershipDate DATE DEFAULT CURRENT_DATE
);

CREATE TABLE Transactions (
    TransactionID SERIAL PRIMARY KEY,
    BookID INT REFERENCES Books(BookID) ON DELETE CASCADE,
    MemberID INT REFERENCES Members(MemberID) ON DELETE CASCADE,
    IssueDate DATE NOT NULL DEFAULT CURRENT_DATE,
    ReturnDate DATE
);

-- Insert Sample Data
INSERT INTO Authors (Name, BirthDate, Nationality)
VALUES
    ('J.K. Rowling', '1965-07-31', 'British'),
    ('George R.R. Martin', '1948-09-20', 'American'),
    ('J.R.R. Tolkien', '1892-01-03', 'British');

INSERT INTO Books (Title, AuthorID, Genre, PublishedYear, TotalCopies, AvailableCopies)
VALUES
    ('Harry Potter and the Philosopher\'s Stone', 1, 'Fantasy', 1997, 10, 10),
    ('A Game of Thrones', 2, 'Fantasy', 1996, 5, 5),
    ('The Hobbit', 3, 'Fantasy', 1937, 8, 8);

INSERT INTO Members (Name, Email, PhoneNumber)
VALUES
    ('Alice Smith', 'alice@example.com', '123-456-7890'),
    ('Bob Johnson', 'bob@example.com', '987-654-3210'),
    ('Charlie Brown', 'charlie@example.com', '456-789-1230');

-- Create a Stored Procedure for Issuing Books
CREATE OR REPLACE FUNCTION IssueBook(book_id INT, member_id INT)
RETURNS VOID AS $$
BEGIN
    -- Check if the book is available
    IF (SELECT AvailableCopies FROM Books WHERE BookID = book_id) <= 0 THEN
        RAISE EXCEPTION 'Book is not available';
    END IF;

    -- Insert transaction
    INSERT INTO Transactions (BookID, MemberID)
    VALUES (book_id, member_id);

    -- Decrement available copies
    UPDATE Books
    SET AvailableCopies = AvailableCopies - 1
    WHERE BookID = book_id;
END;
$$ LANGUAGE plpgsql;

-- Create a Stored Procedure for Returning Books
CREATE OR REPLACE FUNCTION ReturnBook(transaction_id INT)
RETURNS VOID AS $$
DECLARE
    book_id INT;
BEGIN
    -- Get the BookID from the transaction
    SELECT BookID INTO book_id
    FROM Transactions
    WHERE TransactionID = transaction_id;

    IF book_id IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    -- Update the transaction with ReturnDate
    UPDATE Transactions
    SET ReturnDate = CURRENT_DATE
    WHERE TransactionID = transaction_id;

    -- Increment available copies
    UPDATE Books
    SET AvailableCopies = AvailableCopies + 1
    WHERE BookID = book_id;
END;
$$ LANGUAGE plpgsql;

-- Create a Trigger to Prevent Over-Issuing
CREATE OR REPLACE FUNCTION CheckAvailableCopies()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT AvailableCopies FROM Books WHERE BookID = NEW.BookID) <= 0 THEN
        RAISE EXCEPTION 'Cannot issue the book: No available copies.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER BeforeTransactionInsert
BEFORE INSERT ON Transactions
FOR EACH ROW
EXECUTE FUNCTION CheckAvailableCopies();

-- Sample Queries
-- Issue a Book
SELECT IssueBook(1, 1); -- Alice borrows "Harry Potter"

-- Return a Book
SELECT ReturnBook(1); -- Alice returns "Harry Potter"

-- View All Books
SELECT * FROM Books;

-- View All Transactions
SELECT * FROM Transactions;

-- View Books Issued by a Member
SELECT B.Title, T.IssueDate, T.ReturnDate
FROM Transactions T
JOIN Books B ON T.BookID = B.BookID
WHERE T.MemberID = 1; -- Books issued by Alice

-- Update Author Details
UPDATE Authors
SET Nationality = 'American'
WHERE Name = 'George R.R. Martin';

-- Delete a Member and Their Transactions
DELETE FROM Members WHERE MemberID = 3;

-- Additional Functionality: Get Overdue Books
CREATE OR REPLACE FUNCTION GetOverdueBooks()
RETURNS TABLE (MemberName VARCHAR, BookTitle VARCHAR, DaysOverdue INT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        M.Name AS MemberName, 
        B.Title AS BookTitle, 
        (CURRENT_DATE - T.IssueDate - 14) AS DaysOverdue
    FROM Transactions T
    JOIN Members M ON T.MemberID = M.MemberID
    JOIN Books B ON T.BookID = B.BookID
    WHERE T.ReturnDate IS NULL AND (CURRENT_DATE - T.IssueDate) > 14;
END;
$$ LANGUAGE plpgsql;

-- Query Overdue Books
SELECT * FROM GetOverdueBooks();

-- Drop All Objects (for cleanup)
-- DROP TABLE IF EXISTS Transactions, Members, Books, Authors CASCADE;
-- DROP FUNCTION IF EXISTS IssueBook, ReturnBook, CheckAvailableCopies, GetOverdueBooks;
-- DROP TRIGGER IF EXISTS BeforeTransactionInsert ON Transactions;
