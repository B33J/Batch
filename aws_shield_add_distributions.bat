:: For AWS Shield - adding Cloudfront Distributions via IDs in a text file.
@echo off
cls
setlocal EnableDelayedExpansion
echo.
echo Please make sure the CLI MFA has been completed before running this script.
echo.
echo.
pause

IF NOT EXIST "cloudfront\list_of_prd_IDs_for_Shield.txt" (
	echo.
	echo Hey, cannot find source file.  Where is it?
	echo.
	goto quit
)

:: Get a count of the items to do
FOR /F %%a in (cloudfront\list_of_prd_IDs_for_Shield.txt) DO set /a idCount+=1

echo.
echo There are !idCount! Distributions to add to Shield...
echo.
timeout /t 3 >nul

:: Set the Distribution ID, then get the ARN of the Distribution ID, then get the Comment, then go do the aws shield create-protection command
FOR /F %%A in (cloudfront\list_of_prd_IDs_for_Shield.txt) DO (
	set DistributionID=%%A
	FOR /F "USEBACKQ" %%M IN (`aws cloudfront get-distribution --id !DistributionID! --query "Distribution.[ARN]" --output text --region us-east-1`) DO ( 
		set distributionARN=%%M
		FOR /F "USEBACKQ" %%S IN (`aws cloudfront get-distribution --id !DistributionID! --query "Distribution.DistributionConfig.[Comment]" --output text --region us-east-1`) DO (
			set distributionComment=%%S
			CALL :AddToShield
		)
	)
)
:: After looping through all Distribution IDs, quit
goto quit

:AddToShield
:: Run the Shield command
set /a count+=1
echo.
echo Adding !DistributionID! to Shield. ^(!count!^)
aws shield create-protection --name "!DistributionID! !distributionComment!" --resource-arn !distributionARN! --region us-east-1

EXIT /B

:quit
echo.
echo Finished script.
echo.
pause
color 0F
GOTO:EOF