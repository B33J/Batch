@echo off
cls
setlocal EnableDelayedExpansion
title CMG - Amazon Certificate Manager - Search Tool
::for %%i in (%1) do set filedir=%%~dpi
::for %%i in (%1) do set sourcefile=%%~nxi
set line=@@@@@@@@@@@@@@
set dateY=%date:~-4%
set dateM=%date:~4,2%
set dateD=%date:~7,2%

:: TRY NOT TO DELETE ANYTHING ABOVE THIS LINE
jq -help > nul 2>&1
IF "%errorlevel%" == "9009" (
	echo.
	echo WARNING:
	echo It does not appear that JQ is installed.
	echo This will limit some functionality of this script.
	echo.
	pause
)
echo.
echo Welcome to the AWS ACM search tool by bkelley
echo _____________________________________________
echo.
echo Run CLI MFA for this command window? (y/n)
set answer=
set /p answer=
IF /I "%answer%" == "y" (
	IF NOT EXIST cli_mfa.bat (
		echo.
		echo ERROR:
		echo Please download the "cli_mfa.bat" file from the github repo.
		echo.
		pause
		goto quit
	)
	CALL cli_mfa.bat
)
:start
echo.
echo.
echo %line%%line%%line%%line%
echo.
echo This tool is used to search AWS Certificate Manager.
echo Options with '*' require "jq" to be installed.
echo.
echo.
echo 1^) List all certificates ^(ARNs and DomainNames^)
echo 2^) Search all certificate Domain Names *
echo 3^) Download all certs ^(slow^^!^) to a single file for searching Alternative Names
IF EXIST %USERPROFILE%\Documents\temp_all_certs.json (
	echo 4^) Search for Alternative Names *
) ELSE (
	echo 4^) Search for Alternative Names * ^(NOT AVAILABLE - run option 3 first^)
)
echo 5^) 'Describe-Certificate' using an ARN
echo 6^) 'Get-Certificate' using an ARN
echo Q^) Quit
echo =========
set acmanswer=
set /p acmanswer=

IF /I "%acmanswer%" == "Q" goto quit
IF "%acmanswer%" == "1" (
	echo.
	CALL :GET_CERTS
	type %USERPROFILE%\Documents\temp_certs.json
)
IF "%acmanswer%" == "2" (
	echo.
	echo What is your search term?
	set searchterm=
	set /p searchterm=
	CALL :GET_CERTS
	FOR /F "delims=: tokens=1,3 usebackq" %%a in (`type %USERPROFILE%\Documents\temp_certs.json ^| findstr /I /N /C:"!searchterm!"`) do (
		echo.
		set DomainName=%%b
		set DomainName=!DomainName: =!
		echo !DomainName!
		set /A skip=%%a-2
		set "skipthing=skip=!skip!"
		CALL :process_skip
	)
)
IF "%acmanswer%" == "3" (
	echo.
	echo Running "describe-certificate" on all certificates...
	echo.
	set intcount=0
	FOR /F %%C in ('aws acm list-certificates ^| findstr /C:"DomainName"') DO set /a intcount+=1
	echo There are !intcount! certificates to process.
	CALL :download_all_certs
	echo.
	echo Find your file at: %USERPROFILE%\Documents\temp_all_certs.json
	echo.
	echo Now you may run option 4 to search for Alternative Names or CNAMEs in the certificates.
	echo.
	pause
) 
IF "%acmanswer%" == "4" (
	IF NOT EXIST %USERPROFILE%\Documents\temp_all_certs.json (
		echo.
		echo FILE USED IN SEARCH NOT FOUND.
		echo.
		echo Please download the all-certs file by using option 5 in the main menu first.
		echo.
		pause
	) ELSE (
		echo.
		echo SEARCH ALL CERTS
		echo.
		echo What is your search term?
		set searchterm=
		set /p searchterm=
		echo.
		FOR /F "delims= tokens=* usebackq" %%a in (`type %USERPROFILE%\Documents\temp_all_certs.json ^| jq -r ".[] ^| select^(.SubjectAlternativeNames[] ^| contains^(\"!searchterm!\"^)^) ^| {Name: .DomainName, ARN: .CertificateArn} ^|.[]"`) do (
			echo %%a
		)
	)
)
IF "%acmanswer%" == "5" (
	echo.
	echo Describe-Certificate
	echo.
	echo What is the Certificate ARN?
	set certarn=
	set /p certarn=
	aws acm describe-certificate --certificate-arn !certarn!
)
IF "%acmanswer%" == "6" (
	echo.
	echo Get-Certificate
	echo.
	echo What is the Certificate ARN?
	set certarn=
	set /p certarn=
	aws acm get-certificate --certificate-arn !certarn!
)

goto start

:quit
echo.
echo Finished script.
echo.
REM pause
color 0F
GOTO:EOF


:process_skip
FOR /F "%skipthing% tokens=2,3" %%A in (%USERPROFILE%\Documents\temp_certs.json) DO (
	echo %%A
	EXIT /B
)
EXIT /B

:GET_CERTS
:: If the cert list file has the same creation date as today, do nothing
for /f "eol=: delims= tokens=1 usebackq" %%F in (`dir %USERPROFILE%\Documents\temp_certs.json /b /s 2^>nul`) DO (
	set filetime=%%~tF
	set filetime=!filetime:~0,10!
	IF NOT "!filetime!" == "%dateM%/%dateD%/%dateY%" (
		echo Downloading file...
		aws acm list-certificates> %USERPROFILE%\Documents\temp_certs.json
	)
)
:: Then, if the cert list file does not exist, download it
IF NOT EXIST %USERPROFILE%\Documents\temp_certs.json (
	echo Downloading file...
	aws acm list-certificates> %USERPROFILE%\Documents\temp_certs.json
)
:: exit GET_CERTS
EXIT /B

:download_all_certs
break>%USERPROFILE%\Documents\temp_all_certs.json
:: %userprofile%\Documents\temp_certs.json
FOR /F tokens^=4^ delims^=^"^ usebackq %%m IN (`aws acm list-certificates ^| jq -c ^".CertificateSummaryList[] ^| {ARN: .CertificateArn}^"`) DO (
	set /a certCount+=1
	echo ^(!certCount!/!intcount!^) %%m
	aws acm describe-certificate --certificate-arn %%m>>%USERPROFILE%\Documents\temp_all_certs.json
	echo.>>%USERPROFILE%\Documents\temp_all_certs.json
)
EXIT /B
