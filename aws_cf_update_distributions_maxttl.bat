:: By bkelley 2017/10/25   Version 1.0
:: A script to update the "MaxTTL" values in AWS Cloudfront Distributions.
:: Use a list of Distribution IDs to specify which ones to update. See "sourcefile" variable below.
@echo off
setlocal EnableDelayedExpansion

:: VARIABLES
cls
:: Set my user profile for AWS CLI. If you're not bkelley and your default account has permissions, delete the line immediately below.
IF "%username%" == "bkelley" set "setProfile=--profile default"
:: Distribution ID
set distID=
:: ETag pulled out of the distribution config, needed to update the Distribution config via CLI
set ETagvar=
:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt
set downloadfile=tmp_file.json
set tempfile=temp_file.json
:: What "MaxTTL" value to find and replace in the distributions
set MaxTTLvar=900
:: What new value to change the MaxTTL value to
set newTTLvar=86400
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
del %workdir%\%tempfile%
GOTO quit

:MAINPROCESS
set /a intcount+=1
:: Get the distribution config file
echo ~Getting %distID% configuration file from AWS...
echo.
aws cloudfront get-distribution-config --id %distID% %setProfile% > %workdir%\%tempfile%

:: Scan the downloaded file for its ETag value
FOR /F "tokens=2 USEBACKQ delims= " %%H IN (`findstr ETag %workdir%\%tempfile%`) DO (
	set ETagvar=%%H
	REM Format the variable to be cleaner
	set ETagvar=!Etagvar:~1,-2!
	echo ETag value is: !ETagvar!
	echo.
)

:: Replace the MaxTTL values
echo ~Changing MaxTTL values to !newTTLvar!
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"MaxTTL\": !MaxTTLvar!', '\"MaxTTL\": !newTTLvar!' | Set-Content %workdir%\%tempfile%"

:: Remove <"ETag": "",> and <"DistributionConfig": {> lines
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
aws cloudfront update-distribution --id %distID% %setProfile% --distribution-config file://%workdir%\%tempfile% --if-match !ETagvar! >nul
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
pause
color 0F
GOTO:EOF