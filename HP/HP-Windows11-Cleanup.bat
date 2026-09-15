@echo off
setlocal EnableExtensions DisableDelayedExpansion

title HP Windows 11 Pro Cleanup

:: ============================================================
:: HP WINDOWS 11 PRO CLEANUP  -  ONE-FILE VERSION
::
:: Usage:
::   HP-Windows11-Cleanup.bat             normal run
::   HP-Windows11-Cleanup.bat -Preview    report only, no changes
:: ============================================================

:: ------------------------------------------------------------
:: Administrator check / self-elevation
:: ------------------------------------------------------------

net session >nul 2>&1

if %errorlevel% neq 0 (
    echo.
    echo ============================================================
    echo   Requesting Administrator privileges...
    echo ============================================================
    echo.

    if "%~1"=="" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    )

    if errorlevel 1 (
        echo.
        echo Elevation was cancelled or failed. This script must run as
        echo Administrator. Right-click the file and choose
        echo "Run as administrator", then try again.
        echo.
        pause
    )

    exit /b
)

:: ------------------------------------------------------------
:: Extract the PowerShell payload to a temp file
:: ------------------------------------------------------------

set "TEMP_PS=%TEMP%\HP-Cleanup-%RANDOM%%RANDOM%.ps1"

echo.
echo Creating temporary cleanup script...
echo.

:: NOTE: -Last 1 is essential. The marker strings also appear on this very
:: line, so Select-String matches twice. Taking the last match gets the real
:: marker instead of an array (the original bug).

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-Content -LiteralPath '%~f0'; $s = ($c | Select-String -SimpleMatch ':POWERSHELL_START:' | Select-Object -Last 1).LineNumber; $e = ($c | Select-String -SimpleMatch ':POWERSHELL_END:' | Select-Object -Last 1).LineNumber; if (-not $s -or -not $e -or $e -le $s) { exit 1 }; $c[$s..($e-2)] | Set-Content -LiteralPath '%TEMP_PS%' -Encoding UTF8"

if not exist "%TEMP_PS%" (
    echo.
    echo ERROR: Could not create temporary PowerShell script.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: Run it
:: ------------------------------------------------------------

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%" %*

set "PS_EXIT=%ERRORLEVEL%"

del /q "%TEMP_PS%" >nul 2>&1

echo.
echo ============================================================
echo   PowerShell process finished.
echo ============================================================
echo.

if not "%PS_EXIT%"=="0" (
    echo PowerShell returned exit code: %PS_EXIT%
    echo.
)

pause
exit /b


:POWERSHELL_START:
# ============================================================
# HP WINDOWS 11 PRO CLEANUP - PowerShell portion
# ============================================================

param(
    [switch]$Preview
)

$ErrorActionPreference = 'Continue'

$TimeStamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDirectory  = Join-Path $env:ProgramData 'HP-Cleanup'
$LogFile       = Join-Path $LogDirectory "HP-Cleanup-$TimeStamp.log"
$InventoryFile = Join-Path $LogDirectory "SoftwareInventory-$TimeStamp.txt"

New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null

Start-Transcript -Path $LogFile -Append | Out-Null

Clear-Host

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '        HP WINDOWS 11 PRO CLEANUP' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if ($Preview) {
    Write-Host ' *** PREVIEW MODE - no changes will be made ***' -ForegroundColor Magenta
    Write-Host ''
}

Write-Host 'Computer: ' -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor Green

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host 'Operating System: ' -NoNewline
Write-Host $OS.Caption -ForegroundColor Green

Write-Host ''
Write-Host 'Log folder:' -ForegroundColor Yellow
Write-Host $LogDirectory
Write-Host ''


# ============================================================
# WINDOWS VERSION CHECK
# ============================================================

if ($OS.Caption -notlike '*Windows 11*') {

    Write-Host ''
    Write-Host 'WARNING: This does not appear to be Windows 11.' -ForegroundColor Red
    Write-Host ''

    if ((Read-Host 'Continue anyway? (Y/N)') -notmatch '^[Yy]') {
        Write-Host ''
        Write-Host 'Cancelled.'
        Stop-Transcript | Out-Null
        Read-Host 'Press ENTER to close'
        exit 1
    }
}


# ============================================================
# TARGET LISTS
# ============================================================

# Classic installers, matched against registry DisplayName
$TraditionalTargets = @(
    '*McAfee*'
    '*Norton*'
    '*Dropbox*'
    '*ExpressVPN*'
    '*HP Documentation*'
    '*HP JumpStart*'
    '*HP Welcome*'
    '*HP QuickDrop*'
    '*HP Sure Sense*'
    '*Booking.com*'
)

# Store apps. ONE list used for both installed and provisioned removal,
# so the two can never drift apart. Wildcards allowed.
$AppXTargets = @(
    # Microsoft consumer
    'Microsoft.549981C3F5F10*'          # Cortana
    'Microsoft.MicrosoftSolitaireCollection*'
    'Microsoft.XboxApp*'
    'Microsoft.XboxGamingOverlay*'
    'Microsoft.XboxGameOverlay*'
    'Microsoft.Xbox.TCUI*'
    'Microsoft.XboxSpeechToTextOverlay*'
    'Microsoft.GamingApp*'
    'Microsoft.BingNews*'
    'Microsoft.BingWeather*'
    'Microsoft.BingSearch*'
    'Microsoft.MixedReality.Portal*'
    'Microsoft.People*'
    'Microsoft.ZuneMusic*'              # Media Player / Groove
    'Microsoft.ZuneVideo*'
    'Microsoft.WindowsMaps*'
    'Microsoft.GetHelp*'
    'Microsoft.Getstarted*'             # Tips
    'Microsoft.MicrosoftOfficeHub*'
    'Microsoft.Todos*'
    'Microsoft.WindowsFeedbackHub*'
    'Microsoft.SkypeApp*'
    'Microsoft.OutlookForWindows*'
    'Microsoft.WindowsCommunicationsApps*' # legacy Mail and Calendar
    'MicrosoftTeams*'                   # personal Teams
    'MSTeams*'
    'Clipchamp.Clipchamp*'
    'MicrosoftCorporationII.QuickAssist*'
    'Microsoft.WindowsAlarms*'
    'Microsoft.WindowsSoundRecorder*'
    'Microsoft.YourPhone*'               # Phone Link
    'Microsoft.PowerAutomateDesktop*'
    'MicrosoftWindows.Client.WebExperience*' # taskbar Widgets panel
    'Microsoft.Copilot*'                 # standalone Copilot app (see note below)

    # HP store apps. AD2F1837 is HP's publisher prefix - these are AppX,
    # NOT registry entries, which is why the old '*HP QuickDrop*' pattern
    # never matched anything.
    'AD2F1837.HPQuickDrop*'
    'AD2F1837.HPPrivacySettings*'
    'AD2F1837.myHP*'
    'AD2F1837.HPDesktopSupportUtilities*'
    'AD2F1837.HPSystemInformation*'
    'AD2F1837.HPWelcome*'
)

# Packages Windows routinely refuses to uninstall. Failures on these are
# expected and get a softer message instead of red text.
$KnownStubborn = @(
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxGameOverlay'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.549981C3F5F10'
)

# Vendors whose registry uninstaller does not fully remove them.
$NeedsVendorTool = @{
    'McAfee' = 'McAfee Consumer Product Removal tool (MCPR)'
    'Norton' = 'Norton Remove and Reinstall tool'
}


# ============================================================
# [1] RESTORE POINT
# ============================================================

Write-Host ''
Write-Host '[1] Creating System Restore Point...' -ForegroundColor Yellow
Write-Host ''

if ($Preview) {
    Write-Host '  Skipped (preview mode).' -ForegroundColor DarkGray
}
else {
    $SrKey        = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $OrigFreq     = $null
    $FreqExisted  = $false

    try {
        # Windows only allows one restore point per 24h by default. Temporarily
        # lift that so a second run the same day still gets a rollback point.
        if (Test-Path $SrKey) {
            $Prop = Get-ItemProperty -Path $SrKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
            if ($null -ne $Prop) {
                $OrigFreq    = $Prop.SystemRestorePointCreationFrequency
                $FreqExisted = $true
            }
        }
        else {
            New-Item -Path $SrKey -Force | Out-Null
        }

        Set-ItemProperty -Path $SrKey -Name 'SystemRestorePointCreationFrequency' -Type DWord -Value 0 -ErrorAction SilentlyContinue

        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue

        Checkpoint-Computer -Description 'Before HP Windows Cleanup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop

        Write-Host '  Restore point created.' -ForegroundColor Green
    }
    catch {
        Write-Host '  Could not create restore point.' -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
        Write-Host '  Usually means System Restore is disabled by policy.' -ForegroundColor Yellow
        Write-Host ''

        if ((Read-Host '  Continue without a restore point? (Y/N)') -notmatch '^[Yy]') {
            Stop-Transcript | Out-Null
            exit 1
        }
    }
    finally {
        if ($FreqExisted) {
            Set-ItemProperty -Path $SrKey -Name 'SystemRestorePointCreationFrequency' -Type DWord -Value $OrigFreq -ErrorAction SilentlyContinue
        }
        else {
            Remove-ItemProperty -Path $SrKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
        }
    }
}


# ============================================================
# [2] SOFTWARE INVENTORY
# ============================================================

Write-Host ''
Write-Host '[2] Creating software inventory...' -ForegroundColor Yellow
Write-Host ''

try {
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object Name, Version, Publisher |
        Out-File -FilePath $InventoryFile -Encoding UTF8

    Write-Host '  Inventory saved:' -ForegroundColor Green
    Write-Host "  $InventoryFile"
}
catch {
    Write-Host '  Could not create AppX inventory.' -ForegroundColor Yellow
}


# ============================================================
# [3] FIND TRADITIONAL SOFTWARE
# ============================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' SOFTWARE FOUND FOR POSSIBLE REMOVAL' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# The original only checked HKCU, which - when elevated - is the ADMIN's hive,
# not the logged-in user's. Per-user installs like Dropbox were invisible.
# Walk every loaded user hive under HKEY_USERS instead.
if (-not (Get-PSDrive -Name 'HKU' -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name 'HKU' -PSProvider Registry -Root 'HKEY_USERS' -Scope Script -ErrorAction SilentlyContinue | Out-Null
}

$UserHives = Get-ChildItem -Path 'HKU:\' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^S-1-5-21-[\d\-]+$' }

foreach ($Hive in $UserHives) {
    $RegistryPaths += "HKU:\$($Hive.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $RegistryPaths += "HKU:\$($Hive.PSChildName)\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
}

$AllInstalled = @()

foreach ($Path in $RegistryPaths) {
    $AllInstalled += Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
}

$AllInstalled = $AllInstalled |
    Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
    Sort-Object DisplayName -Unique

$MatchedTraditional = @()

foreach ($Pattern in $TraditionalTargets) {

    # NOTE: $Hits, not $Matches. $Matches is a reserved automatic variable
    # populated by -match; reusing it as scratch space is asking for trouble.
    $Hits = $AllInstalled | Where-Object { $_.DisplayName -like $Pattern }

    foreach ($App in $Hits) {
        if ($MatchedTraditional.DisplayName -notcontains $App.DisplayName) {
            $MatchedTraditional += $App
            Write-Host "  REMOVE: $($App.DisplayName)" -ForegroundColor Red
        }
    }
}

if ($MatchedTraditional.Count -eq 0) {
    Write-Host '  No targeted traditional software found.' -ForegroundColor DarkGray
}


# ============================================================
# [4] FIND APPX
# ============================================================

Write-Host ''
Write-Host 'Windows / OEM store applications:' -ForegroundColor Yellow

$FoundAppX     = @()
$InstalledAppX = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue

foreach ($Target in $AppXTargets) {

    $Hits = $InstalledAppX | Where-Object { $_.Name -like $Target }

    foreach ($Package in $Hits) {
        if ($FoundAppX.PackageFullName -notcontains $Package.PackageFullName) {
            $FoundAppX += $Package
            Write-Host "  REMOVE: $($Package.Name)" -ForegroundColor Red
        }
    }
}

if ($FoundAppX.Count -eq 0) {
    Write-Host '  No targeted store applications found.' -ForegroundColor DarkGray
}

$ProvisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
$FoundProvisioned    = @()

foreach ($Target in $AppXTargets) {

    $Hits = $ProvisionedPackages | Where-Object { $_.DisplayName -like $Target }

    foreach ($Package in $Hits) {
        if ($FoundProvisioned.PackageName -notcontains $Package.PackageName) {
            $FoundProvisioned += $Package
        }
    }
}

if ($FoundProvisioned.Count -gt 0) {
    Write-Host ''
    Write-Host "  Plus $($FoundProvisioned.Count) provisioned package(s) - these are the" -ForegroundColor Red
    Write-Host '  copies that reinstall for every new user profile.' -ForegroundColor Red
}


# ============================================================
# [5] WHAT IS BEING KEPT
# ============================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' IMPORTANT SOFTWARE BEING KEPT' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Not targeted:' -ForegroundColor Green
Write-Host ''
Write-Host '  HP Support Assistant          HP Wolf Security'
Write-Host '  HP PC Hardware Diagnostics    HP hardware drivers'
Write-Host '  HP Image Assistant            HP firmware utilities'
Write-Host '  HP System Event Utility       Windows Security'
Write-Host '  HP Hotkey Support             Microsoft Edge / Store'
Write-Host '  HP Connection Optimizer       Windows Update'
Write-Host '  Calculator / Photos / Paint   Snipping Tool / Sticky Notes'
Write-Host '  Notepad / Terminal            Microsoft Store'
Write-Host ''

# Heads-up on collateral damage people forget about
$GamingHit = $FoundAppX | Where-Object { $_.Name -like '*Xbox*' -or $_.Name -like '*GamingApp*' }

if ($GamingHit) {
    Write-Host 'NOTE: Removing the Xbox components also disables Game Bar' -ForegroundColor Yellow
    Write-Host '      (Win+G screen recording) and Game Pass. Fine on a fleet' -ForegroundColor Yellow
    Write-Host '      machine, surprising on a personal one.' -ForegroundColor Yellow
    Write-Host ''
}

$CopilotHit = $FoundAppX | Where-Object { $_.Name -like '*Copilot*' }

if ($CopilotHit) {
    Write-Host 'NOTE: Removing the Copilot app package stops it from opening' -ForegroundColor Yellow
    Write-Host '      as a standalone app, but on newer Windows 11 builds the' -ForegroundColor Yellow
    Write-Host '      taskbar icon/button is baked into the shell and needs a' -ForegroundColor Yellow
    Write-Host '      separate registry policy to fully hide - ask if you want' -ForegroundColor Yellow
    Write-Host '      that added too.' -ForegroundColor Yellow
    Write-Host ''
}


# ============================================================
# [6] CONFIRMATION
# ============================================================

if ($Preview) {
    Write-Host '============================================================' -ForegroundColor Magenta
    Write-Host ' PREVIEW COMPLETE - nothing was changed' -ForegroundColor Magenta
    Write-Host '============================================================' -ForegroundColor Magenta
    Write-Host ''
    Write-Host "Report: $LogFile"
    Write-Host ''
    Stop-Transcript | Out-Null
    Read-Host 'Press ENTER to close'
    exit 0
}

if ($MatchedTraditional.Count -eq 0 -and $FoundAppX.Count -eq 0 -and $FoundProvisioned.Count -eq 0) {
    Write-Host 'Nothing to remove. This machine is already clean.' -ForegroundColor Green
    Write-Host ''
    Stop-Transcript | Out-Null
    Read-Host 'Press ENTER to close'
    exit 0
}

Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' CONFIRMATION REQUIRED' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'The items marked REMOVE above will be uninstalled.' -ForegroundColor Yellow
Write-Host ''

if ((Read-Host 'Proceed with cleanup? (Y/N)') -notmatch '^[Yy]') {
    Write-Host ''
    Write-Host 'Cleanup cancelled.' -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host 'Press ENTER to close'
    exit 0
}


# ============================================================
# [7] UNINSTALL TRADITIONAL SOFTWARE
# ============================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' REMOVING TRADITIONAL SOFTWARE' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

$SuccessCount = 0
$FailCount    = 0

foreach ($App in $MatchedTraditional) {

    Write-Host ''
    Write-Host "Uninstalling: $($App.DisplayName)" -ForegroundColor Yellow

    $Exe       = $null
    $Arguments = ''

    # Prefer a vendor-supplied silent string when one exists.
    if ($App.QuietUninstallString) {
        $Raw = $App.QuietUninstallString.Trim()
    }
    elseif ($App.UninstallString) {
        $Raw = $App.UninstallString.Trim()
    }
    else {
        Write-Host '  No uninstall command found.' -ForegroundColor Red
        $FailCount++
        continue
    }

    try {
        # MSI products usually register "MsiExec.exe /I{GUID}" - note /I, which
        # opens the interactive maintenance dialog and hangs on -Wait forever.
        # Rewrite it to a real silent uninstall.
        if ($Raw -match '(?i)msiexec') {

            $GuidMatch = [regex]::Match($Raw, '\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}')

            if ($GuidMatch.Success) {
                $Exe       = 'msiexec.exe'
                $Arguments = "/x $($GuidMatch.Value) /qn /norestart"
            }
        }

        # Not an MSI - split "path" from arguments.
        if (-not $Exe) {

            $Parsed = [regex]::Match($Raw, '^\s*"([^"]+)"\s*(.*)$')

            if ($Parsed.Success) {
                $Exe       = $Parsed.Groups[1].Value
                $Arguments = $Parsed.Groups[2].Value
            }
            else {
                $Parts     = $Raw -split '\s+', 2
                $Exe       = $Parts[0]
                $Arguments = if ($Parts.Count -gt 1) { $Parts[1] } else { '' }
            }

            # Nudge common installer engines toward silent mode.
            if ($Exe -match '(?i)(uninst|unins000|setup)') {
                if ($Arguments -notmatch '(?i)(/S|/silent|/quiet|/VERYSILENT)') {
                    $Arguments = ($Arguments + ' /S').Trim()
                }
            }
        }

        Write-Host "  Running: $Exe $Arguments" -ForegroundColor DarkGray

        # Splat, because -ArgumentList rejects an empty string outright.
        # That single detail broke every argument-less uninstaller before.
        $SP = @{
            FilePath    = $Exe
            Wait        = $true
            PassThru    = $true
            ErrorAction = 'Stop'
        }

        if ($Arguments) { $SP.ArgumentList = $Arguments }

        $Proc = Start-Process @SP

        # 0 = success, 3010 = success but reboot required, 1605 = already gone
        if ($Proc.ExitCode -in @(0, 3010, 1605)) {
            Write-Host "  Completed (exit $($Proc.ExitCode))." -ForegroundColor Green
            $SuccessCount++
        }
        else {
            Write-Host "  Uninstaller returned exit code $($Proc.ExitCode)." -ForegroundColor Red
            $FailCount++
        }
    }
    catch {
        Write-Host '  FAILED to launch uninstaller.' -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        $FailCount++
    }

    foreach ($Vendor in $NeedsVendorTool.Keys) {
        if ($App.DisplayName -like "*$Vendor*") {
            Write-Host "  NOTE: $Vendor leaves drivers and services behind." -ForegroundColor Yellow
            Write-Host "        Finish with the $($NeedsVendorTool[$Vendor])." -ForegroundColor Yellow
        }
    }
}


# ============================================================
# [8] REMOVE INSTALLED APPX
# ============================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' REMOVING STORE APPLICATIONS' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

foreach ($Package in $FoundAppX) {

    Write-Host ''
    Write-Host "Removing: $($Package.Name)" -ForegroundColor Yellow

    try {
        Remove-AppxPackage -Package $Package.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host '  Removed.' -ForegroundColor Green
        $SuccessCount++
    }
    catch {
        $IsStubborn = $false
        foreach ($Stub in $KnownStubborn) {
            if ($Package.Name -like "$Stub*") { $IsStubborn = $true }
        }

        if ($IsStubborn) {
            Write-Host '  Skipped - Windows blocks removal of this component.' -ForegroundColor DarkGray
        }
        else {
            Write-Host '  Could not remove package.' -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            $FailCount++
        }
    }
}


# ============================================================
# [9] REMOVE PROVISIONED APPX
# ============================================================

Write-Host ''
Write-Host 'Removing provisioned packages (stops reinstall on new profiles)...' -ForegroundColor Yellow
Write-Host ''

foreach ($Package in $FoundProvisioned) {

    Write-Host "Removing provisioned: $($Package.DisplayName)" -ForegroundColor Yellow

    try {
        Remove-AppxProvisionedPackage -Online -PackageName $Package.PackageName -ErrorAction Stop | Out-Null
        Write-Host '  Removed.' -ForegroundColor Green
        $SuccessCount++
    }
    catch {
        Write-Host '  Could not remove provisioned package.' -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

if ($FoundProvisioned.Count -eq 0) {
    Write-Host '  None found.' -ForegroundColor DarkGray
}


# ============================================================
# [10] CONSUMER SUGGESTIONS POLICY
# ============================================================

Write-Host ''
Write-Host 'Disabling Windows consumer suggestions...' -ForegroundColor Yellow

try {
    $CloudContentPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

    if (-not (Test-Path $CloudContentPath)) {
        New-Item -Path $CloudContentPath -Force | Out-Null
    }

    Set-ItemProperty -Path $CloudContentPath -Name 'DisableWindowsConsumerFeatures' -Type DWord -Value 1
    Set-ItemProperty -Path $CloudContentPath -Name 'DisableCloudOptimizedContent'   -Type DWord -Value 1

    Write-Host '  Completed.' -ForegroundColor Green
}
catch {
    Write-Host '  Could not change consumer suggestion settings.' -ForegroundColor Yellow
}


# ============================================================
# FINISHED
# ============================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' CLEANUP COMPLETE' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Succeeded: $SuccessCount" -ForegroundColor Green
Write-Host "  Failed:    $FailCount" -ForegroundColor $(if ($FailCount) { 'Red' } else { 'Green' })
Write-Host ''
Write-Host 'Log file:' -ForegroundColor Yellow
Write-Host "  $LogFile"
Write-Host ''
Write-Host 'Inventory:' -ForegroundColor Yellow
Write-Host "  $InventoryFile"
Write-Host ''
Write-Host 'A restart is recommended.' -ForegroundColor Yellow
Write-Host ''

Stop-Transcript | Out-Null

if ((Read-Host 'Restart computer now? (Y/N)') -match '^[Yy]') {

    # Clean up our own temp file first - the batch wrapper's del never runs
    # if we reboot out from under it.
    if ($PSCommandPath) {
        Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
    }

    Restart-Computer -Force
}
:POWERSHELL_END:
