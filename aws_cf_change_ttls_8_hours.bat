:: By bkelley 2018/11/30   Version 1.0
:: A script to update the "MinTTL" and "DefaultTTL" values in AWS Cloudfront Distributions.
:: Specify which Distribution IDs to change in the "distributionIDs" variable below.
@echo off
setlocal EnableDelayedExpansion

cls

:: VARIABLES
:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: List of Distribution IDs to process
set "distributionIDs=E15W9EXAMPLE E1VK5EXAMPLE"
set downloadfile=tmp_file.json
set tempfile=temp_file.json

set MinTTLvar=900
set newMinTTLvar=28800
set defaultTTLvar=900
set newDefaultTTLvar=28800

set Min120TTLvar=120
set newMin120TTLvar=28120
set default120TTLvar=120
set newDefault120TTLvar=28120

:: END VARIABLES
echo.
echo This script will change the TTLs of the distributions listed inside this script.
echo ^(Make sure your CLI MFA is completed before running this script^)
pause
echo.
echo.
:: The main loop that sets the distID and calls the main work
FOR %%B IN (%distributionIDs%) DO (
	set distID=%%B
	CALL :MAINPROCESS
)
IF EXIST %workdir%\%tempfile% del %workdir%\%tempfile%
GOTO quit

:MAINPROCESS
set /a intcount+=1
:: Get the distribution config file
echo ~Getting ^(!intcount!^) %distID% configuration file from AWS...
echo.
aws cloudfront get-distribution-config --id %distID% --output json> %workdir%\%tempfile%

:: Scan the downloaded file for its ETag value
FOR /F "tokens=2 USEBACKQ delims= " %%H IN (`findstr ETag %workdir%\%tempfile%`) DO (
	set ETagvar=%%H
	REM Format the variable to be cleaner
	set ETagvar=!Etagvar:~1,-2!
	echo ETag value is: !ETagvar!
	echo.
)

:: Replace the MinTTL values
echo ~Changing MinTTL values from !MinTTLvar! to !newMinTTLvar!
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"MinTTL\": !MinTTLvar!', '\"MinTTL\": !newMinTTLvar!' | Set-Content %workdir%\%tempfile%"

:: Replace the DefaultTTL values
echo ~Changing DefaultTTL values from !DefaultTTLvar! to !newDefaultTTLvar!
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"DefaultTTL\": !DefaultTTLvar!', '\"DefaultTTL\": !newDefaultTTLvar!' | Set-Content %workdir%\%tempfile%"

:: Replace the 120 second MinTTL values
echo ~Changing 120 second MinTTL values from !Min120TTLvar! to !newMin120TTLvar!
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"MinTTL\": !Min120TTLvar!', '\"MinTTL\": !newMin120TTLvar!' | Set-Content %workdir%\%tempfile%"

:: Replace the 120 second DefaultTTL values
echo ~Changing 120 second DefaultTTL values from !Default120TTLvar! to !newDefault120TTLvar!
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"DefaultTTL\": !Default120TTLvar!', '\"DefaultTTL\": !newDefault120TTLvar!' | Set-Content %workdir%\%tempfile%"

:: Remove <"ETag": "E31MEC1OY7H***etc",> and <"DistributionConfig": {> lines
echo ~Removing ETag and DistributionConfig lines...
echo.
type %workdir%\%tempfile% | findstr /v "ETag" | findstr /v "DistributionConfig" > %workdir%\tmp.json
timeout /t 1 >nul
type %workdir%\tmp.json > %workdir%\%tempfile%
del %workdir%\tmp.json

:: Remove the last line of the file which is a curly bracket
echo ~Removing last curly bracket in the file
echo.
Powershell -C "$path = '%workdir%\%tempfile%'; $file = Get-Content $path -ReadCount 0; Set-Content $path -Value ($file | Select-Object -First ($file.count - 1))"

:: Then update the distribution with the edited json file
echo ~Sending the updated configuration distribution to AWS...
echo.
aws cloudfront update-distribution --id %distID% --distribution-config file://%workdir%\%tempfile% --if-match !ETagvar! >nul
echo.
echo Done with %distID% ^(!intcount!^)
echo ~@~@~@~@~@~@~
echo.
timeout /t 2 >nul

EXIT/B


:quit
echo.
echo Finished script.
echo.
:: pause
color 0F
GOTO:EOF

