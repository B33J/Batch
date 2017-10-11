::by bkelley  2015/08/21
::checks a website and sends an email if it's down
@echo off

::formatting date and time variables
set datef=%date:~-4%_%date:~4,2%_%date:~7,2%
set timef=%time:~0,2%^:%time:~3,2%^:%time:~6,2%UTC

::main script variables
set website=http://www.website.com
set stringtofind=thisstring
set filetoscan=downloadedfile.html
set logdir=C:\scripts\check_website_logs\
set tries=0
set websitewasdown=0

:start 
set datef=%date:~-4%_%date:~4,2%_%date:~7,2%
set timef=%time:~0,2%^:%time:~3,2%^:%time:~6,2%UTC

::setting notification email variables
::this needs to be included in the main loop so the variables "datef" and "timef" get updated frequently since they're in the email bodies
set emailFrom=\"website@company.com\"
set emailTo=\"bkelley@company.com\"
set emailSubject=\"website is Down - Attempted AppPool restart\"
set emailSubject2=\"website is Down - Attempted IISRESET\"
set emailSubjectUp=\"website is Up!\"

set emailMessage=\"^<table align^=left bgcolor^=DDDDDD cellpadding^=15 width^=550^>^<tr^>^<td^>^<table align^=center bgcolor^=white width^=515^>^<tr^>^<td^>^<table cellpadding^=15^>^<tr^>^<td align^=left^>^<font size^=^+2^>website.com Down Notification^</font^>^<br^>^<hr^>^<table^>^<tr^>^<td width^=50 align^=right^>Time^:^</td^>^<td^>!timef!UTC^</td^>^</tr^>^<tr^>^<td align^=right^>Date^:^</td^>^<td^>!datef!^</td^>^</tr^>^</table^>^<table^>^<tr^>^<td^>%website%^</td^>^</tr^>^</table^>^</td^>^</tr^>^</table^>^<p^>^<b^>Notice^:^</b^>^</p^>^<ul^>^<li^>Attempted automatic AppPool restart of SiteApplication.^<li^>Newest log file attached.^</p^>^</ul^>^<br^>^<br^>^</td^>^</tr^>^</table^>^<p^>^<a href^=http^://www.mywebsite.com^>^<img src^=http^://www.mywebsite.com/wp-content/uploads/2013/02/companylogo.png^>^</a^>^<br^>^<a href^=mailto^:support@company.com^>support@company.com^</a^>^</p^>^</td^>^</tr^>^</table^>\"

set emailMessage2=\"^<table align^=left bgcolor^=DDDDDD cellpadding^=15 width^=550^>^<tr^>^<td^>^<table align^=center bgcolor^=white width^=515^>^<tr^>^<td^>^<table cellpadding^=15^>^<tr^>^<td align^=left^>^<font size^=^+2^>website.com Down Notification^</font^>^<br^>^<hr^>^<table^>^<tr^>^<td width^=50 align^=right^>Time^:^</td^>^<td^>!timef!UTC^</td^>^</tr^>^<tr^>^<td align^=right^>Date^:^</td^>^<td^>!datef!^</td^>^</tr^>^</table^>^<table^>^<tr^>^<td^>%website%^</td^>^</tr^>^</table^>^</td^>^</tr^>^</table^>^<p^>^<b^>Notice^:^</b^>^</p^>^<ul^>^<li^>Attempted automatic IISRESET on the server.^<li^>Newest log file attached.^</p^>^</ul^>^<br^>^<br^>^</td^>^</tr^>^</table^>^<p^>^<a href^=http^://www.mywebsite.com^>^<img src^=http^://www.mywebsite.com/wp-content/uploads/2013/02/companylogo.png^>^</a^>^<br^>^<a href^=mailto^:support@company.com^>support@company.com^</a^>^</p^>^</td^>^</tr^>^</table^>\"

set emailMessageUp=\"^<table align^=left bgcolor^=DDDDDD cellpadding^=15 width^=550^>^<tr^>^<td^>^<table align^=center bgcolor^=white width^=515^>^<tr^>^<td^>^<table cellpadding^=15^>^<tr^>^<td align^=left^>^<font size^=^+2^>website.com UP Notification^</font^>^<br^>^<hr^>^<table^>^<tr^>^<td width^=50 align^=right^>Time^:^</td^>^<td^>!timef!UTC^</td^>^</tr^>^<tr^>^<td align^=right^>Date^:^</td^>^<td^>!datef!^</td^>^</tr^>^</table^>^<table^>^<tr^>^<td^>%website%^</td^>^</tr^>^</table^>^</td^>^</tr^>^</table^>^<p^>^<b^>Notice^:^</b^>^</p^>^<ul^>^<li^>The website is up! Yay!^<li^>Newest log file attached.^</p^>^</ul^>^<br^>^<br^>^</td^>^</tr^>^</table^>^<p^>^<a href^=http^://www.mywebsite.com^>^<img src^=http^://www.mywebsite.com/wp-content/uploads/2013/02/companylogo.png^>^</a^>^<br^>^<a href^=mailto^:support@company.com^>support@company.com^</a^>^</p^>^</td^>^</tr^>^</table^>\"

set emailAttachment="C:\scripts\check_website_logs\log.txt"


cls
powershell -Command "Invoke-WebRequest -Outfile %TEMP%\%filetoscan% %website%"
findstr /L /C:"%stringtofind%" %TEMP%\%filetoscan%
:: If there is an error, do this. If it tried before and still didn't work, do an IISRESET then.
IF not "%ERRORLEVEL%"=="0" (
	set websitewasdown=1
	IF "%tries%"=="1" (
		echo. >> %logdir%log.txt
		time /t >> %logdir%log.txt
		date /t >> %logdir%log.txt
		echo Previous AppPool restart failed. >> %logdir%log.txt
		echo Doing an IIS reset now >> %logdir%log.txt
		IISREST
		set tries=0
		powershell -Command "Send-MailMessage -To %emailTo% -Subject %emailSubject2% -Body %emailMessage2% -BodyAsHtml -From %emailFrom% -Attachments %emailAttachment% -Priority High -SmtpServer localhost
		GOTO end
		)
		
	echo.
	echo The website appears to be down.
	powershell -Command "Restart-WebItem 'IIS:\AppPools\SiteApplication'"
	echo. >> %logdir%log.txt
	time /t >> %logdir%log.txt
	date /t >> %logdir%log.txt
	echo Restarted SiteApplication. >> %logdir%log.txt
	echo. >> %logdir%log.txt
	del %TEMP%\%filetoscan%
	powershell -Command "Send-MailMessage -To %emailTo% -Subject %emailSubject% -Body %emailMessage% -BodyAsHtml -From %emailFrom% -Attachments %emailAttachment% -Priority High -SmtpServer localhost
	set tries=1
	goto end
	)
cls
set tries=0
echo.
echo The site %website% appears to be up!
echo Thanks for checking!
del %TEMP%\%filetoscan%
echo.
::if the website was down at any point, and then appears to be back up, send this email
IF "%websitewasdown%"=="1" (
	echo.
	time /t >> %logdir%log.txt
	date /t >> %logdir%log.txt
	echo %website% is up! >> %logdir%log.txt
	echo. >> %logdir%log.txt
	powershell -Command "Send-MailMessage -To %emailTo% -Subject %emailSubjectUp% -Body %emailMessageUp% -BodyAsHtml -From %emailFrom% -Attachments %emailAttachment% -Priority High -SmtpServer localhost
	set websitewasdown=0
	)
:end
timeout /t 120
goto start
pause
	