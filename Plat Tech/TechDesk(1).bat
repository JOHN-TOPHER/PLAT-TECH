@echo off
setlocal EnableExtensions DisableDelayedExpansion
title TechDesk - PC Diagnostics and Maintenance Toolkit
color 0B

REM ============================================================
REM TechDesk - PC Diagnostics and Maintenance Toolkit
REM Purpose: Combine basic system checks, network tests,
REM file backup, file search, and activity logging in one tool.
REM This script uses commands available in Windows Command Prompt.
REM Review the source and destination paths before backing up files.
REM ============================================================

set "BASE_DIR=%~dp0"
set "REPORT_DIR=%BASE_DIR%Reports"
set "BACKUP_DIR=%BASE_DIR%Backups"
set "LOG_FILE=%REPORT_DIR%\activity.log"

REM Create the folders used to store reports and backup copies.
if not exist "%REPORT_DIR%" md "%REPORT_DIR%" 2>nul
if not exist "%BACKUP_DIR%" md "%BACKUP_DIR%" 2>nul

if not exist "%REPORT_DIR%\" (
    echo ERROR: Could not create the Reports folder.
    echo Check that you can write to this folder: "%BASE_DIR%"
    pause
    exit /b 1
)

if not exist "%BACKUP_DIR%\" (
    echo ERROR: Could not create the Backups folder.
    echo Check that you can write to this folder: "%BASE_DIR%"
    pause
    exit /b 1
)

if not exist "%LOG_FILE%" (
    echo TechDesk activity log>"%LOG_FILE%"
)
call :WRITE_LOG "TechDesk started"

:MAIN_MENU
cls
echo ============================================================
echo                         TECHDESK
echo          PC DIAGNOSTICS ^& MAINTENANCE TOOLKIT
echo ============================================================
echo.
echo   [1] System Information
echo   [2] Network Connectivity Test
echo   [3] File Backup Manager
echo   [4] File Search and Report
echo   [5] View Activity Log
echo   [6] Exit
echo.
echo ------------------------------------------------------------
set "MENU_CHOICE="
set /p "MENU_CHOICE=Select an option (1-6): "

if "%MENU_CHOICE%"=="1" goto SYSTEM_INFO
if "%MENU_CHOICE%"=="2" goto NETWORK_TEST
if "%MENU_CHOICE%"=="3" goto FILE_BACKUP
if "%MENU_CHOICE%"=="4" goto FILE_SEARCH
if "%MENU_CHOICE%"=="5" goto VIEW_LOG
if "%MENU_CHOICE%"=="6" goto EXIT_PROGRAM

echo.
echo Invalid choice. Please enter a number from 1 to 6.
pause
goto MAIN_MENU

:SYSTEM_INFO
cls
echo [System Information]
echo Generating a system report...
set "REPORT_FILE=%REPORT_DIR%\SystemInfo_%RANDOM%.txt"

(
    echo TECHDESK - SYSTEM INFORMATION REPORT
    echo Generated: %date% %time%
    echo.
    echo ===== WINDOWS VERSION =====
    ver
    echo.
    echo ===== COMPUTER NAME =====
    hostname
    echo.
    echo ===== CURRENT USER =====
    whoami
    echo.
    echo ===== SYSTEM DETAILS =====
    systeminfo
    echo.
    echo ===== DISK SPACE =====
    wmic logicaldisk get caption,freespace,size 2^>nul
) > "%REPORT_FILE%" 2>&1

echo Report saved to:
echo "%REPORT_FILE%"
call :WRITE_LOG "System information report generated"
echo.
pause
goto MAIN_MENU

:NETWORK_TEST
cls
echo [Network Connectivity Test]
echo Enter a hostname or IP address to test.
echo Press Enter to use 8.8.8.8 as the default test destination.
set "TARGET="
set /p "TARGET=Destination: "
if not defined TARGET set "TARGET=8.8.8.8"

set "REPORT_FILE=%REPORT_DIR%\NetworkTest_%RANDOM%.txt"
echo TECHDESK - NETWORK TEST REPORT>"%REPORT_FILE%"
echo Generated: %date% %time%>>"%REPORT_FILE%"
echo Destination: %TARGET%>>"%REPORT_FILE%"
echo.>>"%REPORT_FILE%"
echo ===== IP CONFIGURATION =====>>"%REPORT_FILE%"
ipconfig >>"%REPORT_FILE%" 2>&1
echo.>>"%REPORT_FILE%"
echo ===== PING TEST =====>>"%REPORT_FILE%"
ping -n 4 "%TARGET%" >>"%REPORT_FILE%" 2>&1

if errorlevel 1 goto NETWORK_FAILED

echo.
echo RESULT: The ping command completed successfully.
echo Report saved to: "%REPORT_FILE%"
call :WRITE_LOG "Network test completed successfully"
pause
goto MAIN_MENU

:NETWORK_FAILED
echo.
echo RESULT: The ping test failed or received no successful replies.
echo Check the destination and your network connection.
echo Details saved to: "%REPORT_FILE%"
call :WRITE_LOG "Network test failed or received no successful replies"
pause
goto MAIN_MENU

:FILE_BACKUP
cls
echo [File Backup Manager]
echo Enter the full path of the folder you want to back up.
echo Example: C:\Users\YourName\Documents
echo.
set "SOURCE_DIR="
set /p "SOURCE_DIR=Source folder: "

if not defined SOURCE_DIR (
    echo No source folder entered.
    pause
    goto MAIN_MENU
)

if not exist "%SOURCE_DIR%\." (
    echo ERROR: That folder does not exist.
    call :WRITE_LOG "Backup rejected because the source folder was not found"
    pause
    goto MAIN_MENU
)

echo.
echo IMPORTANT: Do not choose a folder that contains the TechDesk
echo Backups folder, because that could cause repeated copying.
echo.
set "CONFIRM_BACKUP="
set /p "CONFIRM_BACKUP=Continue with this source folder? (Y/N): "
if /I not "%CONFIRM_BACKUP%"=="Y" (
    echo Backup cancelled.
    call :WRITE_LOG "User cancelled a backup"
    pause
    goto MAIN_MENU
)

set "DEST_DIR=%BACKUP_DIR%\Backup_%RANDOM%"
set "REPORT_FILE=%REPORT_DIR%\Backup_%RANDOM%.txt"
md "%DEST_DIR%" 2>nul

if not exist "%DEST_DIR%\" (
    echo ERROR: Could not create the backup destination.
    call :WRITE_LOG "Backup failed because the destination could not be created"
    pause
    goto MAIN_MENU
)

echo TECHDESK - BACKUP REPORT>"%REPORT_FILE%"
echo Generated: %date% %time%>>"%REPORT_FILE%"
echo Source: %SOURCE_DIR%>>"%REPORT_FILE%"
echo Destination: %DEST_DIR%>>"%REPORT_FILE%"
echo.>>"%REPORT_FILE%"
echo Starting file copy...
xcopy "%SOURCE_DIR%\*" "%DEST_DIR%\" /E /I /H /Y /C >>"%REPORT_FILE%" 2>&1

REM XCOPY returns different error levels; check the highest codes first.
if errorlevel 5 goto BACKUP_FAILED
if errorlevel 4 goto BACKUP_FAILED
if errorlevel 2 goto BACKUP_FAILED
if errorlevel 1 goto BACKUP_NO_FILES
goto BACKUP_SUCCESS

:BACKUP_SUCCESS
echo Backup completed. Review the report for copied files.
echo Destination: "%DEST_DIR%"
echo Report: "%REPORT_FILE%"
call :WRITE_LOG "File backup completed"
pause
goto MAIN_MENU

:BACKUP_NO_FILES
echo XCOPY did not copy any files. The source may be empty.
echo Review: "%REPORT_FILE%"
call :WRITE_LOG "Backup completed with no files copied"
pause
goto MAIN_MENU

:BACKUP_FAILED
echo ERROR: The backup command reported a problem.
echo Review the report for details: "%REPORT_FILE%"
call :WRITE_LOG "File backup reported an error"
pause
goto MAIN_MENU

:FILE_SEARCH
cls
echo [File Search and Report]
echo Search includes subfolders.
echo Example folder: C:\Users\YourName\Documents
echo Example pattern: *.pdf
echo.
set "SEARCH_DIR="
set /p "SEARCH_DIR=Folder to search: "

if not defined SEARCH_DIR (
    echo No folder entered.
    pause
    goto MAIN_MENU
)

if not exist "%SEARCH_DIR%\." (
    echo ERROR: That folder does not exist.
    call :WRITE_LOG "File search rejected because the folder was not found"
    pause
    goto MAIN_MENU
)

set "SEARCH_PATTERN="
set /p "SEARCH_PATTERN=Filename or pattern (example *.pdf): "
if not defined SEARCH_PATTERN set "SEARCH_PATTERN=*.*"

set "REPORT_FILE=%REPORT_DIR%\FileSearch_%RANDOM%.txt"
set "TEMP_RESULTS=%REPORT_DIR%\SearchResults_%RANDOM%.tmp"

REM Save matching paths first so the script can detect an empty result.
dir /s /b /a-d "%SEARCH_DIR%\%SEARCH_PATTERN%" >"%TEMP_RESULTS%" 2>nul

for %%A in ("%TEMP_RESULTS%") do set "RESULT_SIZE=%%~zA"

(
    echo TECHDESK - FILE SEARCH REPORT
    echo Generated: %date% %time%
    echo Search folder: %SEARCH_DIR%
    echo Search pattern: %SEARCH_PATTERN%
    echo.
    echo ===== MATCHING FILES =====
) >"%REPORT_FILE%"

if "%RESULT_SIZE%"=="0" goto SEARCH_NO_RESULTS

type "%TEMP_RESULTS%" >>"%REPORT_FILE%"
del "%TEMP_RESULTS%" 2>nul
echo.
echo Search complete. Matching file paths were saved to:
echo "%REPORT_FILE%"
call :WRITE_LOG "File search report generated with results"
pause
goto MAIN_MENU

:SEARCH_NO_RESULTS
echo No matching files were found.>"%TEMP_RESULTS%"
type "%TEMP_RESULTS%" >>"%REPORT_FILE%"
del "%TEMP_RESULTS%" 2>nul
echo.
echo No matching files were found.
echo Report saved to: "%REPORT_FILE%"
call :WRITE_LOG "File search completed with no matching results"
pause
goto MAIN_MENU

:VIEW_LOG
cls
echo [Activity Log]
echo ------------------------------------------------------------
if exist "%LOG_FILE%" (
    type "%LOG_FILE%"
) else (
    echo No activity log is available yet.
)
echo ------------------------------------------------------------
echo.
pause
goto MAIN_MENU

:WRITE_LOG
REM Append a timestamped message to the activity log.
>>"%LOG_FILE%" echo [%date% %time%] %~1
exit /b

:EXIT_PROGRAM
call :WRITE_LOG "TechDesk closed"
echo.
echo Thank you for using TechDesk.
echo Reports and backups are stored in the program folders.
endlocal
exit /b 0
