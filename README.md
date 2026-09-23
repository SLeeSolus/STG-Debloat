# STG-Debloat
Debloat scripts for STG.

## How to use this repo
This repo is a collection of scripts and useful commands to run when debloating a fresh HP PC.
There are two parts to this.
### Remove all HP related bloatware and telemetry.
These PCs come with a bunch of HP crap pre-installed. At best, they do nothing but take up space and resources. At worst, they interfere with SentinelOne or other antivirus, causing false positives due to their telemetry functions.

### Deploy Office - Uninstalling Preinstalled O365 and Installing a Clean Copy
These PCs come pre-installed with O365. This is a problem for two reasons:
- There are multiple versions of O365 and these PCs come with the wrong, often outdated, version. This is called the Click-to-Run (C2R) version.
- Saf-T Gard uses applications that depend on a 32-bit installation of Office. The full explanation is that STG uses an application that uses a 32-bit ODBC driver which in turn requires a 32-bit installation of office.




### Enable Scripting
First thing to do before you do anything is to enable the running of scripts, which is disabled by default.
The following command enables running scripts, but only for the window it is ran on. If you close the terminal and open another one, it will need to be ran again.

```PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

### Remove HP Bloatware




### Deploy Office
Microsoft provides a tool called Office Deployment Tool, meant to help admins install Office in a quick, standardized way.

You can find the download for it here, should the version in this repo become outdated:
[Download Office Deployment Tool from Official Microsoft Download Center](https://www.microsoft.com/en-us/download/details.aspx?id=49117)

It is also recommended to use the following tool Microsoft provides to generate the config file.
[Office Customization Tool - Microsoft 365 Apps admin center](https://config.office.com/deploymentsettings)

#### How to Deploy Office
The config included in this repo does two things.
- Uninstalls pre-installed O365
- Installed 32-Bit O365 for Business

You can run it with the following command in PowerShell:
```PowerShell
'.\Office Deployment Tool\DeployOffice.ps1'
```


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

## Generally Useful Commands
### Start-Transcript
Start-Transcript lets you start and stop logging. This is useful for troubleshooting later on, or just to have to audit in the future.

Once you are done with whatever you are doing, you can stop it with Stop-Transcript.

You can also specify the location of the output file with -Path.

Usage Example: Starts a transcript and outputs to a file named Example.txt in the same folder the command is ran in.
```PowerShell
 Start-Transcript -Path ./Example.txt
```

More usage info can be found in the documentation:
[Start-Transcript (Microsoft.PowerShell.Host) - PowerShell | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript?view=powershell-7.6)


### Uninstall Related
HP Documentation
```
C:\Program Files\HP\Documentation\Doc_Uninstall.cmd
```

HP Connection Optimizer
```PowerShell
"C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe" -runfromtemp -l0x0409  -removeonly
```

Find Program and it's uninstall path
```PowerShell
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, UninstallString
```


Execute uninstall string
```PowerShell
Start-Process msiexec.exe -ArgumentList "/X{YOUR-PROGRAM-GUID-HERE} /qn" -Wait
```


1. Get uninstall strings
2. use uninstall strings to uninstall silently.
	2a. For msiexec, use (/quiets runs uninstaller silently):
		msiexec.exe /x <product code goes here> /quiet

	2b. For InstallShield, use (/s runs uninstaller silently):
		"C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe" -runfromtemp -l0x0409  -removeonly /s

