:: This script creates the json file using a list of IPs to add to a WAF rule set.
:: By bkelley
@echo off
setlocal EnableDelayedExpansion
cls
color 0F

set workdir=C:\bkelley_scripts\waf\
set outputfile=update-blacklist.json
set sourcefile=IP_list.txt
set output=%workdir%%outputfile%


:: Start the format of the JSON file
echo { > %output%
echo 	"IPSetId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", >> %output%
echo         "ChangeToken": "", >> %output%
echo         "Updates": [		>> %output%

:: Get the IP addresses from the source file
FOR /F "tokens=*" %%I IN (%workdir%%sourcefile%) DO (
	set /a count+=1
	echo !count!
	set ipstring=%%I
	CALL :OutputLoop
)
:: End the format of the JSON file
echo	] >> %output%
echo } >> %output%

:: After all is done, quit the script
goto quit

:OutputLoop
:: Output json format lines to outputfile
echo 				{ >> %output%
echo					"Action": "INSERT", >> %output%
echo					"IPSetDescriptor": { >> %output%
echo 						"Type": "IPV4", >> %output%
echo						"Value": "!ipstring!" >> %output%
echo							} >> %output%
echo					}, >> %output%

:: Exit OutputLoop
EXIT /B


:quit
echo.
echo Finished script.
echo.
pause
color 0F
GOTO:EOF