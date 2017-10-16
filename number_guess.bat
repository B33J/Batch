::by bkelley
:: Number Guess Game
:: The user can specify the upper limit within which to guess, max of the limit of the %random% function.
@echo off
setLocal EnableDelayedExpansion
cls
:start
color 0F
set errorlevel=
set numberOfGuesses=
set maxint=
set intguess=
set answer=
echo.
echo What's the highest number you want to guess up to? (max of 32767)
echo Input "max" to use the highest number possible.
echo Guessing between 1 and [?]
set maxguess=
set /p maxguess=
::option to quit game during first question
IF "%maxguess%" == "exit" goto quit
IF "%maxguess%" == "quit" goto quit
::set the max possible guess in "max" is input
IF "%maxguess%" == "max" set maxguess=32767
::prevent the user from inputting a number higher than what the %random% function can do
IF "%maxguess%" GTR "32767" (
	echo.
	echo #############
	echo Please input a smaller number^^!
	echo.
	pause
	goto start
)
IF "%maxguess%" EQU "" (
	echo.
	echo #############
	echo Please don't leave this input blank
	echo.
	pause
	goto start
)
set var=
for /f "delims=0123456789" %%i in ("%maxguess%") do set var=%%i
IF defined var (
	echo.
	echo #############
	echo "%maxguess%" is NOT a regular, positive number^^!
	echo Please type in only numbers.
	echo.
	pause
	goto start
)
echo.
echo.
::get the random integer to guess as the answer
set /a answer=%RANDOM% %% %maxguess% + 1
::digits 1 through %maxguess% are acceptable answers, so to say we're playing "between" those two numbers, we need to increase the maxguess by one
set /a maxint=%maxguess%+1
echo.
:guess
echo.
echo So, I'm thinking of a number greater than 0 and less than %maxint%.
echo What is it?
set intguess=
set /p intguess=
::option to quit game during guess question
IF "%intguess%" == "exit" goto quit
IF "%intguess%" == "quit" goto quit
::cheat code
IF "%intguess%"=="cheat" (
	echo.
	echo The answer is %answer%
	echo.
	goto guess
)
::check the syntax of user input
set var2=
for /f "delims=0123456789" %%i in ("%intguess%") do set var2=%%i
IF defined var2 (
	echo.
	echo ERROR ########### ERROR
	echo "%intguess%" is NOT a regular, positive number^^!
	echo Please input only numbers.
	echo.
	pause
	goto guess
)
IF "%intguess%" EQU "" (
	echo.
	echo ERROR ########### ERRROR
	echo Please don't leave this input empty^^!
	pause
	goto guess
)	
::check to see if we're within 0 and our max guess int.
IF %intguess% LSS 0 (
	echo.
	echo ERROR ########### ERROR 
	echo Sorry, your guess was BELOW our playing range of 1 to %maxguess%.
	echo.
	echo Please try again^^!
	pause
	goto guess
)
IF %intguess% GTR %maxguess% (
	echo.
	echo ERROR ########### ERROR
	echo Sorry, your guess was OVER our playing range of 1 to %maxguess%.
	echo.
	echo Please try again^^!
	pause
	goto guess
)
::increment number of guesses at this point of the script
set /a numberOfGuesses+=1
::check to see if we have guessed lower, higher, or right on the answer.
if %intguess% LSS %answer% (
	echo.
	echo.
	echo @#@#@#@#@
	echo The number to guess is higher than that^^!
	echo.
	goto guess
)
if %intguess% GTR %answer% (
	echo.
	echo.
	echo @#@#@#@#@
	echo The number to guess is lower than that^^!
	echo.
	goto guess
)
IF %intguess% EQU %answer% (
	color 0A
	cls
	echo.
	echo #@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@
	echo.
	echo Congratulations^^! You guessed it^^! The number is %answer%^^!
	echo.
	echo #@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@
	echo.
	echo You found it in %numberOfGuesses% guesses.
	echo.
	pause
	cls
	goto start
)

echo None of the IF statements worked. How did you do that?
pause.
goto guess

:quit
echo.
echo Okay bye!
echo.
