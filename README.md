# STG-Debloat
Debloat scripts for STG.

## How to use this stuff


## To-Do
- Create another PowerShell script that starts Debloat.ps1 and DeployOffice.ps1

- Remove HP Bloat
    - ✕ Needs further testing.

- Office Deployment
    - ✓ Uninstall pre-installed Office
    - ✓ Install 32bit Office 

- Installation of Software
    - SX.e
    - ...
    - ...



# Misc

HP Documentation
C:\Program Files\HP\Documentation\Doc_Uninstall.cmd

HP Connection Optimizer
"C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe" -runfromtemp -l0x0409  -removeonly

Find Program and it's uninstall path
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, UninstallString

Execute uninstall string
Start-Process msiexec.exe -ArgumentList "/X{YOUR-PROGRAM-GUID-HERE} /qn" -Wait


1. Get uninstall strings
2. use uninstall strings to uninstall silently.
	2a. For msiexec, use (/quiets runs uninstaller silently):
		msiexec.exe /x <product code goes here> /quiet

	2b. For InstallShield, use (/s runs uninstaller silently):
		"C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe" -runfromtemp -l0x0409  -removeonly /s

