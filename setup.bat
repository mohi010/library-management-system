@echo off
REM ============================================================
REM  Library Management System - Setup Script
REM  Fixes:
REM    #1  Auto-locates mysql.exe in 8 common install paths so the
REM        script works even when mysql is not on the system PATH.
REM    #6  Sets real bcrypt passwords for all staff during setup so
REM        login works immediately without any extra manual step.
REM ============================================================

SET DB_USER=root
SET DB_PASSWORD=
SET DB_HOST=localhost
SET DB_NAME=library_db

REM -------- Fix #1: locate mysql.exe automatically --------
SET "MYSQL_EXE="
where mysql >nul 2>&1
IF NOT ERRORLEVEL 1 (
    SET "MYSQL_EXE=mysql"
    GOTO :found_mysql
)
FOR %%P IN (
    "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    "C:\Program Files\MySQL\MySQL Server 5.7\bin\mysql.exe"
    "C:\Program Files (x86)\MySQL\MySQL Server 8.0\bin\mysql.exe"
    "C:\xampp\mysql\bin\mysql.exe"
    "C:\wamp64\bin\mysql\mysql8.0.31\bin\mysql.exe"
    "C:\wamp\bin\mysql\mysql8.0.31\bin\mysql.exe"
    "C:\laragon\bin\mysql\mysql-8.0\bin\mysql.exe"
) DO (
    IF EXIST %%P (
        SET "MYSQL_EXE=%%~P"
        GOTO :found_mysql
    )
)
echo.
echo ERROR: Cannot find mysql.exe.
echo Make sure MySQL (or XAMPP/WAMP) is installed, then either:
echo   a) Add MySQL bin to your system PATH, or
echo   b) Edit MYSQL_EXE at the top of this script.
pause
exit /b 1

:found_mysql
echo Found MySQL at: %MYSQL_EXE%

REM -------- Step 1: load schema --------
echo.
echo [1/4] Loading DDL (schema, views, triggers, procedures)...
"%MYSQL_EXE%" -u %DB_USER% -h %DB_HOST% --default-character-set=utf8mb4 < library_ddl.sql
IF ERRORLEVEL 1 (
    echo FAILED. Check your DB credentials at the top of this file.
    pause
    exit /b 1
)
echo     OK

REM -------- Step 2: load sample data --------
echo [2/4] Loading bulk sample data...
"%MYSQL_EXE%" -u %DB_USER% -h %DB_HOST% --default-character-set=utf8mb4 < library_data.sql
IF ERRORLEVEL 1 (
    echo FAILED.
    pause
    exit /b 1
)
echo     OK

REM -------- Step 3: install Python packages --------
echo [3/4] Installing Python packages...
cd library_app
pip install -r requirements.txt -q
IF ERRORLEVEL 1 (
    echo FAILED. Make sure Python and pip are installed.
    pause
    exit /b 1
)
echo     OK

REM -------- Fix #6: set real bcrypt passwords for all staff --------
echo [4/4] Setting staff passwords (bcrypt hashed)...
python app.py set-password admin@library.example  admin123
python app.py set-password ritu@library.example   ritu123
python app.py set-password sameer@library.example sameer123
echo     OK

echo.
echo ============================================================
echo  Setup complete!
echo  Staff login credentials:
echo    Admin:     admin@library.example  /  admin123
echo    Librarian: ritu@library.example   /  ritu123
echo    Librarian: sameer@library.example /  sameer123
echo.
echo  To start the app:
echo    cd library_app
echo    python app.py
echo  Then open: http://localhost:5000
echo ============================================================
cd ..
pause
