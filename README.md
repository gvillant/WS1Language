# WS1Language
This script is intended to setup Windows devices with *Workspace One Dropship* provisioning  (*Online* or *Offline*)
A script to add additional language(s) and setup the regional settings, including default user and logon screen. 

## ⚙️ Capabilities
- Install language packs. You can embed language pack CAB files (place them into the LPs folder), and each will be automatically installed. (You can download the language pack ISO and additionnal features languages from the FoD ISO from MSDN or VLSC). Typic LPs folder content :
  - *Microsoft-Windows-Client-Language-Pack_x64_fr-fr.cab*
  - *Microsoft-Windows-LanguageFeatures-Basic-fr-fr-Package\~31bf3856ad364e35~amd64\~\~.cab*
  - *Microsoft-Windows-LanguageFeatures-Handwriting-fr-fr-Package\~31bf3856ad364e35~amd64\~\~.cab*
  - *Microsoft-Windows-LanguageFeatures-OCR-fr-fr-Package\~31bf3856ad364e35~amd64\~\~.cab*
  - *Microsoft-Windows-LanguageFeatures-Speech-fr-fr-Package\~31bf3856ad364e35~amd64\~\~.cab*
  - *Microsoft-Windows-LanguageFeatures-TextToSpeech-fr-fr-Package\~31bf3856ad364e35~amd64\~\~.cab*

- Setup the timezone (if a timezone is specified in the Config.xml file)

- The script detects if the environment is Dropship Offline or Online :
  - If Online : apply Language Packs and xml file, then create a scheduled task to silently reboot before first logon. This reboot is required to display the logon UI in the targeted language. 
  - If Offline : apply Language Packs only. 

- Configure language settings. <ins>With Dropship Online</ins>, adding a language pack isn't enough - you have to tell Windows that you want it to be configured for all users. This is done through an XML file fed to INTL.CPL; customize the file as needed. (There is an example file for French language). Check the Microsoft documentation for detailed settings per country or location :  https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/configure-international-settings-in-windows
- Install features on demand (FOD). The needed components will be downloaded from Windows Update automatically and added to the running OS. Check https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod
  - Example : Language.Fonts.PanEuropeanSupplementalFonts\~\~\~\~0.0.1.0
  - Because Dropship Offline has no Internet access, this feature is unavailable.

## 💾 Building
1. Download script package [here](https://github.com/gvillant/WS1Language/archive/refs/heads/main.zip)
2. Add *CABs* files to the *LPs* folder
3. <ins>For Dropship online</ins>, edit *Language.xml* to setup your specific languages values
4. <ins>For Dropship online</ins>, edit *Config.xml* file to update variables to: 
   - Specify the name of your *Language.xml* file, if required,
   - Specify the timezone,
   - Add Features-on-Demand, if required
5. Zip the folder (without "extra" root folder, ie the ps1 file script should be at the higher level) then create a WS1 application with following settings:

Settings | Value
------------ | -------------
Install behavior | Install as device
install cmdline | **powershell.exe -noprofile -executionpolicy bypass -file .\WS1Language.ps1**
uninstall cmdline | **cmd.exe /c del %ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag**
detection method | **%ProgramData%\Airwatch\WS1Language\WS1Language.ps1.tag** (file exist)

