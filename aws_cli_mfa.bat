:: By bkelley
:: Version 1.1 2019/08/15 - Updated this to handle selecting AWS accounts now. It requires which CLI profile you want to use, it uses that to get the MFA device ARN of that profile, and then uses that to do the get-session-token command stuff.
:: This script is to get AWS CLI Session token
:: It sets environment variables, so you can use it once in the same command prompt window and then run future AWS CLI commands with the default CLI profile.
@echo off
setlocal enabledelayedexpansion
set success=

echo.
echo This is to get new AWS CLI session token credentials and set your environment variables with them.
echo.
:cli_question
:: Which CLI/AWS Account profile to use, if not Default?
echo.
echo Which CLI profile are we using? [default]
set cliprofile=
set /p cliprofile=^>
IF "!cliprofile!" == "" set cliprofile=default

:: Get mfa device SerialNumber from iam
FOR /F tokens^=^4^ delims^=^"^ usebackq %%A in (`aws iam list-mfa-devices --profile !cliprofile!^| findstr /C:SerialNumber`) DO set mfadevice=%%A && set success=true
IF NOT "!success!" == "true" (
	echo CLI profiles are case-sensitive. Please try again.
	echo.
	pause
	goto cli_question
)
:digits_question
:: Get 6 digit code from user
echo.
echo What is your 6 digit MFA code for profile "%cliprofile%"?
set digits=
set /p digits=^>
IF "%digits%" == "" goto digits_question
echo %digits%| findstr /r "^[0-9][0-9][0-9][0-9][0-9][0-9]$">nul
IF %errorlevel% EQU 0 goto run_command
echo.
echo ##########
echo Sorry, that doesn't look like 6 numerical digits. Please try again.
echo.
goto digits_question
:run_command
:: Get new session credentials from AWS
FOR /F "tokens=2,4,5 USEBACKQ" %%a IN (`aws sts get-session-token --serial-number %mfadevice% --token-code %digits% --output text --profile %cliprofile%`) DO (
	endlocal & set AWS_ACCESS_KEY_ID=%%a
	endlocal & set AWS_SECRET_ACCESS_KEY=%%b
	endlocal & set AWS_SESSION_TOKEN=%%c
	echo.
	echo Access Key:    %%a
	echo Secret Key:    %%b
	echo Session Token: %%c
	echo.
	)
echo.
echo Done.
echo.