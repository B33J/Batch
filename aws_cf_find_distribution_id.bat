:: Search AWS CloudFront by using a website alias to find the Distribution ID
:: By bkelley 2017/11/06
:: This script requires "grep for windows"
@echo off
cls
setlocal EnableDelayedExpansion

:: VARIABLES
IF "%username%" == "bkelley" set "cliprofile=--profile default"
:: grep installation directory and program exe
set grep="C:\Program Files (x86)\GnuWin32\bin\grep.exe"
:: set the number of lines to pull that are before the string that we're searching for. Good number to start is around 10. Change this number higher or lower if there are issues retrieving the correct ID
set lines=10

set findIDstring=^"\"Id\": \"E"
:: END VARIABLES
IF NOT EXIST %grep% (
	echo:
	echo Hey, grep needs to be installed on this computer before this script can be run.
	echo:
	echo Expected installation location: %grep%
	echo:
	echo grep for Windows can be downloaded at http://gnuwin32.sourceforge.net/downlinks/grep.php
	echo Make sure to install it to its default install directory.
	echo:
	pause
	goto quit
)
:start
:: Ask for which string to find
echo ~@~@~@~@~@~@~@~@~@~@~@~@~@~
echo Hello^^! This script uses AWS CLI, talks to CloudFront, and will find 
echo the Distribution ID associated with a site name we search for. 
echo:
echo What site are we searching for?
set /p stringtofind=
IF "%stringtofind%" == "" (
	echo:
	echo Please do not leave this input blank.
	echo:
	pause
	goto start
)
echo:
echo We are searching for "%stringtofind%"
echo:
echo Calling CloudFront via the AWS CLI now...
FOR /f "tokens=2 delims=: USEBACKQ" %%F IN (`aws cloudfront list-distributions %cliprofile% ^| %grep% -b%lines% %stringtofind% ^| findstr /C:^"Id\":^ \"E`) DO (
	set tempvar=%%F
	set distID=!tempvar:~2,-3!
	set /a varcount+=1
)
IF NOT DEFINED distID (
	echo:
	echo We ran into an issue and we have to abort^!
	echo:
	echo Maybe the site name/string you typed in could not be found.
	echo Maybe there was an issue with the AWS CLI.
	echo:
	echo:
	pause
	goto quit
)
IF "%varcount%" GTR "1" (
	echo:
	echo There may have been an issue gathering the correct ID.
	echo Did you correctly type in the site name?
	echo:
	echo OR if you did, change the %%lines%% variable in this script to a higher
	echo or lower number to see if that fixes it.
	echo:
	echo:
	pause
	goto quit
)
echo:
echo:
echo The Distribution ID for %stringtofind% is !distID!
echo:




:quit
echo.
echo Finished.
echo.
pause
color 0F
GOTO:EOF

