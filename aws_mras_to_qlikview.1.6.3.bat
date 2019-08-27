GITHUB NOTE: This file has been sanitized of relatively sensitive information
@echo off
::By bkelley 2017/08/11 - 2019/05/22 For mras.log files and publish_to_web metrics
:: Ver 1.1! Added CALL looping functionality for the main work. So now there's only 1 section for each AutoScaled and 1 section for each Static server
:: Ver 1.2! Added better AUTO ARCHIVE GET archiveNumber functionality
:: Ver 1.3! This version removes the need for the Excel document and outputs a tab-delimited txt file for QlikView to ingest
:: Ver 1.4! Adding support for Swing Beta instances and S3 directory changes and mras.log version changes.  New section at ctrl+F "NEW BETA SWING LOG-GET HERE".
:: Ver 1.5! 2018/02/16 Now including "POST /swing/api/rest/query/search" as an action to get from the mras.log files, as well as publish_to_web, which will also be loaded into QlikView.
:: Ver 1.5.5! 2018/02/22 Added handling for Swing ver 3.6 mras.log files, which has a different log entry for user search actions. Also split out the output files since it's no longer just Publish_To_Web actions being gathered.
:: Ver 1.6! 2018/03/08 The rest of Swing has gone to ver 3.6, and with that, we've gotten rid of the Static instances.  Now External and Internal sections use the Swing Beta section of code, so I can now remove the old sections and the Static instance (and zip file) sections.
:: Ver 1.6.1! 2018/04/11 Changed the FindUsersName method to pull out into a new file all lines that have the sessionID and username so batch can iterate over that file quicker. And added a name-counting feature to show progress on the processes that take the most time.
:: Ver 1.6.2! 2018/04/24 Had to update the "mras.log.#" file name handling because [Vendor] updated their log rotation script and changed it to "mras.#.log" instead.
:: Ver 1.6.3! 2019/05/30 Removed BETA Swing section since it is no longer being used.  Implemented "Previous day check" to see if we skipped processing the previous day. Under BEGIN TESTS section.


:: The purpose of this script is to allow for easy [CMS] Swing mras.log pulling and string finding so we can graph all this data in QlikView (see below).
:: See more documentation about the whole process in Microsoft Teams > Operations > Files > [CMS] Logs > mras_log > "Swing Publish_To_Web Documentation.docx"
:: This script pulls mras logs from the "[bucket]" S3 bucket and Static Swing External and Internal servers. 
:: The S3 bucket contains the mras.logs from the Auto-Scaled instances.
:: For the script to fully function, it requires being on the company network, so join the VPN if you are working remotely.
:: It also requires an installation of 7-zip and PuTTY installed to C:\Program Files\
:: As well it requires having the AWS CLI installed. It does NOT require your own special AWS IAM permissions.
:: If you've copied this script to your own computer, please see the "MY CUSTOM VARIABLES" section to set them to your own structure, if so desired. Technically, you can leave them as-is and still run the script.
:: A double-colon "::" denotes a comment about the code
:: If a line has "REM" first, it is a commented-out variable or code
:: This script will skip downloading files if the .txt for that server exists already in the output directory.  That's good for using this script to download specific server logs again if you delete the .txt out of the output directory.
:: QlikView is a graphing dashboard system that we use. The dashboard gets its data from the %fileshare%\formatted directory txt files.
:: Here is a link to the QlikView dashboard: http://[server]/qlikview/index.htm (select Web Metrics.qvw)
:: We have a seperate AWS IAM account solely for accessing the logfile bucket and downloading files. Credentials below:
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=

setlocal EnableDelayedExpansion
set version=1.6.3
set line=@@@@@@@@@@
set errorline=#############
set logfile=C:\Users\%username%\Documents\restserver_log\mras_to_qlikview_log.txt

cls
CALL :ClearVariables

:: @@@@@@@@@@@@@@@@@@@@@@@@@
:: BEGIN MY CUSTOM VARIABLES
:: @@@@@@@@@@@@@@@@@@@@@@@@@

:: The string to pull out of the raw log files:
set stringpublishnew="GET /swing/api/rest/object/actions/publish_to_web -"
set stringsearchnew="POST /swing/api/rest/v3/query/find/view/SwingResultSet -"

:: Listing which mras.log actions we're acquiring. This is doesn't affect the code.
set "SwingActionsToGet=publish_to_web, SwingResultSet"
:: The directory to which the final processed files are put
set outputdir=C:\Users\%username%\Documents\restserver_log\Processed_MRAS\
:: The directory to which files are downloaded and then processed and then deleted
set downloaddir=C:\Users\%username%\Documents\restserver_log\Raw\
:: Program installation directories
set AWSCLIdirectory="C:\Program Files\Amazon\AWSCLI\aws.exe"
set zipdirectory="C:\Program Files\7-Zip\7z.exe"
:: Fileshare directory for the QlikView stuff
set "fileshare=\\[server]\Qlik Data\formatted_txt\"
:: These are the NCD users, specified for the new output
set "users=[list of usernames]"

:: @@@@@@@@@@@@@@@@@@@@@@@
:: END MY CUSTOM VARIABLES
:: @@@@@@@@@@@@@@@@@@@@@@@

echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo Hello^^! This script is for loading data in to QlikView.
echo It downloads mras.log files from [Vendor]'s S3 bucket, processes them, and
echo puts output files in a remote shared directory.
echo Currently, it loads these action metrics from Swing's mras.log files:
echo ^> "publish_to_web"
echo ^> "SwingResultSet"
echo.
echo To see the QlikView dashboard, email [guy]@[company].com for permissions and
echo visit this link here: http://[server]/qlikview/index.htm (select Web Metrics.qvw)
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo You can go ahead and run this script to see if you meet all the necessary requirements
echo to run this script. If you don't, this script should tell you why.
echo.
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
IF "%dateY%" LSS "2018" (
	echo.
	echo #########
	echo Sorry, archived logs are kept for only 3 months and do not exist before 2017.
	echo And time traveling doesn't exist. Try using your current year.
	echo.
	goto questionyear
)
echo %dateY%| findstr /r "^[2][0][0-9][0-9]$">nul
IF %errorlevel% EQU 0 goto questionmonth
echo.
echo ##########
echo Sorry, that date format doesn't look right. Please try again.
echo.
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
		echo Sorry, that month does not exist on a calendar. An acceptable range is 01 - 12.
		echo.
		goto questionmonth
	)
)
echo %dateM%| findstr /r "^[0][1-9]$ ^[1][0-2]$">nul
IF %errorlevel% EQU 0 goto questionday
echo.
echo ##########
echo Sorry, that date format does not look right. Please try again.
echo An acceptable range is 01 - 12.
echo.
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
		echo Sorry, that day does not exist on a calendar. An acceptable range is 01 - 31.
		echo.
		goto questionday
	)
)
echo %dateD%| findstr /r "^[0][1-9]$ ^[1-2][0-9]$ ^[3][0-1]$">nul
IF %errorlevel% EQU 0 goto finishedSetDate
echo.
echo ##########
echo Sorry, that date format doesn't look right. Please try again.
echo An acceptable range is 01 - 31.
echo.
goto questionday

:finishedSetDate
set "titleintro=%version% Get all mras.log files for %dateY%/%dateM%/%dateD% -"


:begin
TITLE %titleintro% Running Status Checks

echo.
echo Running script configuration checks before we begin...

:: BEGIN TESTS

:: Check if the previous day was ran or not
::crazy math, int & string handling section
IF "%dateD%" == "01" (
	set dateDcheck=31
	set rollunder=true
	IF "!dateM!" == "01" (
		set dateMcheck=12
		set /a dateYcheck=%dateY%-1
	) ELSE (
		IF "%dateM%" == "10" (
			set dateMcheck=09
		) ELSE (
			IF "%dateM:~0,1%" == "0" (
				set /a dateMcheck=%dateM:~1,1%-1
				set dateMcheck=0!dateMcheck!
			) ELSE (
				set /a dateMcheck=%dateM%-1
			)
		)
		set dateYcheck=%dateY%
	)
) ELSE (
	IF "%dateD:~0,1%" == "0" (
		set /a dateDcheck=%dateD:~1,1%-1
		set dateDcheck=0!dateDcheck!
	)
	IF NOT "%dateD:~0,1%" == "0" (
		IF "%dateD%" == "10" (
			set dateDcheck=09
		) ELSE (
			set /a dateDcheck=%dateD%-1
		)
	)
	set dateMcheck=%dateM%
	set dateYcheck=%dateY%
)

:: If the rollunder goes into a 30-day month, or Feb, set dateDcheck appropriately
IF "!dateMcheck!" == "02" IF DEFINED rollunder set dateDcheck=28
IF "!dateMcheck!" == "04" IF DEFINED rollunder set dateDcheck=30
IF "!dateMcheck!" == "06" IF DEFINED rollunder set dateDcheck=30
IF "!dateMcheck!" == "09" IF DEFINED rollunder set dateDcheck=30
IF "!dateMcheck!" == "11" IF DEFINED rollunder set dateDcheck=30

IF NOT EXIST "%outputdir%Publish_To_Web\Publish_To_Web_restserver_!dateYcheck!_!dateMcheck!_!dateDcheck!_*" (
	echo.
	echo WARNING:
	echo The previous day's processed log file is missing. Was a day skipped^?
	echo If this is your first time running this script, you can ignore this warning.
	echo.
	FOR /F %%H in ('dir /B /O:^-D %outputdir%Publish_To_Web\') DO (
		set lastLogFile=%%H
		echo The last log file is:
		echo "!lastLogFile!"
		goto :gotfile
	)
	:gotfile
	echo Check the mras_to_qlikview_log.txt file to see which days are missing.
	echo.
	echo If you need to process the missing days, stop this script and re-run it
	echo specifying the first missing day.
	echo.
	pause
)

:: check to see if you have the AWS CLI installed, ask if we need to download the AWSCLI installer or not
aws s3 ls s3://[bucket]/logs/AUSV1PL-SWN01/%dateY%/%dateM%/%dateD%/us-east-1a/ >nul 2>nul
IF "%errorlevel%" EQU "9009" (
	echo.
	echo %errorline%
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
echo AWS Tools - Success
:: check to see if your account has access to the S3 bucket
IF "%errorlevel%" EQU "255" (
	echo.
	echo %errorline%
	echo ERROR: 
	echo Cannot access "[bucket]" S3 bucket^^!
	echo Did the programmatic user "[programatic user name]" lose permissions?
	echo Ask [Vendor] for help.
	echo Email [guy]@[vendor].com about the user listed above.
	echo.
	pause
	set errorlevel=
	goto quit
)
echo S3 bucket access - Success
:: check S3 bucket to see if the set date exists
IF "%errorlevel%" EQU "1" (
	echo.
	echo %errorline%
	echo ERROR: 
	echo The S3 directory specified may not exist for the date set:
	echo ^(//[bucket]/logs/AUSV1PL-SWN01/%dateY%/%dateM%/%dateD%/...^) 
	echo.
	echo Check the S3 console to see if the directory exists for the dates used.
	echo.
	pause
	set errorlevel=
	goto quit
)
echo S3 bucket, date exists - Success

:: check to see if the day we're processing already exists in the processed directory
IF EXIST "%outputdir%Publish_To_Web\Publish_To_Web_restserver_%dateY%_%dateM%_%dateD%_*" (
	echo.
	echo WARNING:
	echo It seems that you might have processed this day already ^(%dateY%/%dateM%/%dateD%^).
	echo Stop this script if you did not mean to run this script as the day above.
	echo.
	echo Otherwise, if you DO want to run this whole script again...
	pause
	echo.
)
echo Existing output check - Success
:: Check to see if we can access the Qlikview fileshare
IF NOT EXIST "%fileshare%" (
	echo.
	echo %errorline%
	echo ERROR:
	echo We cannot find or access the Qlikview fileshare directory:
	echo "%fileshare%"
	echo.
	echo Without being able to access this directory, we cannot update Qlikview data.
	echo Please check with [guy]@[company].com for access issues.
	echo.
	pause
	goto quit
)
:: check to see if 7-Zip is installed at the expected directory, if not, ask if it needs to be downloaded and installed
IF NOT EXIST %zipdirectory% (
	echo.
	echo %errorline%
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
	timeout /t 4>nul	
	pause
	goto quit
)
:after7zipcheck
echo 7zip Installed - Success
:: Check to see if we can write and delete to the QlikView share directory
copy NUL "%fileshare%\tmp.txt" > nul
IF NOT "%errorlevel%" EQU "0" (
	echo.
	echo %errorline%
	echo ERROR:
	echo There are permission or access issues with the Qlikview fileshare directory:
	echo "%fileshare%"
	echo.
	echo Are you connected to the company network?  If you are and still are having issues:
	echo Please ask [guy]@[company].com about any permission issues you may have.
	echo.
	echo This script will continue, however, it will not copy the output files to the
	echo fileshare location listed above. The files will need to be copied to that location
	echo later.  The output files will be found at:
	echo "%downloaddir%"
	echo.
	pause
	echo.
	set filesharecheck=failed
)
del "%fileshare%\tmp.txt"
IF NOT DEFINED filesharecheck (
	echo Fileshare Directory Access - Success
) ELSE (
	echo Fileshare Directory Access - Failure
)

:: END TESTS

echo.
echo Status Checks Success^^!
color 0F
echo. 
echo Date to get:      	%dateY%/%dateM%/%dateD%
echo Finding actions:	%SwingActionsToGet%
echo Output to:        	%outputdir%
echo QlikView fileshare:	%fileshare%
echo --------------------------------------
echo.
echo.
timeout /t 4 >nul

:: Make the output & download directories if they doesn't exist
IF NOT EXIST %outputdir% mkdir %outputdir%
IF NOT EXIST %outputdir%Publish_To_Web\ mkdir %outputdir%Publish_To_Web
IF NOT EXIST %outputdir%Search\ mkdir %outputdir%Search
IF NOT EXIST %downloaddir% mkdir %downloaddir%


:: New Swing 3.6 CALL section, declare variables. The new function gets the Region from S3 so it doesn't need to be declared any more
:: External
TITLE %titleintro% Starting on Swing External
set exORin=external
set swORswn=SWN01
echo.
echo %line%%line%%line%%line%
echo.
echo STARTING ON SWING EXTERNAL LOGS
echo.
echo %line%%line%%line%%line%
CALL :StartTheWholeThing

:: Internal
TITLE %titleintro% Starting on Swing Internal
set exORin=internal
set swORswn=SW01
echo.
echo %line%%line%%line%%line%
echo.
echo STARTING ON SWING INTERNAL LOGS
echo.
echo %line%%line%%line%%line%
CALL :StartTheWholeThing

:: Beta
REM TITLE %titleintro% Starting on Swing Beta
REM set exORin=beta
REM set swORswn=SWNB01
REM echo.
REM echo %line%%line%%line%%line%
REM echo.
REM echo STARTING ON SWING BETA LOGS
REM echo.
REM echo %line%%line%%line%%line%
REM CALL :StartTheWholeThing

:: After completing External, Internal, and Beta:
TITLE %titleintro% Doing Final Processes
:: If we processed any logs, make a backup copy to put into the Teams sharepoint
IF NOT "%mrasCount%" EQU "" (
	echo.
	echo %line% - %time%
	echo Making a zip backup of the Filtered_Publish_To_Web directory...
	echo.
	%zipdirectory% a %outputdir:~0,-15%Processed_mras_logs_Backup.zip %outputdir%
	echo.
	echo Done.
	echo.
	echo If your output directory contains all of the previous log files, feel free to
	echo replace the zip in Teams with the one just created.
)	

color 2F
:end
TITLE %titleintro% Finished^^!
echo.
echo.
echo ~@~@~@~@~@~@~@~@~@~ - %time%
echo.
echo We're done here^^!
echo.
IF !issuesCount! GTR 0 (
	echo.
	echo There were !issuesCount! WARNING^(S^) during this run.
	echo Please scroll back up to review.
	echo.
)
echo.
echo Output dir: %outputdir%
echo.

IF NOT "%mrasCount%" EQU "" (
	echo FUN STATS - We processed:
	echo %mrasCount% mras.log files
	echo !intTotalNamesProcessed! action entries for this day
	echo.
	echo.>>%logfile%
	echo %dateM%/%dateD%/%dateY%>> %logfile%
	echo %mrasCount% mras.log files>> %logfile%
	echo !intTotalNamesProcessed! action entries for this day>> %logfile%
	echo %time%>> %logfile%
)
pause
:quit
color 0F
GOTO:EOF


:StartTheWholeThing
:: Clear %region% to use after this next FOR command
set region=
FOR /F "tokens=2 USEBACKQ" %%A in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/`) DO (
	set region=%%A
	echo.
	TITLE %titleintro% Doing region !region! for !exORin!
	echo ~@~@~@~@~@~@~@~@~@~@~@~@~ - %time%
	echo Doing region !region! for !exORin!
	echo.
	IF NOT "!region!" == "us-east-1a/" (
		IF NOT "!region!" == "us-east-1b/" (
			REM :: if it's not either 1a or 1b, then there's an issue/error
			echo.
			echo %errorline%
			echo ERROR:
			echo Something went wrong when selecting a Region.
			echo Maybe it does not exist in where we are looking or we found something else.
			echo.
			echo Skipping doing !exORin! Swing logs...
			timeout /t 6 >nul
			EXIT /B	
		)
	)
	IF "!region!" == "us-east-1a/" (
		set as1aORas1b=AS1a
	)
	IF "!region!" == "us-east-1b/" (
		set as1aORas1b=AS1b
	)
	IF EXIST %outputdir%Publish_To_Web\Publish_To_Web_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt (
		echo.
		echo ATTENTION:
		echo It seems that you might have processed this day already for !exORin! ^(%dateY%/%dateM%/%dateD%^).
		echo Stop this script if you did not mean to run this script as the day above.
		echo.
		echo Otherwise, if you DO want to continue the script...
		pause
		EXIT /B
	)
	CALL :InstanceIDLoop
	CALL :CreateQlikOuputFile
)
IF NOT DEFINED region (
	echo.
	echo ATTENTION:
	echo The date being used ^(%dateY%/%dateM%/%dateD%^) does not exist in S3 for Swing !exORin!.
	echo.
	echo Skipping doing Swing !exORin! logs...
	timeout /t 4 >nul
	EXIT /B
)
:: Exit the StartTheWholeThing call
EXIT /B


:InstanceIDLoop
set instanceINC=
FOR /F "tokens=2 USEBACKQ" %%C in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%`) DO set /a instanceINC+=1
IF "%instanceINC%" EQU "1" (
	echo.
	echo There is %instanceINC% instance listed in this S3 directory.
	echo.
) ELSE (
	echo.
	echo There are %instanceINC% instances listed in this S3 directory.
	echo.
	)
timeout /t 2 >nul

FOR /F "tokens=2 USEBACKQ" %%C in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%`) DO (
	echo.
	echo Going through Instance ID "%%C" directory.
	set instanceID=%%C
	CALL :[cms]ORservlets
)
:: Exit InstanceIDLoop
EXIT /B

:[cms]ORservlets
FOR /F "tokens=2 USEBACKQ" %%M in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/`) DO (
	IF "%%M" == "[cms]-servlets/" (
		echo.
		echo Going through /[cms]-servlets/
		CALL :[cms]_servlets_process
	)
	IF "%%M" == "servlets_logs/" (
		echo.
		echo Going through /servlets_logs/
		CALL :servlets_logs_process_tomcat
	)
)
:: Exit [cms]ORservlets
EXIT /B

:[cms]_servlets_process
	FOR /F "tokens=4 USEBACKQ" %%a in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/[cms]-servlets/swing/com.[vendor].mras.mras-core/`) DO set /a mrasLoop+=1
	IF NOT DEFINED mrasLoop (
		echo.
		echo WARNING:
		echo There are no mras.logs in where we are looking.
		echo Either the directory is empty or it doesn't exist.
		echo.
		echo Skipping this [cms]_servlets directory
		echo.
		timeout /t 3 >nul
		goto exitThisInstanceLoop[cms]
	)
	set /a mrasCount+=!mrasLoop!
	:: Throw a Warning if this directory doesn't exist or if there are no mras.log files
	IF "%mrasLoop%" == "" (
		set /a issuesCount+=1
		echo.
		echo WARNING:
		echo The directory we're looking for under "%instanceID%" doesn't exist.
		echo.
		echo OR we can't find any mras.log files in where we're looking.
		echo.
		echo Skipping this Instance ID directory.
		echo.
		REM pause
		timeout /t 4 >nul
		goto exitThisInstanceLoop
	)
	IF "%mrasLoop%" EQU "1" (
		echo.
		echo There is %mrasLoop% mras.log file in this Instance ID S3 directory.
		echo.
	) ELSE (
		echo.
		echo There are %mrasLoop% mras.log files in this Instance ID S3 directory.
		echo.
		)
	timeout /t 2 >nul
	:theMrasLoop[cms]_Servlets
	:: We need to start with the highest number [mras.log.#] first and process them downward.

	IF NOT "%mrasLoop%" == "" (
		set /a mrasLoop-=1
		set mrasFileName=mras.!mrasLoop!.log
		echo.
	)
	IF "%mrasLoop%" == "" set mrasFileName=mras.log
	IF %mrasLoop% EQU 0 (
		set mrasLoop=
		set mrasFileName=mras.log
	)
	
	:: Set the directory and file name to get
	set s3directory=[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/[cms]-servlets/swing/com.[vendor].mras.mras-core/%mrasFileName%
	TITLE %titleintro% Downloading Files from S3: !exORin! %as1aORas1b%
	echo %line% - %time%
	echo Downloading "%mrasFileName%"
	aws s3 cp s3://%s3directory% %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log
	echo Done.
	echo.
	IF NOT EXIST %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log (
		IF NOT "%mrasLoop%" == "" (
			set /a issuesCount+=1
			echo.
			echo %errorline%
			echo ERROR:
			echo There was an issue downloading this log file.
			echo.
			echo %mrasFileName% will be skipped.
			echo The next one in the series will try to be downloaded.
			echo.
			timeout /t 4 >nul
			goto theMrasLoop[cms]_Servlets
		)
		echo.
		echo %errorline%
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
	echo %line% - %time%
	echo Copying this text to a temp file "mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
	type %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log >> %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
	echo Done.
	echo.
	echo %line% - %time%
	echo Deleting downloaded file.
	del %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log
	echo Done.

	IF "%mrasLoop%" == "" goto exitThisInstanceLoop[cms]

	goto theMrasLoop[cms]_Servlets
:exitThisInstanceLoop[cms]
:: Exit [cms]_servlets_process		
EXIT /B

:servlets_logs_process_tomcat
FOR /F "tokens=2 USEBACKQ" %%a in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/servlets_logs/`) DO (
	echo Processing tomcat directory: %%a
	set tomcatDirectory=%%a
	CALL :servlets_logs_process
)
:: Exit servlets_logs_process_tomcat
EXIT /B

:servlets_logs_process
	FOR /F "tokens=4 USEBACKQ" %%a in (`aws s3 ls s3://[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/servlets_logs/!tomcatDirectory!swing/com.[vendor].mras.mras-core/`) DO set /a mrasLoop+=1
	IF NOT DEFINED mrasLoop (
		echo.
		echo WARNING:
		echo There are no mras.logs in where we are looking.
		echo Either the directory is empty or it doesn't exist.
		echo.
		echo Skipping this tomcat directory ^(!tomcatDirectory!^)
		echo.
		timeout /t 3 >nul
		goto exitThisInstanceLoopServlets
	)
	set /a mrasCount+=!mrasLoop!
	IF "%mrasLoop%" EQU "1" (
		echo.
		echo There is %mrasLoop% mras.log file in this Instance ID S3 directory.
		echo.
	) ELSE (
		echo.
		echo There are %mrasLoop% mras.log files in this Instance ID S3 directory.
		echo.
		)
	timeout /t 2 >nul
	:theMrasLoopServlets_Logs
	:: We need to start with the highest number [mras.log.#] first and process them downward.

	IF NOT "%mrasLoop%" == "" (
		set /a mrasLoop-=1
		set mrasFileName=mras.!mrasLoop!.log
		echo.
	)
	IF "%mrasLoop%" == "" set mrasFileName=mras.log
	IF %mrasLoop% EQU 0 (
		set mrasLoop=
		set mrasFileName=mras.log
	)
	
	:: Set the directory and file name to get
	set s3directory=[bucket]/logs/AUSV1PL-%swORswn%/%dateY%/%dateM%/%dateD%/%region%%instanceID%[cms]/[service]/logfiles/servlets_logs/!tomcatDirectory!swing/com.[vendor].mras.mras-core/%mrasFileName%
	TITLE %titleintro% Downloading Files from S3: %exORin% %as1aORas1b%
	echo %line% - %time%
	echo Downloading "%mrasFileName%"
	aws s3 cp s3://%s3directory% %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log
	echo Done.
	echo.

	IF NOT EXIST %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log (
		IF NOT "%mrasLoop%" == "" (
			set /a issuesCount+=1
			echo.
			echo %errorline%
			echo ERROR:
			echo There was an issue downloading this log file.
			echo.
			echo %mrasFileName% will be skipped.
			echo The next one in the series will try to be downloaded.
			echo.
			timeout /t 4 >nul
			goto theMrasLoopServlets_Logs
		)
		echo.
		echo %errorline%
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
	echo %line% - %time%
	echo Copying this text to a temp file "mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log"
	type %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log >> %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
	echo Done.
	echo.
	echo %line% - %time%
	echo Deleting downloaded file ^(mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log^)
	del %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%%mrasLoop%.log
	echo Done.

	IF "%mrasLoop%" == "" goto exitThisInstanceLoopServlets

	goto theMrasLoopServlets_Logs
:exitThisInstanceLoopServlets
:: Exit servlets_logs_process
EXIT /B


:: Insert new file output thing here
:CreateQlikOuputFile

:: We have to search for publish_to_web and the new search action, so set things accordingly and call the function
set stringtosearch=%stringpublishnew%
set actionName=Publish_To_Web
set actionLower=publish_to_web
CALL :new_findstr_on_files

set stringtosearch=%stringsearchnew%
set actionName=Search
set actionLower=search
CALL :new_findstr_on_files


echo.
echo %line% - %time%
echo Deleting tempfile mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
del %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log
echo Done.
echo.
echo.
TITLE %titleintro% Finished with %exORin% %as1aORas1b%
echo Finished with %exORin% %as1aORas1b%
echo @~@~@~@~@~@~@~@~@~@~@~@~@~
:: Exit CreateQlikOuputFile - the overall main loop and see if there's another Region to do
EXIT /B


:new_findstr_on_files
	set rawusersnamefile=mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_raw_usersname_file.txt
	echo.
	echo %line% - %time%
	echo Finding "!actionName!" lines in mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log...
	echo Using: !stringtosearch!
	findstr /C:!stringtosearch! %downloaddir%mras_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%_tmp.log >> %outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
	echo Done.


	:: Delete the file we just had output if it's empty because then it's not needed.
	for /F %%S IN ("%outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt") DO set filesize=%%~zS
	IF "%filesize%" EQU "0" (
		echo.
		echo %line% - %time%
		echo The file !actionName!_restserver_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt is empty.
		echo Deleting it.
		del %outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_%exORin%_%as1aORas1b%.txt
		echo Done.
		echo.
	)
	set filesize=
	set instanceINC=


	set skipINT=0
	echo.
	echo %line% - %time%
	echo Creating !actionName! output file for QlikView for "!exORin! !as1aORas1b!"...

	IF NOT EXIST "%outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt" (
		set /a issuesCount+=1
		echo.
		echo ATTENTION:
		echo Sourcefile for "!actionName!" does not exist,
		echo ^(!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt^)
		echo skipping making the formatted output file for QlikView.
		REM pause
		timeout /t 4 >nul
		EXIT /B
	)
	IF EXIST "%fileshare%!actionLower!\formatted_!actionLower!_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!.txt" (
		set /a issuesCount+=1
			echo.
		echo ATTENTION:
		echo The output file for "!actionName!" already exists in the QlikView fileshare.
		echo Skipping this output file.
		echo.
		echo ^(formatted_!actionLower!_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!.txt^)
		echo.
		REM pause
		timeout /t 4 >nul
		EXIT /B
	)

	:: Create the list of UsersNames for the next FOR loop to grab the first line from
	IF EXIST %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_usernames.txt del %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_usernames.txt
	IF EXIST %downloaddir%!rawusersnamefile! del %downloaddir%!rawusersnamefile!
	echo.
	echo Generating UsersName file...
	REM Make a file that contains just lines that have sessionIDs and usernames
	echo.
	echo Pulling raw lines of sessionID and usernames from the log file... 
	findstr /C:"with username:" %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_tmp.log | findstr /C:"true" >> %downloaddir%!rawusersnamefile!
	echo Done.
	echo.
	echo Finding sessionID string and calling FindUsersName...
	FOR /F "tokens=* USEBACKQ" %%a in (`findstr /C:!stringtosearch! %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_tmp.log`) DO (
		set intCountOfNames=0
		:: Set total number of names to find
		FOR /F "tokens=3 USEBACKQ" %%y IN (`find /v /c "" %outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt`) DO set intTotalNames=%%y
		:: Find the Token
		FOR /F "tokens=4 delims=^[,^]" %%n in ("%%a") DO (
			set sessionID=%%n
			CALL :FindUsersName
		)
		set intCountOfNames=0
	)
	echo Done.  %time%
	echo.
	echo parsing !actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt...
	echo and making the output file for QlikView...
	:: Parse each line, using tokens to find each variable needed
	FOR /F "tokens=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17" %%A IN (%outputdir%!actionName!\!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt) DO (
		set "DateTime=%%A %%B"
		set EntryType=%%C
		set TD=%%D
		set TE=%%E
		set TF=%%F
		set TG=%%G
		set TH=%%H
		set TK=%%K
		set TL=%%L
		set TM=%%M
		set TN=%%N
		set TO=%%O
		set TQ=%%Q	
		set duration=%%P
		set Method=%%I
		set ActionURI=%%J
		set /a intNamesToProcess=!skipINT!+1
		TITLE %titleintro% Processing !intNamesToProcess! of !intTotalNames!
		CALL :SetUsersName
		echo.!NCDusers! | findstr /C:"!usersName!">nul && (
			set userGroup=[thisLabel]
			) || (
			set userGroup=^<blank^>
		)
		IF "!actionName!" == "Publish_To_Web" (
			FOR /F "tokens=8 delims=_" %%z IN ("!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt") DO (
				set exORinCheck=%%z
			)
		) ELSE (
			FOR /F "tokens=6 delims=_" %%z IN ("!actionName!_restserver_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!.txt") DO (
			set exORinCheck=%%z
			)
		)
		echo !DateTime!	!usersName!	!duration!	!exORinCheck!	!as1aORas1b!	!userGroup!	!EntryType!	!Method!	!ActionURI!	!DateTime! !EntryType! !TD! !TE! !TF! !TG! !TH! !Method! !ActionURI! !TK! !TL! !TM! !TN! !TO! !duration! !TQ!>> %downloaddir%formatted_!actionLower!_!dateY!_!dateM!_!dateD!_!exORinCheck!_%as1aORas1b%.txt
		set /a skipINT+=1
		set skip="skip=!skipINT!"
	)
	set /a intTotalNamesProcessed+=!intTotalNames!
	set intNamesToProcess=0
	set intTotalNames=0
	echo Done.
	echo.
	echo %line% - %time%
	echo Moving formatted output to the fileshare directory
	move "%downloaddir%formatted_!actionLower!_!dateY!_!dateM!_!dateD!_!exORinCheck!_!as1aORas1b!.txt" "%fileshare%!actionLower!\"
	IF NOT "%errorlevel%" EQU "0" (
		set /a issuesCount+=1
		echo.
		echo WARNING:
		echo There was an issue copying the formatted txt file from
		echo "%downloaddir%formatted_!actionLower!_!dateY!_!dateM!_!dateD!_!exORinCheck!_!as1aORas1b!.txt"
		echo to the directory:
		echo "%fileshare%!actionLower!\"
		echo.
		echo Please review the issue.
		echo.
		REM pause
		timeout /t 4 >nul
	)
	echo Done.
	:: Delete these files because we don't need them any more and it's good housekeeping
	IF EXIST %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_usernames.txt del %downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_usernames.txt
	IF EXIST %downloaddir%!rawusersnamefile! del %downloaddir%!rawusersnamefile!


:: Exit new_findstr_on_files
EXIT /B


:: The part to download and run the required program installer files. Originates from one of the first script configuration checks near the start of the script.
:: These next things apparently require Windows 10 / PowerShell 5+
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

:FindUsersName
FOR /F "tokens=6 delims=:, USEBACKQ" %%m in (`findstr /C:"!sessionID!" %downloaddir%!rawusersnamefile!`) DO (
	set UsersName=%%m
	set UsersName=!UsersName:~1!
	set /a intNamesToProcess+=1
	TITLE %titleintro% Processing !intNamesToProcess! of !intTotalNames!
	echo !UsersName!>> %downloaddir%mras_%dateY%_%dateM%_%dateD%_!exORin!_!as1aORas1b!_usernames.txt
	EXIT /B
)
:: Exit FindUsersName
EXIT /B

:SetUsersName
:: This grabs the Nth name from a list, where N = %skip%
FOR /F %skip% %%g IN (%downloaddir%mras_!dateY!_!dateM!_!dateD!_!exORin!_!as1aORas1b!_usernames.txt) DO (
	set usersname=%%g
	EXIT /B
)
:: Exit SetUsersName
EXIT /B
:ClearVariables
set stringpublishnew=
set stringsearchnew=
set exORin=
set as1aORas1b=
set swORswn=
set region=
set exORincheck=
set instanceINC=
set instanceID=
set mrasLoop=
set mrasFileName=
set actionName=
set actionLower=
set usersname=
set filesharecheck=
set intTotalNamesProcessed=
EXIT /B