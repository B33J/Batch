:: By bkelley 2017/10/25   Version 1.0
:: A script to change the "CMS" tag string to "CloudFront" in AWS Cloudfront Distributions.
:: Use a list of Distribution IDs to specify which ones to update. See "sourcefile" variable below.
@echo off
setlocal EnableDelayedExpansion

:: VARIABLES
cls
:: If you're not bkelley, delete the <IF "%username%" == "bkelley" > part and change your profile name if necessary.
IF "%username%" == "bkelley" set "setProfile=--profile default"
:: Distribution ID
set distID=
:: ETag pulled out of the distribution config
set ETagvar=
:: Set our working directory
set workdir=C:\bkelley_scripts\cloudfront
:: File to get the list of Distribution IDs from
set sourcefile=%workdir%\list_of_IDs.txt
:: Strings to change from (keep the quotation mark on the very end)
set "changestringfrom=\"Value\": \"CMS\""
:: Strings to change to (keep quotation mark on the end)
set "changestringto=\"Value\": \"CloudFront\""
:: END VARIABLES

FOR /F "tokens=* USEBACKQ" %%A IN (%sourcefile%) DO set /a countDistIDs+=1
echo.
echo There are %countDistIDs% Distributions to do.
echo.
echo.
:: The main loop that sets the distID and calls the main work
FOR /F "tokens=* USEBACKQ" %%B IN (%sourcefile%) DO (
	set distID=%%B
	CALL :MAINPROCESS
)

GOTO quit

:MAINPROCESS
set /a intcount+=1
:: Get the distribution info to grab the ARN string
aws cloudfront get-distribution --id %distID% %setProfile% > %workdir%\temp_arn.json
IF NOT "%errorlevel%" == "0" (goto skipthisone)
echo.
echo Working on %distID% ^(!intcount!^)
:: Scan the downloaded file for its ARN string
FOR /F "tokens=2 USEBACKQ delims= " %%H IN (`findstr ARN:aws:cloudfront %workdir%\temp_arn.json`) DO (
	set ARNstring=%%H
	set ARNstring=!ARNstring:~1,-1!
	echo ARN string is: !ARNstring!
	echo.
)

:: Now get distribution's tags
echo.
echo ~Downloading !distID!'s tags
aws cloudfront list-tags-for-resource --resource !ARNstring! %setProfile% > %workdir%\temp_dist_tags.json

:: Replace the tag strings
echo.
echo ~Replacing "CMS" with "CloudFront"
Powershell -C "(Get-Content %workdir%\temp_dist_tags.json) -replace '%changestringfrom%', '%changestringto%' | Set-Content %workdir%\temp_new_tag.json"


:: Then update the distribution tags with the edited temp_new_tag.json file
echo.
echo ~Updating !distID! with the new tag^(s^)
aws cloudfront tag-resource --resource !ARNstring! %setProfile% --cli-input-json file://%workdir%\temp_new_tag.json
echo.
echo Done with !distID!
echo ~@~@~@~@~@~@~
echo.
echo.
:skipthisone
:: Clean up after each operation
del %workdir%\temp_arn.json
del %workdir%\temp_dist_tags.json
del %workdir%\temp_new_tag.json
timeout /t 1 >nul

EXIT/B


:quit
echo.
echo Finished script.
echo.
pause
color 0F
GOTO:EOF