$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName } | 
    Select-Object DisplayName, UninstallString | 
    Sort-Object DisplayName | 
    Format-Table -AutoSize
