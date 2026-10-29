@echo off
REM ============================================================
REM  PROGRAM : PC Maintenance Toolkit
REM  STEP    : 5 - View Activity Log added
REM  PURPOSE : A menu-driven tool for basic PC maintenance.
REM            All five menu options now work. A login screen
REM            and welcome screen can be added as a final step.
REM  AUTHOR  : (your name)
REM  DATE    : (today's date)
REM ============================================================

REM --- Keep variables local to this script ---
setlocal

REM --- Window title and color (0 = black background, A = light green text) ---
title PC Maintenance Toolkit
color 0A

REM --- Always work from the folder where this script is saved ---
cd /d "%~dp0"

REM --- Variables for the folders and files used by the program ---
set "REPORT_DIR=Reports"
set "LOG_DIR=Logs"
set "BACKUP_DIR=Backup"
set "REPORT_FILE=%REPORT_DIR%\system_report.txt"
set "LOG_FILE=%LOG_DIR%\activity.log"

REM --- Warn the user when free disk space is below this many GB ---
set "LOW_SPACE_GB=10"

REM --- Targets for the network check (the router is detected automatically) ---
set "PUBLIC_IP=8.8.8.8"
set "TEST_SITE=google.com"

REM --- Create the Reports and Logs folders if they do not exist yet ---
REM --- (the Backup folder is created later, only when a backup is made) ---
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"


REM ============================================================
REM  MAIN MENU
REM ============================================================
:MENU
cls

REM --- Clear the old choice so pressing Enter with no input is detected ---
set "choice="

echo ==========================================
echo         PC MAINTENANCE TOOLKIT
echo ==========================================
echo.
echo   1. System Information
echo   2. Network Check
echo   3. Backup
echo   4. View Activity Log
echo   5. Exit
echo.
set /p "choice=Enter your choice (1-5): "

REM --- Validate the choice and jump to the matching section ---
if not defined choice goto INVALID
if "%choice%"=="1" goto SYSINFO
if "%choice%"=="2" goto NETWORK
if "%choice%"=="3" goto BACKUP
if "%choice%"=="4" goto VIEWLOG
if "%choice%"=="5" goto EXIT

REM --- Anything else is not a valid option ---
goto INVALID


REM ============================================================
REM  INVALID INPUT HANDLER
REM ============================================================
:INVALID
echo.
echo Invalid choice. Please enter a number from 1 to 5.
echo.
pause
goto MENU


REM ============================================================
REM  OPTION 1 - SYSTEM INFORMATION
REM  Gathers PC details, saves them to Reports\system_report.txt,
REM  shows the report on screen, and writes a line to the log.
REM ============================================================
:SYSINFO
cls
echo Collecting system information, please wait...
echo.

REM --- Read the free space of the system drive (usually C:) ---
REM --- The "bytes free" line of DIR holds the number in its 3rd token ---
set "FREE_BYTES="
for /f "tokens=3" %%A in ('dir "%SystemDrive%\" ^| find "bytes free"') do set "FREE_BYTES=%%A"
if not defined FREE_BYTES set "FREE_BYTES=0"

REM --- Remove the commas, then drop the last 9 digits to get whole GB ---
REM --- (Done this way because IF cannot compare numbers above 2 billion) ---
set "FREE_BYTES=%FREE_BYTES:,=%"
set "FREE_GB=%FREE_BYTES:~0,-9%"
if not defined FREE_GB set "FREE_GB=0"

REM --- Write the report: ">" creates a new file, ">>" adds to it ---
echo ========== SYSTEM REPORT ========== > "%REPORT_FILE%"
echo Generated : %date% %time% >> "%REPORT_FILE%"
echo Computer  : %COMPUTERNAME% >> "%REPORT_FILE%"
echo User      : %USERNAME% >> "%REPORT_FILE%"
echo Processor : %PROCESSOR_IDENTIFIER% >> "%REPORT_FILE%"
echo Cores     : %NUMBER_OF_PROCESSORS% >> "%REPORT_FILE%"

REM --- SYSTEMINFO lists many lines; FINDSTR keeps only the ones we want ---
REM --- /B means the line must START with the text (avoids "BIOS Version") ---
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory" /C:"Available Physical Memory" >> "%REPORT_FILE%"

echo Free disk space on %SystemDrive% : about %FREE_GB% GB >> "%REPORT_FILE%"

REM --- Low disk space warning ---
if %FREE_GB% LSS %LOW_SPACE_GB% (
    echo WARNING: Free disk space is below %LOW_SPACE_GB% GB. >> "%REPORT_FILE%"
) else (
    echo Disk status: OK >> "%REPORT_FILE%"
)

REM --- Show the saved report on screen ---
cls
type "%REPORT_FILE%"
echo.
echo Report saved to: %REPORT_FILE%

REM --- Record this action in the activity log ---
echo %date% %time% - System information report generated >> "%LOG_FILE%"

echo.
pause
goto MENU


REM ============================================================
REM  OPTION 2 - NETWORK CHECK
REM  Tests the router, a public IP address, and a website.
REM  Each result is shown on screen and added to the activity log.
REM ============================================================
:NETWORK
cls
echo Checking network connectivity, please wait...
echo.

REM --- Find the router address (default gateway) in the routing table ---
REM --- The default route is the line that starts with 0.0.0.0 0.0.0.0 ---
set "GATEWAY="
for /f "tokens=1,2,3" %%A in ('route print 0.0.0.0') do (
    if "%%A"=="0.0.0.0" if "%%B"=="0.0.0.0" set "GATEWAY=%%C"
)
if /i "%GATEWAY%"=="On-link" set "GATEWAY="

REM --- Build the list of targets to test ---
set "TARGETS=%PUBLIC_IP% %TEST_SITE%"
if defined GATEWAY (
    set "TARGETS=%GATEWAY% %PUBLIC_IP% %TEST_SITE%"
) else (
    echo Router address not found - the router test will be skipped.
    echo.
)

REM --- Reset the counters ---
set /a TOTAL=0
set /a UP_COUNT=0

REM --- Test each target one by one using the PINGONE routine below ---
echo Results:
for %%T in (%TARGETS%) do call :PINGONE %%T

REM --- Show a summary ---
echo.
echo %UP_COUNT% of %TOTAL% targets reachable.
if %UP_COUNT% EQU %TOTAL% echo Result: All targets reachable. The network looks healthy.
if %UP_COUNT% EQU 0 echo Result: No target reachable. Check the cable, Wi-Fi, or router.
if %UP_COUNT% GTR 0 if %UP_COUNT% LSS %TOTAL% echo Result: Some targets failed. See the DOWN lines above.

REM --- Record the summary in the activity log ---
echo %date% %time% - Network check finished: %UP_COUNT% of %TOTAL% reachable >> "%LOG_FILE%"

echo.
echo Results saved to: %LOG_FILE%
echo.
pause
goto MENU


REM ------------------------------------------------------------
REM  PINGONE - tests ONE target (passed in as %1)
REM  A reply containing "TTL=" means the target answered.
REM  FIND sets ERRORLEVEL to 1 when "TTL=" is not found.
REM ------------------------------------------------------------
:PINGONE
set /a TOTAL+=1
ping -n 2 -w 1500 %1 | find "TTL=" >nul
if errorlevel 1 goto PINGONE_DOWN
echo   %1 : UP
echo %date% %time% - %1 UP >> "%LOG_FILE%"
set /a UP_COUNT+=1
goto :eof

:PINGONE_DOWN
echo   %1 : DOWN
echo %date% %time% - %1 DOWN >> "%LOG_FILE%"
goto :eof


REM ============================================================
REM  OPTION 3 - BACKUP
REM  Asks for a folder, checks that it exists, and copies it into
REM  a new dated folder inside Backup\. The result is logged.
REM  (This section avoids ( ) blocks on purpose, because folder
REM   names such as "Program Files (x86)" would break them.)
REM ============================================================
:BACKUP
cls
echo ============== BACKUP ==============
echo.
echo Tip: you can drag a folder into this window to paste its path.
echo.

REM --- Ask for the folder to back up (clear the old value first) ---
set "SRC="
set /p "SRC=Enter the folder to back up: "

REM --- Stop if the user typed nothing ---
if not defined SRC goto BACKUP_EMPTY

REM --- Remove any quotes around the path, then check it is not empty ---
set "SRC=%SRC:"=%"
if not defined SRC goto BACKUP_EMPTY

REM --- Remove a trailing backslash, which can confuse XCOPY ---
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"

REM --- Stop if the folder does not exist ---
if not exist "%SRC%\" goto BACKUP_NOTFOUND

REM --- Build a folder name from the date and time ---
REM --- Spaces, slashes and colons are replaced so the name is valid ---
set "STAMP_DATE=%date: =_%"
set "STAMP_DATE=%STAMP_DATE:/=-%"
set "STAMP_TIME=%time:~0,8%"
set "STAMP_TIME=%STAMP_TIME: =0%"
set "STAMP_TIME=%STAMP_TIME::=-%"
set "DEST=%BACKUP_DIR%\Backup_%STAMP_DATE%_%STAMP_TIME%"

echo.
echo Source      : %SRC%
echo Destination : %DEST%
echo.

REM --- Create the Backup folder and the new dated folder if missing ---
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if not exist "%DEST%" mkdir "%DEST%"

REM --- Copy everything: /E = include subfolders, /I = destination is a folder, /Y = no prompts ---
xcopy "%SRC%" "%DEST%" /E /I /Y

REM --- XCOPY sets ERRORLEVEL to 0 on success and 1 or higher on failure ---
if errorlevel 1 goto BACKUP_FAIL

echo.
echo Backup completed successfully.
echo %date% %time% - Backup OK: %SRC% copied to %DEST% >> "%LOG_FILE%"
goto BACKUP_END

:BACKUP_EMPTY
echo.
echo No folder entered. Backup cancelled.
echo %date% %time% - Backup cancelled: no folder entered >> "%LOG_FILE%"
goto BACKUP_END

:BACKUP_NOTFOUND
echo.
echo Folder not found: %SRC%
echo %date% %time% - Backup failed: folder not found: %SRC% >> "%LOG_FILE%"
goto BACKUP_END

:BACKUP_FAIL
echo.
echo Backup failed, or the folder had no files to copy.
echo %date% %time% - Backup failed: %SRC% >> "%LOG_FILE%"
goto BACKUP_END

:BACKUP_END
echo.
pause
goto MENU


REM ============================================================
REM  OPTION 4 - VIEW ACTIVITY LOG
REM  Shows Logs\activity.log. The user can see everything or only
REM  the lines that report a problem (DOWN, failed, cancelled).
REM ============================================================
:VIEWLOG
cls
echo ========== ACTIVITY LOG ==========
echo.

REM --- If the log file does not exist yet, there is nothing to show ---
if not exist "%LOG_FILE%" goto VIEWLOG_NONE

echo   1. Show everything
echo   2. Show only problems
echo.

REM --- Clear the old value so pressing Enter with no input is detected ---
set "logchoice="
set /p "logchoice=Choose 1 or 2: "

if "%logchoice%"=="1" goto VIEWLOG_ALL
if "%logchoice%"=="2" goto VIEWLOG_PROBLEMS

REM --- Anything else is invalid: show an error and ask again ---
echo.
echo Invalid choice. Please enter 1 or 2.
echo.
pause
goto VIEWLOG

:VIEWLOG_ALL
cls
echo ========== FULL ACTIVITY LOG ==========
echo.
type "%LOG_FILE%"
goto VIEWLOG_END

:VIEWLOG_PROBLEMS
cls
echo ========== PROBLEMS ONLY ==========
echo.

REM --- FINDSTR prints only the lines that contain one of these words ---
REM --- It is case-sensitive on purpose, so a folder named "Downloads"
REM --- is not mistaken for the word DOWN ---
findstr /C:"DOWN" /C:"failed" /C:"cancelled" "%LOG_FILE%"

REM --- FINDSTR sets ERRORLEVEL to 1 when it finds no matching line ---
if errorlevel 1 echo No problems found in the log.
goto VIEWLOG_END

:VIEWLOG_NONE
echo No activity recorded yet.
echo Use the other menu options first, then come back here.
goto VIEWLOG_END

:VIEWLOG_END
echo.
pause
goto MENU


REM ============================================================
REM  OPTION 5 - EXIT
REM ============================================================
:EXIT
cls
echo Thank you for using the PC Maintenance Toolkit.
echo.
echo Reports are saved in: %REPORT_DIR%
echo Backups are saved in: %BACKUP_DIR%
echo Logs are saved in:    %LOG_DIR%
echo.
pause
endlocal
exit /b