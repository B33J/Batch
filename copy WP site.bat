:: This script aids in copying WordPress sites for RFP requests.
set Dir=E:\Inetpub\wwwroot\
@echo off
dir %Dir% /A:D
echo.
:restart
echo.
echo Close this window to cancel the script at any time.
echo.
echo.
echo Which WordPress directory folder to copy?
set /p WPDirSource=

IF EXIST "%Dir%%WPDirSource%" (
	GOTO continue
	) ELSE (
	echo.
	echo That folder doesn't exist.
	)
echo.
echo.
GOTO restart
:continue
echo.
echo Name of the new folder?
set WPDirNew=
set /p WPDirNew=
echo.
echo Is this correct? (y/n)
echo "%WPDirNew%"
echo.
set YesNo=
set /p YesNo=
IF "%YesNo%"=="y" (
	GOTO next1
	) ELSE (
	GOTO continue
	)
:next1
echo.
echo We are ready to robocopy "%WPDirSource%" to the directory %Dir%%WPDirNew%
echo.
echo Close this window if you want to cancel.
echo.
pause
echo.
robocopy %Dir%%WPDirSource% %Dir%%WPDirNew% /COPYALL /E /R:0
echo.
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
IF NOT EXIST %Dir%%WPDirNew%\wp-config.php echo The wp-config.php file doesn't exist. Was the folder copied properly?
IF NOT EXIST %Dir%%WPDirNew%\wp-config.php GOTO :quit
echo.
echo You must edit the wp-config.php database connection parameters.
echo The three things to edit are 'dbname', 'username', & 'password':
echo define('DB_NAME', 'dbname');
echo define('DB_USER', 'username');
echo define('DB_PASSWORD', 'password');
echo.
echo After editing the file, make sure you save it.
echo Feel free to keep the wp-config.php file open for reference for the next step.
echo.
echo To automatically have the wp-config.php file open, 
pause
echo.
start /d "C:\Program Files (x86)\Notepad++\notepad++.exe" notepad++.exe "%Dir%%WPDirNew%\wp-config.php"
echo ***************************************
echo Please save the file before continuing.
pause
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo Let's make the new empty database.
echo Use the same information you just put into the wp-config.php file.
:databasequestion
echo.
:databasename
echo New database name? (maximum 16 characters)
set NewDBname=
set /P NewDBname=
IF "%NewDBname%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO databasename
	)
echo.
:databaseuser
echo New user for that database? (maximum 16 characters)
set NewDBuser=
set /P NewDBuser=
IF "%NewDBuser%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO databaseuser
	)
echo.
:newdbpassq
echo Password for that database user? (maximum 16 characters)
set NewDBpass=
set /P NewDBpass=
IF "%NewDBpass%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO newdbpassq
	)
echo.
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo Ready to create the database with:
echo Database name: %NewDBName%
echo Database user: %NewDBuser%
echo Database pass: %NewDBpass%
echo.
echo Is this correct? (y/n)
set YesNo=
set /p YesNo=
IF "%YesNo%"=="y" (
	GOTO next2
	) ELSE (
	GOTO databasequestion
	)
:next2

echo.
mysql -u root -pThePassWord -e "create database %NewDBname%;"
echo create database %NewDBname%;

echo.
mysql -u root -pThePassWord -e "create user '%NewDBuser%'@'%%';"
echo create user '%NewDBuser%'@'%%';

echo.
mysql -u root -pThePassWord -e "set password for '%NewDBuser%'@'%%' = password('%NewDBpass%');"
echo set password for '%NewDBuser%'@'%%' = password('%NewDBpass%');

echo.
mysql -u root -pThePassWord -e "grant all privileges on %NewDBname%.* to '%NewDBuser%'@'%%';"
echo grant all privileges on %NewDBname%.* to '%NewDBuser%'@'%%';

echo.
mysql -u root -pThePassWord -e "flush privileges;"
echo flush privileges;

echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo New database and user created.
echo.
echo Let's copy a preexisting database to use for the new website.
echo.
pause
mysql -u root -pThePassWord -e "show databases;"
echo.
:databasenamequestion
echo Which database to dump and edit? (Not the one we just made)
set DatabaseName=
set /p DatabaseName=  
IF "%DatabaseName%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO databasenamequestion
	)
echo.
echo.
mysql -u root -pThePassWord -e "show databases;" | find "%DatabaseName%"
IF NOT "%ERRORLEVEL%"=="0" (
	echo.
	echo That database does not exist. Please type in the correct database name.
	echo.
	GOTO databasenamequestion
	)
mysqldump -u root -pThePassWord %DatabaseName% > C:\temp\temp_%DatabaseName%
echo The sql file %DatabaseName% was dumped to C:\temp\
echo.
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo Instructions:
echo Please Find^&Replace all appropriate website references inside the dump file:
echo 1- "Database:" near the top of the file 
echo 2- If changing it, the WordPress Admin username. Example string to search:  " admin' "
echo    otherwise you can leave this one the same.
echo 3- "http://website.subdomain.website.com" absolute URLs - VITAL to do so!
echo.
echo Make sure to save it! 
echo Do not rename it or change its temp directory.
echo.
echo To automatically open the file,
pause
start /d "C:\Program Files (x86)\Notepad++\notepad++.exe" notepad++.exe "C:\temp\temp_%DatabaseName%"
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo IF YOU HAVE SAVED THE FILE, it is ready to be imported.
pause
IF NOT EXIST "C:\temp\temp_%DatabaseName%" (
	echo.
	echo The database file is missing. We have to abort the script.
	echo Goodbye.
	echo.
	GOTO quit
	)
mysql -u root -pThePassWord %NewDBname% < "C:\temp\temp_%DatabaseName%"
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo Let's run a test to see if we can connect to the database.
echo We're using the new credentials you just made.
echo.
pause
echo.
mysql -u %NewDBuser% -p%NewDBpass% -e "show databases;"
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo If the database "%NewDBname%" is displayed above, it worked!
echo.
echo.
pause
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo.
echo Now let's add the site in IIS.
echo.
echo.
:iissitenamequestion
echo Enter the site name for the IIS entry.
echo (Example: "RFP - newsite")
echo.
set IISsitename=
set /p IISsitename=
IF "%IISsitename%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO iissitenamequestion
	)
echo.
echo Enter JUST the subdomain name
echo.            
echo http://[thispart].wordpress.mywebsite.com
echo.            
echo.
:domainnamequestion
set domainname=
set /p domainname=
IF "%domainname%"=="" (
	echo.
	echo Please don't leave this blank
	echo.
	GOTO domainnamequestion
	)
echo.
echo.
:: If this script is running on the server hosting IIS, then add the new WP site in IIS
c:\windows\system32\inetsrv\AppCmd ADD SITE /name:"%IISsitename%" /bindings:http://%domainname%.wordpress.mywebsite.com:80 /physicalPath:%Dir%%WPDirNew% 
c:\windows\system32\inetsrv\appcmd set config "%IISsitename%" -section:system.webServer/security/authentication/anonymousAuthentication /userName:""  /commit:apphost
echo.
echo.
echo.
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo.
echo.
echo.
echo Now make sure the appropriate DNS entries have been made.
echo.
echo We are done here!
:quit
echo.

pause