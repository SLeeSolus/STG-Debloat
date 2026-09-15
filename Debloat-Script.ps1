<#
.SYNOPSIS
   Removes HP bloatware and related components, with optional removal of Microsoft 365 and OneNote installations (Click-to-Run, AppX, provisioned).
.DESCRIPTION
   This script automates the removal of HP preinstalled software including:
   - AppX and provisioned AppX packages
   - Installed Win32 programs
   - HP background services
   Optionally, it also detects and removes:
   - Microsoft 365 Click-to-Run installations using the Office Deployment Tool (ODT)
   - Residual Office and OneNote components registered in the system registry
   - OneNoteFreeRetail components in multiple languages (e.g., de-de, en-gb, fr-fr)
   The script includes a DryRun mode to preview actions before executing them, and provides granular parameter control for tailoring what gets removed.
   Usage Examples:
   ---------------
   # Dry run: Preview actions without making any changes
   .\Debloat-HPv2.ps1 -DryRun
   # Full removal while preserving HotKeyServiceUWP and Microsoft 365 apps:
   .\Debloat-HPv2.ps1
   # Full removal including the HotKeyServiceUWP service, and removing Microsoft 365 apps and OneNote variants:
   .\Debloat-HPv2.ps1 -RemoveHotKeyService:$true -RemoveM365Apps:$true
   # Customize removal: Only remove installed programs and skip AppX, provisioned package, and Microsoft 365 apps removal:
   .\Debloat-HPv2.ps1 -RemoveAppxPackages:$false -RemoveProvisionedPackages:$false -RemoveInstalledPrograms:$true -RemoveM365Apps:$false
   WARNING: Test thoroughly before deployment. Some services (e.g. HotKeyServiceUWP) may be required
   for HP-specific hardware functions (like special keys). Adjust parameters as needed for your environment.
.PARAMETER RemoveHotKeyService
   If set to $true, the HotKeyServiceUWP service will be stopped and disabled.
   (Default: $false – service is preserved.)
.PARAMETER RemoveOtherServices
   If set to $true, other HP-related services will be stopped and disabled.
   (Default: $true)
.PARAMETER RemoveAppxPackages
   If set to $true, installed HP AppX packages will be removed.
   (Default: $true)
.PARAMETER RemoveProvisionedPackages
   If set to $true, provisioned HP AppX packages will be removed.
   (Default: $true)
.PARAMETER RemoveInstalledPrograms
   If set to $true, installed HP programs will be uninstalled.
   (Default: $true)
.PARAMETER RemoveM365Apps
   If set to $true, removes Microsoft 365 Click-to-Run installations, OneNoteFreeRetail components (multi-language),
   Microsoft OneDrive, and residual Office apps using registry-based detection and ODT fallback.
   (Default: $false)
.PARAMETER DryRun
   If present, the script will only log the actions without making any changes.
.NOTES
   Contributors: mark05e, francishagyard2, erottier, JoachimBerghmans, sikkepitje, Ithendyr,
   Netweezurd, dunxd, ll4mat, IntuneAdmin017, foeyonghai
   Additional credits:
   https://www.reddit.com/r/sysadmin/comments/jjtpnp/script_to_silently_uninstall_builtin_office_365/,
   https://community.spiceworks.com/t/script-to-silent-uninstall-microsoft-office-standard-2013-from-windows-machine-bypass-admin-credential/1057204
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [bool]$RemoveHotKeyService = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$RemoveOtherServices = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$RemoveAppxPackages = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$RemoveProvisionedPackages = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$RemoveInstalledPrograms = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$RemoveM365Apps = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# ---------------------------
# Configuration – Lists of items to remove
# ---------------------------
$UninstallPackages = @(
    "AD2F1837.HPJumpStarts",
    "AD2F1837.HPPCHardwareDiagnosticsWindows",
    "AD2F1837.HPPowerManager",
    "AD2F1837.HPPrivacySettings",
    "AD2F1837.HPSupportAssistant",
    "AD2F1837.HPSureShieldAI",
    "AD2F1837.HPSystemInformation",
    "AD2F1837.HPQuickDrop",
    "AD2F1837.HPWorkWell",
    "AD2F1837.myHP",
    "AD2F1837.HPDesktopSupportUtilities",
    "AD2F1837.HPQuickTouch",
    "AD2F1837.HPEasyClean",
    "AD2F1837.HPSystemInformation"
)

$UninstallPrograms = @(
    "HP Client Security Manager",
    "HP Connection Optimizer",
    "HP Documentation",
    "HP MAC Address Manager",
    "HP Notifications",
    "HP Security Update Service",
    "HP System Default Settings",
    "HP Sure Click",
    "HP Sure Click Security Browser",
    "HP Sure Run",
    "HP Sure Recover",
    "HP Sure Sense",
    "HP Sure Sense Installer",
    "HP Support Assistant",
    "HP Wolf Security",
    "HP Wolf Security - Console",
    "HP Wolf Security Application Support for Sure Sense",
    "HP Wolf Security Application Support for Windows"
)

$UninstallM365Apps = @(
    "Microsoft.OneNote*",
    "Microsoft.365Apps*",
    "Microsoft.OneDrive*",
    "Microsoft.OneDriveSync",
    "RealtekSemiconductorCorp.HPAudioControl",
    "Microsoft.BingWeather",
    "Microsoft.GamingApp",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider"
)

$OtherServices = @(
    "HPAppHelperCap",
    "HP Comm Recover",
    "HPDiagsCap",
    "LanWlanWwanSwitchgingServiceUWP",  # Verify if needed in your environment
    "HPNetworkCap",
    "HPSysInfoCap",
    "HP TechPulse Core"
)

$HPidentifier = "AD2F1837"

# ---------------------------
# Helper Function: Execute-Command (DryRun aware)
# ---------------------------
function Execute-Command {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Command,
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    if ($DryRun) {
        Write-Host "DRY RUN: Would execute -> $Description"
    } else {
        try {
            & $Command
        } catch {
            Write-Warning "Failed to execute: $Description - $_"
        }
    }
}

# ---------------------------
# Inventory: Identify installed packages, provisioned packages, and programs
# ---------------------------
if ($RemoveAppxPackages) {
    Write-Host "Collecting installed HP AppX packages..."
    $InstalledPackages = Get-AppxPackage -AllUsers | Where-Object {
        ($UninstallPackages -contains $_.Name) -or ($_.Name -match "^$HPidentifier")
    }
}

if ($RemoveProvisionedPackages) {
    Write-Host "Collecting provisioned HP AppX packages..."
    $ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object {
        ($UninstallPackages -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier")
    }
}

if ($RemoveInstalledPrograms) {
    Write-Host "Collecting installed HP programs..."
    $InstalledPrograms = Get-Package | Where-Object { $UninstallPrograms -contains $_.Name }
}

# ---------------------------
# Functions to stop/disable services
# ---------------------------
function StopDisableService {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq 'Running') {
            Execute-Command -Command { Stop-Service -Name $Name -Force -Confirm:$false -ErrorAction Stop } -Description "Stop service '$Name'"
        }
        Execute-Command -Command { Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop } -Description "Disable service '$Name'"
    } else {
        Write-Verbose "Service '$Name' not found."
    }
}

# ---------------------------
# Remove Services: Optional removal of HotKeyServiceUWP and others
# ---------------------------
if ($RemoveHotKeyService) {
    Write-Host "Removing HotKeyServiceUWP..."
    StopDisableService -Name "HotKeyServiceUWP"
} else {
    Write-Host "Skipping removal of HotKeyServiceUWP (preserved)."
}

if ($RemoveOtherServices) {
    Write-Host "Removing other HP-related services..."
    foreach ($s in $OtherServices) {
        StopDisableService -Name $s
    }
} else {
    Write-Host "Skipping removal of other HP-related services."
}

# ---------------------------
# Step 1: Remove Provisioned AppX Packages
# ---------------------------
function Remove-ProvisionedPackages {
    foreach ($ProvPackage in $ProvisionedPackages) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would remove provisioned package: [$($ProvPackage.DisplayName)]"
        } else {
            try {
                Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
                Write-Host "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
            } catch {
                Write-Warning "Failed to remove provisioned package: [$($ProvPackage.DisplayName)] - $_"
            }
        }
    }
}

# ---------------------------
# Step 2: Remove Installed AppX Packages
# ---------------------------
function Remove-InstalledAppxPackages {
    foreach ($AppxPackage in $InstalledPackages) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would remove Appx package: [$($AppxPackage.Name)]"
        } else {
            try {
                Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "Successfully removed Appx package: [$($AppxPackage.Name)]"
            } catch {
                Write-Warning "Failed to remove Appx package: [$($AppxPackage.Name)] - $_"
            }
        }
    }
}

# ---------------------------
# Step 3: Remove Installed Programs
# ---------------------------
function Remove-InstalledPrograms {
    foreach ($prog in $InstalledPrograms) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would uninstall program: [$($prog.Name)]"
        } else {
            try {
                $prog | Uninstall-Package -AllVersions -Force -ErrorAction Stop
                Write-Host "Successfully uninstalled: [$($prog.Name)]"
            } catch {
                Write-Warning "Failed to uninstall program: [$($prog.Name)] - $_"
                # Fallback using MSI uninstall if available
                try {
                    $msi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "$($prog.Name)" }
                    if ($msi) {
                        Write-Host "Attempting MSI uninstall for: [$($prog.Name)]..."
                        msiexec /x $msi.IdentifyingNumber /qn /norestart
                        Write-Host "MSI uninstall initiated for: [$($prog.Name)]"
                    } else {
                        Write-Warning "MSI package for [$($prog.Name)] not found."
                    }
                } catch {
                    Write-Warning "MSI uninstall failed for [$($prog.Name)]: $_"
                }
            }
        }
    }
}

# ---------------------------
# Step 4: Dynamic Fallback for HP Wolf Security (if installed)
# ---------------------------
function Remove-HPWolfSecurityFallback {
    Write-Host "Running fallback for HP Wolf Security uninstall..."

    $hpWolfPatterns = @(
        "*HP Wolf Security*",
        "*Sure Click*",
        "*Sure Sense*"
    )

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $uninstallPaths) {
        $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and ($hpWolfPatterns | Where-Object { $_ -like $_.DisplayName })
        }

        foreach ($app in $apps) {
            $displayName = $app.DisplayName
            $uninstallCmd = $app.UninstallString

            if (-not $uninstallCmd) {
                Write-Warning "No UninstallString found for: $displayName"
                continue
            }

            if ($DryRun) {
                Write-Host "DRY RUN: Would uninstall HP Wolf-related app: $displayName"
                continue
            }

            try {
                $logPath = "C:\Windows\Temp\HPWolfUninstall_$($app.PSChildName).log"

                if ($uninstallCmd -match "(?i)msiexec") {
                    if ($uninstallCmd -match "/x\s+\{[\w\-]+\}") {
                        $fullCmd = "$uninstallCmd /qn /norestart /log `"$logPath`""
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $fullCmd" -Wait -NoNewWindow
                        Write-Host "Successfully uninstalled HP Wolf component: $displayName"
                    } else {
                        Write-Warning "Unsupported or incomplete msiexec uninstall command for: $displayName → [$uninstallCmd]"
                    }
                } else {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCmd" -Wait -NoNewWindow
                    Write-Host "Successfully ran uninstall command for: $displayName"
                }
            } catch {
                Write-Warning "Failed to uninstall ${displayName}: $_"
            }
        }
    }
}

# ---------------------------
# Step 5: Remove pre-installed Microsoft 365 Apps (MS-Bloat)
# ---------------------------
function Remove-M365Apps {
    # 1) Remove any Store-based packages (OneNote, OfficeHub placeholders, etc.)
    foreach ($package in $UninstallM365Apps) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would remove Appx packages matching [$package]"
        } else {
            Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $package } |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $package } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }
    }

    # 2) Remove Click-to-Run Office using ODT
    if (-not $DryRun) {
        Remove-M365AppsC2RWithODT
    }
    else {
        Write-Host "DRY RUN: Would invoke ODT-based Office removal for Click-to-Run installations."
    }
}

function Remove-M365AppsC2RWithODT {
    # $PSScriptRoot automatically points to the folder of the *current script* in PS 3.0+
    $odtSetupPath = Join-Path $PSScriptRoot 'setup.exe'
    $odtXmlPath   = Join-Path $PSScriptRoot 'UninstallOffice.xml'

    if (-not (Test-Path $odtSetupPath)) {
        Write-Warning "ODT setup.exe not found at '$odtSetupPath'."
        return
    }
    if (-not (Test-Path $odtXmlPath)) {
        Write-Warning "ODT config XML not found at '$odtXmlPath'."
        return
    }

    Write-Host "Running Office Deployment Tool to remove Click-to-Run Office..."
    try {
        Start-Process -FilePath $odtSetupPath -ArgumentList "/configure `"$odtXmlPath`"" -Wait -NoNewWindow
        Write-Host "ODT-based uninstall completed. A reboot may be required."
    }
    catch {
        Write-Warning "Failed to run ODT-based removal. $_"
    }

    # Now call the fallback to remove leftover OneDrive via registry-based UninstallString
    Write-Host "Checking for leftover OneDrive installations..."
    Remove-OfficeFromRegistryFallback
}

function Remove-OfficeFromRegistryFallback {
    Write-Host "Running registry-based fallback to uninstall remaining Microsoft Office components..."

    $PatternProductID = '(?(?=^[^\.]+$)\S*|(?<=\.)\S*)'
    $xmlFile = "$env:TEMP\config.xml"

    $Installs = @()
    $Installs += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.DisplayName -like "Microsoft Office*" -or $_.DisplayName -like "Microsoft OneNote*") -and
        $_.PSChildName -notmatch '^\{.*\}$'
    }

    $Installs += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.DisplayName -like "Microsoft Office*" -or $_.DisplayName -like "Microsoft OneNote*") -and
        $_.PSChildName -notmatch '^\{.*\}$'
    }

    $Installs | Where-Object { $_ } | ForEach-Object {
        $productID = if ($_.PSChildName -match $PatternProductID) { $matches[0] } else { $_.PSChildName }

        if ($_.UninstallString -match "(?i)ClickToRun") {
            $UninstallString = "$($_.UninstallString) displaylevel=false forceappshutdown=true acceptEULA=true"
        }
        else {
            try {
                [xml]$configXml = @"
			<Configuration Product="$productID">
    			<Display Level="none" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" />
    			<Setting Id="SETUP_REBOOT" Value="Never" />
			</Configuration>
			"@
                $configXml.Save($xmlFile)
                $UninstallString = "$($_.UninstallString) /config `"$xmlFile`""
            } catch {
                Write-Warning "Failed to create uninstall config for $productID. $_"
                return
            }
        }

        # Extract executable and arguments
        $fileMatch = [regex]::Match($UninstallString, '"([^"]+)"')
        $FilePath = $fileMatch.Groups[1].Value
        $Arguments = $UninstallString -replace [regex]::Escape("`"$FilePath`""), ""

        Write-Output ("{0,-15} {1}" -f "Program Name:", $_.DisplayName.Trim())
        Write-Output ("{0,-15} {1}" -f "ProductID:", $productID)
        Write-Output ("{0,-15} {1}" -f "Uninstall:", $UninstallString)
        Write-Output ""

        try {
            Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -NoNewWindow
            Write-Host "Uninstall completed for: $($_.DisplayName.Trim())"
        } catch {
            Write-Warning "Failed to uninstall $($_.DisplayName): $_"
        }

        if (Test-Path $xmlFile) {
            Remove-Item $xmlFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------
# Main Execution
# ---------------------------
Write-Host "Starting HP bloatware removal process..."

if ($RemoveProvisionedPackages) { Remove-ProvisionedPackages }
if ($RemoveAppxPackages) { Remove-InstalledAppxPackages }
if ($RemoveInstalledPrograms) { Remove-InstalledPrograms }
if ($RemoveM365Apps) { Remove-M365Apps }   # Added call to remove Microsoft 365 apps
Remove-HPWolfSecurityFallback

Write-Host "HP bloatware removal process complete."

 
# Optional: Review remaining HP items
Write-Host "Remaining AppX packages matching 'HP':"
Get-AppxPackage -AllUsers | Where-Object { $_.Name -match "HP" } | Format-Table Name, PackageFullName

Write-Host "Remaining provisioned packages matching 'HP':"
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match "HP" } | Format-Table DisplayName, PackageName

Write-Host "Remaining installed packages matching 'HP':"
Get-Package | Where-Object { $_.Name -match "HP" } | Format-Table Name
#>

<# 
# Optional: Prompt for reboot after completion:
$reboot = Read-Host "Do you want to reboot now? (y/n)"
if ($reboot -match "^(y|yes)$") {
    Restart-Computer -Force -Confirm:$false
}
#>
