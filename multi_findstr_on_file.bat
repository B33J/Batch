::YOU SHOULD DRAG AND DROP YOUR LOG FILE ONTO THIS BATCH FILE IN WINDOWS EXPLORER TO PROCESS THE LOG

::Filter Log File by the entry type "INFO"
::bkelley

@echo off
setlocal enabledelayedexpansion

set filetype=.txt
::set outputdir=C:\Users\bkelley\Documents\restserver_log\sharepoint\Raw\
set workfiledir=%1

::Drag and Drop functionality here
for %%i in (%1) do set outputdir=%%~dpi
for %%i in (%1) do set sourcefile=%%~nxi

::add "By-Type" at the beginning of the output file name AND remove the .log file extension so we can change it to %filetype%
echo.
echo What's the file prefix?  Will be:  [placed here]_%sourcefile:~0,-4%%filetype%
set /p fileprefix=
set fileoutput=%fileprefix%_%sourcefile:~0,-4%

::did you drag and drop your file?
if "%workfiledir%" == "" (
	echo.
	echo Please drag and drop your log file onto the batch script within Windows Explorer.
	echo.
	pause
	goto end
)
::is the source file there?
if not exist %workfiledir% (
	echo.
	echo Can't find the file to process.
	echo.
	echo Please drag and drop your file onto this batch script within Windows Explorer.
	echo OR edit this file to make sure all variables are set correctly.
	echo.
	pause
	goto end
)
::does the output file exist already?
if exist %outputdir%%fileoutput%%filetype% (
	echo.
	echo The output file already exists.
	echo.
	echo It exists at %outputdir%%fileoutput%%filetype%
	echo.
	pause
	goto end
)
::does the output directory exist?
if not exist %outputdir% (
	echo.
	echo The output directory does not exist.
	echo.
	echo Was the "outputdir" value set correctly?
	echo.
	pause
	goto end
)

::recursive searching by how many times?
:searchloopquestion
set searchloop=0
echo.
echo If you want to recursively search this file, kind of like:
echo # ^>$ cat directory/file.txt ^|grep "string" ^|grep "other string" ^|grep "etc" #
echo How many additional searches do you want?
echo 0 or blank for just one search
echo 1 for two total searches
echo 2 for three total searches
echo etc.
echo __________________________________
set /p searchloop=
set searchloopint=%searchloop%
if %searchloop% GTR 4 (
	echo.
	echo Warning: You're doing more than 4 stacked searches.
	echo Are you sure about that?
	pause
)
echo.
echo.
echo.
echo What is the string to search for?
set /P customstring=
echo.
echo.
echo Processing %sourcefile%
echo.
echo From location %workfiledir%
echo.
echo Output to %outputdir%%fileoutput%%searchloopint%%filetype%
findstr /r /c:%customstring% "%workfiledir%" >> %outputdir%%fileoutput%%searchloopint%%filetype%

if "%searchloop%" == "" ( goto skiploop )
:searchloop
if not %searchloop% EQU 0 (
	echo.
	echo.
	set /A searchloopint-=1
	echo What is the next string to search for? ^(!searchloop!^) ^(!searchloopint!^)
	set customstring=
	set /P customstring=
	if "!customstring!" == "" (
		echo.
		echo WARNING:
		echo You left this input blank.  Please input something.
		echo.
		echo To quit this script, press Ctrl+C
		echo.
		pause
		goto searchloop
	)
	
	echo.
	echo.
	echo Processing %outputdir%%fileoutput%!searchloop!%filetype%
	echo.
	echo Output to %outputdir%%fileoutput%!searchloopint!%filetype%
	findstr /r /c:"!customstring!" "%outputdir%%fileoutput%!searchloop!%filetype%" >> %outputdir%%fileoutput%!searchloopint!%filetype%
	::delete the previous file used to search, unless searchloopint is zero
	if !searchloopint! EQU 0 (
		del %outputdir%%fileoutput%1%filetype%
		goto skipdelete 
		)
	del %outputdir%%fileoutput%!searchloop!%filetype%
	:skipdelete
	set /a searchloop-=1
	goto searchloop
)
:skiploop
color 2F
echo.
echo We're done here. 
echo.
:: If I'm running this script, then automatically open the file for me to view
if "%username%" == "bkelley" (
	if exist %outputdir%%fileoutput%%searchloopint%%filetype% ( "C:\Program Files (x86)\Notepad++\notepad++.exe" %outputdir%%fileoutput%%searchloopint%%filetype% )
	if not exist %outputdir%%fileoutput%%searchloopint%%filetype% ( "C:\Program Files (x86)\Notepad++\notepad++.exe" %outputdir%%fileoutput%%filetype% )

)
pause
:end