Start-Process -FilePath ".\HPDebloat.ps1" -Wait
Start-Process -FilePath ".\Office Deployment Tool\setup.exe" -ArgumentList "/configure .\Office Deployment Tool\STG-O365-Office-Deployment-Config.xml" -Wait
