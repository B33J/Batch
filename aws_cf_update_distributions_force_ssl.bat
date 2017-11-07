:: By bkelley 2017/11/06   Version 1.0
:: A script to update the Origin "https-only" and Behavior "redirect-to-https" values in AWS Cloudfront Distributions.
:: Use a list of Distribution IDs to specify which ones to update. See "sourcefile" variable below.
@echo off
setlocal EnableDelayedExpansion
cls

:: VARIABLES

:: Set my user profile for AWS CLI
set "setProfile=--profile default"
:: Distribution ID
set distID=
:: ETag pulled out of the distribution config, needed to make the distribution config change via CLI
set ETagvar=
:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt
set downloadfile=tmp_file.json
set tempfile=temp_file.json

:: Of the next variables below, make sure to keep a quotation mark on the end
:: First set of strings to change
set "changevaluefrom=\"ViewerProtocolPolicy\": \"allow-all\""
set "changevalueto=\"ViewerProtocolPolicy\": \"redirect-to-https\""
:: Second set of strings to change
set "changevalue2from=\"OriginProtocolPolicy\": \"match-viewer\""
set "changevalue2to=\"OriginProtocolPolicy\": \"https-only\""

:: END VARIABLES

:: Check to see if the sourcefile to use exists
IF NOT EXIST %sourcefile% (
	echo.
	echo Hey, I cannot find your list of Distribution IDs to use.
	echo Where is that text file?
	echo.
	pause.
	goto quit
)
:: Count the number of Distribution IDs in the source file
FOR /F "tokens=*" %%A IN (%sourcefile%) DO set /a countDistIDs+=1
IF "%countDistIDs%" == "" (
	echo.
	echo Hey, the list of Distribution IDs to use is empty.
	echo Please check on that.
	echo.
	pause
	goto quit
)
echo.
echo There are %countDistIDs% Distributions to do.
echo.
echo.

:: The main loop that sets the distID and calls the main work
FOR /F "tokens=*" %%B IN (%sourcefile%) DO (
	set distID=%%B
	CALL :MAINPROCESS
)
del %workdir%\%tempfile%
GOTO quit

:MAINPROCESS
set /a intcount+=1
echo Distribution ID is: %distID% ^(!intcount!^)
echo.
echo ~Getting the distribution config file...
echo.

:: Get the distribution config file
aws cloudfront get-distribution-config --id %distID% %setProfile% > %workdir%\%tempfile%
IF NOT "%errorlevel%" == "0" (
	echo.
	echo Uh oh, we ran into an issue and have to abort.
	echo Better start double-checking things, like:
	echo ~AWS ClI profile being used, permissions
	echo ~List of Distribution IDs to use is correct
	echo ~Vaguely other stuff^^!
	echo.
	pause
	goto quit
)

:: Scan the downloaded file for its ETag value
FOR /F "tokens=2 USEBACKQ delims= " %%H IN (`findstr ETag %workdir%\%tempfile%`) DO (
	set ETagvar=%%H
	REM Format the variable to be cleaner
	set ETagvar=!Etagvar:~1,-2!
	echo ETag value is: !ETagvar!
	echo.
)

:: Replace the ViewerProtocolPolicy values
echo ~Changing "allow-all" to "redirect-to-https"
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '%changevaluefrom%', '%changevalueto%' | Set-Content %workdir%\%tempfile%"

:: Replace OriginProtocolPolicy values
echo ~Changing "match-viewer" to "https-only"
echo.
Powershell -C "(Get-Content %workdir%\%tempfile%) -replace '%changevalue2from%', '%changevalue2to%' | Set-Content %workdir%\%tempfile%"

:: Remove <"ETag": "",> and <"DistributionConfig": {> lines (to get the config format to work with CloudFront properly)
echo ~Removing ETag and DistributionConfig lines...
echo.
type %workdir%\%tempfile% | findstr /v "ETag" | findstr /v "DistributionConfig" > %workdir%\tmp.json
timeout /t 1 >nul
type %workdir%\tmp.json > %workdir%\%tempfile%
del %workdir%\tmp.json

:: Remove the last line of the file which is a curly bracket (as above, to get the format right)
echo ~Removing last curly bracket in the file
echo.
Powershell -C "$path = '%workdir%\%tempfile%'; $file = Get-Content $path -ReadCount 0; Set-Content $path -Value ($file | Select-Object -First ($file.count - 1))"

:: Then update the distribution with the edited json file
echo.
echo ~Sending the updated config file up to CloudFront...
echo.
aws cloudfront update-distribution --id %distID% %setProfile% --distribution-config file://%workdir%\%tempfile% --if-match !ETagvar! >nul

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
