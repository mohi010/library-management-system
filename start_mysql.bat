@echo off
REM Starts MySQL Server 8.4 using the local user datadir
echo Starting MySQL Server on port 3306...
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe" --datadir="C:\Users\akm98\mysql_data" --port=3306 --console
pause

