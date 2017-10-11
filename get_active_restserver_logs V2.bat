:: This file has been sanitized so it won't work!
:: This script assumes you have AWS CLI and an IAM account that has no permission restrictions
:: Get all active restserver.log files from the 6 servers via zip files and downloads them to the %downloaddir% directory
:: by bkelley 2017/10/11  Version 2.0 (Added CALL functions)
@echo off
setlocal enabledelayedexpansion

cls
set line=@@@@@@@@@@
set downloaddir=C:\Users\%username%\Documents\restserver_log\Raw\

echo Hello^^!  
echo This script remotes into all 6 servers, zips up the current-day restserver.log
echo files and puts them on your local machine specified by the "downloaddir" variable.
timeout /t 3 >nul
echo.
echo Getting current IP addresses since they change...
echo.
:: External Static
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=External_Static ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set EXstaticIP=%%n
echo %EXstaticIP%
:: External AS1a
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=External_AS Name^=availability-zone^,Values^=us-east-1a ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set EXas1aIP=%%n
echo %EXas1aIP%
:: External AS1b
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=External_AS Name^=availability-zone^,Values^=us-east-1b ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set EXas1bIP=%%n
echo %EXas1bIP%
:: Internal Static
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=Internal_Static ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set INstaticIP=%%n
echo %INstaticIP%
:: Internal AS1a
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=Internal_AS Name^=availability-zone^,Values^=us-east-1a ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set INas1aIP=%%n
echo %INas1aIP%
:: Internal AS1b
FOR /F "tokens=4 USEBACKQ" %%n IN (`aws ec2 describe-instances --filters Name^=tag:Name^,Values^=Internal_AS Name^=availability-zone^,Values^=us-east-1b ^| findstr /C:"PRIVATEIPADDRESSES"`) DO set INas1bIP=%%n
echo %INas1bIP%
echo.

:: Set Server label
set "servername=External Static"
:: Set Server IP from the part above
set serverip=%EXstaticIP%
:: Set zip file name for the output
set ziptoget=restserver_external_static.zip
:: Go to the main processing
CALL :StaticLoop

set "servername=External AS1a"
set remoteIP=%EXas1aIP%
set ziptoget=restserver_external_AS1a.zip
CALL :ASLoop

set "servername=External AS1b"
set remoteIP=%EXas1bIP%
set ziptoget=restserver_external_AS1b.zip
CALL :ASLoop

set "servername=Internal Static"
set serverip=%INstaticIP%
set ziptoget=restserver_internal_Static.zip
CALL :StaticLoop

set "servername=Internal AS1a"
set remoteip=%INas1aIP%
set ziptoget=restserver_internal_AS1a.zip
CALL :ASLoop

set "servername=Internal AS1b"
set remoteIP=%INas1bIP%
set ziptoget=restserver_internal_AS1b.zip
CALL :ASLoop

:: After doing everything, skip the processing parts to go to the end
GOTO finish

:StaticLoop
echo %line%
echo.
echo %servername%: %serverip%
echo.
:: Make zip of the files
plink -ssh -batch -pw password username@%serverip% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
:: Pull zip to local
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
:: Delete zip on server
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
:: Check if the zip was successfully downloaded, if not, goto quit
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	echo ^(%servername%: %serverip%^)
	echo.
	pause
	goto quit
)
EXIT /B

:ASLoop
echo.
echo %line%
echo.
echo %servername%: %serverip% to %remoteip%
echo.
:: Remote to AS server through Static server to run the zip command
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteip% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
:: SCP the zip file from the AS to the Static server
plink -ssh -batch -pw password username@%serverip% scp username@%remoteip%:/filesystem/directory/%ziptoget% /filesystem/directory
:: Remove the zip on the AS server
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteip% rm %ziptoget%
:: Copy the zip on the Static server to local
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
:: Remove the zip on the Static server
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	echo %servername%
	echo Server: %serverip% 
	echo Remote: %remoteip%
	echo.
	pause
	goto quit
)
EXIT /B

:finish
%SystemRoot%\explorer.exe "%downloaddir%"
color 2F
echo.
echo ~@~@~@~@~
echo FINISHED^^!
echo.
echo Output directory: %downloaddir%
pause
:quit
color 0F
