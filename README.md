# WS1Language
A script to add additional language(s) and setup the regional settings, including default user and logon screen. 


uninstall : cmd.exe /c del %ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag
detection method (file exist) : %ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag
install cmdline : powershell.exe -noprofile -executionpolicy bypass -file .\WS1Language.ps1
