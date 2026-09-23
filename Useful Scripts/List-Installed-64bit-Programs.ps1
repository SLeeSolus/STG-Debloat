Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName -ne $null } | 
    Select-Object DisplayName, UninstallString | 
    Sort-Object DisplayName
