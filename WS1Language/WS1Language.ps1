<#
.VERSION 1.3

.RELEASENOTES
Version 1.0 (25/05/2021): Initial version
Version 1.1 (25/05/2021): Dropship offline support
Version 1.2 (08/11/2021): Timezone support
Version 1.3 (17/11/2021): Improved current username detection

.SYNOPSIS
This script is intended to setup Windows devices with Workspace One Dropship provisioning (Online or Offline) 
The script install additional language(s) files (.cab), setup the regional settings and timezone , including default user and logon screen.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
.DESCRIPTION
The script detects if the environment is Dropship Offline or Online :
If Online : apply Language Packs and Language.xml file and timezone, then create a scheduled task to silently reboot before first logon. This reboot is required to display the logon UI in the targeted language.
If Offline : apply Language Packs and timezone only.
Setup the Config.xml file to specify the timezone and the Language.xml file. 

.EXAMPLE
Should be packaged in WS1 with the following cmdline : 	powershell.exe -noprofile -executionpolicy bypass -file .\WS1Language.ps1
#>

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

$WorkingDir = "$($env:ProgramData)\Airwatch\WS1Language"
$details = Get-ComputerInfo

# PREP: Load the Config.xml
$installFolder = "$PSScriptRoot\"
Write-Host "Install folder: $installFolder"
Write-Host "Loading configuration: $($installFolder)Config.xml"
[Xml]$config = Get-Content "$($installFolder)Config.xml"

# Create a tag file just so WS1 knows this was installed
if (-not (Test-Path $WorkingDir))
{
    Mkdir $WorkingDir
}
Set-Content -Path "$WorkingDir\WS1Language.ps1.tag" -Value "Installed"

if (($details.CsUserName -match "Administrator") -or ($env:Username -match "Administrator")) {
	# Dropship Offline environment detected. Apply CABs files only !
	# Start logging
	Start-Transcript "$WorkingDir\WS1Language_Provisioning.log"
		
	Write-host "Logged-on user is $($details.CsUserName), Dropship OFFLINE environment detected. Apply language packs only"

	$installFolder = "$PSScriptRoot\"
	Write-Host "Install folder: $installFolder"

	# Add language packs
	Get-ChildItem "$($installFolder)LPs" -Filter *.cab | ForEach-Object {
		Write-Host "Adding language pack: $($_.FullName)"
		Add-WindowsPackage -Online -NoRestart -PackagePath $_.FullName
	}

	# Set time zone (if specified)
	if ($config.Config.TimeZone) {
		Write-Host "Setting time zone: $($config.Config.TimeZone)"
		Set-Timezone -Id $config.Config.TimeZone
	}
	else {
		# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
		Write-Host "Enable location services so the time zone will be set automatically"
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
		Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
	}

	Stop-Transcript
	exit
}

if ($details.CsUserName -match "workspaceone")
{
	# Dropship Provisioning environment detected. script part. 1
	# Start logging
	Start-Transcript "$WorkingDir\WS1Language_Provisioning.log"
		
	Write-host "Logged-on user is $($details.CsUserName), Dropship Provisioning environment detected. Apply language packs and create scheduled task"

	$installFolder = "$PSScriptRoot\"
	Write-Host "Install folder: $installFolder"

	# Add language packs
	Get-ChildItem "$($installFolder)LPs" -Filter *.cab | ForEach-Object {
		Write-Host "Adding language pack: $($_.FullName)"
		Add-WindowsPackage -Online -NoRestart -PackagePath $_.FullName
	}

	# Set language and regional settings based on Language.xml file
	# With WS1 Dropship online, language settings should be applied after the provisioning step because of cleanup scripts. So we will use a scheduled task to apply the xml and reboot the device before the first user logon.  

	$XMLfile = $config.Config.Language
	
	Write-Host "Configuring language using: $XMLfile"
	Write-Host "Command Line : $env:SystemRoot\System32\control.exe intl.cpl,,/f:$($installFolder)$XMLfile)"
	& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$($installFolder)$XMLfile`""

	# Check to see if already scheduled
	$existingTask = Get-ScheduledTask -TaskName "WS1Language" -ErrorAction SilentlyContinue
	if ($null -ne $existingTask)
	{
		Write-Host "Scheduled task already exists."
	}
	else { 
		# Copy WS1Language script and xml to $WorkingDir
		Copy-Item "$PSScriptRoot\WS1Language.ps1" "$WorkingDir\WS1Language.ps1" -Force
		Copy-Item "$PSScriptRoot\$XMLfile" "$WorkingDir\Language.xml" -Force

		# Create the scheduled task action
		$action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $WorkingDir\WS1Language.ps1"

		# Create the scheduled task trigger
		$triggers = @()
		$triggers += New-ScheduledTaskTrigger -AtStartup
		
		# Register the scheduled task
		Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName "WS1Language" -Description "WS1Language" -Force
		Write-Host "Scheduled task created."
	}


	# Add language related features on demand ONLINE (fonts, others requirements ...). Check here: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod
	$currentWU = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction Ignore).UseWuServer
	if ($currentWU -eq 1)
	{
		Write-Host "Turning off WSUS"
		Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 0
		Restart-Service wuauserv
	}

		Add-WindowsCapability -Online -Name "Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0"

	if ($currentWU -eq 1)
	{
		Write-Host "Turning on WSUS"
		Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 1
		Restart-Service wuauserv
	}
	
	# Set time zone (if specified)
	if ($config.Config.TimeZone) {
		Write-Host "Setting time zone: $($config.Config.TimeZone)"
		Set-Timezone -Id $config.Config.TimeZone
	}
	else {
		# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
		Write-Host "Enable location services so the time zone will be set automatically"
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
		Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
	}

	Stop-Transcript
}
else {
	# Customer environment detected. Script part. 2
	# Start logging
	Start-Transcript "$WorkingDir\WS1Language_Customer.log"
	
	Write-host "Logged-on user is $($details.CsUserName), Customer environment detected. Apply language and regional settings, remove scheduled task then reboot"
	Write-Host "Configuring language using: $WorkingDir\Language.xml"
	Write-Host "Command Line : $env:SystemRoot\System32\control.exe intl.cpl,,/f:$WorkingDir\Language.xml"
	#& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$WorkingDir\Language.xml`""
	Start-Process -Filepath "$env:SystemRoot\System32\control.exe" -ArgumentList "intl.cpl,,/f:`"$WorkingDir\Language.xml`"" -Wait
	
	# Remove the scheduled task
	Disable-ScheduledTask -TaskName "WS1Language" -ErrorAction Ignore
	Unregister-ScheduledTask -TaskName "WS1Language" -Confirm:$false -ErrorAction Ignore
	Write-Host "Scheduled task unregistered."
	
	#Initiating the restart
	Write-Host "Initiating a restart Now !"
	Stop-Transcript
	& shutdown.exe /r /t 0 /f /c "WS1Language initiated restart"
	
}
