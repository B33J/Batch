@echo off
::By bkelley 2017/08/11 - 2017/10/09 For restserver.log files (Version 1.0!  Woo!)
:: This batch file has been 'sanitized/vagued up' since it's on Github, so it's currently broken!
:: The purpose of this script is to allow for easy restserver.log pulling and string finding so we can update the excel document.
:: See more documentation about the whole process in "Documentation.docx"
:: This script pulls logs from the "" S3 bucket and Static External and Internal servers. 
:: The S3 bucket contains the restserver.logs from the Auto-Scaled instances.
:: Static servers (External/Internal) still have their restserver logs archived on their filesystem in /filesystem/directory/logsfiles/oldlogs/
:: For the script to fully function, it requires being on the Company network, so join the VPN if you are working remotely.
:: It also requires an installation of 7-zip and PuTTY installed to C:\Program Files\
:: As well it requires having the AWS CLI installed.
:: If you've copied this script to your own computer, please see the "MY CUSTOM VARIABLES" section to set them to your own structure, if so desired. Technically, you can leave them as-is and still run the script.
:: A double-colon "::" denotes a comment about the code
:: If a line has "REM" first, it is a commented-out variable or code
:: This script will skip downloading files if the .txt for that server exists already in the output directory.  That's good for using this script to download specific server logs again if you delete the .txt out of the output directory.
:: Now we have a seperate AWS IAM account solely for accessing the "" bucket and downloading files. Credentials below:
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=

setlocal EnableDelayedExpansion
set line=@@@@@@@@@@
cls

:: @@@@@@@@@@@@@@@@@@@@@@@@@
:: BEGIN MY CUSTOM VARIABLES
:: @@@@@@@@@@@@@@@@@@@@@@@@@

:: The string to pull out of the raw log files:
set stringtosearch="GET /action/process processed in"
:: Processtype options[Process_Here, By-Error-Type, Date-Time, or Custom]
set processtype=Process_Here
:: The directory to which the final processed files are put
set outputdir=C:\Users\%username%\Documents\restserver_log\Filtered_%processtype%\
:: The directory to which files are downloaded and then processed and then deleted
set downloaddir=C:\Users\%username%\Documents\restserver_log\Raw\
:: Program installation directories
set AWSCLIdirectory="C:\Program Files\Amazon\AWSCLI\aws.exe"
set zipdirectory="C:\Program Files\7-Zip\7z.exe"
set puttydirectory="C:\Program Files\PuTTY\pscp.exe"
:: For user "bkelley", this variable is to allow the script to open the Excel file automatically for convenience
set excelfile="C:\Users\%username%\Documents\restserver_log\Document.xlsx"
:: For user "bkelley", Dropbox directory for sharing with this other user for the stuff
set dropbox=C:\Users\bkelley\Dropbox\log-restserver\
:: Static server IP variables
::  Prod:
set serveripExternal=10.10.10.15
set serveripInternal=10.10.10.10
::  Staging:
REM set serveripExternal=10.10.10.25
REM set serveripInternal=10.10.10.20

:: @@@@@@@@@@@@@@@@@@@@@@@
:: END MY CUSTOM VARIABLES
:: @@@@@@@@@@@@@@@@@@@@@@@

echo.
echo Hello^^! This script is for gathering 'certain' info from the restserver.log files.
echo.
echo We can pull a certain day's log files by specifying the YEAR, MONTH, and DAY.
echo The MONTH and DAY inputs have to be in at least a double-digit format. ^(e.g. "02"^)
echo Leaving the next inputs blank will instead use the answer in [brackets], which is today.
echo.
:questionyear
echo.
echo Which YEAR to use? [%date:~-4%]
set dateY=
set /p dateY=
IF "%dateY%" == "" set dateY=%date:~-4%
IF "%dateY%" LSS "2017" (
	echo.
	echo #########
	echo Sorry, logs do not exist before 2017.
	echo And time traveling doesn't exist. Try using your current year.
	echo.
	pause
	goto questionyear
)
echo %dateY%| findstr /r "^20[0-9][0-9]$">nul
IF %errorlevel% EQU 0 goto questionmonth
echo.
echo ##########
echo Sorry, that date format doesn't look right. Please try again.
echo.
pause
goto questionyear

:questionmonth
echo.
echo Which MONTH to use? [%date:~4,2%]
set dateM=
set /p dateM=
IF "%dateM%" == "" (set dateM=%date:~4,2%)
IF NOT "%dateM:~0,1%" == "0" (
	IF "%dateM%" GTR "12" (
		echo.
		echo ##########
		echo Sorry, that month doesn't exist on a calendar. An acceptable range is 01 - 12.
		echo.
		pause
		goto questionmonth
	)
)
echo %dateM%| findstr /r "^[0-1][0-9]$">nul
IF %errorlevel% EQU 0 goto questionday
echo.
echo ##########
echo Sorry, that date format doesn't look right. Please try again.
echo An acceptable range is 01 - 12.
echo.
pause
goto questionmonth

:questionday
echo.
echo Which DAY to use? [%date:~7,2%]
set dateD=
set /p dateD=
IF "%dateD%" == "" (set dateD=%date:~7,2%)
IF NOT "%dateD:~0,1%" == "0" (
	IF "%dateD%" GTR "31" (
		echo.
		echo ##########
		echo Sorry, that day doesn't exist on a calendar. An acceptable range is 01 - 31.
		echo.
		pause
		goto questionday
	)
)
IF "%dateD%" == "00" goto questionDayError
echo %dateD%| findstr /r "^[0-3][0-9]$">nul
IF %errorlevel% EQU 0 goto finishedSetDate
:questionDayError
echo.
echo ##########
echo Sorry, that date format doesn't look right. Please try again.
echo An acceptable range is 01 - 31.
echo.
pause
goto questionday

:finishedSetDate

:: The archive to download from the static servers has a number in its name. The most recent archive is zero (0). The oldest is seven (7).
:: If the variable below is commented out, then the following code automatically sets which archive number to get
:: If you know specifically which archive to get, then uncomment the next line and change the number to the one you need.
REM set archiveToGet=tomcat.tar.1.gz

:: AUTO ARCHIVE NUMBER GET
:: If you are using the variable above, skip the next section of code
IF NOT "%archiveToGet%" == "" GOTO begin

:: If you set dateM to a different month than the current one, then:
IF NOT "%dateM%" == "%date:~4,2%" (
	set skipGetArchive=1
	echo.
	echo WARNING:
	echo The month you have set is not the current month.
	echo You will need to manually set the "archiveToGet" variable, if applicable.
	echo ^(Sorry^! This particular code is tricky^)
	echo.
	pause
	GOTO begin
)
:: This calculates which archive to get by minusing %dateD% from the actual date.  Today's date equates out to zero.
set dateDtoday=%date:~7,2%
:: below is to test if there are leading zeroes in the date, and work around that for the 'set /a' operation.
IF "%dateDtoday:~0,1%" == "0" (
	IF "%dateD:~0,1%" == "0" (
		:: if both today's date and %dateD% have leading zeroes, then do this:
		set /a archivenumber=%dateDtoday:~1%-%dateD:~1%
		goto skipMathSet
	)
	:: if the actual date is < 10, and %dateD% is NOT < 10, then do this:
	set /a archivenumber=%dateDtoday:~1%-%dateD%
	goto skipMathSet
)
IF "%dateD:~0,1%" == "0" (
	IF "%dateDtoday:~0,1%" == "0" (
		:: if both %dateD% and today's date have leading zeroes, then do this:
		set /a archivenumber=%dateDtoday:~1%-%dateD:~1%
		goto skipMathSet
	)
	:: if %dateD% is < 10, but %dateDtoday% is NOT < 10, then do this:
	set /a archivenumber=%dateDtoday%-%dateD:~1%
	goto skipMathSet
)
:: if neither %dateD% nor %dateDtoday% are < 10, do this:
set /a archivenumber=%dateDtoday%-%dateD%

:skipMathSet
:: if a date you're entering is a higher number than the current date, then:
IF %archivenumber% LSS 0 (
	echo.
	echo ERROR:
	echo The variable "dateD" is set in the future for the current month.
	echo If you're pulling an archive from the previous month, you'll have to
	echo manually set the "archiveToGet" variable in this script.
	echo.
	pause.
	goto quit
)
:: if a date you're entering is greater than 7 days ago, skip getting the archives.
IF %archivenumber% GTR 7 (
	echo.
	echo WARNING:
	echo The date you are using ^(%dateD%^) is older than the oldest archive on the static servers.
	echo.
	echo This script will skip downloading the tomcat.tar.#.gz archives.
	echo.
	set skipGetArchive=1
	pause
)
:: After all that math, set which numbered archive to get
set archiveToGet=tomcat.tar.%archivenumber%.gz
:: END AUTO ARCHIVE NUMBER GET

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Running Status Checks

:begin
echo.
echo Running script configuration checks before we begin...

:: BEGIN TESTS

:: check to see if you have the AWS CLI installed, ask if we need to download the AWSCLI installer or not
aws s3 ls s3://bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1a/ >nul 2>nul
IF "%errorlevel%" EQU "9009" (
	echo.
	echo ERROR:
	echo The AWS CLI tools are not detected on this computer.
	echo.
	echo The tools are needed to download files from the S3 bucket.
	echo.
	:AWSCLIdownloadquestion
	echo.
	echo Would you like to download the AWS CLI .msi installer and run it? [yes/no]
	set userInput=
	set /p userInput=
	IF "!userInput!" == "yes" (
		CALL :InstallAWSCLI
		IF NOT EXIST %AWSCLIdirectory% (
			echo.
			echo If you successfully installed the AWS CLI tools but you see this message,
			echo please open this batch script and change the "AWSCLIdirectory" variable
			echo in the "MY CUSTOM VARIABLES" section to the path of your non-default 
			echo AWS CLI installation directory.
			echo.
			echo If you did not complete the installation process, please check your Downloads
			echo folder for the AWSCLI64.msi to restart the installation manually.
			echo.
			pause
		)
	)
	IF "!userInput!" == "" GOTO AWSCLIdownloadquestion
	IF EXIST %AWSCLIdirectory% GOTO afterAWSCLIcheck
	echo.
	echo Cancelling script...
	echo.
	timeout /t 4>nul
	pause
	set errorlevel=
	goto quit
)
:afterAWSCLIcheck
echo .
:: check to see if your account has access to the S3 bucket
IF "%errorlevel%" EQU "255" (
	echo.
	echo ERROR: 
	echo Cannot access "bucket" S3 bucket^^!
	echo Did the programmatic user "user-s3-bucket-access" lose permissions?
	echo Ask VendorCompany for help.
	echo Email help@VendorCompany.com about the user listed above.
	echo ^(this.guy@VendorCompany.com set up the account^)
	echo.
	pause
	set errorlevel=
	goto quit
)
echo .
:: check S3 bucket to see if the set date exists
IF "%errorlevel%" EQU "1" (
	echo.
	echo ERROR: 
	echo The S3 directory specified may not exist for the date set:
	echo ^(//bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/...^) 
	echo.
	echo Check the S3 console to see if the directory exists for the dates used.
	echo.
	pause
	set errorlevel=
	goto quit
)
echo .
:: check to see if 7-Zip is installed at the expected directory, if not, ask if it needs to be downloaded and installed
IF NOT EXIST %zipdirectory% (
	echo.
	echo ERROR:
	echo Batch cannot find the expected 7-Zip installation.
	echo.
	echo Expected location: %zipdirectory%
	echo.
	echo If you have 7-Zip installed, please open this batch file and set the
	echo variable "zipdirectory" to the location of your 7z.exe file.
	:7zipdownloadquestion
	echo.
	echo If you do not have 7-Zip installed, would you like to download
	echo the 7-Zip installer and run it? [yes/no]
	set userInput=
	set /p userInput=
	IF "!userInput!" == "yes" (
		CALL :Install7zip
		IF NOT EXIST %zipdirectory% (
			echo.
			echo If you successfully installed 7-Zip but you see this message,
			echo please open this batch script and change the "zipdirectory" variable
			echo in the "MY CUSTOM VARIABLES" section to the path of your non-default 
			echo 7-Zip installation directory.
			echo.
			echo If you did not complete the installation process, please check your Downloads
			echo folder for the 7z1701-x64.exe to restart the installation manually.
			echo.
			pause
		)
	)
	IF "!userInput!" == "" GOTO 7zipdownloadquestion
	IF EXIST %zipdirectory% GOTO after7zipcheck
	echo.
	echo Cancelling script...
	echo.
	timeout /t 4>nul	pause
	goto quit
)
:after7zipcheck
echo .
:: check to see if PuTTY is installed at the expected directory, if not, ask to download and install it
IF NOT EXIST %puttydirectory% (
	echo.
	echo ERROR:
	echo Batch cannot find the expected PuTTY installation.
	echo.
	echo Expected location: %puttydirectory%
	echo.
	echo If you have PuTTY installed, please open this batch file and set the
	echo variable "puttydirectory" to the location of your pscp.exe file.
	:puttydownloadquestion
	echo.
	echo If you do not have PuTTY installed, would you like to download
	echo the PuTTY installer and run it? [yes/no]
	set userInput=
	set /p userInput=
	IF "!userInput!" == "yes" (
		CALL :Installputty
		IF NOT EXIST %puttydirectory% (
			echo.
			echo If you successfully installed PuTTY but you see this message,
			echo please open this batch script and change the "puttydirectory" variable
			echo in the "MY CUSTOM VARIABLES" section to the path of your non-default 
			echo PuTTY ^(the pscp.exe file^) installation directory.
			echo.
			echo If you did not complete the installation process, please check your Downloads
			echo folder for the putty-64bit-0.70-installer.msi to restart the installation 
			echo manually.
			echo.
			pause
		)
	)
	IF "!userInput!" == "" GOTO puttydownloadquestion
	IF EXIST %puttydirectory% GOTO afterputtycheck
	echo.
	echo Cancelling script...
	echo.
	timeout /t 4>nul
	pause
	goto quit
)
:afterputtycheck
echo .
:: check to see if the day we're processing already exists in the processed directory
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_external_AS1a.txt" (
	echo.
	echo WARNING:
	echo It seems that you might have processed this day already ^(%dateY%/%dateM%/%dateD%^).
	echo Stop this script if you did not mean to run this script as the day above.
	echo.
	echo Otherwise, if you DO want to run this whole script again...
	pause
)
echo .
:: check to see if you can access the Static servers
%puttydirectory% -batch -scp -pw password -ls username@%serveripExternal%:/directory >nul 2>nul
IF "%errorlevel%" == "1" (
	echo.
	echo ERROR:
	echo Your computer cannot reach the Static servers.
	echo Make sure you are on the Company network or the VPN.
	echo.
	pause
	set errorlevel=
	goto quit
)
echo .

:: END TESTS

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Getting Instance Names
echo.
echo Success^^!
color 0F
echo. 
echo Date to get:      %dateY%/%dateM%/%dateD%
echo Archive to get:   %archiveToGet%
echo Do a FINDSTR for: %stringtosearch%
echo Output to:        %outputdir%
echo --------------------------------------
echo.
echo.
timeout /t 4 >nul
:: Get all log files from External AS1a & AS1b, Internal AS1a & AS1b, External Static, and Internal Static
:: Starting the actual work:
echo.
echo %line%
echo Downloading files from S3 bucket...
:: Get the logfiles from S3, rename them, then process them for "%stringtosearch%" and put them in the output directory

:: External 1a
set exORin=external
set as1aORas1b=AS1a
echo.
echo %exORin% %as1aORas1b%:
:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt" (
	echo.
	echo WARNING:
	echo The file for External AS1a already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt^)
	echo.
	echo We will skip processing External AS1a logs.
	echo.
	pause
	goto SkipDoingExternal1a
)
:: Count how many instance IDs there are
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1a/`) DO set /a instanceINC+=1
:: Grammar nazi
IF "%instanceINC%" EQU "1" (
	echo.
	echo There is %instanceINC% instance listed in this S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %instanceINC% instances listed in this S3 directory.
	echo.
	)

:: Loop through the instance ID directories
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1a/`) DO (
	set instance1ae=%%F
	set /a instanceINC-=1
	echo Going through Instance ID "!instance1ae!" directory.
	CALL :mainInstance1aeLoop
)
:: After escaping the FOR loop, we have processed through all instances, skip the loop
GOTO skipinstanceID1aeLoop
:mainInstance1aeLoop
set restserverLoop=
:: This counts how many objects (restserver.log) files are in the specific S3 directory
for /F "USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%datey%/%dateM%/%dateD%/us-east-1a/%instance1ae%directory/directory/logfiles/tomcat/`) DO set /a restserverLoop+=1
set /a restserverCount+=%restserverLoop%

:: Throw a Warning if this directory doesn't exist or if there are no restserver.log files
IF "%restserverLoop%" == "" (
	echo.
	echo.
	echo WARNING:
	echo The directory we're looking for under "%instance1ae%" doesn't exist.
	echo.
	echo OR we can't find any restserver.log files in where we're looking.
	echo.
	echo Skipping this Instance ID directory.
	echo.
	pause
	goto exitExternal1aLoop
)
:: Grammar nazi
IF "%restserverLoop%" EQU "1" (
	echo.
	echo There is %restserverLoop% restserver.log file in this Instance ID S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %restserverLoop% restserver.log files in this Instance ID S3 directory.
	echo.
	)
timeout /t 2 >nul
:external1aLoop
:: We need to start with the highest number [restserver.log.#] first and process them downward.

IF NOT "%restserverLoop%" == "" (
	set /a restserverLoop-=1
	set restserverFileName=restserver.log.!restserverLoop!
	echo.
)
IF "%restserverLoop%" == "" set restserverFileName=restserver.log
IF %restserverLoop% EQU 0 (
	set restserverLoop=
	set restserverFileName=restserver.log
)
:: Set the file name to get
set %exORin%1a=bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1a/%instance1ae%methode/password/logfiles/tomcat/%restserverFileName%

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Downloading Files from S3: External AS1a
echo %line%
echo Downloading "%restserverFileName%"
aws s3 cp s3://%external1a% %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.
echo.
:: Check if the download succeeded
IF NOT EXIST %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log (
	echo.
	echo ERROR:
	echo There was an issue downloading this log file and we need to abort.
	echo.
	echo Does the file you meant to download actually exist?
	echo.
	echo You might need to check the S3 bucket directory to see if it looks as expected.
	echo.
	echo Then try running this script again if it seems like it should have worked.
	echo.
	pause
	goto quit
)
echo %line%
echo Copying text to temp file "restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
type %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.
echo %line%
echo Deleting downloaded file.
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.

IF "%restserverLoop%" == "" goto exitExternal1aLoop

goto external1aLoop
:exitExternal1aLoop
exit /b
:skipinstanceID1aeLoop
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log...
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
echo Done.
echo.
echo %line%
echo Deleting %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.

:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
	echo.
)
set filesize=
set instanceINC=
:SkipDoingExternal1a

:: External 1b
set as1aORas1b=AS1b
echo.
echo %exORin% %as1aORas1b%:
:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt" (
	echo.
	echo WARNING:
	echo The file for External AS1b already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt^)
	echo.
	echo We will skip processing External AS1b logs.
	echo.
	pause
	goto SkipDoingExternal1b
)
:: Count how many instance IDs there are
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1b/`) DO set /a instanceINC+=1

:: Grammar nazi
IF "%instanceINC%" EQU "1" (
	echo.
	echo There is %instanceINC% instance listed in this S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %instanceINC% instances listed in this S3 directory.
	echo.
	)

:: Loop through the instance ID directories
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1b/`) DO (
	set instance1be=%%F
	set /a instanceINC-=1
	echo Going through Instance ID "!instance1be!" directory.
	CALL :mainInstance1beLoop
)
:: We have processed through all instances, skip the loop
GOTO skipinstanceID1beLoop
:mainInstance1beLoop
set restserverLoop=
:: This counts how many objects (restserver.log) files are in the specific S3 directory
for /F "USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/External-Server/%datey%/%dateM%/%dateD%/us-east-1b/%instance1be%directory/directory/logfiles/tomcat/`) DO set /a restserverLoop+=1
set /a restserverCount+=%restserverLoop%

:: Throw a Warning if this directory doesn't exist or if there are no restserver.log files
IF "%restserverLoop%" == "" (
	echo.
	echo.
	echo WARNING:
	echo The directory we're looking for under "%instance1ae%" doesn't exist.
	echo.
	echo OR we can't find any restserver.log files in where we're looking.
	echo.
	echo Skipping this Instance ID directory.
	echo.
	pause
	goto exitExternal1bLoop
)
:: Grammar nazi
IF "%restserverLoop%" EQU "1" (
	echo.
	echo There is %restserverLoop% restserver.log file in this Instance ID S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %restserverLoop% restserver.log files in this Instance ID S3 directory.
	echo.
	)
timeout /t 2 >nul
:external1bLoop
:: We need to start with the highest number [restserver.log.#] first and process them downward.

IF NOT "%restserverLoop%" == "" (
	set /a restserverLoop-=1
	set restserverFileName=restserver.log.!restserverLoop!
	echo.
)
IF "%restserverLoop%" == "" set restserverFileName=restserver.log
IF %restserverLoop% EQU 0 (
	set restserverLoop=
	set restserverFileName=restserver.log
)
:: Set the file name to get
set %exORin%1b=bucket/logs/External-Server/%dateY%/%dateM%/%dateD%/us-east-1b/%instance1be%directory/directory/logfiles/tomcat/%restserverFileName%

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Downloading Files from S3: External AS1b
echo %line%
echo Downloading "%restserverFileName%"
aws s3 cp s3://%external1b% %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.
echo.

IF NOT EXIST %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log (
	echo.
	echo ERROR:
	echo There was an issue downloading this log file and we need to abort.
	echo.
	echo Does the file you meant to download actually exist?
	echo.
	echo You might need to check the S3 bucket directory to see if it looks as expected.
	echo.
	echo Then try running this script again if it seems like it should have worked.
	echo.
	pause
	goto quit
)
echo %line%
echo Copying text to temp file "restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
type %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.
echo %line%
echo Deleting downloaded file.
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.

IF "%restserverLoop%" == "" goto exitExternal1bLoop

goto external1bLoop
:exitExternal1bLoop
exit /b
:skipinstanceID1beLoop
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log...
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
echo Done.
echo.
echo %line%
echo Deleting %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.

:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
	echo.
)
set filesize=
set instanceINC=
:SkipDoingExternal1b


:: Internal 1a
set as1aORas1b=AS1a
set exORin=internal
echo.
echo %exORin% %as1aORas1b%:
:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt" (
	echo.
	echo WARNING:
	echo The file for Internal AS1a already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt^)
	echo.
	echo We will skip processing Internal AS1a logs.
	echo.
	pause
	goto SkipDoingInternal1a
)
:: Count how many instance IDs there are
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1a/`) DO set /a instanceINC+=1

:: Grammar nazi
IF "%instanceINC%" EQU "1" (
	echo.
	echo There is %instanceINC% instance listed in this S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %instanceINC% instances listed in this S3 directory.
	echo.
	)

:: Loop through the instance ID directories
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1a/`) DO (
	set instance1ai=%%F
	set /a instanceINC-=1
	echo Going through Instance ID "!instance1ai!" directory.
	CALL :mainInstance1aiLoop
)
:: We have processed through all instances, skip the loop
GOTO skipinstanceID1aiLoop
:mainInstance1aiLoop
set restserverLoop=
:: This counts how many objects (restserver.log) files are in the specific S3 directory
for /F "USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%datey%/%dateM%/%dateD%/us-east-1a/%instance1ai%directory/directory/logfiles/tomcat/`) DO set /a restserverLoop+=1
set /a restserverCount+=%restserverLoop%

:: Throw a Warning if this directory doesn't exist or if there are no restserver.log files
IF "%restserverLoop%" == "" (
	echo.
	echo.
	echo WARNING:
	echo The directory we're looking for under "%instance1ae%" doesn't exist.
	echo.
	echo OR we can't find any restserver.log files in where we're looking.
	echo.
	echo Skipping this Instance ID directory.
	echo.
	pause
	goto exitInternal1aLoop
)
:: Grammar nazi
IF "%restserverLoop%" EQU "1" (
	echo.
	echo There is %restserverLoop% restserver.log file in this Instance ID S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %restserverLoop% restserver.log files in this Instance ID S3 directory.
	echo.
	)
timeout /t 2 >nul
:internal1aLoop
:: We need to start with the highest number [restserver.log.#] first and process them downward.

IF NOT "%restserverLoop%" == "" (
	set /a restserverLoop-=1
	set restserverFileName=restserver.log.!restserverLoop!
	echo.
)
IF "%restserverLoop%" == "" set restserverFileName=restserver.log
IF %restserverLoop% EQU 0 (
	set restserverLoop=
	set restserverFileName=restserver.log
)
:: Set the file name to get
set %exORin%1a=bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1a/%instance1ai%directory/directory/logfiles/tomcat/%restserverFileName%

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Downloading files from S3: Internal AS1a
echo %line%
echo Downloading "%restserverFileName%"
aws s3 cp s3://%internal1a% %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.
echo.

IF NOT EXIST %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log (
	echo.
	echo ERROR:
	echo There was an issue downloading this log file and we need to abort.
	echo.
	echo Does the file you meant to download actually exist?
	echo.
	echo You might need to check the S3 bucket directory to see if it looks as expected.
	echo.
	echo Then try running this script again if it seems like it should have worked.
	echo.
	pause
	goto quit
)
echo %line%
echo Copying text to temp file "restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
type %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.
echo %line%
echo Deleting downloaded file.
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.

IF "%restserverLoop%" == "" goto exitInternal1aLoop

goto internal1aLoop
:exitInternal1aLoop
exit /b
:skipinstanceID1aiLoop
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log...
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
echo Done.
echo.
echo %line%
echo Deleting %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.

:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
	echo.
)
set filesize=
set instanceINC=
:SkipDoingInternal1a


:: Internal 1b
set as1aORas1b=AS1b
echo.
echo %exORin% %as1aORas1b%:
:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt" (
	echo.
	echo WARNING:
	echo The file for Internal AS1b already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt^)
	echo.
	echo We will skip processing Internal AS1b logs.
	echo.
	pause
	goto SkipDoingInternal1b
)
:: Count how many instance IDs there are
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1b/`) DO set /a instanceINC+=1

:: Grammar nazi
IF "%instanceINC%" EQU "1" (
	echo.
	echo There is %instanceINC% instance listed in this S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %instanceINC% instances listed in this S3 directory.
	echo.
	)

:: Loop through the instance ID directories
for /F "tokens=2 USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1b/`) DO (
	set instance1bi=%%F
	set /a instanceINC-=1
	echo Going through Instance ID "!instance1bi!" directory.
	CALL :mainInstance1biLoop
)
:: We have processed through all instances, skip the loop
GOTO skipinstanceID1biLoop
:mainInstance1biLoop
set restserverLoop=
:: This counts how many objects (restserver.log) files are in the specific S3 directory
for /F "USEBACKQ" %%F IN (`aws s3 ls s3://bucket/logs/Internal-Server/%datey%/%dateM%/%dateD%/us-east-1b/%instance1bi%directory/directory/logfiles/tomcat/`) DO set /a restserverLoop+=1
set /a restserverCount+=%restserverLoop%

:: Throw a Warning if this directory doesn't exist or if there are no restserver.log files
IF "%restserverLoop%" == "" (
	echo.
	echo.
	echo WARNING:
	echo The directory we're looking for under "%instance1ae%" doesn't exist.
	echo.
	echo OR we can't find any restserver.log files in where we're looking.
	echo.
	echo Skipping this Instance ID directory.
	echo.
	pause
	goto exitInternal1bLoop
)
:: Grammar nazi
IF "%restserverLoop%" EQU "1" (
	echo.
	echo There is %restserverLoop% restserver.log file in this Instance ID S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %restserverLoop% restserver.log files in this Instance ID S3 directory.
	echo.
	)
timeout /t 2 >nul
:internal1bLoop
:: We need to start with the highest number [restserver.log.#] first and process them downward.

IF NOT "%restserverLoop%" == "" (
	set /a restserverLoop-=1
	set restserverFileName=restserver.log.!restserverLoop!
	echo.
)
IF "%restserverLoop%" == "" set restserverFileName=restserver.log
IF %restserverLoop% EQU 0 (
	set restserverLoop=
	set restserverFileName=restserver.log
)
:: Set the file name to get
set %exORin%1b=bucket/logs/Internal-Server/%dateY%/%dateM%/%dateD%/us-east-1b/%instance1bi%directory/directory/logfiles/tomcat/%restserverFileName%

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Downloading Files from S3: Internal AS1b
echo %line%
echo Downloading "%restserverFileName%"
aws s3 cp s3://%internal1b% %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.
echo.

IF NOT EXIST %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log (
	echo.
	echo ERROR:
	echo There was an issue downloading this log file and we need to abort.
	echo.
	echo Does the file you meant to download actually exist?
	echo.
	echo You might need to check the S3 bucket directory to see if it looks as expected.
	echo.
	echo Then try running this script again if it seems like it should have worked.
	echo.
	pause
	goto quit
)
echo %line%
echo Copying text to temp file "restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
type %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.
echo %line%
echo Deleting downloaded file.
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%%restserverLoop%.log
echo Done.

IF "%restserverLoop%" == "" goto exitInternal1bLoop

goto internal1bLoop
:exitInternal1bLoop
exit /b
:skipinstanceID1biLoop
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log...
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
echo Done.
echo.
echo %line%
echo Deleting %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.

:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
	echo.
)
set filesize=
:SkipDoingInternal1b

:: @@@@@@@@@@@@@@@@@@
:: STATIC SERVER LOGS
:: @@@@@@@@@@@@@@@@@@

IF "%skipGetArchive%" == "1" ( GOTO skippedArchives )

:: Now doing Static server restserver log file acquisition
TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Getting Files From Static External Server
echo.
echo.
echo %line%
echo Downloading files from static servers:
echo External ^(%serveripExternal%^)
echo Internal ^(%serveripInternal%^)
echo.
:: Remove the number from the archive (might be broken now because 'vague')
set namearchiveto=%archiveToGet:~0,17%gz

:: Get External Static log from server
:: use a temporary directory so there are no issues finding which tomcat directory to work in of which we are extracting from "%archiveToGet%"
IF exist %downloaddir%tmp ( rmdir /Q /S %downloaddir%tmp )
mkdir %downloaddir%tmp

set exORin=external
:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt" (
	echo.
	echo WARNING:
	echo The file for External Static already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt^)
	echo.
	echo We will skip processing External Static logs.
	echo.
	pause
	goto SkipDoingExternalStatic
)

echo.
echo %line%
echo Downloading %archiveToGet% from External Static ^(%serveripExternal%^)
echo.
%puttydirectory% -scp -batch -pw password username@%serveripExternal%:/directory/directory/logfiles/oldlogs/%archiveToGet% %downloaddir%tmp\
IF "%errorlevel%" == "1" (
	echo.
	echo ERROR:
	echo This script cannot find "%archiveToGet%".
	echo.
	echo Is that file listed below?
	%puttydirectory% -scp -batch -pw password -ls username@%serveripExternal%:/directory/directory/logfiles/oldlogs/
	echo.
	pause
	goto quit
)
echo Done.
echo.
echo %line%
echo Renaming %archiveToGet% to %namearchiveto%
echo.
move /y %downloaddir%tmp\%archiveToGet% %downloaddir%tmp\%namearchiveto%
echo Done.

echo.
echo %line%
echo Unzipping %namearchiveto%
echo.
%zipdirectory% x %downloaddir%tmp\%namearchiveto% -o%downloaddir%tmp\
%zipdirectory% x %downloaddir%tmp\%namearchiveto:~-0,-3% -o%downloaddir%tmp\
echo.
echo Done.
echo.
echo %line%
echo Deleting zip files
echo.
del %downloaddir%tmp\%namearchiveto%
del %downloaddir%tmp\%namearchiveto:~-0,-3%
echo Done.

echo.
for /F "tokens=5 USEBACKQ" %%C IN (`dir %downloaddir%tmp\ ^|findstr "tomcat"`) DO (
	set tomcatdirectory=%%C
	echo Going through !tomcatdirectory!
	CALL :MainExternalLoop
)
goto MainExternalLoopSkip
:MainExternalLoop
	:: To count the number of restserver.log files
	for /F "tokens=3 delims=. USEBACKQ" %%X IN (`dir %downloaddir%tmp\!tomcatdirectory!\ ^| findstr "restserver.log"`) DO set /a restserverLoop+=1
	set /a restserverCount+=!restserverLoop!

	IF "%restserverLoop%" == "" (
		IF NOT EXIST %downloaddir%tmp\!tomcatdirectory!\restserver.log (
			echo.
			echo WARNING:
			echo This extracted zip file may not contain any "restserver.log" files!
			echo Please manually download and extract the intended zip file
			echo to confirm if restserver.log files exist.
			echo.
			echo Hint: ^(!tomcatdirectory!^)
			echo.
			pause
			goto noExternalFiles
		)
		set restserverFileName=restserver.log
		set restserverLoop=0
	)
	:: Add 1 to the loop because the number pulled is minus 1 from the total number of restserver.log files in the directory
	set /a restserverLoop+=1
	:: Grammar nazi
	IF !restserverLoop! EQU 1 (
		echo.
		echo There is !restserverLoop! restserver.log file in this tomcat directory.
		echo.
	) ELSE (
		echo.
		echo There are !restserverLoop! restserver.log files in this tomcat directory.
		echo.
		)
	timeout /t 2 >nul
	:tomcatELoop
	:: We need to start with the highest number [restserver.log.#] first and process them downward.

	IF NOT "!restserverLoop!" == "" (
		set /a restserverLoop-=1
		set restserverFileName=restserver.log.!restserverLoop!
	)
	IF "!restserverLoop!" == "" set restserverFileName=restserver.log
	IF !restserverLoop! EQU 0 (
		set restserverLoop=
		set restserverFileName=restserver.log
	)
	
	echo %line%
	echo Copying text of !restserverFileName! to temp file.
	type %downloaddir%tmp\!tomcatdirectory!\!restserverFileName! >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
	echo Done.
	echo.

	IF "%restserverLoop%" == "" goto exittomcatELoop

	goto tomcatELoop
	:exittomcatELoop

exit /B
:MainExternalLoopSkip
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
echo Output to %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
echo Done.
echo.
:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
	echo.
)
set filesize=
echo %line%
echo Deleting temporary file restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
echo Done.
echo.
:noExternalFiles
echo.
echo %line%
echo Removing extracted tomcat directories
for /F "tokens=5 USEBACKQ" %%C IN (`dir %downloaddir%tmp\ ^|findstr "tomcat"`) DO (
	del /F /S /Q %downloaddir%tmp\%%C\* >nul
	rmdir /Q /S %downloaddir%tmp\%%C
)
echo Done.
:SkipDoingExternalStatic
:: END External Static log stuff

:: @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

:: BEGIN Internal Static log stuff

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Getting Files From Internal Static Server
set exORin=internal

:: If the final output file already exists, skip this part
IF EXIST "%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt" (
	echo.
	echo WARNING:
	echo The file for Internal Static already exists in the output directory.
	echo ^(%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt^)
	echo.
	echo We will skip processing Internal Static logs.
	echo.
	pause
	goto SkipDoingInternalStatic
)

echo.
echo %line%
echo Downloading %archiveToGet% from Internal Static ^(%serveripInternal%^)
echo.
%puttydirectory% -scp -batch -pw password username@%serveripInternal%:/directory/directory/logfiles/oldlogs/%archiveToGet% %downloaddir%tmp\
IF "%errorlevel%" == "1" (
	echo.
	echo ERROR:
	echo This script cannot find "%archiveToGet%".
	echo.
	echo Is that file listed below?
	%puttydirectory% -scp -batch -pw password -ls username@%serveripInternal%:/directory/directory/logfiles/oldlogs/
	echo.
	pause
	goto quit
)
echo Done.
echo.
echo %line%
echo Renaming %archiveToGet% to %namearchiveto%
echo.
move /y %downloaddir%tmp\%archiveToGet% %downloaddir%tmp\%namearchiveto%
echo Done.

echo.
echo %line%
echo Unzipping %namearchiveto%
echo.
echo.
%zipdirectory% x %downloaddir%tmp\%namearchiveto% -o%downloaddir%tmp\
%zipdirectory% x %downloaddir%tmp\%namearchiveto:~-0,-3% -o%downloaddir%tmp\
echo Done.
echo.
echo %line%
echo Deleting zip files
echo.
del %downloaddir%tmp\%namearchiveto%
del %downloaddir%tmp\%namearchiveto:~-0,-3%
echo Done.

echo.
for /F "tokens=5 USEBACKQ" %%C IN (`dir %downloaddir%tmp\ ^|findstr "tomcat"`) DO (
	set tomcatdirectory=%%C
	echo Going through !tomcatdirectory!
	CALL :MainInternalLoop
)
:: If we have finished processing each tomcat directory, skip the processing part
goto MainInternalLoopSkip
:MainInternalLoop
	:: To count the number of restserver.log files
	for /F "tokens=3 delims=. USEBACKQ" %%X IN (`dir %downloaddir%tmp\!tomcatdirectory!\ ^| findstr "restserver.log"`) DO set /a restserverLoop+=1
	set /a restserverCount+=!restserverLoop!

	IF "%restserverLoop%" == "" (
		IF NOT EXIST %downloaddir%tmp\!tomcatdirectory!\restserver.log (
			echo.
			echo WARNING:
			echo This extracted zip file may not contain any "restserver.log" files!
			echo Please manually download and extract the intended zip file
			echo to confirm if restserver.log files exist.
			echo.
			echo Hint: ^(!tomcatdirectory!^)
			echo.
			pause
			goto noInternalFiles
		)
		set restserverFileName=restserver.log
		set restserverLoop=0
	)
	
	:: Add 1 to the loop because the number pulled is minus 1 from the total number of restserver.log files in the directory on S3
	set /a restserverLoop+=1
	:: Grammar nazi
	IF !restserverLoop! EQU 1 (
		echo.
		echo There is !restserverLoop! restserver.log file in this tomcat directory.
		echo.
	) ELSE (
		echo.
		echo There are !restserverLoop! restserver.log files in this tomcat directory.
		echo.
		)
	timeout /t 2 >nul
	:tomcatILoop
	:: We need to start with the highest number [restserver.log.#] first and process them downward.

	IF NOT "!restserverLoop!" == "" (
		set /a restserverLoop-=1
		set restserverFileName=restserver.log.!restserverLoop!
	)
	IF "!restserverLoop!" == "" set restserverFileName=restserver.log
	IF !restserverLoop! EQU 0 (
		set restserverLoop=
		set restserverFileName=restserver.log
	)
	
	echo %line%
	echo Copying text of !restserverFileName! to temp file.
	type %downloaddir%tmp\!tomcatdirectory!\!restserverFileName! >> %downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
	echo Done.
	echo.

	IF "%restserverLoop%" == "" goto exittomcatILoop

	goto tomcatILoop
	:exittomcatILoop
:: Exit MainExternalLoop subroutine
exit /B

:MainInternalLoopSkip
echo.
echo %line%
echo Running FINDSTR command on restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
echo Output to %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
findstr /c:%stringtosearch% "%downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log" >> %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
echo Done.
echo.
:: Delete the file we just had output if it's empty so it doesn't mess up the Excel document table data
for /F %%S IN ("%outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt") DO set filesize=%%~zS
IF "%filesize%" EQU "0" (
	echo.
	echo %line%
	echo.
	echo The file %processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt is empty.
	echo Deleting it.
	del %outputdir%%processtype%_restserver_%dateM%_%dateD%_%exORin%_Static.txt
	echo.
)
set filesize=
echo %line%
echo Deleting temporary file restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
del %downloaddir%restserver_%dateM%_%dateD%_%exORin%_Static_tmp.log
echo Done.
echo.
:noInternalFiles
echo.
echo %line%
echo Removing extracted tomcat directories
for /F "tokens=5 USEBACKQ" %%C IN (`dir %downloaddir%tmp\ ^|findstr "tomcat"`) DO (
	del /F /S /Q %downloaddir%tmp\%%C\* >nul
	rmdir /Q /S %downloaddir%tmp\%%C
)
echo Done.
:SkipDoingInternalStatic
echo.
echo %line%
echo Deleting temporary working directory
rmdir /Q /S %downloaddir%tmp
echo Done.
echo.

:: END Internal Static log stuff

TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Doing Final Processes
:: If we processed any logs, then if doing Process_Here, make a backup copy to put into the sharepoint
IF NOT "%restserverCount%" EQU "" (
	IF "%processtype%" == "Process_Here" (
			echo.
			echo %line%
			echo Making a zip backup of the Filtered_Process_Here directory...
			echo.
			%zipdirectory% a %outputdir:~0,-24%Filtered_Process_Here_Backup.zip %outputdir%
			echo.
			echo Done.
			echo.
			echo If your output directory contains all of the previous log files, feel free to
			echo replace the zip in the sharepoint with the one just created.
	)
)	
:: Check if we processed any logs during this run, then if the user is bkelley (change the string below in the code to your username if you want this functionality), then if the day we're pulling is today's date, then if %excelfile% variable is not empty, then if the excel file exists, then automatically open it for convenience so it can be edited, and then after saving and closing the file, copy it to the Dropbox directory
:: This script will pause while the excel file is open.
IF NOT "%restserverCount%" EQU "" (
	IF "%username%" == "bkelley" (
		IF "%dateD%" == "%date:~7,2%" (
			IF NOT %excelfile% == "" (
				IF EXIST %excelfile% (
					IF "%processtype%" == "Process_Here" (
						FOR /F %%A IN (%excelfile%) DO (
							set oldexcelsize=%%~zA
							set filename=%%~nxA
						)
						echo.
						echo %line%
						echo Opening %filename% so you can update it.
						echo While the document is open, this script will pause.
						echo Make sure to save and close the document to continue this script.
						echo.
						%excelfile%
						timeout /t 4 >nul
						FOR /F %%J IN (%excelfile%) DO set newexcelsize=%%~zJ
						:: If the file sizes are the same after opening the file, don't copy it to dropbox
						IF NOT "!oldexcelsize!" EQU "!newexcelsize!" (
							echo.
							echo %line%
							echo Copying Document.xlsx to the Dropbox directory.
							copy %excelfile% %dropbox%Document.xlsx
							echo Done.
							echo.
						) ELSE ( 
							echo. 
							echo The excel file seems to be the same size like it wasn't changed. 
							echo So it's not going to be copied to the Dropbox directory at:
							echo %dropbox%
							echo.
							)
					)
				) ELSE IF NOT EXIST %excelfile% (
					echo.
					echo %line%
					echo Cannot find %excelfile%...
					echo So, nevermind on opening it automatically^^!
					echo.
					)
			)
		)
	)
)
:skippedArchives
color 2F
:end
TITLE Get all restserver.log files for %dateY%/%dateM%/%dateD% - Finished^^!
echo.
echo.
echo ~@~@~@~@~@~@~@~@~@~
echo.
echo We're done here^^!
echo.
echo Output dir: %outputdir%
echo.
IF NOT "%restserverCount%" EQU "" (
	echo Fun stats:
	echo We processed %restserverCount% restserver.log files
	echo.
)
pause
:quit
color 0F
GOTO:EOF

:: The part to download and run the required program installer files. Originates from one of the first script configuration checks near the start of the script.
:InstallAWSCLI
echo Downloading AWS CLI tools...
echo.
PowerShell -C "Invoke-WebRequest -Uri https://s3.amazonaws.com/aws-cli/AWSCLI64.msi -Outfile C:\Users\%username%\Downloads\AWSCLI64.msi"
timeout /t 3 >nul
echo.
echo Running C:\Users\%username%\Downloads\AWSCLI64.msi ...
MSIEXEC /package C:\Users\%username%\Downloads\AWSCLI64.msi /passive
echo.
echo Completed trying to install AWS CLI.
echo.
pause
EXIT /B
:Install7zip
echo Downloading 7-Zip...
echo.
PowerShell -C "Invoke-WebRequest -Uri http://www.7-zip.org/a/7z1701-x64.exe -Outfile C:\Users\%username%\Downloads\7z1701-x64.exe"
timeout /t 3 >nul
echo Running C:\Users\%username%\Downloads\7z1701-x64.exe
C:\Users\%username%\Downloads\7z1701-x64.exe
echo.
echo Completed trying to install 7-Zip.
echo.
pause
EXIT /B
:Installputty
echo Downloading PuTTY...
echo.
PowerShell -C "Invoke-WebRequest -Uri https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.70-installer.msi -Outfile C:\Users\%username%\Downloads\putty-64bit-0.70-installer.msi"
timeout /t 3 >nul
echo Running C:\Users\%username%\Downloads\putty-64bit-0.70-installer.msi
MSIEXEC /package C:\Users\%username%\Downloads\putty-64bit-0.70-installer.msi /passive
echo.
echo Completed trying to install PuTTY.
echo.
pause
EXIT /B
