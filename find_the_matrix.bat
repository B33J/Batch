@echo off
cls
color 0F
CALL :VARIABLES
echo.
echo ^>
timeout /t 2 >nul
echo ^>SEARCH_FOR_THE_MATRIX.bat
timeout /t 3 >nul
echo ^>RUNNING^!
timeout /t 1 >nul
:matrix
color 0A
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
echo %random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%%random%
set /a number+=1
if "%infinite%" == "true" goto matrix
if %number% GTR 500 GOTO QUESTION
goto matrix

:QUESTION
IF "%errorloop%" LSS "3" (
	timeout /t 1 >nul
	echo ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR
	set /a errorloop+=1
	goto QUESTION
)
set errorloop=0
timeout /t 3 >nul
cls
timeout /t 2 >nul
echo.
echo ^> Wake up, Neo...
echo.
timeout /t 5 >nul
cls
echo.
echo ^> The Matrix has you...
echo.
timeout /t 5 >nul
cls
echo.
echo ^> Follow the white rabbit.
echo.
timeout /t 5 >nul
cls
echo.
echo ^> Knock knock.
echo.
timeout /t 3 >nul
set number=0
cls
set infinite=true
timeout /t 2 >nul
goto matrix
:quit
echo.
pause >nul
:VARIABLES
title What is the Matrix?
set loop=0
set errorloop=0
set number=0
set infinite=
EXIT /B