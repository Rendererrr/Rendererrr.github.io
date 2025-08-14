@echo off
REM ==============================
REM Auto Git Push & Publish Script
REM ==============================

REM Set your commit message
set /p msg="Enter commit message: "

REM Stage all changes
git add -A

REM Commit with the provided message
git commit -m "%msg%"

REM Push to the current branch and publish if new
git push -u origin HEAD

pause
