# WS1Language
A script to add additional language(s) and setup the regional settings, including default user and logon screen. 

## ⚙️ Capabilities
- Install language packs. You can embed language pack CAB files (place them into the LPs folder), and each will be automatically installed. (You can download the language pack ISO and additionnal features languages from the FoD ISO from MSDN or VLSC). Typic LPs folder content :
  - *Microsoft-Windows-LanguageFeatures-Basic-fr-fr-Package~31bf3856ad364e35~amd64\~~.cab*
  - *Microsoft-Windows-LanguageFeatures-Handwriting-fr-fr-Package~31bf3856ad364e35~amd64\~~.cab*
  - *Microsoft-Windows-LanguageFeatures-OCR-fr-fr-Package~31bf3856ad364e35~amd64\~~.cab*
  - *Microsoft-Windows-LanguageFeatures-Speech-fr-fr-Package~31bf3856ad364e35~amd64\~~.cab*
  - *Microsoft-Windows-LanguageFeatures-TextToSpeech-fr-fr-Package~31bf3856ad364e35~amd64\~~.cab*

- Configure language settings. Adding a language pack isn't enough - you have to tell Windows that you want it to be configured for all users. This is done through an XML file fed to INTL.CPL; customize the file as needed. (There is an example file for French language)
- Install features on demand (FOD). The needed components will be downloaded from Windows Update automatically and added to the running OS.Check https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod
  - Example : Language.Fonts.PanEuropeanSupplementalFonts\~~\~~0.0.1.0

## 💾 Building
Zip the folder (without "extra" root folder, ie the ps1 file script should be at the higher level) then create a WS1 application with following settings:
- Install as device
- install cmdline : powershell.exe -noprofile -executionpolicy bypass -file .\WS1Language.ps1
- uninstall : cmd.exe /c del %ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag
- detection method (file exist) : %ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag

