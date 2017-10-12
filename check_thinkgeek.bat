:: This script checks the ThinkGeek site for when a product becomes available. Good for when there's a really hot item that lots of people want and you want to have a chance at buying it.
:: It checks the product page for the string "Coming Soon" and if it's not there (like it became "Available"), the script will flash the command prompt window green, letting you know to go get it.
:: You can increase the frequency of the checks by changing the first "timeout /t <seconds>" command.
:: Check SNES page
:: http://www.thinkgeek.com/product/kmrn/
@echo off
set checkINT=1
:restart
powershell -Command "Invoke-WebRequest -Outfile %TEMP%\thinkgeekpage.html http://www.thinkgeek.com/product/kmrn/"
findstr /L /C:"Coming Soon" %TEMP%\thinkgeekpage.html >nul
IF "%errorlevel%" EQU "0" (
	set /a checkINT+=1
	echo.
	echo The page has not changed.
	echo Check number %checkINT%
	echo.
) ELSE (
	cls
	COLOR 2F
	echo.
	echo THE PAGE HAS CHANGED^!^!^!
	echo.
	GOTO flash
	)
del %TEMP%\thinkgeekpage.html
Timeout /t 30
GOTO restart
:flash
COLOR 0F
timeout /t 1 >nul
COLOR 2F
timeout /t 1 >nul
goto flash

:: (I sucessfully got the SNES Classic on 2017/10/11 because of this script.)