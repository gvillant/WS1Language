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

# Create a tag file just so WS1 knows this was installed
if (-not (Test-Path $WorkingDir))
{
    Mkdir $WorkingDir
}
Set-Content -Path "$WorkingDir\WS1Language.ps1.tag" -Value "Installed"
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
	# With WS1 Dropship online, language settings should be applied after the provisioning step because of sysprep resealing. So we will use a scheduled task to apply the xml and reboot the device before the first user logon.  

	$XMLfile = "Language_FR.xml"
	
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