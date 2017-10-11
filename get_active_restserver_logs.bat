:: Get all active restserver.log files from the 6 servers via zip files and downloads them to the %downloaddir% directory
:: This script uses AWS CLI
:: by bkelley 2017/10/10  Version 1.0
@echo off
setlocal enabledelayedexpansion
set dateY=%date:~-4%
set dateM=%date:~4,2%
set dateD=%date:~7,2%

::for %%i in (%1) do set filedir=%%~dpi
::for %%i in (%1) do set sourcefile=%%~nxi

cls
set line=@@@@@@@@@@
set zipdirectory="C:\Program Files\7-Zip\7z.exe"
set downloaddir=C:\Users\%username%\Documents\restserver_log\Raw\

echo Hello^^!  
echo This script remotes into all 6 servers, zips up the current-day restserver.log
echo files and puts them on your local machine specified by the "downloaddir" variable.
timeout /t 3 >nul
echo.
echo Getting IP addresses since they change...
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
echo %line%
echo.
echo External Static:
echo.
:: Set Server IP
set serverip=%EXstaticIP%
:: Set zip file name
set ziptoget=restserver_external_static.zip
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
	pause
	goto quit
)
echo.
echo %line%
echo.
echo External AS1a:
echo.
:: Set the AutoScaled IP
set remoteIP=%EXas1aIP%
set ziptoget=restserver_external_AS1a.zip
:: Remote to AS server thru Static server to run the zip command
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
:: SCP the zip file from the AS to the Static server
plink -ssh -batch -pw password username@%serverip% scp username@%remoteIP%:/filesystem/directory/%ziptoget% /filesystem/directory
:: Remove the zip on the AS server
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% rm %ziptoget%
:: Copy the zip on the Static server to local
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
:: Remove the zip on the Static server
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	pause
	goto quit
)
echo.
echo %line%
echo.
echo External AS1b:
echo.
set remoteIP=%EXas1bIP%
set ziptoget=restserver_external_AS1b.zip
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
plink -ssh -batch -pw password username@%serverip% scp username@%remoteIP%:/filesystem/directory/%ziptoget% /filesystem/directory
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% rm %ziptoget%
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	pause
	goto quit
)
echo.
echo %line%
echo.
echo Internal Static:
echo.
set serverip=%INstaticIP%
set ziptoget=restserver_internal_Static.zip
plink -ssh -batch -pw password username@%serverip% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	pause
	goto quit
)
echo.
echo %line%
echo.
echo Internal AS1a:
echo.
set remoteIP=%INas1aIP%
set ziptoget=restserver_internal_AS1a.zip
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
plink -ssh -batch -pw password username@%serverip% scp username@%remoteIP%:/filesystem/directory/%ziptoget% /filesystem/directory
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% rm %ziptoget%
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	pause
	goto quit
)
echo.
echo %line%
echo.
echo Internal AS1b:
echo.
set remoteIP=%INas1bIP%
set ziptoget=restserver_internal_AS1b.zip
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% zip %ziptoget% /filesystem/directory/logfiles/tomcat/*
plink -ssh -batch -pw password username@%serverip% scp username@%remoteIP%:/filesystem/directory/%ziptoget% /filesystem/directory
plink -ssh -batch -pw password username@%serverip% ssh username@%remoteIP% rm %ziptoget%
pscp -scp -batch -pw password username@%serverip%:/filesystem/directory/%ziptoget% %downloaddir%
plink -ssh -batch -pw password username@%serverip% rm %ziptoget%
IF NOT EXIST "%downloaddir%%ziptoget%" (
	echo.
	echo Whoah, we ran into a download problem.
	echo We have to abort!
	echo.
	pause
	goto quit
)
%SystemRoot%\explorer.exe "%downloaddir%
color 2F
:quit
echo.
echo ~@~@~@~@~
echo FINISHED^^!
echo.
echo Output directory: %downloaddir%
pause
color 0F



