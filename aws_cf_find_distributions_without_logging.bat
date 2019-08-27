:: Find CF distributions with no buckets for logs
@echo off
setlocal EnableDelayedExpansion



:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt

CALL aws_cli_mfa.bat


:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt
set downloadfile=tmp_file.json
set tempfile=temp_file.json
set outputfile=%workdir%\CF_Distributions_without_logging.txt


:: END VARIABLES

FOR /F "tokens=* USEBACKQ" %%A IN (%sourcefile%) DO set /a countDistIDs+=1
echo There are %countDistIDs% Distributions to do.
echo.
echo.
:: The main loop that sets the distID and calls the main work
FOR /F "tokens=* USEBACKQ" %%B IN (%sourcefile%) DO (
	set distID=%%B
	CALL :MAINPROCESS
)
:: Clean up any existing tempfile before we begin
del %workdir%\%tempfile%

GOTO quit

:MAINPROCESS
set /a intcount+=1
echo.
echo ^(Doing !intcount!^/!countDistIDs!^)
:: Get the distribution config file
echo ~Getting %distID% configuration file from AWS...
echo.
aws cloudfront get-distribution-config --id %distID% > %workdir%\%tempfile%
IF "%errorlevel%" == "255" (
	echo.
	echo ############# There was an error.  Please review. #############
	echo.
	pause
	EXIT /B
)

:: Check config file for "Bucket" value. If it doesn't find "cmg-cf-logs", output stuff.
findstr cmg-cf-logs %workdir%\%tempfile%>nul
IF NOT %ERRORLEVEL% EQU 0 echo !distID! does not have logging set. & echo.>>%outputfile% & echo !distID!>>%outputfile% & findstr Comment %workdir%\%tempfile%>>%outputfile% & timeout /t 2>nul

:: exit MAINPROCESS
EXIT/B


:quit
echo.
echo Finished script.
echo.
:: pause
color 0F
GOTO:EOF