:: By bkelley 2017/10/25   Version 1.0
:: A script to update the "MaxTTL" values in AWS Cloudfront Distributions.
:: Use a list of Distribution IDs to specify which ones to update. See "sourcefile" variable below.
@echo off
setlocal EnableDelayedExpansion

:: VARIABLES
cls
:: Set my user profile for AWS CLI. If you're not bkelley, delete the <IF "%username%" == "bkelley" > part and change your profile name if necessary.
IF "%username%" == "bkelley" set "setProfile=--profile B33J"
:: Distribution ID
set distID=
:: ETag pulled out of the distribution config
set ETagvar=
:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt
set downloadfile=tmp_file.json
set tempfile=temp_file.json
set newTTLvar=1000
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
:: Get the distribution config file
aws cloudfront get-distribution-config --id %distID% %setProfile% > %workdir%\%tempfile%
echo Distribution ID is: %distID%
:: Scan the downloaded file for its ETag value
FOR /F "tokens=2 USEBACKQ delims= " %%H IN (`findstr ETag %workdir%\%tempfile%`) DO (
	set ETagvar=%%H
	REM Format the variable to be cleaner
	set ETagvar=!Etagvar:~1,-2!
	echo ETag value is: !ETagvar!
	echo.
)
:: Scan the downloaded file for its MaxTTL value
FOR /F "tokens=2 USEBACKQ delims= " %%I IN (`findstr MaxTTL %workdir%\%tempfile%`) DO (
	set MaxTTLvar=%%I
	REM Format the variable to be cleaner
	set MaxTTLvar=!MaxTTLvar:~,-1!
	echo MaxTTL value is: !MaxTTLvar!
	echo.
)
echo We want to change the MaxTTL value to !newTTLvar!
echo.

:: Replace the MaxTTL values
echo ~Changing MaxTTL values
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '\"MaxTTL\": !MaxTTLvar!', '\"MaxTTL\": !newTTLvar!' | Set-Content %workdir%\%tempfile%"

:: Remove <"ETag": "E31MEC1OY7HP6F",> and <"DistributionConfig": {> lines
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
aws cloudfront update-distribution --id %distID% %setProfile% --distribution-config file://%workdir%\%tempfile% --if-match !ETagvar! >nul
echo.
echo Done with %distID%
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