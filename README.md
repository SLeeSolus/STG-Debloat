# STG-Debloat
Debloat scripts for STG.

---
### Enable Scripting
First thing to do before you do anything is to enable the running of scripts, which is disabled by default.
The following command enables running scripts, but only for the window it is ran on. If you close the terminal and open another one, it will need to be ran again.

```PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

### Usage:
Navigate to the root of the STG-Debloat folder and run the command below in PowerShell.
This will remove HP bloatware, uninstall preinstalled O365, and install 32-Bit O365 for Business: 
```PowerShell
.\Start-Debloat.ps1
```

That should be all you need to debloat a new PC from HP. Continue reading below for more info regarding how things work.

---

## Further Information
This repo is a collection of scripts and useful commands to run when debloating a fresh HP PC.
There are two parts to this.
### 1. Remove all HP related bloatware and telemetry.
These PCs come with a bunch of HP crap pre-installed. At best, they do nothing but take up space and resources. At worst, they interfere with SentinelOne or other antivirus, causing false positives due to their telemetry functions.

### 2. Deploy Office - Uninstalling Preinstalled O365 and Installing a Clean Copy
These PCs come pre-installed with O365. This is a problem for two reasons:
- There are multiple versions of O365 and these PCs come with the wrong, often outdated, version. This is called the Click-to-Run (C2R) version.
- Saf-T Gard uses applications that depend on a 32-bit installation of Office. The full explanation is that STG uses an application that uses a 32-bit ODBC driver which in turn requires a 32-bit installation of office.


### Deploy Office
Microsoft provides a tool called Office Deployment Tool, meant to help admins install Office in a quick, standardized way.

You can find the download for it here, should the version in this repo become outdated:
[Download Office Deployment Tool from Official Microsoft Download Center](https://www.microsoft.com/en-us/download/details.aspx?id=49117)

It is also recommended to use the following tool Microsoft provides to generate the config file:
[Office Customization Tool - Microsoft 365 Apps admin center](https://config.office.com/deploymentsettings)

#### How to Deploy
The config included in this repo does two things.
- Uninstalls pre-installed O365
- Installed 32-Bit O365 for Business

You can run it with the following command in PowerShell.
This will run the deployment only and not touch an HP software:
```PowerShell
'.\Office Deployment Tool\DeployOffice.ps1'
```

---
# Misc

## Useful Scripts and Commands

## HP Uninstall Strings
For your convenience, here are the uninstall strings for the two common left over applications that the debloater sometimes seems to miss.

HP Documentation
```
C:\Program Files\HP\Documentation\Doc_Uninstall.cmd
```

HP Connection Optimizer
```PowerShell
"C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe" -runfromtemp -l0x0409  -removeonly
```

### Find an applications uninstall string
Sometimes, the HP Debloat script doesn't work. To uninstall these persistant programs that are left over after the initial debloat script, you will need that program's uninstall string.

Every program installed gives Windows an "uninstall string", which is a command used to uninstall. This is what Windows runs in the background when you manually uninstall a program in Control Panel > Uninstall.

You can retrieve these uninstall strings with the following commands.
There are two commands. One for 32-Bit and another for 64-Bit.

32-Bit - List Programs w/ Uninstall Strings
```PowerShell
'.\Useful Scripts\List-Installed-32bit-Programs.ps1'
```

64-Bit - List Programs w/ Uninstall Strings
```PowerShell
'.\Useful Scripts\List-Installed-64bit-Programs.ps1'
```

#### Running Uninstall Strings Quietly
If you'd like to run the uninstallers silently, you can do so with the following commands which differ depending on the uninstaller that is used.

msiexec, silent
```PowerShell
msiexec.exe /x <product code goes here> /quiet
```

InstallShield, silent
```PowerShell
"C:\path\to\uninstaller\{product code}\setup.exe" -runfromtemp -l0x0409 -removeonly /s
```

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

