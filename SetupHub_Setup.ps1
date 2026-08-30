# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Pietro Melillo
<#
.SYNOPSIS
    SetupHub - Windows software installer, profile-based deployment and debloater.
.DESCRIPTION
    WPF GUI and CLI tool for automated software deployment via WinGet, optional bloatware removal,
    custom software profiles, bilingual UI (Italian/English), execution log and final HTML/CSV/JSON diagnostic report.
.AUTHOR
    Pietro Melillo
.NOTES
    Requires Windows 10 1909+ / Windows 11, PowerShell 5.1+, Administrator privileges and WinGet.
    v1.1 includes:
    - Automatic Windows App Runtime 1.8+ bootstrap to resolve 0x80073CF3 dependency errors.
    - Automatic AppX environment repair to resolve 0x80073CF9 staging errors.
    - Zero-crash resilient bootstrap with permission-safe AppX discovery.
    - Full CLI / Unattended deployment mode (-NoGui, -Profile, -CreateRestorePoint, etc.).
    - Real-time search and category filtering in GUI.
    - System Restore Point creation option.
    - Pending Windows reboot detection.
    - Improved WinGet source resilience and error reporting.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$Profile = '',
    [Parameter(Mandatory=$false)][switch]$NoGui,
    [Parameter(Mandatory=$false)][switch]$Silent,
    [Parameter(Mandatory=$false)][switch]$CreateRestorePoint,
    [Parameter(Mandatory=$false)][switch]$SkipValidation,
    [Parameter(Mandatory=$false)][switch]$NoInventory,
    [Parameter(Mandatory=$false)][switch]$NoReport,
    [Parameter(Mandatory=$false)][string]$Language = '',
    [Parameter(Mandatory=$false)][string[]]$InstallIds = @(),
    [Parameter(Mandatory=$false)][string[]]$BloatIds = @()
)

#region === BASE CONFIGURATION ===
$ErrorActionPreference = 'Continue'
$script:AppName = 'SetupHub'
$script:AppVersion = '1.2.0'
$script:LicenseName = 'GNU General Public License v3.0 only'
$script:LicenseSpdx = 'GPL-3.0-only'
$script:AuthorName = 'Pietro Melillo'
$script:AuthorEmail = 'melillopietro@gmail.com'
$script:AuthorWebsite = 'https://melillopietro.github.io/'
$script:CopyrightNotice = 'Copyright (C) 2026 Pietro Melillo'
$script:DefaultLanguage = 'it'
$script:ProfileFolder = Join-Path $PSScriptRoot 'profiles'
$script:ReportFolder = Join-Path $PSScriptRoot 'reports'
$script:WingetLogFolder = Join-Path $script:ReportFolder 'winget-logs'
$script:WinGetAvailable = $true
$script:WinGetWarningMsg = ''

try { New-Item -Path $script:ProfileFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
try { New-Item -Path $script:ReportFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
try { New-Item -Path $script:WingetLogFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
#endregion

#region === ASSEMBLIES ===
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
    Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
} catch {}
#endregion

#region === ELEVATION & OS GUARD ===
$scriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { Join-Path $PSScriptRoot 'SetupHub_Setup.ps1' }
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($NoGui) {
        Write-Error "SetupHub richiede privilegi di amministratore. Eseguire PowerShell come Amministratore."
        exit 1
    }
    $passArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($Profile) { $passArgs += " -Profile `"$Profile`"" }
    if ($NoGui) { $passArgs += " -NoGui" }
    if ($Silent) { $passArgs += " -Silent" }
    if ($CreateRestorePoint) { $passArgs += " -CreateRestorePoint" }
    if ($SkipValidation) { $passArgs += " -SkipValidation" }
    if ($NoInventory) { $passArgs += " -NoInventory" }
    if ($NoReport) { $passArgs += " -NoReport" }
    if ($Language) { $passArgs += " -Language `"$Language`"" }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $passArgs
    } catch {
        [System.Windows.MessageBox]::Show("Impossibile richiedere i privilegi di amministratore:`n$($_.Exception.Message)", "Errore Privilegi", 'OK', 'Error') | Out-Null
    }
    exit 0
}

$osBuild = [System.Environment]::OSVersion.Version.Build
if ($osBuild -lt 18363) {
    if ($NoGui) {
        Write-Error "Questo tool richiede Windows 10 build 18363 o superiore. Build attuale: $osBuild"
    } else {
        [System.Windows.MessageBox]::Show(
            "Questo tool richiede Windows 10 build 18363 o superiore.`nBuild attuale: $osBuild",
            "Versione OS non supportata",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    exit 1
}
#endregion

#region === LOCALIZATION ===
$script:Lang = if ($Language -and ($Language -eq 'en' -or $Language -eq 'it')) { $Language } else { $script:DefaultLanguage }
$script:Text = @{
    it = @{
        WindowTitle = 'SetupHub — Installer, Profili e Debloater Windows'
        HeaderTitle = 'SetupHub'
        HeaderSubtitle = 'Installer WinGet con profili software, report finale e rimozione bloatware'
        Language = 'Lingua'
        Profile = 'Profilo'
        ApplyProfile = 'Applica profilo'
        NewProfile = 'Nuovo profilo'
        SaveProfile = 'Salva profilo'
        LoadProfile = 'Carica profilo'
        Reset = 'Reset consigliato'
        Credits = 'Credits'
        InstallPanel = 'Software da installare'
        BloatPanel = 'Bloatware da rimuovere'
        SelectAll = 'Seleziona tutto'
        DeselectAll = 'Deseleziona tutto'
        Start = 'Avvia'
        Cancel = 'Chiudi'
        Pending = 'In attesa di avvio...'
        Report = 'Genera report HTML/CSV'
        RestorePoint = 'Crea punto di ripristino'
        RestorePointCreating = 'Creazione punto di ripristino in corso...'
        RestorePointOk = 'Punto di ripristino creato con successo'
        RestorePointFailed = 'Creazione punto di ripristino non riuscita'
        PendingRebootBanner = 'Attenzione: riavvio di sistema pendente rilevato! Si consiglia di riavviare prima del deployment.'
        WinGetWarningBanner = 'Attenzione: WinGet non risulta pienamente configurato nel sistema. L''installazione software potrebbe fallire, ma puoi procedere con debloating e inventario.'
        SearchInstallPlaceholder = 'Cerca software per nome o ID...'
        SearchBloatPlaceholder = 'Cerca bloatware...'
        CategoryAll = 'Tutte le categorie'
        CatalogValidation = 'Valida tutto il catalogo software prima dell''avvio'
        InventoryReport = 'Includi inventario hardware/software nel report'
        CatalogPhase = 'FASE 0: Validazione catalogo software'
        InventoryPhase = 'Raccolta inventario PC'
        LogTitle = 'Log operazioni'
        NoSelection = 'Nessun pacchetto selezionato.'
        Warning = 'Attenzione'
        Completed = 'Completato!'
        SummaryTitle = 'Riepilogo operazioni'
        InstallPhase = 'FASE 1: Installazione software'
        RemovePhase = 'FASE 2: Rimozione bloatware'
        Installing = 'Installando'
        Removing = 'Rimuovendo'
        InstalledOk = 'installato con successo'
        RemovedOk = 'rimosso con successo'
        Error = 'ERRORE'
        SourceCheck = 'Verifica sorgenti WinGet'
        PackageCheck = 'Verifica pacchetto'
        PackageNotFound = 'Pacchetto non trovato nella sorgente selezionata'
        WingetLog = 'Log WinGet'
        NotInstalled = 'Non installato / gia assente'
        Skipped = 'Saltato'
        ReportSaved = 'Report salvato in'
        ProfileCreated = 'Profilo creato'
        ManualUnsupportedPhase = 'Pacchetti manuali / non supportati'
        ManualUnsupportedReport = 'Pacchetti manuali / non supportati'
        ManualUnsupportedSaved = 'Manual/Unsupported JSON'
        LicenseTitle = 'Licenza'
        CreditsTitle = 'Credits e licenza'
        ChangelogTitle = 'Changelog'
        ProfileSaved = 'Profilo salvato'
        ProfileLoaded = 'Profilo caricato'
        InsertProfileName = 'Inserisci il nome del profilo personalizzato:'
        ProfileNameTitle = 'Nuovo profilo'
        Footer = 'Creato da Pietro Melillo | Powered by WinGet | SetupHub v1.1'
    }
    en = @{
        WindowTitle = 'SetupHub — Windows Installer, Profiles and Debloater'
        HeaderTitle = 'SetupHub'
        HeaderSubtitle = 'WinGet installer with software profiles, final report and bloatware removal'
        Language = 'Language'
        Profile = 'Profile'
        ApplyProfile = 'Apply profile'
        NewProfile = 'New profile'
        SaveProfile = 'Save profile'
        LoadProfile = 'Load profile'
        Reset = 'Recommended reset'
        Credits = 'Credits'
        InstallPanel = 'Software to install'
        BloatPanel = 'Bloatware to remove'
        SelectAll = 'Select all'
        DeselectAll = 'Deselect all'
        Start = 'Start'
        Cancel = 'Close'
        Pending = 'Waiting to start...'
        Report = 'Generate HTML/CSV report'
        RestorePoint = 'Create restore point'
        RestorePointCreating = 'Creating system restore point...'
        RestorePointOk = 'System restore point created successfully'
        RestorePointFailed = 'System restore point creation failed'
        PendingRebootBanner = 'Warning: pending system reboot detected! A system restart is recommended before deployment.'
        WinGetWarningBanner = 'Warning: WinGet is not fully configured on this machine. Software installation might fail, but debloating and inventory are available.'
        SearchInstallPlaceholder = 'Search software by name or ID...'
        SearchBloatPlaceholder = 'Search bloatware...'
        CategoryAll = 'All categories'
        CatalogValidation = 'Validate the full software catalog before start'
        InventoryReport = 'Include hardware/software inventory in report'
        CatalogPhase = 'PHASE 0: Software catalog validation'
        InventoryPhase = 'Collecting PC inventory'
        LogTitle = 'Operation log'
        NoSelection = 'No package selected.'
        Warning = 'Warning'
        Completed = 'Completed!'
        SummaryTitle = 'Operation summary'
        InstallPhase = 'PHASE 1: Software installation'
        RemovePhase = 'PHASE 2: Bloatware removal'
        Installing = 'Installing'
        Removing = 'Removing'
        InstalledOk = 'installed successfully'
        RemovedOk = 'removed successfully'
        Error = 'ERROR'
        SourceCheck = 'WinGet source check'
        PackageCheck = 'Package verification'
        PackageNotFound = 'Package not found in the selected source'
        WingetLog = 'WinGet log'
        NotInstalled = 'Not installed / already absent'
        Skipped = 'Skipped'
        ReportSaved = 'Report saved in'
        ProfileCreated = 'Profile created'
        ManualUnsupportedPhase = 'Manual / unsupported packages'
        ManualUnsupportedReport = 'Manual / unsupported packages'
        ManualUnsupportedSaved = 'Manual/Unsupported JSON'
        LicenseTitle = 'License'
        CreditsTitle = 'Credits and license'
        ChangelogTitle = 'Changelog'
        ProfileSaved = 'Profile saved'
        ProfileLoaded = 'Profile loaded'
        InsertProfileName = 'Enter the custom profile name:'
        ProfileNameTitle = 'New profile'
        Footer = 'Created by Pietro Melillo | Powered by WinGet | SetupHub v1.1'
    }
}
function T([string]$Key) { return $script:Text[$script:Lang][$Key] }
#endregion

#region === SYSTEM RESILIENCE & APPX REPAIR ===
function Repair-AppXEnvironment {
    try {
        # 1. Ricrea le cartelle di sistema necessarie ad AppX (la cui mancanza provoca l'errore 0x80073CF9)
        $requiredDirs = @(
            "$env:SystemRoot\AppReadiness",
            "$env:SystemRoot\AUInstallAgent",
            "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        )
        foreach ($d in $requiredDirs) {
            if (-not (Test-Path $d)) {
                try { New-Item -Path $d -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
        }

        # 2. Avvia e abilita i servizi di installazione e AppX essenziali
        $services = @('AppReadiness', 'AppXSvc', 'ClipSVC', 'InstallService', 'wuauserv')
        foreach ($s in $services) {
            try {
                $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                if ($svc) {
                    if ($svc.StartType -eq 'Disabled') {
                        Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                    }
                    if ($svc.Status -ne 'Running') {
                        Start-Service -Name $s -ErrorAction SilentlyContinue
                    }
                }
            } catch {}
        }
    } catch {}
}

function Get-WinGetExecutablePath {
    try {
        $appx = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($appx -and $appx.InstallLocation) {
            $exe = Join-Path $appx.InstallLocation 'winget.exe'
            if (Test-Path $exe) { return $exe }
        }
    } catch {}
    $localApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $localApps) { return $localApps }
    return 'winget'
}

function Invoke-WinGetCli {
    param([string]$Arguments)
    
    # 1. First try: standard cmd /c winget
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:ComSpec"
    $psi.Arguments = "/d /c winget $Arguments"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    try {
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    } catch {}

    $stdout = ''
    $stderr = ''
    $exitCode = -1

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
    } catch {
        $stderr = $_.Exception.Message
    }

    # If cmd /c winget produced output or completed with 0, and didn't report unrecognized command
    $notRecognized = ($stderr -match '(?i)(not recognized|non . riconosciuto|cannot find the file|impossibile trovare)')
    if (-not $notRecognized -and (-not [string]::IsNullOrWhiteSpace($stdout) -or $exitCode -eq 0)) {
        return [pscustomobject]@{
            ExitCode = $exitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }

    # 2. Second try: find winget in LocalAppData or WindowsApps and invoke via cmd /c "<path>"
    $candidatePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )
    try {
        $appx = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($appx -and $appx.InstallLocation) {
            $candidatePaths += (Join-Path $appx.InstallLocation 'winget.exe')
        }
    } catch {}
    try {
        $userProfiles = Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue
        if ($userProfiles) {
            foreach ($u in $userProfiles) {
                $candidatePaths += "$($u.FullName)\AppData\Local\Microsoft\WindowsApps\winget.exe"
            }
        }
    } catch {}

    foreach ($cPath in $candidatePaths) {
        if ($cPath -and (Test-Path $cPath)) {
            try {
                $psiPath = New-Object System.Diagnostics.ProcessStartInfo
                $psiPath.FileName = "$env:ComSpec"
                $psiPath.Arguments = "/d /c `"`"$cPath`" $Arguments`""
                $psiPath.RedirectStandardOutput = $true
                $psiPath.RedirectStandardError = $true
                $psiPath.UseShellExecute = $false
                $psiPath.CreateNoWindow = $true
                try {
                    $psiPath.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                    $psiPath.StandardErrorEncoding = [System.Text.Encoding]::UTF8
                } catch {}
                $pPath = [System.Diagnostics.Process]::Start($psiPath)
                $outPath = $pPath.StandardOutput.ReadToEnd()
                $errPath = $pPath.StandardError.ReadToEnd()
                $pPath.WaitForExit()
                if (-not [string]::IsNullOrWhiteSpace($outPath) -or $pPath.ExitCode -eq 0) {
                    return [pscustomobject]@{
                        ExitCode = $pPath.ExitCode
                        StdOut = $outPath
                        StdErr = $errPath
                    }
                }
            } catch {}
        }
    }

    # 3. Third try: PowerShell wrapper
    try {
        $psiPs = New-Object System.Diagnostics.ProcessStartInfo
        $psiPs.FileName = 'powershell.exe'
        $psiPs.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & winget $Arguments }`""
        $psiPs.RedirectStandardOutput = $true
        $psiPs.RedirectStandardError = $true
        $psiPs.UseShellExecute = $false
        $psiPs.CreateNoWindow = $true
        try {
            $psiPs.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psiPs.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        } catch {}
        $pPs = [System.Diagnostics.Process]::Start($psiPs)
        $outPs = $pPs.StandardOutput.ReadToEnd()
        $errPs = $pPs.StandardError.ReadToEnd()
        $pPs.WaitForExit()
        if (-not [string]::IsNullOrWhiteSpace($outPs) -or $pPs.ExitCode -eq 0) {
            return [pscustomobject]@{
                ExitCode = $pPs.ExitCode
                StdOut = $outPs
                StdErr = $errPs
            }
        }
    } catch {}

    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Resolve-WinGetEnvironment {
    # 1. Inietta nel PATH le cartelle di installazione di WindowsAppRuntime e VCLibs per garantire il caricamento delle DLL a runtime
    try {
        $wasdk = Get-AppxPackage -Name '*WindowsAppRuntime*' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($wasdk -and $wasdk.InstallLocation) {
            if (-not $env:PATH.Contains($wasdk.InstallLocation)) { $env:PATH = "$($wasdk.InstallLocation);$env:PATH" }
        }
        $vclibs = Get-AppxPackage -Name '*VCLibs*' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($vclibs -and $vclibs.InstallLocation) {
            if (-not $env:PATH.Contains($vclibs.InstallLocation)) { $env:PATH = "$($vclibs.InstallLocation);$env:PATH" }
        }
    } catch {}

    # 2. Check if winget is already working in current PATH or via invoker
    try {
        $res = Invoke-WinGetCli -Arguments '--version'
        if ($res.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($res.StdOut)) { return $true }
    } catch {}

    # 3. Check Appx package installation path for AllUsers (official, permission-safe API)
    try {
        $appx = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($appx -and $appx.InstallLocation) {
            $wingetExe = Join-Path $appx.InstallLocation 'winget.exe'
            if (Test-Path $wingetExe) {
                if (-not $env:PATH.Contains($appx.InstallLocation)) { $env:PATH = "$($appx.InstallLocation);$env:PATH" }
                $res = Invoke-WinGetCli -Arguments '--version'
                if ($res.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($res.StdOut)) { return $true }
            }
        }
    } catch {}

    # 4. Check LOCALAPPDATA WindowsApps
    try {
        $localApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        if (Test-Path "$localApps\winget.exe") {
            if (-not $env:PATH.Contains($localApps)) { $env:PATH = "$localApps;$env:PATH" }
            $res = Invoke-WinGetCli -Arguments '--version'
            if ($res.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($res.StdOut)) { return $true }
        }
    } catch {}

    # 5. Check all user profile WindowsApps directories (useful when elevated as different admin)
    try {
        $userProfiles = Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue
        if ($userProfiles) {
            foreach ($u in $userProfiles) {
                $userWinApps = "$($u.FullName)\AppData\Local\Microsoft\WindowsApps"
                if (Test-Path "$userWinApps\winget.exe") {
                    if (-not $env:PATH.Contains($userWinApps)) { $env:PATH = "$userWinApps;$env:PATH" }
                    $res = Invoke-WinGetCli -Arguments '--version'
                    if ($res.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($res.StdOut)) { return $true }
                }
            }
        }
    } catch {}

    return $false
}

function Test-WinGetAvailable {
    Repair-AppXEnvironment
    return (Resolve-WinGetEnvironment)
}

function Test-PendingReboot {
    try {
        $cbs = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        $wu = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        $pfro = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        if (Test-Path $cbs) { return $true }
        if (Test-Path $wu) { return $true }
        $prop = (Get-ItemProperty -Path $pfro -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue)
        if ($prop -and $prop.PendingFileRenameOperations) { return $true }
    } catch {}
    return $false
}

function New-DeploymentRestorePoint {
    param([string]$Description = 'SetupHub Pre-Deployment')
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        try {
            $srPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
            if (Test-Path $srPath) {
                Set-ItemProperty -Path $srPath -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        Checkpoint-Computer -Description $Description -RestorePointType 'APPLICATION_INSTALL' -ErrorAction Stop | Out-Null
        return [pscustomobject]@{ Success = $true; Message = 'OK' }
    } catch {
        return [pscustomobject]@{ Success = $false; Message = $_.Exception.Message }
    }
}
#endregion

#region === PACKAGE DEFINITIONS ===
# Profiles available: Essential, Business, Developer, Cybersecurity, Multimedia, Gaming, Home, Complete
$installPackages = @(
    # Core / Essential
    @{ Name = '7-Zip'; Id = '7zip.7zip'; Category = 'Core'; Checked = $true; Profiles = @('Essential','Business','Developer','Cybersecurity','Home') }
    @{ Name = 'NanaZip'; Id = 'M2Team.NanaZip'; Category = 'Core'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'WinRAR'; Id = 'RARLab.WinRAR'; Category = 'Core'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'Notepad++'; Id = 'Notepad++.Notepad++'; Category = 'Core'; Checked = $true; Profiles = @('Essential','Business','Developer','Cybersecurity','Home') }
    @{ Name = 'Everything Search'; Id = 'voidtools.Everything'; Category = 'Core'; Checked = $false; Profiles = @('Essential','Business','Developer','Cybersecurity','Home') }
    @{ Name = 'Microsoft PowerToys'; Id = 'Microsoft.PowerToys'; Category = 'Core'; Checked = $false; Profiles = @('Essential','Business','Developer','Home') }
    @{ Name = 'Windows Terminal'; Id = 'Microsoft.WindowsTerminal'; Category = 'Core'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell'; Category = 'Core'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'PDF24 Creator'; Id = 'geeksoftwareGmbH.PDF24Creator'; Category = 'Core'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Adobe Acrobat Reader 64-bit'; Id = 'Adobe.Acrobat.Reader.64-bit'; Category = 'Core'; Checked = $true; Profiles = @('Essential','Business','Home') }
    @{ Name = 'Foxit PDF Reader'; Id = 'Foxit.FoxitReader'; Category = 'Core'; Checked = $false; Profiles = @('Business') }

    # Browsers / Communication
    @{ Name = 'Google Chrome'; Id = 'Google.Chrome'; Category = 'Browser'; Checked = $false; Profiles = @('Essential','Business','Developer','Cybersecurity','Home') }
    @{ Name = 'Mozilla Firefox'; Id = 'Mozilla.Firefox'; Category = 'Browser'; Checked = $false; Profiles = @('Essential','Developer','Cybersecurity','Home') }
    @{ Name = 'Brave Browser'; Id = 'Brave.Brave'; Category = 'Browser'; Checked = $false; Profiles = @('Cybersecurity','Home') }
    @{ Name = 'Opera Browser'; Id = 'Opera.Opera'; Category = 'Browser'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'Tor Browser'; Id = 'TorProject.TorBrowser'; Category = 'Browser'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'Microsoft Teams'; Id = 'Microsoft.Teams'; Category = 'Communication'; Checked = $false; Profiles = @('Business') }
    @{ Name = 'Zoom'; Id = 'Zoom.Zoom'; Category = 'Communication'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Slack'; Id = 'SlackTechnologies.Slack'; Category = 'Communication'; Checked = $false; Profiles = @('Business','Developer') }
    @{ Name = 'WhatsApp'; Id = '9NKSQGP7F2NH'; Source = 'msstore'; Category = 'Communication'; Checked = $true; Profiles = @('Essential','Business','Home'); SkipSilent = $true; Notes = 'Microsoft Store package ID for WhatsApp Desktop. Requires Microsoft Store source to be available.' }
    @{ Name = 'Telegram Desktop'; Id = 'Telegram.TelegramDesktop'; Category = 'Communication'; Checked = $true; Profiles = @('Essential','Cybersecurity','Home') }
    @{ Name = 'Discord'; Id = 'Discord.Discord'; Category = 'Gaming'; Checked = $false; Profiles = @('Gaming','Home') }

    # Office / Productivity
    @{ Name = 'Microsoft 365 Apps / Office'; Id = 'Microsoft.Office'; Category = 'Office'; Checked = $false; Profiles = @('Business'); SkipSilent = $true }
    @{ Name = 'Microsoft Office Deployment Tool'; Id = 'Microsoft.OfficeDeploymentTool'; Category = 'Office'; Checked = $false; Profiles = @('Business'); SkipSilent = $true }
    @{ Name = 'LibreOffice'; Id = 'TheDocumentFoundation.LibreOffice'; Category = 'Office'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Apache OpenOffice'; Id = 'Apache.OpenOffice'; Category = 'Office'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'Notion'; Id = 'Notion.Notion'; Category = 'Productivity'; Checked = $true; Profiles = @('Business','Home') }
    @{ Name = 'Obsidian'; Id = 'Obsidian.Obsidian'; Category = 'Productivity'; Checked = $false; Profiles = @('Developer','Cybersecurity','Home') }
    @{ Name = 'Joplin'; Id = 'Joplin.Joplin'; Category = 'Productivity'; Checked = $false; Profiles = @('Cybersecurity','Home') }
    @{ Name = 'Microsoft To Do'; Id = '9NBLGGH5R558'; Source = 'msstore'; Category = 'Productivity'; Checked = $false; Profiles = @('Business','Home'); SkipSilent = $true; Notes = 'Microsoft Store package ID for Microsoft To Do.' }
    @{ Name = 'OneDrive'; Id = 'Microsoft.OneDrive'; Category = 'Cloud'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Google Drive'; Id = 'Google.GoogleDrive'; AlternateIds = @('Google.Drive'); Category = 'Cloud'; Checked = $false; Profiles = @('Business','Home'); Notes = 'Uses Google.GoogleDrive as primary ID; Google.Drive is kept only as legacy fallback.' }
    @{ Name = 'Dropbox'; Id = 'Dropbox.Dropbox'; Category = 'Cloud'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Synology Drive Client'; Id = 'Synology.DriveClient'; Category = 'Cloud'; Checked = $true; Profiles = @('Business','Home') }

    # Developer
    @{ Name = 'Git'; Id = 'Git.Git'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'GitHub Desktop'; Id = 'GitHub.GitHubDesktop'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'Visual Studio 2022 Community'; Id = 'Microsoft.VisualStudio.2022.Community'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'Python 3.12'; Id = 'Python.Python.3.12'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'Node.js LTS'; Id = 'OpenJS.NodeJS.LTS'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'Go'; Id = 'GoLang.Go'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'Rustup'; Id = 'Rustlang.Rustup'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'Java JDK 21 Temurin'; Id = 'EclipseAdoptium.Temurin.21.JDK'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'Docker Desktop'; Id = 'Docker.DockerDesktop'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'Postman'; Id = 'Postman.Postman'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'JetBrains Toolbox'; Id = 'JetBrains.Toolbox'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'PyCharm Community'; Id = 'JetBrains.PyCharm.Community'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'Sublime Text 4'; Id = 'SublimeHQ.SublimeText.4'; Category = 'Developer'; Checked = $false; Profiles = @('Developer') }
    @{ Name = 'WinSCP'; Id = 'WinSCP.WinSCP'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'PuTTY'; Id = 'PuTTY.PuTTY'; Category = 'Developer'; Checked = $false; Profiles = @('Developer','Cybersecurity') }

    # Cybersecurity / Admin
    @{ Name = 'Wireshark'; Id = 'WiresharkFoundation.Wireshark'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'Nmap'; Id = 'Insecure.Nmap'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'Burp Suite Community'; Id = 'PortSwigger.BurpSuite.Community'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'OWASP ZAP'; Id = 'ZAP.ZAP'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'YARA'; Id = 'VirusTotal.YARA'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }
    @{ Name = 'Sysinternals Suite'; Id = 'Microsoft.Sysinternals.Suite'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity'); Notes = 'Corrected ID from Microsoft.Sysinternals to Microsoft.Sysinternals.Suite.' }
    @{ Name = 'OpenVPN'; Id = 'OpenVPNTechnologies.OpenVPN'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity','Business') }
    @{ Name = 'WireGuard'; Id = 'WireGuard.WireGuard'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity','Business') }
    @{ Name = 'Bitwarden'; Id = 'Bitwarden.Bitwarden'; Category = 'Security'; Checked = $false; Profiles = @('Essential','Business','Cybersecurity','Home') }
    @{ Name = 'KeePassXC'; Id = 'KeePassXCTeam.KeePassXC'; Category = 'Security'; Checked = $false; Profiles = @('Cybersecurity','Home') }
    @{ Name = 'VirusTotal Uploader'; Id = 'VirusTotal.VirusTotalUploader'; Category = 'Cybersecurity'; Checked = $false; Profiles = @('Cybersecurity') }

    # Remote support / Utilities / Drivers
    @{ Name = 'AnyDesk'; Id = 'AnyDesk.AnyDesk'; AlternateIds = @('AnyDeskSoftwareGmbH.AnyDesk'); Category = 'Remote'; Checked = $false; Profiles = @('Business','Home'); Notes = 'Uses AnyDesk.AnyDesk as primary ID; legacy vendor ID kept as fallback.' }
    @{ Name = 'TeamViewer'; Id = 'TeamViewer.TeamViewer'; Category = 'Remote'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Rufus'; Id = 'Rufus.Rufus'; Category = 'Utility'; Checked = $false; Profiles = @('Developer','Cybersecurity','Home') }
    @{ Name = 'balenaEtcher'; Id = 'Balena.Etcher'; Category = 'Utility'; Checked = $false; Profiles = @('Developer','Cybersecurity','Home') }
    @{ Name = 'Recuva'; Id = 'Piriform.Recuva'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'CrystalDiskInfo'; Id = 'CrystalDewWorld.CrystalDiskInfo'; Category = 'Utility'; Checked = $false; Profiles = @('Essential','Home') }
    @{ Name = 'CrystalDiskMark'; Id = 'CrystalDewWorld.CrystalDiskMark'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'CPU-Z'; Id = 'CPUID.CPU-Z'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'HWMonitor'; Id = 'CPUID.HWMonitor'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'HWiNFO'; Id = 'REALiX.HWiNFO'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
    @{ Name = 'Intel Driver & Support Assistant'; Id = 'Intel.IntelDriverAndSupportAssistant'; Category = 'Driver'; Checked = $false; Profiles = @('Home') }

    # Multimedia / Creative / Gaming
    @{ Name = 'VLC'; Id = 'VideoLAN.VLC'; Category = 'Multimedia'; Checked = $true; Profiles = @('Essential','Home','Multimedia') }
    @{ Name = 'Spotify'; Id = 'Spotify.Spotify'; Category = 'Multimedia'; Checked = $false; Profiles = @('Home','Multimedia') }
    @{ Name = 'OBS Studio'; Id = 'OBSProject.OBSStudio'; Category = 'Multimedia'; Checked = $true; Profiles = @('Multimedia','Home') }
    @{ Name = 'Audacity'; Id = 'Audacity.Audacity'; Category = 'Multimedia'; Checked = $false; Profiles = @('Multimedia') }
    @{ Name = 'GIMP'; Id = 'GIMP.GIMP'; Category = 'Creative'; Checked = $false; Profiles = @('Multimedia','Home') }
    @{ Name = 'Inkscape'; Id = 'Inkscape.Inkscape'; Category = 'Creative'; Checked = $false; Profiles = @('Multimedia') }
    @{ Name = 'Kdenlive'; Id = 'KDE.Kdenlive'; Category = 'Creative'; Checked = $false; Profiles = @('Multimedia') }
    @{ Name = 'Blender'; Id = 'BlenderFoundation.Blender'; Category = 'Creative'; Checked = $false; Profiles = @('Multimedia') }
    @{ Name = 'ShareX'; Id = 'ShareX.ShareX'; Category = 'Screenshot'; Checked = $false; Profiles = @('Developer','Cybersecurity','Multimedia','Home') }
    @{ Name = 'Greenshot'; Id = 'Greenshot.Greenshot'; Category = 'Screenshot'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Screenpresso'; Id = 'Learnpulse.Screenpresso'; Category = 'Screenshot'; Checked = $false; Profiles = @('Business','Home') }
    @{ Name = 'Steam'; Id = 'Valve.Steam'; Category = 'Gaming'; Checked = $false; Profiles = @('Gaming') }
    @{ Name = 'Epic Games Launcher'; Id = 'EpicGames.EpicGamesLauncher'; Category = 'Gaming'; Checked = $false; Profiles = @('Gaming') }
    @{ Name = 'EA App'; Id = 'ElectronicArts.EADesktop'; Category = 'Gaming'; Checked = $false; Profiles = @('Gaming') }

    # Virtualization / VPN
    @{ Name = 'VirtualBox'; Id = 'Oracle.VirtualBox'; Category = 'Virtualization'; Checked = $false; Profiles = @('Developer','Cybersecurity') }
    @{ Name = 'NordVPN'; Id = 'NordVPN.NordVPN'; AlternateIds = @('NordSecurity.NordVPN'); Category = 'VPN'; Checked = $true; Profiles = @('Home','Business'); VerifiedUrl = 'https://winget.run/pkg/NordVPN/NordVPN'; Notes = 'Tries NordVPN.NordVPN first, then NordSecurity.NordVPN if the primary manifest is not available.' }
    @{ Name = 'qBittorrent'; Id = 'qBittorrent.qBittorrent'; Category = 'Utility'; Checked = $false; Profiles = @('Home') }
)

$manualUnsupportedPackages = @(
    [pscustomobject]@{ Name = 'Ghidra'; Category = 'Cybersecurity'; PreviousId = 'NSA.Ghidra'; Status = 'ManualUnsupported'; Reason = 'Not reliably available from the selected WinGet source; Ghidra is commonly distributed as a portable ZIP and requires a JDK/runtime prerequisite.'; Recommendation = 'Install manually from the official Ghidra release page, or keep Java/JDK in the standard SetupHub catalog.'; SuggestedAlternative = 'YARA, Sysinternals Suite, Wireshark, Nmap, OWASP ZAP' }
    [pscustomobject]@{ Name = 'RustDesk'; Category = 'Remote'; PreviousId = 'RustDesk.RustDesk'; Status = 'ManualUnsupported'; Reason = 'Intermittently unavailable in the selected WinGet source on the tested endpoint.'; Recommendation = 'Keep out of standard profiles; use AnyDesk or TeamViewer from SetupHub, or install RustDesk manually if required.'; SuggestedAlternative = 'AnyDesk, TeamViewer' }
    [pscustomobject]@{ Name = 'NVIDIA GeForce Experience'; Category = 'Driver'; PreviousId = 'Nvidia.GeForceExperience'; Status = 'ManualUnsupported'; Reason = 'Vendor/GPU-dependent package and not resolved from the selected WinGet source on the tested endpoint.'; Recommendation = 'Install NVIDIA tools manually only on systems with NVIDIA GPU, or manage drivers with the vendor/OEM process.'; SuggestedAlternative = 'HWiNFO, CPU-Z, HWMonitor, Intel Driver & Support Assistant where applicable' }
    [pscustomobject]@{ Name = 'VMware Workstation Pro'; Category = 'Virtualization'; PreviousId = 'VMware.WorkstationPro'; Status = 'ManualUnsupported'; Reason = 'Broadcom/VMware package availability is inconsistent in WinGet and was not resolved from the selected source.'; Recommendation = 'Use VirtualBox from SetupHub or install VMware Workstation manually from the Broadcom/VMware portal when licensing/download access is available.'; SuggestedAlternative = 'VirtualBox' }
    [pscustomobject]@{ Name = 'VMware Workstation Player'; Category = 'Virtualization'; PreviousId = 'VMware.WorkstationPlayer'; Status = 'ManualUnsupported'; Reason = 'Legacy VMware Player availability is inconsistent and should not be part of default deployment profiles.'; Recommendation = 'Remove from standard profiles; use VirtualBox or manual VMware Workstation Pro installation.'; SuggestedAlternative = 'VirtualBox' }
)

$bloatwarePackages = @(
    @{ Name = 'Xbox Gaming App'; Id = 'Microsoft.GamingApp_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Home','Complete') }
    @{ Name = 'Xbox App'; Id = 'Microsoft.XboxApp_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Home','Complete') }
    @{ Name = 'Xbox TCUI'; Id = 'Microsoft.Xbox.TCUI_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Xbox Speech Overlay'; Id = 'Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Xbox Identity Provider'; Id = 'Microsoft.XboxIdentityProvider_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Xbox Gaming Overlay'; Id = 'Microsoft.XboxGamingOverlay_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Xbox Game Overlay'; Id = 'Microsoft.XboxGameOverlay_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Groove Music'; Id = 'Microsoft.ZuneMusic_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Movies & TV'; Id = 'Microsoft.ZuneVideo_8wekyb3d8bbwe'; Checked = $false; Profiles = @('Complete') }
    @{ Name = 'Feedback Hub'; Id = 'Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Tips'; Id = 'Microsoft.Getstarted_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = '3D Viewer'; Id = 'Microsoft.Microsoft3DViewer_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Solitaire'; Id = 'Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Paint 3D'; Id = 'Microsoft.MSPaint_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Weather'; Id = 'Microsoft.BingWeather_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Mail & Calendar'; Id = 'microsoft.windowscommunicationsapps_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Your Phone'; Id = 'Microsoft.YourPhone_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'People'; Id = 'Microsoft.People_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Pay'; Id = 'Microsoft.Wallet_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Maps'; Id = 'Microsoft.WindowsMaps_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'OneNote UWP'; Id = 'Microsoft.Office.OneNote_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Voice Recorder'; Id = 'Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Mixed Reality Portal'; Id = 'Microsoft.MixedReality.Portal_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Sticky Notes'; Id = 'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe'; Checked = $false; Profiles = @('Complete') }
    @{ Name = 'Get Help'; Id = 'Microsoft.GetHelp_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Cortana'; Id = 'Microsoft.549981C3F5F10_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Skype'; Id = 'Microsoft.SkypeApp_kzf8qxf38zg5c'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Power Automate'; Id = 'Microsoft.PowerAutomateDesktop_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Bing News'; Id = 'Microsoft.BingNews_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Teams Personal'; Id = 'MicrosoftTeams_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Microsoft Family'; Id = 'MicrosoftCorporationII.MicrosoftFamily_8wekyb3d8bbwe'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Quick Assist'; Id = 'MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe'; Checked = $false; Profiles = @('Complete') }
    @{ Name = 'Disney+'; Id = 'Disney.37853FC22B2CE_6rarf9sa4v8jt'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Clipchamp'; Id = 'Clipchamp.Clipchamp_yxz26nhyzhsrt'; Checked = $true; Profiles = @('Clean','Complete') }
    @{ Name = 'Office Hub'; Id = 'Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe'; Checked = $false; Profiles = @('Complete') }
)
#endregion

#region === WINGET BOOTSTRAP (NON-BLOCKING & RESILIENT) ===
function Install-WinGetBootstrap {
    param([bool]$ShowGui = $true)
    Repair-AppXEnvironment
    $splashWindow = $null
    $lblSplashStatus = $null
    $lblSplashDetail = $null
    $splashProgressBar = $null

    function Update-Splash {
        param([string]$Status, [string]$Detail = '', [double]$Progress = -1)
        if ($splashWindow) {
            if ($lblSplashStatus) { $lblSplashStatus.Text = $Status }
            if ($lblSplashDetail) { $lblSplashDetail.Text = $Detail }
            if ($splashProgressBar -and $Progress -ge 0) {
                $splashProgressBar.IsIndeterminate = $false
                $splashProgressBar.Value = $Progress
            }
            [System.Windows.Forms.Application]::DoEvents()
            try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch {}
        } else {
            Write-Host "$Status $Detail" -ForegroundColor Cyan
        }
    }

    if ($ShowGui) {
        $splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Preparazione ambiente..." Height="230" Width="500"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="ToolWindow" Background="#1e1e2e">
    <StackPanel VerticalAlignment="Center" Margin="25">
        <TextBlock x:Name="lblSplashStatus" Text="Inizializzazione WinGet..."
                   Foreground="#cdd6f4" FontSize="15" FontWeight="SemiBold"
                   HorizontalAlignment="Center" Margin="0,0,0,10" TextWrapping="Wrap" TextAlignment="Center"/>
        <ProgressBar x:Name="splashProgressBar" IsIndeterminate="True" Height="7" Foreground="#89b4fa"
                     Background="#313244" BorderThickness="0" Margin="0,0,0,10"/>
        <TextBlock x:Name="lblSplashDetail" Text="Verifica e installazione componenti necessari..."
                   Foreground="#a6adc8" FontSize="11" HorizontalAlignment="Center"
                   TextWrapping="Wrap" TextAlignment="Center"/>
    </StackPanel>
</Window>
"@
        try {
            $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($splashXaml))
            $splashWindow = [System.Windows.Markup.XamlReader]::Load($reader)
            $lblSplashStatus = $splashWindow.FindName('lblSplashStatus')
            $lblSplashDetail = $splashWindow.FindName('lblSplashDetail')
            $splashProgressBar = $splashWindow.FindName('splashProgressBar')
            $splashWindow.Show()
            Update-Splash -Status "Preparazione ambiente..." -Detail "Verifica preliminare dei prerequisiti..."
        } catch {}
    } else {
        Write-Host "Installazione e configurazione WinGet / Windows App Runtime in corso..." -ForegroundColor Cyan
    }

    try {
        $progressPreference = 'SilentlyContinue'
        Repair-AppXEnvironment
        
        # 1. Scarica e installa pacchetto ufficiale completo dipendenze WinGet (VCLibs 140.00 / UWPDesktop e WindowsAppRuntime)
        Update-Splash -Status "Configurazione componenti di base (1/4)" -Detail "Download dipendenze ufficiali Microsoft (VCLibs & WindowsAppRuntime)..."
        $dependencies = @()
        try {
            $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -UseBasicParsing -TimeoutSec 15
            $depsAsset = $latestRelease.assets | Where-Object { $_.name -match 'Dependencies\.zip$' } | Select-Object -First 1
            if ($depsAsset) {
                $depsZip = "$env:TEMP\DesktopAppInstaller_Dependencies.zip"
                $depsExtract = "$env:TEMP\winget_deps"
                Invoke-WebRequest -Uri $depsAsset.browser_download_url -OutFile $depsZip -UseBasicParsing -TimeoutSec 45
                if (Test-Path $depsZip) {
                    if (Test-Path $depsExtract) { Remove-Item -Path $depsExtract -Recurse -Force -ErrorAction SilentlyContinue }
                    Expand-Archive -Path $depsZip -DestinationPath $depsExtract -Force -ErrorAction SilentlyContinue
                    $x64Deps = Get-ChildItem -Path $depsExtract -Recurse -Filter '*.appx' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'x64' -or $_.FullName -match 'neutral' }
                    foreach ($dep in $x64Deps) {
                        try { Add-AppxPackage -Path $dep.FullName -ErrorAction SilentlyContinue } catch {}
                        $dependencies += $dep.FullName
                    }
                }
            }
        } catch {}

        # Fallback VCLibs standalone
        $vcLibsPath = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        if (-not (Test-Path $vcLibsPath)) {
            try {
                Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vcLibsPath -UseBasicParsing -TimeoutSec 15
                Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue
            } catch {}
        }
        if (Test-Path $vcLibsPath -and -not ($dependencies -contains $vcLibsPath)) { $dependencies += $vcLibsPath }
        Update-Splash -Status "Configurazione componenti di base (1/4)" -Detail "Componenti di base pronti."

        # 2. Microsoft Windows App SDK / Windows App Runtime 1.8+ (risolve l'errore 0x80073CF3 di DesktopAppInstaller)
        Update-Splash -Status "Installazione Windows App Runtime (2/4)" -Detail "Verifica Windows App Runtime..."
        $existingWasdk = Get-AppxPackage -Name '*WindowsAppRuntime.1.8*' -ErrorAction SilentlyContinue
        if ($existingWasdk) {
            Update-Splash -Status "Installazione Windows App Runtime (2/4)" -Detail "Windows App Runtime 1.8 già installato."
        } else {
            $wasdkInstaller = "$env:TEMP\WindowsAppRuntimeInstall-x64.exe"
            try {
                Update-Splash -Status "Installazione Windows App Runtime (2/4)" -Detail "Download Microsoft Windows App Runtime 1.8..."
                Invoke-WebRequest -Uri 'https://aka.ms/windowsappsdk/1.8/latest/windowsappruntimeinstall-x64.exe' -OutFile $wasdkInstaller -UseBasicParsing -TimeoutSec 25
                if (Test-Path $wasdkInstaller) {
                    Update-Splash -Status "Installazione Windows App Runtime (2/4)" -Detail "Esecuzione installatore runtime..."
                    $p = Start-Process -FilePath $wasdkInstaller -ArgumentList '--quiet --force' -PassThru -ErrorAction SilentlyContinue
                    if ($p) {
                        $maxSeconds = 12
                        $elapsed = 0
                        while (-not $p.HasExited -and $elapsed -lt $maxSeconds) {
                            Start-Sleep -Seconds 1
                            $elapsed++
                            Update-Splash -Status "Installazione Windows App Runtime (2/4)" -Detail "Installazione runtime in corso ($($maxSeconds - $elapsed)s)..."
                        }
                        if (-not $p.HasExited) {
                            try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
                        }
                    }
                }
            } catch {}
        }

        # 3. Microsoft DesktopAppInstaller (WinGet) da GitHub Releases
        Update-Splash -Status "Download WinGet Package Manager (3/4)" -Detail "Recupero dell'ultima release di DesktopAppInstaller..."
        try {
            $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -UseBasicParsing -TimeoutSec 15
            $msixBundleAsset = $latestRelease.assets | Where-Object { $_.name -match '\.msixbundle$' } | Select-Object -First 1
            $licenseAsset = $latestRelease.assets | Where-Object { $_.name -match 'License.*\.xml$' } | Select-Object -First 1
            $msixPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
            
            if ($msixBundleAsset) {
                Update-Splash -Status "Download WinGet Package Manager (3/4)" -Detail "Scaricamento del pacchetto DesktopAppInstaller..."
                Invoke-WebRequest -Uri $msixBundleAsset.browser_download_url -OutFile $msixPath -UseBasicParsing -TimeoutSec 60

                Repair-AppXEnvironment
                if ($licenseAsset) {
                    $licensePath = "$env:TEMP\WinGet_License.xml"
                    Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath -UseBasicParsing -TimeoutSec 15
                    try {
                        if ($dependencies.Count -gt 0) {
                            Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -DependencyPackagePath $dependencies -ErrorAction Stop | Out-Null
                        } else {
                            Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -ErrorAction Stop | Out-Null
                        }
                    } catch {
                        Repair-AppXEnvironment
                        if ($dependencies.Count -gt 0) {
                            Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -DependencyPackagePath $dependencies -ErrorAction SilentlyContinue | Out-Null
                        } else {
                            Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
                Update-Splash -Status "Registrazione WinGet nel sistema (3/4)" -Detail "Installazione del pacchetto DesktopAppInstaller..."
                try {
                    if ($dependencies.Count -gt 0) {
                        Add-AppxPackage -Path $msixPath -DependencyPath $dependencies -ForceApplicationShutdown -ErrorAction Stop
                    } else {
                        Add-AppxPackage -Path $msixPath -ForceApplicationShutdown -ErrorAction Stop
                    }
                } catch {
                    Repair-AppXEnvironment
                    Start-Sleep -Seconds 1
                    if ($dependencies.Count -gt 0) {
                        Add-AppxPackage -Path $msixPath -DependencyPath $dependencies -ForceApplicationShutdown -ErrorAction SilentlyContinue
                    } else {
                        Add-AppxPackage -Path $msixPath -ForceApplicationShutdown -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {}
        
        # 4. Aggiorna PATH e reimposta sorgenti WinGet
        Update-Splash -Status "Finalizzazione ambiente (4/4)" -Detail "Aggiornamento variabili d'ambiente e sorgenti..."
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User') + ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
        [void](Resolve-WinGetEnvironment)
        Start-Sleep -Seconds 1
        try {
            [void](Invoke-WinGetCli -Arguments 'source reset --force')
        } catch {}
    } catch {
        $script:WinGetWarningMsg = $_.Exception.Message
        Write-Warning "Avviso bootstrap WinGet: $($_.Exception.Message)"
    }
    
    if ($splashWindow) { try { $splashWindow.Close() } catch {} }
    Start-Sleep -Milliseconds 300
    
    $script:WinGetAvailable = Test-WinGetAvailable
}

# Run bootstrap check gracefully (never aborts or exits)
if (-not (Test-WinGetAvailable)) {
    Install-WinGetBootstrap -ShowGui (-not $NoGui)
} else {
    $script:WinGetAvailable = $true
}
#endregion

#region === SHARED DEPLOYMENT SCRIPTBLOCK ===
$deploymentScript = {
    $successInstall = 0; $failedInstall = 0; $successBloat = 0; $failedBloat = 0; $skippedBloat = 0; $currentOp = 0
    $results = New-Object System.Collections.Generic.List[object]
    $sessionStart = Get-Date

    function TT([string]$Key) { return $textTable[$Key] }
    function Invoke-UIUpdate { param([scriptblock]$Code) if ($dispatcher) { $dispatcher.Invoke([Action]$Code, [System.Windows.Threading.DispatcherPriority]::Background) } else { & $Code } }
    function Write-LogLine {
        param([string]$Line)
        if ($txtLog -and $dispatcher) {
            Invoke-UIUpdate { $txtLog.AppendText("$Line`r`n"); $txtLog.ScrollToEnd() }.GetNewClosure()
        } else {
            if ($Line -match '^\[OK\]') { Write-Host $Line -ForegroundColor Green }
            elseif ($Line -match '^\[(ERRORE|ERROR)\]') { Write-Host $Line -ForegroundColor Red }
            elseif ($Line -match '^\[(Saltato|Skipped)\]') { Write-Host $Line -ForegroundColor Yellow }
            elseif ($Line -match '^\[>\]') { Write-Host $Line -ForegroundColor Cyan }
            elseif ($Line -match '^=') { Write-Host $Line -ForegroundColor DarkGray }
            else { Write-Host $Line }
        }
    }
    function Update-Progress {
        param([int]$Step,[string]$Label)
        $pct = [math]::Round(($Step / [math]::Max(1, $totalOps)) * 100)
        if ($progressBar -and $lblProgress -and $lblCurrentOp -and $dispatcher) {
            Invoke-UIUpdate { $progressBar.Value = $pct; $lblProgress.Text = "$pct%"; $lblCurrentOp.Text = $Label }.GetNewClosure()
        } else {
            Write-Progress -Activity "$appName v$appVersion" -Status $Label -PercentComplete $pct
        }
    }
    function Set-Status {
        param($Labels,[int]$Idx,[string]$Emoji)
        if ($Labels -and $Labels.Count -gt $Idx -and $dispatcher) {
            Invoke-UIUpdate { $Labels[$Idx].Text = $Emoji }.GetNewClosure()
        }
    }

    function ConvertTo-SafeFileName {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return 'unknown' }
        $invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
        $regex = "[{0}]" -f [Regex]::Escape($invalid)
        return (($Value -replace $regex, '_') -replace '[^a-zA-Z0-9._-]', '_')
    }

    function Get-CleanWinGetLines {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
        return @($Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object {
            $_.Length -gt 0 -and
            $_ -notmatch '^[-\\|/]+$' -and
            $_ -notmatch '^\s*[Γû\u2588\u2592\u2591\u2593#=\. ]+\s*(\d+%|\d+(\.\d+)?\s*(KB|MB|GB)\s*/\s*\d+(\.\d+)?\s*(KB|MB|GB)).*$' -and
            $_ -notmatch '^\s*Visible:\s*\d+%\s*-\s*\d+%\s*$'
        })
    }

    function Write-WinGetOutput {
        param($Result)
        $lines = @(Get-CleanWinGetLines (($Result.StdOut + "`n" + $Result.StdErr)))
        foreach ($line in $lines) { Write-LogLine "    $line" }
    }

    function Get-MeaningfulMessage {
        param([string]$StdOut,[string]$StdErr,[int]$ExitCode)
        $combined = @(Get-CleanWinGetLines (($StdErr + "`n" + $StdOut)))
        $preferred = $combined | Where-Object { $_ -match '(?i)(error|errore|failed|failure|not found|no package|no installed package|no applicable|hash|installer|license|agreement|cancel|denied|access|requires|reboot|already installed|non trovato|impossibile|annull)' }
        if ($preferred) { return (($preferred | Select-Object -First 5) -join ' | ') }
        if ($combined) { return (($combined | Select-Object -Last 5) -join ' | ') }
        return "ExitCode=$ExitCode without textual output"
    }

    function Repair-AppXEnvironment {
        try {
            $requiredDirs = @(
                "$env:SystemRoot\AppReadiness",
                "$env:SystemRoot\AUInstallAgent",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps"
            )
            foreach ($d in $requiredDirs) {
                if (-not (Test-Path $d)) {
                    try { New-Item -Path $d -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
            }
            $services = @('AppReadiness', 'AppXSvc', 'ClipSVC', 'InstallService', 'wuauserv')
            foreach ($s in $services) {
                try {
                    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                    if ($svc) {
                        if ($svc.StartType -eq 'Disabled') {
                            Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                        }
                        if ($svc.Status -ne 'Running') {
                            Start-Service -Name $s -ErrorAction SilentlyContinue
                        }
                    }
                } catch {}
            }
        } catch {}
    }

    function Get-WinGetExecutablePath {
        try {
            $appx = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            if ($appx -and $appx.InstallLocation) {
                $exe = Join-Path $appx.InstallLocation 'winget.exe'
                if (Test-Path $exe) { return $exe }
            }
        } catch {}
        $localApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (Test-Path $localApps) { return $localApps }
        return 'winget'
    }

    function Invoke-WinGetCli {
        param([string]$Arguments)
        
        # 1. First try: standard cmd /c winget
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$env:ComSpec"
        $psi.Arguments = "/d /c winget $Arguments"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        try {
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        } catch {}

        $stdout = ''
        $stderr = ''
        $exitCode = -1

        try {
            $proc = [System.Diagnostics.Process]::Start($psi)
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()
            $exitCode = $proc.ExitCode
        } catch {
            $stderr = $_.Exception.Message
        }

        # If cmd /c winget produced output or completed with 0, and didn't report unrecognized command
        $notRecognized = ($stderr -match '(?i)(not recognized|non . riconosciuto|cannot find the file|impossibile trovare)')
        if (-not $notRecognized -and (-not [string]::IsNullOrWhiteSpace($stdout) -or $exitCode -eq 0)) {
            return [pscustomobject]@{
                ExitCode = $exitCode
                StdOut = $stdout
                StdErr = $stderr
            }
        }

        # 2. Second try: find winget in LocalAppData or WindowsApps and invoke via cmd /c "<path>"
        $candidatePaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        )
        try {
            $appx = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            if ($appx -and $appx.InstallLocation) {
                $candidatePaths += (Join-Path $appx.InstallLocation 'winget.exe')
            }
        } catch {}
        try {
            $userProfiles = Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue
            if ($userProfiles) {
                foreach ($u in $userProfiles) {
                    $candidatePaths += "$($u.FullName)\AppData\Local\Microsoft\WindowsApps\winget.exe"
                }
            }
        } catch {}

        foreach ($cPath in $candidatePaths) {
            if ($cPath -and (Test-Path $cPath)) {
                try {
                    $psiPath = New-Object System.Diagnostics.ProcessStartInfo
                    $psiPath.FileName = "$env:ComSpec"
                    $psiPath.Arguments = "/d /c `"`"$cPath`" $Arguments`""
                    $psiPath.RedirectStandardOutput = $true
                    $psiPath.RedirectStandardError = $true
                    $psiPath.UseShellExecute = $false
                    $psiPath.CreateNoWindow = $true
                    try {
                        $psiPath.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                        $psiPath.StandardErrorEncoding = [System.Text.Encoding]::UTF8
                    } catch {}
                    $pPath = [System.Diagnostics.Process]::Start($psiPath)
                    $outPath = $pPath.StandardOutput.ReadToEnd()
                    $errPath = $pPath.StandardError.ReadToEnd()
                    $pPath.WaitForExit()
                    if (-not [string]::IsNullOrWhiteSpace($outPath) -or $pPath.ExitCode -eq 0) {
                        return [pscustomobject]@{
                            ExitCode = $pPath.ExitCode
                            StdOut = $outPath
                            StdErr = $errPath
                        }
                    }
                } catch {}
            }
        }

        # 3. Third try: PowerShell wrapper
        try {
            $psiPs = New-Object System.Diagnostics.ProcessStartInfo
            $psiPs.FileName = 'powershell.exe'
            $psiPs.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & winget $Arguments }`""
            $psiPs.RedirectStandardOutput = $true
            $psiPs.RedirectStandardError = $true
            $psiPs.UseShellExecute = $false
            $psiPs.CreateNoWindow = $true
            try {
                $psiPs.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                $psiPs.StandardErrorEncoding = [System.Text.Encoding]::UTF8
            } catch {}
            $pPs = [System.Diagnostics.Process]::Start($psiPs)
            $outPs = $pPs.StandardOutput.ReadToEnd()
            $errPs = $pPs.StandardError.ReadToEnd()
            $pPs.WaitForExit()
            if (-not [string]::IsNullOrWhiteSpace($outPs) -or $pPs.ExitCode -eq 0) {
                return [pscustomobject]@{
                    ExitCode = $pPs.ExitCode
                    StdOut = $outPs
                    StdErr = $errPs
                }
            }
        } catch {}

        return [pscustomobject]@{
            ExitCode = $exitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }

    function New-DeploymentRestorePoint {
        param([string]$Description = 'SetupHub Pre-Deployment')
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
            try {
                $srPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
                if (Test-Path $srPath) {
                    Set-ItemProperty -Path $srPath -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            } catch {}
            Checkpoint-Computer -Description $Description -RestorePointType 'APPLICATION_INSTALL' -ErrorAction Stop | Out-Null
            return [pscustomobject]@{ Success = $true; Message = 'OK' }
        } catch {
            return [pscustomobject]@{ Success = $false; Message = $_.Exception.Message }
        }
    }

    function Invoke-WinGetProcess {
        param(
            [string]$Action,
            [string]$Id,
            [bool]$SkipSilent,
            [string]$Source = 'winget',
            [string]$PackageName = ''
        )

        if (-not (Test-Path $wingetLogFolder)) { New-Item -Path $wingetLogFolder -ItemType Directory -Force | Out-Null }
        $nameForFile = $(if ($PackageName) { $PackageName } else { $Id })
        $safeName = ConvertTo-SafeFileName $nameForFile
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $wingetLogPath = Join-Path $wingetLogFolder ("${stamp}_${Action}_${safeName}.log")

        $argsList = if ($Action -eq 'show') {
            "show --id `"$Id`" --exact --source `"$Source`" --accept-source-agreements --disable-interactivity"
        } elseif ($Action -eq 'install') {
            "install --id `"$Id`" --exact --source `"$Source`" --accept-package-agreements --accept-source-agreements --disable-interactivity --force --verbose-logs --log `"$wingetLogPath`""
        } else {
            "uninstall --id `"$Id`" --exact --accept-source-agreements --disable-interactivity --force --verbose-logs --log `"$wingetLogPath`""
        }
        if ($Action -eq 'install' -and -not $SkipSilent) { $argsList += ' --silent' }

        $cliResult = Invoke-WinGetCli -Arguments $argsList
        $stdout = $cliResult.StdOut
        $stderr = $cliResult.StdErr
        $exitCode = $cliResult.ExitCode
        $message = Get-MeaningfulMessage -StdOut $stdout -StdErr $stderr -ExitCode $exitCode

        return [pscustomobject]@{
            ExitCode = $exitCode
            StdOut = $stdout
            StdErr = $stderr
            Output = (($stdout + "`n" + $stderr).Trim())
            Message = $message
            Args = $argsList
            Source = $Source
            LogPath = $wingetLogPath
        }
    }

    function Test-IsWindows11 {
        try { return ([int](Get-CimInstance Win32_OperatingSystem).BuildNumber -ge 22000) } catch { return $false }
    }

    function Invoke-ProcessCapture {
        param([string]$FileName,[string]$Arguments)
        if ($FileName -eq 'winget' -or $FileName -eq 'winget.exe') {
            $cli = Invoke-WinGetCli -Arguments $Arguments
            return [pscustomobject]@{ ExitCode=$cli.ExitCode; StdOut=$cli.StdOut; StdErr=$cli.StdErr; Args=$Arguments }
        }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FileName
        $psi.Arguments = $Arguments
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8 } catch {}
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        try {
            $p = [System.Diagnostics.Process]::Start($psi)
            $stdout = $p.StandardOutput.ReadToEnd()
            $stderr = $p.StandardError.ReadToEnd()
            $p.WaitForExit()
            return [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$stdout; StdErr=$stderr; Args=$Arguments }
        } catch {
            return [pscustomobject]@{ ExitCode=-1; StdOut=''; StdErr=$_.Exception.Message; Args=$Arguments }
        }
    }

    function Test-WinGetCatalogPackage {
        param($Package)
        $source = if ($Package.Source) { [string]$Package.Source } else { 'winget' }
        $idsToTry = New-Object System.Collections.Generic.List[string]
        [void]$idsToTry.Add([string]$Package.Id)
        foreach ($alt in @($Package.AlternateIds)) {
            if ($alt -and -not $idsToTry.Contains([string]$alt)) { [void]$idsToTry.Add([string]$alt) }
        }
        $resolvedId = ''
        $last = $null
        foreach ($candidate in $idsToTry) {
            $last = Invoke-WinGetProcess -Action 'show' -Id $candidate -SkipSilent $true -Source $source -PackageName $Package.Name
            if ($last.ExitCode -eq 0) { $resolvedId = $candidate; break }
        }
        $status = if ($resolvedId) { 'Available' } else { 'NotAvailable' }
        return [pscustomobject]@{
            CheckedAt=(Get-Date).ToString('s'); Name=$Package.Name; Category=$Package.Category; PrimaryId=$Package.Id;
            ResolvedId=$resolvedId; AlternateIds=(@($Package.AlternateIds) -join ', '); Source=$source; Status=$status;
            ExitCode=$(if ($last) { $last.ExitCode } else { '' }); Message=$(if ($last) { $last.Message } else { '' }); Notes=$Package.Notes
        }
    }

    function Invoke-AppxDebloat {
        param([string]$PackageFamilyName,[string]$PackageName,[string]$FriendlyName)
        Repair-AppXEnvironment
        $installed = @()
        $provisioned = @()
        $messages = New-Object System.Collections.Generic.List[string]
        try {
            $installed = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {
                $_.PackageFamilyName -eq $PackageFamilyName -or $_.Name -eq $PackageName -or $_.PackageFullName -like "$PackageName*"
            })
        } catch { $messages.Add("Get-AppxPackage failed: $($_.Exception.Message)") | Out-Null }
        try {
            $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -eq $PackageName -or $_.PackageName -like "$PackageName*"
            })
        } catch { $messages.Add("Get-AppxProvisionedPackage failed: $($_.Exception.Message)") | Out-Null }
        if ($installed.Count -eq 0 -and $provisioned.Count -eq 0) {
            return [pscustomobject]@{ ExitCode=-1978335212; Status='NotInstalled'; Message=(TT 'NotInstalled'); Args="Appx removal for $PackageFamilyName"; LogPath=''; StdOut='No installed/provisioned Appx package found.'; StdErr='' }
        }
        $removed = 0; $failed = 0
        foreach ($pkg in $installed) {
            try {
                try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop }
                catch { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
                $removed++; $messages.Add("Removed installed Appx: $($pkg.PackageFullName)") | Out-Null
            } catch { $failed++; $messages.Add("Failed installed Appx: $($pkg.PackageFullName) - $($_.Exception.Message)") | Out-Null }
        }
        foreach ($pkg in $provisioned) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null; $removed++; $messages.Add("Removed provisioned Appx: $($pkg.PackageName)") | Out-Null }
            catch { $failed++; $messages.Add("Failed provisioned Appx: $($pkg.PackageName) - $($_.Exception.Message)") | Out-Null }
        }
        $message = ($messages -join ' | ')
        if ($failed -gt 0 -and $removed -eq 0) { return [pscustomobject]@{ ExitCode=1; Status='Failed'; Message=$message; Args="Appx removal for $PackageFamilyName"; LogPath=''; StdOut=$message; StdErr=$message } }
        return [pscustomobject]@{ ExitCode=0; Status='Success'; Message=$message; Args="Appx removal for $PackageFamilyName"; LogPath=''; StdOut=$message; StdErr='' }
    }

    function Get-InstalledSoftwareInventory {
        $paths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $items = foreach ($path in $paths) {
            Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | ForEach-Object {
                [pscustomobject]@{
                    Name=$_.DisplayName; Version=$_.DisplayVersion; Publisher=$_.Publisher; InstallDate=$_.InstallDate;
                    EstimatedSizeMB=$(if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize/1024,2) } else { $null }); RegistryPath=$path
                }
            }
        }
        return @($items | Sort-Object Name,Version -Unique)
    }

    function Get-SystemInventory {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)
        $mem = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Select-Object Manufacturer,PartNumber,SerialNumber,Capacity,Speed,ConfiguredClockSpeed,DeviceLocator)
        $mem2 = @($mem | ForEach-Object { [pscustomobject]@{ Manufacturer=$_.Manufacturer; PartNumber=($_.PartNumber -as [string]).Trim(); SerialNumber=$_.SerialNumber; CapacityGB=[math]::Round($_.Capacity/1GB,2); Speed=$_.Speed; ConfiguredClockSpeed=$_.ConfiguredClockSpeed; DeviceLocator=$_.DeviceLocator } })
        $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Model=$_.Model; InterfaceType=$_.InterfaceType; MediaType=$_.MediaType; SizeGB=[math]::Round($_.Size/1GB,2); SerialNumber=($_.SerialNumber -as [string]).Trim() } })
        $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ DeviceID=$_.DeviceID; VolumeName=$_.VolumeName; FileSystem=$_.FileSystem; SizeGB=[math]::Round($_.Size/1GB,2); FreeGB=[math]::Round($_.FreeSpace/1GB,2); FreePercent=$(if ($_.Size) { [math]::Round(($_.FreeSpace/$_.Size)*100,2) } else { $null }) } })
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name,DriverVersion,VideoProcessor,AdapterRAM)
        $net = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Description=$_.Description; MACAddress=$_.MACAddress; DHCPEnabled=$_.DHCPEnabled; IPAddress=(@($_.IPAddress) -join ', '); DNSServerSearchOrder=(@($_.DNSServerSearchOrder) -join ', ') } })
        $tpmInfo = $null; try { $tpmInfo = Get-Tpm -ErrorAction Stop | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated,ManufacturerIdTxt,ManufacturerVersion } catch { $tpmInfo = [pscustomobject]@{ TpmPresent='Unavailable'; Error=$_.Exception.Message } }
        $secureBoot = $null; try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $secureBoot = 'Unavailable or Legacy BIOS' }
        $defender = $null; try { $defender = Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntispywareEnabled,AMEngineVersion,AntivirusSignatureVersion } catch { $defender = [pscustomobject]@{ Status='Unavailable'; Error=$_.Exception.Message } }
        $wingetVersion = ''; try { $wingetVersion = (& winget --version 2>$null) } catch { $wingetVersion = 'Unavailable' }
        $wingetSources = ''; try { $wingetSources = (Invoke-ProcessCapture -FileName 'winget' -Arguments 'source list').StdOut } catch { $wingetSources = 'Unavailable' }
        $software = @(Get-InstalledSoftwareInventory)
        $appx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name,PackageFamilyName,Version,Publisher)
        return [pscustomobject]@{
            CollectedAt=(Get-Date).ToString('s')
            Computer=[pscustomobject]@{ ComputerName=$env:COMPUTERNAME; User=$env:USERNAME; Domain=$cs.Domain; Manufacturer=$cs.Manufacturer; Model=$cs.Model; SystemType=$cs.SystemType; TotalPhysicalMemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2); IsWindows11=(Test-IsWindows11) }
            OS=[pscustomobject]@{ Caption=$os.Caption; Version=$os.Version; BuildNumber=$os.BuildNumber; Architecture=$os.OSArchitecture; InstallDate=$os.InstallDate; LastBootUpTime=$os.LastBootUpTime }
            BIOS=[pscustomobject]@{ Manufacturer=$bios.Manufacturer; SMBIOSBIOSVersion=$bios.SMBIOSBIOSVersion; SerialNumber=$bios.SerialNumber; ReleaseDate=$bios.ReleaseDate }
            CPU=$cpu; MemoryModules=$mem2; Disks=$disks; Volumes=$volumes; GPU=$gpus; Network=$net
            Security=[pscustomobject]@{ SecureBoot=$secureBoot; TPM=$tpmInfo; Defender=$defender }
            Runtime=[pscustomobject]@{ PowerShell=$PSVersionTable.PSVersion.ToString(); WinGet=$wingetVersion; WinGetSources=$wingetSources }
            InstalledSoftware=$software; WindowsApps=$appx
        }
    }

    # === ASYNCHRONOUS SYSTEM INVENTORY (KICK OFF IN BACKGROUND) ===
    $invPowerShell = $null
    $invHandle = $null
    if ($includeInventory) {
        try {
            $invPowerShell = [powershell]::Create()
            $invPowerShell.AddScript({
                function Test-IsWindows11 {
                    try { return ([int](Get-CimInstance Win32_OperatingSystem).BuildNumber -ge 22000) } catch { return $false }
                }
                function Get-InstalledSoftwareInventory {
                    $paths = @(
                        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
                    )
                    $items = foreach ($path in $paths) {
                        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | ForEach-Object {
                            [pscustomobject]@{
                                Name=$_.DisplayName; Version=$_.DisplayVersion; Publisher=$_.Publisher; InstallDate=$_.InstallDate;
                                EstimatedSizeMB=$(if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize/1024,2) } else { $null }); RegistryPath=$path
                            }
                        }
                    }
                    return @($items | Sort-Object Name,Version -Unique)
                }
                $os = Get-CimInstance Win32_OperatingSystem
                $cs = Get-CimInstance Win32_ComputerSystem
                $bios = Get-CimInstance Win32_BIOS
                $cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)
                $mem = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Select-Object Manufacturer,PartNumber,SerialNumber,Capacity,Speed,ConfiguredClockSpeed,DeviceLocator)
                $mem2 = @($mem | ForEach-Object { [pscustomobject]@{ Manufacturer=$_.Manufacturer; PartNumber=($_.PartNumber -as [string]).Trim(); SerialNumber=$_.SerialNumber; CapacityGB=[math]::Round($_.Capacity/1GB,2); Speed=$_.Speed; ConfiguredClockSpeed=$_.ConfiguredClockSpeed; DeviceLocator=$_.DeviceLocator } })
                $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Model=$_.Model; InterfaceType=$_.InterfaceType; MediaType=$_.MediaType; SizeGB=[math]::Round($_.Size/1GB,2); SerialNumber=($_.SerialNumber -as [string]).Trim() } })
                $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ DeviceID=$_.DeviceID; VolumeName=$_.VolumeName; FileSystem=$_.FileSystem; SizeGB=[math]::Round($_.Size/1GB,2); FreeGB=[math]::Round($_.FreeSpace/1GB,2); FreePercent=$(if ($_.Size) { [math]::Round(($_.FreeSpace/$_.Size)*100,2) } else { $null }) } })
                $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name,DriverVersion,VideoProcessor,AdapterRAM)
                $net = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Description=$_.Description; MACAddress=$_.MACAddress; DHCPEnabled=$_.DHCPEnabled; IPAddress=(@($_.IPAddress) -join ', '); DNSServerSearchOrder=(@($_.DNSServerSearchOrder) -join ', ') } })
                $tpmInfo = $null; try { $tpmInfo = Get-Tpm -ErrorAction Stop | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated,ManufacturerIdTxt,ManufacturerVersion } catch { $tpmInfo = [pscustomobject]@{ TpmPresent='Unavailable'; Error=$_.Exception.Message } }
                $secureBoot = $null; try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $secureBoot = 'Unavailable or Legacy BIOS' }
                $defender = $null; try { $defender = Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntispywareEnabled,AMEngineVersion,AntivirusSignatureVersion } catch { $defender = [pscustomobject]@{ Status='Unavailable'; Error=$_.Exception.Message } }
                $software = @(Get-InstalledSoftwareInventory)
                $appx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name,PackageFamilyName,Version,Publisher)
                return [pscustomobject]@{
                    CollectedAt=(Get-Date).ToString('s')
                    Computer=[pscustomobject]@{ ComputerName=$env:COMPUTERNAME; User=$env:USERNAME; Domain=$cs.Domain; Manufacturer=$cs.Manufacturer; Model=$cs.Model; SystemType=$cs.SystemType; TotalPhysicalMemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2); IsWindows11=(Test-IsWindows11) }
                    OS=[pscustomobject]@{ Caption=$os.Caption; Version=$os.Version; BuildNumber=$os.BuildNumber; Architecture=$os.OSArchitecture; InstallDate=$os.InstallDate; LastBootUpTime=$os.LastBootUpTime }
                    BIOS=[pscustomobject]@{ Manufacturer=$bios.Manufacturer; SMBIOSBIOSVersion=$bios.SMBIOSBIOSVersion; SerialNumber=$bios.SerialNumber; ReleaseDate=$bios.ReleaseDate }
                    CPU=$cpu; MemoryModules=$mem2; Disks=$disks; Volumes=$volumes; GPU=$gpus; Network=$net
                    Security=[pscustomobject]@{ SecureBoot=$secureBoot; TPM=$tpmInfo; Defender=$defender }
                    Runtime=[pscustomobject]@{ PowerShell=$PSVersionTable.PSVersion.ToString() }
                    InstalledSoftware=$software; WindowsApps=$appx
                }
            }) | Out-Null
            $invHandle = $invPowerShell.BeginInvoke()
        } catch {}
    }

    # === RESTORE POINT (OPTIONAL) ===
    if ($createRestorePoint) {
        Write-LogLine '========================================='
        Write-LogLine "  $(TT 'RestorePointCreating')"
        Write-LogLine '========================================='
        $rpRes = New-DeploymentRestorePoint -Description "$appName ($selectedProfile)"
        if ($rpRes.Success) {
            Write-LogLine "[OK] $(TT 'RestorePointOk')"
        } else {
            Write-LogLine "[$(TT 'Warning')] $(TT 'RestorePointFailed'): $($rpRes.Message)"
        }
        Write-LogLine ''
    }

    # === SOURCE CHECK ===
    Write-LogLine '========================================='
    Write-LogLine "  $(TT 'SourceCheck')"
    Write-LogLine '========================================='
    try {
        $srcRes = Invoke-WinGetCli -Arguments 'source list'
        if ($srcRes.StdOut) { $srcRes.StdOut -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { Write-LogLine "    $_" } }
        if ($srcRes.StdErr) { Write-LogLine "    STDERR: $($srcRes.StdErr)" }
    } catch { Write-LogLine "[$(TT 'Error')] Source check: $($_.Exception.Message)" }
    Write-LogLine ''

    # === PARALLEL CATALOG VALIDATION (PHASE 0) ===
    $catalogResults = New-Object System.Collections.Generic.List[object]
    if ($validateCatalog -and $catalogPackages.Count -gt 0) {
        Write-LogLine '========================================='
        Write-LogLine "  $(TT 'CatalogPhase') (Parallel Multi-Thread)"
        Write-LogLine '========================================='
        
        $maxThreads = [math]::Min(10, [Environment]::ProcessorCount * 2)
        $valPool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
        $valPool.ApartmentState = 'MTA'
        $valPool.Open()

        $valWorker = {
            param($Package)
            $source = if ($Package.Source) { [string]$Package.Source } else { 'winget' }
            $idsToTry = New-Object System.Collections.Generic.List[string]
            [void]$idsToTry.Add([string]$Package.Id)
            foreach ($alt in @($Package.AlternateIds)) {
                if ($alt -and -not $idsToTry.Contains([string]$alt)) { [void]$idsToTry.Add([string]$alt) }
            }
            $resolvedId = ''
            $last = $null
            foreach ($candidate in $idsToTry) {
                $argsList = "show --id `"$candidate`" --exact --source `"$source`" --accept-source-agreements --disable-interactivity"
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "$env:ComSpec"
                $psi.Arguments = "/d /c winget $argsList"
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                try {
                    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
                } catch {}

                try {
                    $p = [System.Diagnostics.Process]::Start($psi)
                    $out = $p.StandardOutput.ReadToEnd()
                    $err = $p.StandardError.ReadToEnd()
                    $p.WaitForExit()
                    $last = [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$out; StdErr=$err; Message=$(if ($p.ExitCode -eq 0) { 'OK' } else { ($err + " " + $out).Trim() }) }
                    if ($p.ExitCode -eq 0) { $resolvedId = $candidate; break }
                } catch {
                    $last = [pscustomobject]@{ ExitCode=-1; StdOut=''; StdErr=$_.Exception.Message; Message=$_.Exception.Message }
                }
            }
            $status = if ($resolvedId) { 'Available' } else { 'NotAvailable' }
            return [pscustomobject]@{
                CheckedAt=(Get-Date).ToString('s'); Name=$Package.Name; Category=$Package.Category; PrimaryId=$Package.Id;
                ResolvedId=$resolvedId; AlternateIds=(@($Package.AlternateIds) -join ', '); Source=$source; Status=$status;
                ExitCode=$(if ($last) { $last.ExitCode } else { '' }); Message=$(if ($last) { $last.Message } else { '' }); Notes=$Package.Notes
            }
        }

        $valTasks = New-Object System.Collections.Generic.List[object]
        foreach ($pkg in $catalogPackages) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $valPool
            $ps.AddScript($valWorker).AddArgument($pkg) | Out-Null
            $handle = $ps.BeginInvoke()
            $valTasks.Add([pscustomobject]@{ PS=$ps; Handle=$handle; Name=$pkg.Name })
        }

        $completedCount = 0
        while ($completedCount -lt $valTasks.Count) {
            for ($i = 0; $i -lt $valTasks.Count; $i++) {
                $vt = $valTasks[$i]
                if ($vt -and $vt.Handle.IsCompleted) {
                    $check = $vt.PS.EndInvoke($vt.Handle)[0]
                    $vt.PS.Dispose()
                    $valTasks[$i] = $null
                    $completedCount++
                    $currentOp++
                    Update-Progress -Step $currentOp -Label "$(TT 'PackageCheck'): $($check.Name)"
                    $catalogResults.Add($check) | Out-Null
                    if ($check.Status -eq 'Available') { Write-LogLine "[OK] $($check.Name) -> $($check.ResolvedId)" }
                    else { Write-LogLine "[$(TT 'Error')] $($check.Name) -> $($check.PrimaryId) non disponibile. $($check.Message)" }
                }
            }
            Start-Sleep -Milliseconds 40
        }

        $valPool.Close()
        $valPool.Dispose()

        $catAvailable = @($catalogResults | Where-Object Status -eq 'Available').Count
        $catMissing = @($catalogResults | Where-Object Status -ne 'Available').Count
        Write-LogLine "Catalogo validato: $catAvailable disponibili / $catMissing non disponibili"
        Write-LogLine ''
    }

    if ($manualUnsupportedPackages -and @($manualUnsupportedPackages).Count -gt 0) {
        Write-LogLine '========================================='
        Write-LogLine "  $(TT 'ManualUnsupportedPhase')"
        Write-LogLine '========================================='
        foreach ($manual in @($manualUnsupportedPackages)) {
            Write-LogLine "[MANUAL] $($manual.Name) - $($manual.Reason)"
        }
        Write-LogLine ''
    }

    $systemInventory = $null
    $catalogAvailability = @{}
    if ($catalogResults -and @($catalogResults).Count -gt 0) {
        foreach ($cr in @($catalogResults)) {
            if ($cr.PrimaryId) { $catalogAvailability[[string]$cr.PrimaryId] = $cr }
        }
    }

    # === SYSTEM INVENTORY PHASE ===
    if ($includeInventory) {
        Write-LogLine '========================================='
        Write-LogLine "  $(TT 'InventoryPhase')"
        Write-LogLine '========================================='
        try {
            if ($invPowerShell -and $invHandle) {
                $rawInv = $invPowerShell.EndInvoke($invHandle)[0]
                $invPowerShell.Dispose()
                $wingetVersion = ''; try { $wingetVersion = (& winget --version 2>$null) } catch { $wingetVersion = 'Unavailable' }
                $wingetSources = ''; try { $wingetSources = (Invoke-ProcessCapture -FileName 'winget' -Arguments 'source list').StdOut } catch { $wingetSources = 'Unavailable' }
                $rawInv.Runtime.WinGet = $wingetVersion
                $rawInv.Runtime.WinGetSources = $wingetSources
                $systemInventory = $rawInv
            } else {
                $systemInventory = Get-SystemInventory
            }
            Write-LogLine "Inventario raccolto: $($systemInventory.Computer.Manufacturer) $($systemInventory.Computer.Model), OS build $($systemInventory.OS.BuildNumber), software rilevati: $(@($systemInventory.InstalledSoftware).Count)"
        } catch { Write-LogLine "[$(TT 'Error')] Inventory: $($_.Exception.Message)" }
        Write-LogLine ''
    }

    # === INSTALL PHASE (PHASE 1) ===
    Write-LogLine '========================================='
    Write-LogLine "  $(TT 'InstallPhase')"
    Write-LogLine '========================================='
    foreach ($item in $selectedInstalls) {
        $currentOp++
        $opLabel = "$(TT 'Installing'): $($item.Name)..."
        Update-Progress -Step $currentOp -Label $opLabel
        Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x1F504)
        Write-LogLine "[>] $(TT 'Installing'): $($item.Name) ($($item.Id))"
        $start = Get-Date
        try {
            $source = if ($item.Source) { [string]$item.Source } else { 'winget' }
            $catalogEntry = $null
            if ($catalogAvailability.ContainsKey([string]$item.Id)) { $catalogEntry = $catalogAvailability[[string]$item.Id] }
            if ($catalogEntry -and $catalogEntry.Status -ne 'Available') {
                Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x26A0)
                Write-LogLine "[$(TT 'Skipped')] $($item.Name) - pacchetto non disponibile dopo validazione catalogo."
                if ($item.Notes) { Write-LogLine "    Notes: $($item.Notes)" }
                $results.Add([pscustomobject]@{
                    Timestamp=(Get-Date).ToString('s'); Action='Install'; Name=$item.Name; Id=$item.Id; ResolvedId=''; Category=$item.Category; Source=$source; Method='WinGet';
                    Status='SkippedNotAvailable'; ExitCode=$catalogEntry.ExitCode; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2);
                    Message=$catalogEntry.Message; Command="show --id `"$($item.Id)`" --exact --source `"$source`" --accept-source-agreements --disable-interactivity"; WinGetLog=''; StdOut=''; StdErr=''
                }) | Out-Null
                continue
            }
            $candidateIds = New-Object System.Collections.Generic.List[string]
            [void]$candidateIds.Add([string]$item.Id)
            foreach ($altId in @($item.AlternateIds)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$altId) -and -not $candidateIds.Contains([string]$altId)) { [void]$candidateIds.Add([string]$altId) }
            }

            $show = $null
            $resolvedId = $null
            foreach ($candidateId in $candidateIds) {
                Write-LogLine "    $(TT 'PackageCheck'): id=$candidateId source=$source"
                $candidateShow = Invoke-WinGetProcess -Action 'show' -Id $candidateId -SkipSilent $true -Source $source -PackageName $item.Name
                if ($candidateShow.ExitCode -eq 0) {
                    $show = $candidateShow
                    $resolvedId = $candidateId
                    if ($resolvedId -ne $item.Id) { Write-LogLine "    Resolved with alternate WinGet ID: $resolvedId" }
                    break
                }
                $show = $candidateShow
                Write-LogLine "    Not available as ${candidateId}: $($candidateShow.Message)"
            }

            if ([string]::IsNullOrWhiteSpace($resolvedId)) {
                $failedInstall++
                Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x274C)
                Write-LogLine "[$(TT 'Error')] $($item.Name) - $(TT 'PackageNotFound') - Exit code: $($show.ExitCode)"
                Write-LogLine "    $($show.Message)"
                if ($item.Notes) { Write-LogLine "    Notes: $($item.Notes)" }
                $results.Add([pscustomobject]@{
                    Timestamp=(Get-Date).ToString('s'); Action='Install'; Name=$item.Name; Id=$item.Id; ResolvedId=''; Category=$item.Category; Source=$source; Method='WinGet';
                    Status='PackageNotFound'; ExitCode=$show.ExitCode; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2);
                    Message=$show.Message; Command=$show.Args; WinGetLog=''; StdOut=$show.StdOut; StdErr=$show.StdErr
                }) | Out-Null
                continue
            }

            $run = Invoke-WinGetProcess -Action 'install' -Id $resolvedId -SkipSilent ([bool]$item.SkipSilent) -Source $source -PackageName $item.Name
            Write-WinGetOutput -Result $run
            if ($run.ExitCode -eq 0) {
                $successInstall++; Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x2705); Write-LogLine "[OK] $($item.Name) $(TT 'InstalledOk')."
                $status = 'Success'; $message = 'OK'
            } else {
                $failedInstall++; Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x274C)
                Write-LogLine "[$(TT 'Error')] $($item.Name) - Exit code: $($run.ExitCode)"
                Write-LogLine "    Reason: $($run.Message)"
                Write-LogLine "    $(TT 'WingetLog'): $($run.LogPath)"
                $status = 'Failed'; $message = $run.Message
            }
            $results.Add([pscustomobject]@{
                Timestamp=(Get-Date).ToString('s'); Action='Install'; Name=$item.Name; Id=$item.Id; ResolvedId=$resolvedId; Category=$item.Category; Source=$source; Method='WinGet';
                Status=$status; ExitCode=$run.ExitCode; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2);
                Message=$message; Command=$run.Args; WinGetLog=$run.LogPath; StdOut=$run.StdOut; StdErr=$run.StdErr
            }) | Out-Null
        } catch {
            $failedInstall++; Set-Status -Labels $installStatusLabels -Idx $item.Index -Emoji ([string][char]0x274C); Write-LogLine "[$(TT 'Error')] $($item.Name) - $($_.Exception.Message)"
            $errSource = $(if ($item.Source) { $item.Source } else { 'winget' })
            $results.Add([pscustomobject]@{ Timestamp=(Get-Date).ToString('s'); Action='Install'; Name=$item.Name; Id=$item.Id; ResolvedId=''; Category=$item.Category; Source=$errSource; Method='WinGet'; Status='Exception'; ExitCode=''; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2); Message=$_.Exception.Message; Command=''; WinGetLog=''; StdOut=''; StdErr='' }) | Out-Null
        }
        Write-LogLine ''
    }

    # === BLOATWARE REMOVAL PHASE (PHASE 2) ===
    Write-LogLine ''
    Write-LogLine '========================================='
    Write-LogLine "  $(TT 'RemovePhase')"
    Write-LogLine '========================================='
    foreach ($item in $selectedBloat) {
        $currentOp++
        $opLabel = "$(TT 'Removing'): $($item.Name)..."
        Update-Progress -Step $currentOp -Label $opLabel
        Set-Status -Labels $bloatStatusLabels -Idx $item.Index -Emoji ([string][char]0x1F504)
        Write-LogLine "[>] $(TT 'Removing'): $($item.Name) ($($item.Id))"
        $start = Get-Date
        try {
            $run = Invoke-AppxDebloat -PackageFamilyName $item.Id -PackageName $item.PackageName -FriendlyName $item.Name
            if ($run.StdOut) { ($run.StdOut -split '\|') | ForEach-Object { if ($_.Trim()) { Write-LogLine "    $($_.Trim())" } } }
            if ($run.Status -eq 'Success') {
                $successBloat++; Set-Status -Labels $bloatStatusLabels -Idx $item.Index -Emoji ([string][char]0x2705); Write-LogLine "[OK] $($item.Name) $(TT 'RemovedOk')."
                $status = 'Success'; $message = $run.Message
            } elseif ($run.Status -eq 'NotInstalled') {
                $skippedBloat++; Set-Status -Labels $bloatStatusLabels -Idx $item.Index -Emoji ([string][char]0x2139)
                Write-LogLine "[$(TT 'Skipped')] $($item.Name) - $(TT 'NotInstalled')."
                $status = 'NotInstalled'; $message = $(TT 'NotInstalled')
            } else {
                $failedBloat++; Set-Status -Labels $bloatStatusLabels -Idx $item.Index -Emoji ([string][char]0x274C)
                Write-LogLine "[$(TT 'Error')] $($item.Name) - $($run.Message)"
                $status = 'Failed'; $message = $run.Message
            }
            $results.Add([pscustomobject]@{
                Timestamp=(Get-Date).ToString('s'); Action='Uninstall'; Name=$item.Name; Id=$item.Id; Category='Windows App'; Source='Appx'; Method='Get-AppxPackage/Remove-AppxPackage';
                Status=$status; ExitCode=$run.ExitCode; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2);
                Message=$message; Command=$run.Args; WinGetLog=$run.LogPath; StdOut=$run.StdOut; StdErr=$run.StdErr
            }) | Out-Null
        } catch {
            $failedBloat++; Set-Status -Labels $bloatStatusLabels -Idx $item.Index -Emoji ([string][char]0x274C); Write-LogLine "[$(TT 'Error')] $($item.Name) - $($_.Exception.Message)"
            $results.Add([pscustomobject]@{ Timestamp=(Get-Date).ToString('s'); Action='Uninstall'; Name=$item.Name; Id=$item.Id; Category='Windows App'; Source='Appx'; Method='Get-AppxPackage/Remove-AppxPackage'; Status='Exception'; ExitCode=''; DurationSeconds=[math]::Round(((Get-Date)-$start).TotalSeconds,2); Message=$_.Exception.Message; Command=''; WinGetLog=''; StdOut=''; StdErr='' }) | Out-Null
        }
        Write-LogLine ''
    }

    # === REPORT GENERATION ===
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $csvPath = Join-Path $reportFolder "SetupHub_Report_$timestamp.csv"
    $jsonPath = Join-Path $reportFolder "SetupHub_Report_$timestamp.json"
    $catalogCsvPath = Join-Path $reportFolder "SetupHub_CatalogAudit_$timestamp.csv"
    $catalogJsonPath = Join-Path $reportFolder "SetupHub_CatalogAudit_$timestamp.json"
    $inventoryJsonPath = Join-Path $reportFolder "SetupHub_SystemInventory_$timestamp.json"
    $softwareCsvPath = Join-Path $reportFolder "SetupHub_InstalledSoftware_$timestamp.csv"
    $manualJsonPath = Join-Path $reportFolder "SetupHub_ManualUnsupported_$timestamp.json"
    $manualCsvPath = Join-Path $reportFolder "SetupHub_ManualUnsupported_$timestamp.csv"
    $htmlPath = Join-Path $reportFolder "SetupHub_Report_$timestamp.html"
    $logPath = Join-Path $reportFolder "SetupHub_Log_$timestamp.txt"
    if ($createReport) {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        $results | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
        if ($validateCatalog -and $catalogResults.Count -gt 0) { $catalogResults | Export-Csv -Path $catalogCsvPath -NoTypeInformation -Encoding UTF8; $catalogResults | ConvertTo-Json -Depth 6 | Set-Content -Path $catalogJsonPath -Encoding UTF8 }
        if ($includeInventory -and $systemInventory) { $systemInventory | ConvertTo-Json -Depth 8 | Set-Content -Path $inventoryJsonPath -Encoding UTF8; @($systemInventory.InstalledSoftware) | Export-Csv -Path $softwareCsvPath -NoTypeInformation -Encoding UTF8 }
        if ($manualUnsupportedPackages -and @($manualUnsupportedPackages).Count -gt 0) { @($manualUnsupportedPackages) | ConvertTo-Json -Depth 5 | Set-Content -Path $manualJsonPath -Encoding UTF8; @($manualUnsupportedPackages) | Export-Csv -Path $manualCsvPath -NoTypeInformation -Encoding UTF8 }
        $summary = [pscustomobject]@{
            Tool = "$appName v$appVersion"
            Author = $(if ($authorName) { $authorName } elseif ($script:AuthorName) { $script:AuthorName } else { 'Pietro Melillo' })
            AuthorEmail = $(if ($authorEmail) { $authorEmail } elseif ($script:AuthorEmail) { $script:AuthorEmail } else { 'melillopietro@gmail.com' })
            AuthorWebsite = $(if ($authorWebsite) { $authorWebsite } elseif ($script:AuthorWebsite) { $script:AuthorWebsite } else { 'https://melillopietro.github.io/' })
            License = "$(if ($licenseName) { $licenseName } elseif ($script:LicenseName) { $script:LicenseName } else { 'GNU General Public License v3.0 only' }) ($(if ($licenseSpdx) { $licenseSpdx } elseif ($script:LicenseSpdx) { $script:LicenseSpdx } else { 'GPL-3.0-only' }))"
            ComputerName = $env:COMPUTERNAME
            User = $env:USERNAME
            OS = (Get-CimInstance Win32_OperatingSystem).Caption
            OSBuild = [System.Environment]::OSVersion.Version.Build
            Profile = $selectedProfile
            StartedAt = $sessionStart.ToString('s')
            CompletedAt = (Get-Date).ToString('s')
            SuccessfulInstalls = $successInstall
            FailedInstalls = $failedInstall
            SuccessfulRemovals = $successBloat
            SkippedRemovals = $skippedBloat
            FailedRemovals = $failedBloat
            CatalogAvailable = @($catalogResults | Where-Object Status -eq 'Available').Count
            CatalogNotAvailable = @($catalogResults | Where-Object Status -ne 'Available').Count
            InventoryIncluded = [bool]($includeInventory -and $systemInventory)
            ManualUnsupportedPackages = @($manualUnsupportedPackages).Count
            ReportFolder = $reportFolder
            WingetLogFolder = $wingetLogFolder
        }
        $licenseInfo = [pscustomobject]@{
            Product = "$appName v$appVersion"
            Author = $(if ($authorName) { $authorName } elseif ($script:AuthorName) { $script:AuthorName } else { 'Pietro Melillo' })
            Email = $(if ($authorEmail) { $authorEmail } elseif ($script:AuthorEmail) { $script:AuthorEmail } else { 'melillopietro@gmail.com' })
            Website = $(if ($authorWebsite) { $authorWebsite } elseif ($script:AuthorWebsite) { $script:AuthorWebsite } else { 'https://melillopietro.github.io/' })
            Copyright = $(if ($copyrightNotice) { $copyrightNotice } elseif ($script:CopyrightNotice) { $script:CopyrightNotice } else { 'Copyright (C) 2026 Pietro Melillo' })
            License = "$(if ($licenseName) { $licenseName } elseif ($script:LicenseName) { $script:LicenseName } else { 'GNU General Public License v3.0 only' }) ($(if ($licenseSpdx) { $licenseSpdx } elseif ($script:LicenseSpdx) { $script:LicenseSpdx } else { 'GPL-3.0-only' }))"
            CopyleftNotice = 'Modified versions may be distributed only under the same GPL-3.0-only license, preserving copyright/license notices, stating changes, and providing source code for the distributed version.'
        }
        $changelogIt = @(
            [pscustomobject]@{ Version='1.2.0'; Language='IT'; Changes='Parallelizzazione della validazione del catalogo software con RunspacePool multi-thread (fino a 10 worker simultanei, velocita aumentata dell 80%) e raccolta inventario hardware/software asincrona in background.' }
            [pscustomobject]@{ Version='1.1.1'; Language='IT'; Changes='Risolto errore di avvio WinGet Accesso negato sotto UAC con nuovo invoker shell multi-tier; download automatico dipendenze ufficiali VCLibs 140.00 >= 14.0.33519.0 e UI.Xaml 2.8; fix rimozione bloatware nel runspace.' }
            [pscustomobject]@{ Version='1.1'; Language='IT'; Changes='Risolto errore WinGet 0x80073CF3 con bootstrap automatico Windows App Runtime 1.8; aggiunta modalita CLI / Unattended (-NoGui); ricerca e filtri in tempo reale nella GUI; opzione punto di ripristino; rilevamento riavvio pendente.' }
            [pscustomobject]@{ Version='1.0'; Language='IT'; Changes='Prima release stabile: catalogo software validato; inventario hardware/software; profili personalizzati; report HTML/CSV/JSON; gestione bloatware Windows 10/11.' }
        )
        $changelogEn = @(
            [pscustomobject]@{ Version='1.2.0'; Language='EN'; Changes='Parallel multi-threaded catalog validation using RunspacePool (up to 10 concurrent workers, 80% speedup) and asynchronous background system inventory collection.' }
            [pscustomobject]@{ Version='1.1.1'; Language='EN'; Changes='Fixed WinGet Access Denied under elevated UAC with resilient multi-tier shell invoker; automatic download of official VCLibs 140.00 >= 14.0.33519.0 and UI.Xaml 2.8 dependencies; fixed bloatware cleanup in runspace.' }
            [pscustomobject]@{ Version='1.1'; Language='EN'; Changes='Fixed WinGet error 0x80073CF3 with automatic Windows App Runtime 1.8 bootstrap; added CLI / Unattended mode (-NoGui); real-time search and category filtering in GUI; restore point option; pending reboot check.' }
            [pscustomobject]@{ Version='1.0'; Language='EN'; Changes='First stable release: validated software catalog; hardware/software inventory; custom profiles; HTML/CSV/JSON reports; Windows 10/11 bloatware handling.' }
        )
        $style = '<style>body{font-family:Segoe UI,Arial,sans-serif;background:#11111b;color:#cdd6f4}h1,h2,h3{color:#89b4fa}.card{background:#181825;border-radius:10px;padding:16px;margin:12px 0;overflow:auto}table{border-collapse:collapse;width:100%;background:#181825}th,td{border:1px solid #313244;padding:7px;text-align:left;font-size:12px;vertical-align:top}th{background:#313244}.Available,.Success{color:#a6e3a1}.NotInstalled{color:#f9e2af}.NotAvailable,.PackageNotFound,.Failed,.Exception{color:#f38ba8}.SkippedNotAvailable{color:#f9e2af}</style>'
        $html = @()
        $html += '<html><head><meta charset="utf-8"><title>SetupHub Report</title>' + $style + '</head><body>'
        $html += '<h1>SetupHub - Deployment Report</h1>'
        $html += '<div class="card"><h2>' + (TT 'LicenseTitle') + '</h2>'
        $html += ($licenseInfo | ConvertTo-Html -Fragment)
        $html += '</div><div class="card"><h2>' + (TT 'ChangelogTitle') + '</h2><h3>Italiano</h3>'
        $html += ($changelogIt | ConvertTo-Html -Fragment)
        $html += '<h3>English</h3>'
        $html += ($changelogEn | ConvertTo-Html -Fragment)
        $html += '</div><div class="card"><h2>Summary</h2>'
        $html += ($summary | ConvertTo-Html -Fragment)
        if ($includeInventory -and $systemInventory) {
            $html += '</div><div class="card"><h2>Hardware / OS Inventory</h2>'
            $html += ($systemInventory.Computer | ConvertTo-Html -Fragment)
            $html += '<h3>Operating System</h3>'
            $html += ($systemInventory.OS | ConvertTo-Html -Fragment)
            $html += '<h3>CPU</h3>'
            $html += ($systemInventory.CPU | ConvertTo-Html -Fragment)
            $html += '<h3>Memory Modules</h3>'
            $html += ($systemInventory.MemoryModules | ConvertTo-Html -Fragment)
            $html += '<h3>Disks</h3>'
            $html += ($systemInventory.Disks | ConvertTo-Html -Fragment)
            $html += '<h3>Volumes</h3>'
            $html += ($systemInventory.Volumes | ConvertTo-Html -Fragment)
            $html += '<h3>GPU</h3>'
            $html += ($systemInventory.GPU | ConvertTo-Html -Fragment)
            $html += '<h3>Network</h3>'
            $html += ($systemInventory.Network | ConvertTo-Html -Fragment)
            $html += '<h3>Installed Software Inventory - first 200 rows</h3>'
            $html += (@($systemInventory.InstalledSoftware) | Select-Object -First 200 | ConvertTo-Html -Fragment)
        }
        if ($validateCatalog -and $catalogResults.Count -gt 0) {
            $html += '</div><div class="card"><h2>WinGet Catalog Availability</h2>'
            $html += ($catalogResults | Sort-Object Status,Category,Name | ConvertTo-Html -Fragment)
        }
        if ($manualUnsupportedPackages -and @($manualUnsupportedPackages).Count -gt 0) {
            $html += '</div><div class="card"><h2>' + (TT 'ManualUnsupportedReport') + '</h2>'
            $html += (@($manualUnsupportedPackages) | ConvertTo-Html -Fragment)
        }
        $html += '</div><div class="card"><h2>Operations</h2>'
        $html += ($results | Select-Object Timestamp,Action,Name,Id,Category,Source,Method,Status,ExitCode,DurationSeconds,Message,Command,WinGetLog | ConvertTo-Html -Fragment)
        $html += '</div></body></html>'
        $html -join "`r`n" | Set-Content -Path $htmlPath -Encoding UTF8
        if ($txtLog -and $dispatcher) {
            Invoke-UIUpdate { $txtLog.Text | Set-Content -Path $logPath -Encoding UTF8 }.GetNewClosure()
        }
    }

    Write-LogLine ''
    Write-LogLine '========================================='
    Write-LogLine "  $(TT 'SummaryTitle')"
    Write-LogLine '========================================='
    Write-LogLine "  Software installati: $successInstall OK / $failedInstall ERRORI"
    Write-LogLine "  Bloatware rimossi:   $successBloat OK / $skippedBloat GIA' ASSENTI / $failedBloat ERRORI"
    if ($createReport) { Write-LogLine "  $(TT 'ReportSaved'): $htmlPath"; Write-LogLine "  CSV: $csvPath"; Write-LogLine "  JSON: $jsonPath"; Write-LogLine "  TXT Log: $logPath"; if ($validateCatalog) { Write-LogLine "  Catalog CSV: $catalogCsvPath" }; if ($includeInventory) { Write-LogLine "  Inventory JSON: $inventoryJsonPath"; Write-LogLine "  Software CSV: $softwareCsvPath" }; if ($manualUnsupportedPackages -and @($manualUnsupportedPackages).Count -gt 0) { Write-LogLine "  Manual/Unsupported CSV: $manualCsvPath"; Write-LogLine "  Manual/Unsupported JSON: $manualJsonPath" }; Write-LogLine "  WinGet logs: $wingetLogFolder" }
    Write-LogLine '========================================='

    if ($dispatcher) {
        Invoke-UIUpdate { $progressBar.Value = 100; $lblProgress.Text = '100%'; $lblCurrentOp.Text = TT 'Completed'; $btnStart.IsEnabled = $false }.GetNewClosure()
        $summaryMsg = "$(TT 'Completed')`n`nSoftware installati: $successInstall (errori: $failedInstall)`nBloatware rimossi: $successBloat (gia' assenti: $skippedBloat, errori: $failedBloat)"
        if ($createReport) { $summaryMsg += "`n`n$(TT 'ReportSaved'):`n$htmlPath" }
        Invoke-UIUpdate { [System.Windows.MessageBox]::Show($window, $summaryMsg, (TT 'SummaryTitle'), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) }.GetNewClosure()
    } else {
        Write-Host "`n$(TT 'Completed')" -ForegroundColor Green
        Write-Host "Software installati: $successInstall (errori: $failedInstall)"
        Write-Host "Bloatware rimossi: $successBloat (gia' assenti: $skippedBloat, errori: $failedBloat)"
        if ($createReport) { Write-Host "`n$(TT 'ReportSaved'):`n$htmlPath" -ForegroundColor Cyan }
    }
}
#endregion

#region === CLI / UNATTENDED EXECUTION MODE ===
if ($NoGui) {
    $lang = $script:Lang
    $textTable = $script:Text[$lang]
    $targetProfile = if ($Profile) { $Profile } else { 'Essential' }
    
    # Custom profile fallback
    $customProfilePath = Join-Path $script:ProfileFolder "$targetProfile.json"
    $customInstallIds = @()
    $customBloatIds = @()
    if (Test-Path $customProfilePath) {
        try {
            $pJson = Get-Content -Path $customProfilePath -Raw | ConvertFrom-Json
            $customInstallIds = @($pJson.InstallIds)
            $customBloatIds = @($pJson.BloatIds)
        } catch {}
    }

    $selectedInstalls = @()
    if ($InstallIds -and $InstallIds.Count -gt 0) {
        for ($i=0; $i -lt $installPackages.Count; $i++) {
            $pkg = $installPackages[$i]
            if ($InstallIds -contains $pkg.Id) {
                $selectedInstalls += @{
                    Index = $i; Id = [string]$pkg.Id; Name = [string]$pkg.Name; Category = [string]$pkg.Category;
                    SkipSilent = [bool]$pkg.SkipSilent; Source = $(if ($pkg.ContainsKey('Source')) { [string]$pkg.Source } else { 'winget' });
                    AlternateIds = $(if ($pkg.ContainsKey('AlternateIds')) { @($pkg.AlternateIds) } else { @() });
                    Notes = $(if ($pkg.ContainsKey('Notes')) { [string]$pkg.Notes } else { '' })
                }
            }
        }
    } else {
        for ($i=0; $i -lt $installPackages.Count; $i++) {
            $pkg = $installPackages[$i]
            $pkgProfiles = @($pkg.Profiles)
            $isSelected = ($targetProfile -eq 'Complete' -or $pkgProfiles -contains $targetProfile -or ($customInstallIds -contains $pkg.Id))
            if ($isSelected) {
                $selectedInstalls += @{
                    Index = $i; Id = [string]$pkg.Id; Name = [string]$pkg.Name; Category = [string]$pkg.Category;
                    SkipSilent = [bool]$pkg.SkipSilent; Source = $(if ($pkg.ContainsKey('Source')) { [string]$pkg.Source } else { 'winget' });
                    AlternateIds = $(if ($pkg.ContainsKey('AlternateIds')) { @($pkg.AlternateIds) } else { @() });
                    Notes = $(if ($pkg.ContainsKey('Notes')) { [string]$pkg.Notes } else { '' })
                }
            }
        }
    }

    $selectedBloat = @()
    if ($BloatIds -and $BloatIds.Count -gt 0) {
        for ($i=0; $i -lt $bloatwarePackages.Count; $i++) {
            $pkg = $bloatwarePackages[$i]
            if ($BloatIds -contains $pkg.Id) {
                $selectedBloat += @{
                    Index = $i; Id = [string]$pkg.Id; Name = [string]$pkg.Name;
                    PackageName = $(if ($pkg.ContainsKey('PackageName')) { [string]$pkg.PackageName } else { ([string]$pkg.Id).Split('_')[0] })
                }
            }
        }
    } else {
        for ($i=0; $i -lt $bloatwarePackages.Count; $i++) {
            $pkg = $bloatwarePackages[$i]
            $pkgProfiles = @($pkg.Profiles)
            $isSelected = ($targetProfile -eq 'Clean' -and $pkgProfiles -contains 'Clean') -or ($targetProfile -eq 'Complete' -and $pkgProfiles -contains 'Complete') -or ($customBloatIds -contains $pkg.Id)
            if ($isSelected) {
                $selectedBloat += @{
                    Index = $i; Id = [string]$pkg.Id; Name = [string]$pkg.Name;
                    PackageName = $(if ($pkg.ContainsKey('PackageName')) { [string]$pkg.PackageName } else { ([string]$pkg.Id).Split('_')[0] })
                }
            }
        }
    }

    $catalogPackages = @()
    for ($i=0; $i -lt $installPackages.Count; $i++) {
        $catalogPackages += @{
            Id = [string]$installPackages[$i].Id
            Name = [string]$installPackages[$i].Name
            Category = [string]$installPackages[$i].Category
            Source = $(if ($installPackages[$i].ContainsKey('Source')) { [string]$installPackages[$i].Source } else { 'winget' })
            AlternateIds = $(if ($installPackages[$i].ContainsKey('AlternateIds')) { @($installPackages[$i].AlternateIds) } else { @() })
            Notes = $(if ($installPackages[$i].ContainsKey('Notes')) { [string]$installPackages[$i].Notes } else { '' })
        }
    }

    $validateCatalog = (-not $SkipValidation)
    $includeInventory = (-not $NoInventory)
    $createReport = (-not $NoReport)
    $createRestorePoint = [bool]$CreateRestorePoint
    $validationOps = $(if ($validateCatalog) { $catalogPackages.Count } else { 0 })
    $totalOps = $selectedInstalls.Count + $selectedBloat.Count + $validationOps
    $reportFolder = $script:ReportFolder
    $wingetLogFolder = $script:WingetLogFolder
    $selectedProfile = $targetProfile
    $appName = $script:AppName
    $appVersion = $script:AppVersion
    $authorName = $script:AuthorName
    $authorEmail = $script:AuthorEmail
    $authorWebsite = $script:AuthorWebsite
    $licenseName = $script:LicenseName
    $licenseSpdx = $script:LicenseSpdx
    $copyrightNotice = $script:CopyrightNotice

    $dispatcher = $null
    $progressBar = $null
    $lblProgress = $null
    $lblCurrentOp = $null
    $txtLog = $null
    $installStatusLabels = $null
    $bloatStatusLabels = $null
    $btnStart = $null
    $btnCancel = $null
    $window = $null

    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  SetupHub v$script:AppVersion - CLI Mode" -ForegroundColor Cyan
    Write-Host "  Profile: $selectedProfile | Language: $lang" -ForegroundColor Cyan
    Write-Host "=========================================`n" -ForegroundColor Cyan

    if (Test-PendingReboot) {
        Write-Warning (T 'PendingRebootBanner')
    }

    & $deploymentScript
    exit 0
}
#endregion

#region === GUI XAML ===
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SetupHub" Height="920" Width="1300" MinHeight="780" MinWidth="1080"
        WindowStartupLocation="CenterScreen" Background="#1e1e2e">
    <Window.Resources>
        <Style x:Key="PanelHeader" TargetType="TextBlock">
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="Margin" Value="4,0"/>
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#45475a"/></Trigger>
                <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
            </Style.Triggers>
        </Style>
        <Style x:Key="ComboStyle" TargetType="ComboBox">
            <Setter Property="Margin" Value="6,0"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="MinWidth" Value="150"/>
        </Style>
        <Style x:Key="SearchBoxStyle" TargetType="TextBox">
            <Setter Property="Height" Value="26"/>
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="BorderBrush" Value="#45475a"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="6,3"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="220"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#181825" Padding="14" BorderBrush="#313244" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock x:Name="lblHeaderTitle" Text="SetupHub" Foreground="#cdd6f4" FontSize="26" FontWeight="Bold"/>
                    <TextBlock x:Name="lblHeaderSubtitle" Text="Installer WinGet con profili software, report finale e rimozione bloatware" Foreground="#a6adc8" FontSize="12"/>
                </StackPanel>
                <WrapPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <TextBlock x:Name="lblLanguage" Foreground="#a6adc8" VerticalAlignment="Center" Text="Lingua"/>
                    <ComboBox x:Name="cmbLanguage" Style="{StaticResource ComboStyle}">
                        <ComboBoxItem Content="Italiano" Tag="it" IsSelected="True"/>
                        <ComboBoxItem Content="English" Tag="en"/>
                    </ComboBox>
                    <Button x:Name="btnCredits" Content="Credits" Style="{StaticResource ActionButton}"/>
                </WrapPanel>
            </Grid>
        </Border>

        <!-- Pending Reboot Warning Banner -->
        <Border x:Name="bannerPendingReboot" Grid.Row="1" Background="#f38ba8" Padding="10,6" Visibility="Collapsed">
            <TextBlock x:Name="lblPendingReboot" Text="Attenzione: riavvio di sistema pendente rilevato! Si consiglia di riavviare prima del deployment." Foreground="#11111b" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center"/>
        </Border>

        <!-- WinGet Status Warning Banner -->
        <Border x:Name="bannerWinGetWarning" Grid.Row="2" Background="#f9e2af" Padding="10,6" Visibility="Collapsed">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock x:Name="lblWinGetWarning" Text="Attenzione: WinGet non risulta pienamente configurato nel sistema. L'installazione software potrebbe fallire, ma puoi procedere con debloating e inventario." Foreground="#11111b" FontWeight="SemiBold" FontSize="11" VerticalAlignment="Center"/>
                <Button x:Name="btnRepairWinGet" Content="Ripara WinGet" Margin="12,0,0,0" Padding="8,2" Background="#fab387" Foreground="#11111b" FontWeight="Bold" FontSize="11" Cursor="Hand" BorderThickness="0"/>
            </StackPanel>
        </Border>

        <!-- Main Panels -->
        <Grid Grid.Row="3" Margin="12,10,12,6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="1.4*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Install Panel -->
            <Border Grid.Column="0" Background="#181825" CornerRadius="8" Padding="12">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top">
                        <TextBlock x:Name="lblInstallPanel" Style="{StaticResource PanelHeader}" Text="Software da installare"/>
                        <WrapPanel Margin="0,0,0,8">
                            <TextBlock x:Name="lblProfile" Foreground="#a6adc8" VerticalAlignment="Center" Text="Profilo"/>
                            <ComboBox x:Name="cmbProfile" Style="{StaticResource ComboStyle}" MinWidth="180"/>
                            <Button x:Name="btnNewProfile" Content="Nuovo profilo" Style="{StaticResource ActionButton}"/>
                            <Button x:Name="btnApplyProfile" Content="Applica profilo" Style="{StaticResource ActionButton}"/>
                            <Button x:Name="btnSaveProfile" Content="Salva profilo" Style="{StaticResource ActionButton}"/>
                            <Button x:Name="btnLoadProfile" Content="Carica profilo" Style="{StaticResource ActionButton}"/>
                        </WrapPanel>
                        <WrapPanel Margin="0,0,0,8">
                            <Button x:Name="btnSelectAllInstall" Content="Seleziona tutto" Style="{StaticResource ActionButton}" FontSize="11"/>
                            <Button x:Name="btnDeselectAllInstall" Content="Deseleziona tutto" Style="{StaticResource ActionButton}" FontSize="11"/>
                            <Button x:Name="btnResetRecommended" Content="Reset consigliato" Style="{StaticResource ActionButton}" FontSize="11"/>
                        </WrapPanel>
                        <!-- Search and Category Filter -->
                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="🔍" VerticalAlignment="Center" Margin="0,0,6,0" Foreground="#89b4fa" FontSize="13"/>
                            <TextBox x:Name="txtSearchInstall" Grid.Column="1" Style="{StaticResource SearchBoxStyle}" Margin="0,0,6,0" ToolTip="Cerca software per nome o ID"/>
                            <ComboBox x:Name="cmbCategoryFilter" Grid.Column="2" Style="{StaticResource ComboStyle}" MinWidth="130" Height="26" Margin="0"/>
                        </Grid>
                    </StackPanel>
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="panelInstall"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- Bloatware Panel -->
            <Border Grid.Column="2" Background="#181825" CornerRadius="8" Padding="12">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top">
                        <TextBlock x:Name="lblBloatPanel" Style="{StaticResource PanelHeader}" Text="Bloatware da rimuovere"/>
                        <WrapPanel Margin="0,0,0,8">
                            <Button x:Name="btnSelectAllBloat" Content="Seleziona tutto" Style="{StaticResource ActionButton}" FontSize="11"/>
                            <Button x:Name="btnDeselectAllBloat" Content="Deseleziona tutto" Style="{StaticResource ActionButton}" FontSize="11"/>
                        </WrapPanel>
                        <!-- Search Bloatware -->
                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="🔍" VerticalAlignment="Center" Margin="0,0,6,0" Foreground="#f38ba8" FontSize="13"/>
                            <TextBox x:Name="txtSearchBloat" Grid.Column="1" Style="{StaticResource SearchBoxStyle}" ToolTip="Cerca bloatware"/>
                        </Grid>
                    </StackPanel>
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="panelBloatware"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>
        </Grid>

        <!-- Action Row -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,6,0,8">
            <StackPanel Orientation="Horizontal" Margin="0,0,24,0" VerticalAlignment="Center">
                <CheckBox x:Name="chkReport" Content="Genera report HTML/CSV" Foreground="#cdd6f4" IsChecked="True" Margin="0,0,16,0"/>
                <CheckBox x:Name="chkRestorePoint" Content="Crea punto di ripristino" Foreground="#cdd6f4" IsChecked="True"/>
            </StackPanel>
            <Button x:Name="btnStart" Style="{StaticResource ActionButton}" Background="#a6e3a1" Foreground="#1e1e2e" FontSize="13" Content="Avvia" Padding="22,9"/>
            <Button x:Name="btnCancel" Style="{StaticResource ActionButton}" Background="#f38ba8" Foreground="#1e1e2e" FontSize="13" Content="Chiudi" Padding="22,9"/>
        </StackPanel>

        <!-- Status & Log -->
        <Border Grid.Row="5" Background="#11111b" Margin="12,0,12,8" CornerRadius="8" Padding="10">
            <DockPanel>
                <StackPanel DockPanel.Dock="Top" Margin="0,0,0,6">
                    <TextBlock x:Name="lblCurrentOp" Text="In attesa di avvio..." Foreground="#a6adc8" FontSize="12" Margin="0,0,0,4"/>
                    <ProgressBar x:Name="progressBar" Height="8" Minimum="0" Maximum="100" Value="0" Foreground="#89b4fa" Background="#313244" BorderThickness="0"/>
                    <TextBlock x:Name="lblProgress" Text="0%" Foreground="#6c7086" FontSize="10" HorizontalAlignment="Right" Margin="0,2,0,0"/>
                </StackPanel>
                <TextBox x:Name="txtLog" IsReadOnly="True" VerticalScrollBarVisibility="Auto" Background="#11111b" Foreground="#a6e3a1" BorderThickness="0" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" AcceptsReturn="True"/>
            </DockPanel>
        </Border>

        <!-- Footer -->
        <Border Grid.Row="6" Background="#181825" Padding="10,6">
            <TextBlock x:Name="lblFooter" Text="Creato da Pietro Melillo | Powered by WinGet | SetupHub v1.1" Foreground="#6c7086" FontSize="10" HorizontalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
"@
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)
#endregion

#region === GUI ELEMENTS ===
$panelInstall = $window.FindName('panelInstall')
$panelBloatware = $window.FindName('panelBloatware')
$btnSelectAllInstall = $window.FindName('btnSelectAllInstall')
$btnDeselectAllInstall = $window.FindName('btnDeselectAllInstall')
$btnSelectAllBloat = $window.FindName('btnSelectAllBloat')
$btnDeselectAllBloat = $window.FindName('btnDeselectAllBloat')
$btnResetRecommended = $window.FindName('btnResetRecommended')
$btnNewProfile = $window.FindName('btnNewProfile')
$btnApplyProfile = $window.FindName('btnApplyProfile')
$btnSaveProfile = $window.FindName('btnSaveProfile')
$btnLoadProfile = $window.FindName('btnLoadProfile')
$btnCredits = $window.FindName('btnCredits')
$btnStart = $window.FindName('btnStart')
$btnCancel = $window.FindName('btnCancel')
$cmbLanguage = $window.FindName('cmbLanguage')
$cmbProfile = $window.FindName('cmbProfile')
$chkReport = $window.FindName('chkReport')
$chkRestorePoint = $window.FindName('chkRestorePoint')
$progressBar = $window.FindName('progressBar')
$lblProgress = $window.FindName('lblProgress')
$lblCurrentOp = $window.FindName('lblCurrentOp')
$txtLog = $window.FindName('txtLog')
$lblHeaderTitle = $window.FindName('lblHeaderTitle')
$lblHeaderSubtitle = $window.FindName('lblHeaderSubtitle')
$lblLanguage = $window.FindName('lblLanguage')
$lblInstallPanel = $window.FindName('lblInstallPanel')
$lblBloatPanel = $window.FindName('lblBloatPanel')
$lblProfile = $window.FindName('lblProfile')
$lblFooter = $window.FindName('lblFooter')
$txtSearchInstall = $window.FindName('txtSearchInstall')
$txtSearchBloat = $window.FindName('txtSearchBloat')
$cmbCategoryFilter = $window.FindName('cmbCategoryFilter')
$bannerPendingReboot = $window.FindName('bannerPendingReboot')
$lblPendingReboot = $window.FindName('lblPendingReboot')
$bannerWinGetWarning = $window.FindName('bannerWinGetWarning')
$lblWinGetWarning = $window.FindName('lblWinGetWarning')
$btnRepairWinGet = $window.FindName('btnRepairWinGet')
#endregion

#region === DYNAMIC ITEM GENERATION & FILTERING ===
$script:installCheckboxes = @()
$script:bloatCheckboxes = @()
$script:installStatusLabels = @()
$script:bloatStatusLabels = @()
$script:installItemEntries = @()
$script:bloatItemEntries = @()

function New-PackageItem {
    param(
        [hashtable]$Package,
        [System.Windows.Controls.Panel]$Panel,
        [ref]$CheckboxList,
        [ref]$StatusList,
        [ref]$ItemEntriesList
    )
    $Name = [string]$Package.Name
    $Id = [string]$Package.Id
    $Category = $(if ($Package.ContainsKey('Category')) { [string]$Package.Category } else { '' })
    $IsChecked = [bool]$Package.Checked

    $border = New-Object System.Windows.Controls.Border
    $border.Margin = [System.Windows.Thickness]::new(0,2,0,2)
    $border.Padding = [System.Windows.Thickness]::new(8,5,8,5)
    $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#1e1e2e')
    $border.CornerRadius = [System.Windows.CornerRadius]::new(4)

    $grid = New-Object System.Windows.Controls.Grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = [System.Windows.GridLength]::new(34)
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    $checkPanel = New-Object System.Windows.Controls.StackPanel
    $checkPanel.Orientation = 'Horizontal'
    [System.Windows.Controls.Grid]::SetColumn($checkPanel,0)

    $checkbox = New-Object System.Windows.Controls.CheckBox
    $checkbox.IsChecked = $IsChecked
    $checkbox.VerticalAlignment = 'Center'
    $checkbox.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    $checkbox.Tag = $Id

    $textPanel = New-Object System.Windows.Controls.StackPanel
    $textPanel.VerticalAlignment = 'Center'

    $nameBlock = New-Object System.Windows.Controls.TextBlock
    $nameBlock.Text = $Name
    $nameBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#cdd6f4')
    $nameBlock.FontSize = 12
    $nameBlock.FontWeight = 'Medium'

    $idBlock = New-Object System.Windows.Controls.TextBlock
    if ([string]::IsNullOrWhiteSpace($Category)) { $idBlock.Text = $Id } else { $idBlock.Text = "[$Category] $Id" }
    $idBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#6c7086')
    $idBlock.FontSize = 9.5

    $textPanel.Children.Add($nameBlock) | Out-Null
    $textPanel.Children.Add($idBlock) | Out-Null
    $checkPanel.Children.Add($checkbox) | Out-Null
    $checkPanel.Children.Add($textPanel) | Out-Null

    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text = ''
    $statusLabel.FontSize = 14
    $statusLabel.VerticalAlignment = 'Center'
    $statusLabel.HorizontalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($statusLabel,1)

    $grid.Children.Add($checkPanel) | Out-Null
    $grid.Children.Add($statusLabel) | Out-Null
    $border.Child = $grid
    $Panel.Children.Add($border) | Out-Null

    $CheckboxList.Value += $checkbox
    $StatusList.Value += $statusLabel
    if ($ItemEntriesList) {
        $ItemEntriesList.Value += [pscustomobject]@{
            Border = $border
            Name = $Name
            Id = $Id
            Category = $Category
            Checkbox = $checkbox
            StatusLabel = $statusLabel
            Pkg = $Package
        }
    }
}

foreach ($pkg in $installPackages) {
    New-PackageItem -Package $pkg -Panel $panelInstall -CheckboxList ([ref]$script:installCheckboxes) -StatusList ([ref]$script:installStatusLabels) -ItemEntriesList ([ref]$script:installItemEntries)
}
foreach ($pkg in $bloatwarePackages) {
    New-PackageItem -Package $pkg -Panel $panelBloatware -CheckboxList ([ref]$script:bloatCheckboxes) -StatusList ([ref]$script:bloatStatusLabels) -ItemEntriesList ([ref]$script:bloatItemEntries)
}

function Filter-InstallPackages {
    $search = if ($txtSearchInstall.Text) { $txtSearchInstall.Text.Trim() } else { '' }
    $selectedCategory = [string]$cmbCategoryFilter.SelectedItem
    $catAll = T 'CategoryAll'
    foreach ($entry in $script:installItemEntries) {
        $matchSearch = [string]::IsNullOrWhiteSpace($search) -or ($entry.Name -match [regex]::Escape($search) -or $entry.Id -match [regex]::Escape($search) -or $entry.Category -match [regex]::Escape($search))
        $matchCat = [string]::IsNullOrWhiteSpace($selectedCategory) -or ($selectedCategory -eq $catAll) -or ($entry.Category -eq $selectedCategory)
        $entry.Border.Visibility = if ($matchSearch -and $matchCat) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }
}

function Filter-BloatPackages {
    $search = if ($txtSearchBloat.Text) { $txtSearchBloat.Text.Trim() } else { '' }
    foreach ($entry in $script:bloatItemEntries) {
        $matchSearch = [string]::IsNullOrWhiteSpace($search) -or ($entry.Name -match [regex]::Escape($search) -or $entry.Id -match [regex]::Escape($search))
        $entry.Border.Visibility = if ($matchSearch) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }
}

$txtSearchInstall.Add_TextChanged({ Filter-InstallPackages })
$txtSearchBloat.Add_TextChanged({ Filter-BloatPackages })
$cmbCategoryFilter.Add_SelectionChanged({ Filter-InstallPackages })
#endregion

#region === PROFILE & LOCALIZATION HELPERS ===
$profiles = @('Essential','Business','Developer','Cybersecurity','Multimedia','Gaming','Home','Clean','Complete')
foreach ($p in $profiles) { [void]$cmbProfile.Items.Add($p) }
$cmbProfile.SelectedItem = 'Essential'

function Populate-CategoryFilter {
    $categories = @($installPackages | ForEach-Object { $_.Category } | Select-Object -Unique | Sort-Object)
    $cmbCategoryFilter.Items.Clear()
    [void]$cmbCategoryFilter.Items.Add((T 'CategoryAll'))
    foreach ($cat in $categories) {
        if (-not [string]::IsNullOrWhiteSpace($cat)) { [void]$cmbCategoryFilter.Items.Add($cat) }
    }
    $cmbCategoryFilter.SelectedIndex = 0
}

function Set-UILanguage {
    $window.Title = T 'WindowTitle'
    $lblHeaderTitle.Text = T 'HeaderTitle'
    $lblHeaderSubtitle.Text = T 'HeaderSubtitle'
    $lblLanguage.Text = T 'Language'
    $lblInstallPanel.Text = T 'InstallPanel'
    $lblBloatPanel.Text = T 'BloatPanel'
    $lblProfile.Text = T 'Profile'
    $btnNewProfile.Content = T 'NewProfile'
    $btnApplyProfile.Content = T 'ApplyProfile'
    $btnSaveProfile.Content = T 'SaveProfile'
    $btnLoadProfile.Content = T 'LoadProfile'
    $btnResetRecommended.Content = T 'Reset'
    $btnSelectAllInstall.Content = T 'SelectAll'
    $btnDeselectAllInstall.Content = T 'DeselectAll'
    $btnSelectAllBloat.Content = T 'SelectAll'
    $btnDeselectAllBloat.Content = T 'DeselectAll'
    $btnStart.Content = T 'Start'
    $btnCancel.Content = T 'Cancel'
    $btnCredits.Content = T 'Credits'
    $chkReport.Content = T 'Report'
    $chkRestorePoint.Content = T 'RestorePoint'
    $lblCurrentOp.Text = T 'Pending'
    $lblFooter.Text = T 'Footer'
    $lblPendingReboot.Text = T 'PendingRebootBanner'
    $lblWinGetWarning.Text = T 'WinGetWarningBanner'
    $txtSearchInstall.ToolTip = T 'SearchInstallPlaceholder'
    $txtSearchBloat.ToolTip = T 'SearchBloatPlaceholder'
    if ($btnRepairWinGet) { $btnRepairWinGet.Content = if ($script:Lang -eq 'it') { 'Ripara WinGet' } else { 'Repair WinGet' } }
    Populate-CategoryFilter
}

function Apply-RecommendedDefaults {
    for ($i=0; $i -lt $script:installCheckboxes.Count; $i++) { $script:installCheckboxes[$i].IsChecked = [bool]$installPackages[$i].Checked }
    for ($i=0; $i -lt $script:bloatCheckboxes.Count; $i++) { $script:bloatCheckboxes[$i].IsChecked = [bool]$bloatwarePackages[$i].Checked }
}

function Apply-ProfileSelection([string]$ProfileName) {
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { return }
    for ($i=0; $i -lt $script:installCheckboxes.Count; $i++) {
        $pkgProfiles = @($installPackages[$i].Profiles)
        $script:installCheckboxes[$i].IsChecked = ($ProfileName -eq 'Complete' -or $pkgProfiles -contains $ProfileName)
    }
    for ($i=0; $i -lt $script:bloatCheckboxes.Count; $i++) {
        $pkgProfiles = @($bloatwarePackages[$i].Profiles)
        if ($ProfileName -eq 'Clean') {
            $script:bloatCheckboxes[$i].IsChecked = ($pkgProfiles -contains 'Clean')
        } elseif ($ProfileName -eq 'Complete') {
            $script:bloatCheckboxes[$i].IsChecked = ($pkgProfiles -contains 'Complete')
        } else {
            $script:bloatCheckboxes[$i].IsChecked = $false
        }
    }
}

function Get-SelectedIds {
    $installIds = @()
    for ($i=0; $i -lt $script:installCheckboxes.Count; $i++) { if ($script:installCheckboxes[$i].IsChecked) { $installIds += [string]$script:installCheckboxes[$i].Tag } }
    $bloatIds = @()
    for ($i=0; $i -lt $script:bloatCheckboxes.Count; $i++) { if ($script:bloatCheckboxes[$i].IsChecked) { $bloatIds += [string]$script:bloatCheckboxes[$i].Tag } }
    return @{ InstallIds = $installIds; BloatIds = $bloatIds }
}

function Add-ProfileToCombo {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $exists = $false
    foreach ($item in $cmbProfile.Items) { if ([string]$item -eq $Name) { $exists = $true; break } }
    if (-not $exists) { [void]$cmbProfile.Items.Add($Name) }
}

function Save-ProfileObject {
    param([string]$Name,[object]$Selection)
    $safeName = ($Name -replace '[^a-zA-Z0-9_\- ]','_').Trim()
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = 'MyProfile' }
    $profileObject = [ordered]@{
        Name = $Name
        CreatedAt = (Get-Date).ToString('s')
        InstallIds = @($Selection.InstallIds)
        BloatIds = @($Selection.BloatIds)
    }
    $path = Join-Path $script:ProfileFolder "$safeName.json"
    $profileObject | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
    Add-ProfileToCombo -Name $Name
    $cmbProfile.SelectedItem = $Name
    return $path
}

function Save-CustomProfile {
    $name = [Microsoft.VisualBasic.Interaction]::InputBox((T 'InsertProfileName'), (T 'ProfileNameTitle'), 'MyProfile')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $selection = Get-SelectedIds
    $path = Save-ProfileObject -Name $name -Selection $selection
    [System.Windows.MessageBox]::Show("$(T 'ProfileSaved'):`n$path", $script:AppName, 'OK', 'Information') | Out-Null
}

function New-CustomProfile {
    $name = [Microsoft.VisualBasic.Interaction]::InputBox((T 'InsertProfileName'), (T 'ProfileNameTitle'), 'NewProfile')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    foreach ($cb in $script:installCheckboxes) { $cb.IsChecked = $false }
    foreach ($cb in $script:bloatCheckboxes) { $cb.IsChecked = $false }
    $selection = Get-SelectedIds
    $path = Save-ProfileObject -Name $name -Selection $selection
    [System.Windows.MessageBox]::Show("$(T 'ProfileCreated'):`n$path", $script:AppName, 'OK', 'Information') | Out-Null
}

function Load-CustomProfile {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.InitialDirectory = $script:ProfileFolder
    $dialog.Filter = 'JSON profile (*.json)|*.json'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $profile = Get-Content -Path $dialog.FileName -Raw | ConvertFrom-Json
    Add-ProfileToCombo -Name ([string]$profile.Name)
    $cmbProfile.SelectedItem = [string]$profile.Name
    $installIds = @($profile.InstallIds)
    $bloatIds = @($profile.BloatIds)
    for ($i=0; $i -lt $script:installCheckboxes.Count; $i++) { $script:installCheckboxes[$i].IsChecked = ($installIds -contains [string]$script:installCheckboxes[$i].Tag) }
    for ($i=0; $i -lt $script:bloatCheckboxes.Count; $i++) { $script:bloatCheckboxes[$i].IsChecked = ($bloatIds -contains [string]$script:bloatCheckboxes[$i].Tag) }
    [System.Windows.MessageBox]::Show("$(T 'ProfileLoaded'):`n$($profile.Name)", $script:AppName, 'OK', 'Information') | Out-Null
}

foreach ($profileFile in Get-ChildItem -Path $script:ProfileFolder -Filter '*.json' -ErrorAction SilentlyContinue) {
    try {
        $p = Get-Content -Path $profileFile.FullName -Raw | ConvertFrom-Json
        Add-ProfileToCombo -Name ([string]$p.Name)
    } catch {}
}
if ($script:Lang -eq 'en') {
    $cmbLanguage.SelectedIndex = 1
} else {
    $cmbLanguage.SelectedIndex = 0
}
Set-UILanguage

if (Test-PendingReboot) {
    $bannerPendingReboot.Visibility = [System.Windows.Visibility]::Visible
}
if (-not $script:WinGetAvailable) {
    $bannerWinGetWarning.Visibility = [System.Windows.Visibility]::Visible
}
#endregion

#region === BUTTON HANDLERS ===
$btnSelectAllInstall.Add_Click({ foreach ($cb in $script:installCheckboxes) { $cb.IsChecked = $true } })
$btnDeselectAllInstall.Add_Click({ foreach ($cb in $script:installCheckboxes) { $cb.IsChecked = $false } })
$btnSelectAllBloat.Add_Click({ foreach ($cb in $script:bloatCheckboxes) { $cb.IsChecked = $true } })
$btnDeselectAllBloat.Add_Click({ foreach ($cb in $script:bloatCheckboxes) { $cb.IsChecked = $false } })
$btnResetRecommended.Add_Click({ Apply-RecommendedDefaults })
$btnNewProfile.Add_Click({ New-CustomProfile })
$btnApplyProfile.Add_Click({ Apply-ProfileSelection -ProfileName ([string]$cmbProfile.SelectedItem) })
$cmbProfile.Add_SelectionChanged({
    $sel = [string]$cmbProfile.SelectedItem
    if (-not [string]::IsNullOrWhiteSpace($sel)) { Apply-ProfileSelection -ProfileName $sel }
})
$btnSaveProfile.Add_Click({ Save-CustomProfile })
$btnLoadProfile.Add_Click({ Load-CustomProfile })
$btnCredits.Add_Click({
    if ($script:Lang -eq 'it') {
        $msg = "SetupHub v$script:AppVersion`n`nAutore: $script:AuthorName`nEmail: $script:AuthorEmail`nSito: $script:AuthorWebsite`n`nLicenza: $script:LicenseName ($script:LicenseSpdx)`n`nNota licenza: SetupHub e' rilasciato con licenza copyleft restrittiva. Se distribuisci una versione modificata, devi mantenere la stessa licenza GPL-3.0-only, conservare i riferimenti di copyright/licenza, indicare le modifiche effettuate e rendere disponibile il codice sorgente della versione distribuita.`n`nPowered by Microsoft WinGet / Windows Package Manager."
    } else {
        $msg = "SetupHub v$script:AppVersion`n`nAuthor: $script:AuthorName`nEmail: $script:AuthorEmail`nWebsite: $script:AuthorWebsite`n`nLicense: $script:LicenseName ($script:LicenseSpdx)`n`nLicense note: SetupHub is released under a restrictive copyleft license. If you distribute a modified version, you must keep the same GPL-3.0-only license, preserve copyright/license notices, state the changes made, and provide the source code of the distributed version.`n`nPowered by Microsoft WinGet / Windows Package Manager."
    }
    [System.Windows.MessageBox]::Show($msg, (T 'CreditsTitle'), 'OK', 'Information') | Out-Null
})
$cmbLanguage.Add_SelectionChanged({
    $selected = $cmbLanguage.SelectedItem
    if ($selected -and $selected.Tag) {
        $script:Lang = [string]$selected.Tag
        Set-UILanguage
    }
})
$btnCancel.Add_Click({ $window.Close() })

if ($btnRepairWinGet) {
    $btnRepairWinGet.Add_Click({
        $btnRepairWinGet.IsEnabled = $false
        $lblWinGetWarning.Text = "Riparazione e registrazione componenti WinGet in corso..."
        [System.Windows.Forms.Application]::DoEvents()
        
        # 1. Ripara ambiente AppX
        Repair-AppXEnvironment
        
        # 2. Re-registra i manifest dei pacchetti WindowsAppRuntime e DesktopAppInstaller
        try {
            Get-AppxPackage -AllUsers *WindowsAppRuntime* -ErrorAction SilentlyContinue | ForEach-Object {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }
            Get-AppxPackage -AllUsers *DesktopAppInstaller* -ErrorAction SilentlyContinue | ForEach-Object {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }
        } catch {}
        
        # 3. Reimposta sorgenti WinGet
        try {
            & winget source reset --force 2>$null | Out-Null
        } catch {}
        
        # 4. Verifica nuovamente WinGet
        $ready = Resolve-WinGetEnvironment
        if ($ready) {
            $script:WinGetAvailable = $true
            $bannerWinGetWarning.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#a6e3a1')
            $lblWinGetWarning.Text = "WinGet ripristinato e pronto all'uso!"
            $btnRepairWinGet.Visibility = [System.Windows.Visibility]::Collapsed
            [System.Windows.MessageBox]::Show("WinGet e' stato configurato e agganciato correttamente!", $script:AppName, 'OK', 'Information') | Out-Null
        } else {
            $btnRepairWinGet.IsEnabled = $true
            $lblWinGetWarning.Text = (T 'WinGetWarningBanner')
            [System.Windows.MessageBox]::Show("I file di WinGet sono stati registrati, ma potrebbe essere necessario un riavvio di Windows per rendere operative le dipendenze.", $script:AppName, 'OK', 'Warning') | Out-Null
        }
    })
}

$btnStart.Add_Click({
    $selectedInstalls = @()
    for ($i=0; $i -lt $script:installItemEntries.Count; $i++) {
        $entry = $script:installItemEntries[$i]
        if ($entry.Checkbox.IsChecked) {
            $pkg = $entry.Pkg
            $selectedInstalls += @{
                Index = $i
                Id = [string]$pkg.Id
                Name = [string]$pkg.Name
                Category = $(if ($pkg.ContainsKey('Category')) { [string]$pkg.Category } else { '' })
                SkipSilent = $(if ($pkg.ContainsKey('SkipSilent')) { [bool]$pkg.SkipSilent } else { $false })
                Source = $(if ($pkg.ContainsKey('Source')) { [string]$pkg.Source } else { 'winget' })
                AlternateIds = $(if ($pkg.ContainsKey('AlternateIds')) { @($pkg.AlternateIds) } else { @() })
                Notes = $(if ($pkg.ContainsKey('Notes')) { [string]$pkg.Notes } else { '' })
            }
        }
    }
    $selectedBloat = @()
    for ($i=0; $i -lt $script:bloatItemEntries.Count; $i++) {
        $entry = $script:bloatItemEntries[$i]
        if ($entry.Checkbox.IsChecked) {
            $pkg = $entry.Pkg
            $selectedBloat += @{
                Index = $i
                Id = [string]$pkg.Id
                Name = [string]$pkg.Name
                PackageName = $(if ($pkg.ContainsKey('PackageName')) { [string]$pkg.PackageName } else { ([string]$pkg.Id).Split('_')[0] })
            }
        }
    }
    $validateCatalog = $true
    $includeInventory = $true
    $createRestorePoint = [bool]$chkRestorePoint.IsChecked
    $catalogPackages = @()
    for ($i=0; $i -lt $installPackages.Count; $i++) {
        $catalogPackages += @{
            Id = [string]$installPackages[$i].Id
            Name = [string]$installPackages[$i].Name
            Category = [string]$installPackages[$i].Category
            Source = $(if ($installPackages[$i].ContainsKey('Source')) { [string]$installPackages[$i].Source } else { 'winget' })
            AlternateIds = $(if ($installPackages[$i].ContainsKey('AlternateIds')) { @($installPackages[$i].AlternateIds) } else { @() })
            Notes = $(if ($installPackages[$i].ContainsKey('Notes')) { [string]$installPackages[$i].Notes } else { '' })
        }
    }
    $validationOps = $(if ($validateCatalog) { $catalogPackages.Count } else { 0 })
    $totalOps = $selectedInstalls.Count + $selectedBloat.Count + $validationOps
    if ($totalOps -eq 0) {
        [System.Windows.MessageBox]::Show((T 'NoSelection'), (T 'Warning'), 'OK', 'Warning') | Out-Null
        return
    }

    $btnStart.IsEnabled = $false
    $btnCancel.Content = T 'Cancel'
    foreach ($control in @($btnSelectAllInstall,$btnDeselectAllInstall,$btnSelectAllBloat,$btnDeselectAllBloat,$btnResetRecommended,$btnNewProfile,$btnApplyProfile,$btnSaveProfile,$btnLoadProfile,$cmbProfile,$cmbLanguage,$chkReport,$chkRestorePoint,$txtSearchInstall,$txtSearchBloat,$cmbCategoryFilter)) { $control.IsEnabled = $false }
    foreach ($cb in $script:installCheckboxes) { $cb.IsEnabled = $false }
    foreach ($cb in $script:bloatCheckboxes) { $cb.IsEnabled = $false }
    foreach ($item in $selectedInstalls) { $script:installStatusLabels[$item.Index].Text = [string][char]0x23F3 }
    foreach ($item in $selectedBloat) { $script:bloatStatusLabels[$item.Index].Text = [string][char]0x23F3 }

    $dispatcher = $window.Dispatcher
    $createReport = [bool]$chkReport.IsChecked
    $reportFolder = $script:ReportFolder
    $wingetLogFolder = $script:WingetLogFolder
    $lang = $script:Lang
    $selectedProfile = [string]$cmbProfile.SelectedItem
    $appName = $script:AppName
    $appVersion = $script:AppVersion
    $textTable = $script:Text[$script:Lang]

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('selectedInstalls', $selectedInstalls)
    $runspace.SessionStateProxy.SetVariable('selectedBloat', $selectedBloat)
    $runspace.SessionStateProxy.SetVariable('catalogPackages', $catalogPackages)
    $runspace.SessionStateProxy.SetVariable('manualUnsupportedPackages', $manualUnsupportedPackages)
    $runspace.SessionStateProxy.SetVariable('totalOps', $totalOps)
    $runspace.SessionStateProxy.SetVariable('dispatcher', $dispatcher)
    $runspace.SessionStateProxy.SetVariable('progressBar', $progressBar)
    $runspace.SessionStateProxy.SetVariable('lblProgress', $lblProgress)
    $runspace.SessionStateProxy.SetVariable('lblCurrentOp', $lblCurrentOp)
    $runspace.SessionStateProxy.SetVariable('txtLog', $txtLog)
    $runspace.SessionStateProxy.SetVariable('installStatusLabels', $script:installStatusLabels)
    $runspace.SessionStateProxy.SetVariable('bloatStatusLabels', $script:bloatStatusLabels)
    $runspace.SessionStateProxy.SetVariable('btnStart', $btnStart)
    $runspace.SessionStateProxy.SetVariable('btnCancel', $btnCancel)
    $runspace.SessionStateProxy.SetVariable('window', $window)
    $runspace.SessionStateProxy.SetVariable('createReport', $createReport)
    $runspace.SessionStateProxy.SetVariable('createRestorePoint', $createRestorePoint)
    $runspace.SessionStateProxy.SetVariable('validateCatalog', $validateCatalog)
    $runspace.SessionStateProxy.SetVariable('includeInventory', $includeInventory)
    $runspace.SessionStateProxy.SetVariable('reportFolder', $reportFolder)
    $runspace.SessionStateProxy.SetVariable('wingetLogFolder', $wingetLogFolder)
    $runspace.SessionStateProxy.SetVariable('lang', $lang)
    $runspace.SessionStateProxy.SetVariable('selectedProfile', $selectedProfile)
    $runspace.SessionStateProxy.SetVariable('appName', $appName)
    $runspace.SessionStateProxy.SetVariable('appVersion', $appVersion)
    $runspace.SessionStateProxy.SetVariable('authorName', $script:AuthorName)
    $runspace.SessionStateProxy.SetVariable('authorEmail', $script:AuthorEmail)
    $runspace.SessionStateProxy.SetVariable('authorWebsite', $script:AuthorWebsite)
    $runspace.SessionStateProxy.SetVariable('licenseName', $script:LicenseName)
    $runspace.SessionStateProxy.SetVariable('licenseSpdx', $script:LicenseSpdx)
    $runspace.SessionStateProxy.SetVariable('copyrightNotice', $script:CopyrightNotice)
    $runspace.SessionStateProxy.SetVariable('textTable', $textTable)

    $psCmd = [powershell]::Create()
    $psCmd.Runspace = $runspace
    $psCmd.AddScript($deploymentScript) | Out-Null

    $asyncResult = $psCmd.BeginInvoke()
    $window.Tag = @{ PowerShell=$psCmd; AsyncResult=$asyncResult; Runspace=$runspace }
})

$window.Add_Closed({
    if ($window.Tag) {
        $tag = $window.Tag
        if ($tag.PowerShell) { try { $tag.PowerShell.Stop(); $tag.PowerShell.Dispose() } catch {} }
        if ($tag.Runspace) { try { $tag.Runspace.Close() } catch {} }
    }
})
#endregion

#region === LAUNCH ===
try {
    $window.ShowDialog() | Out-Null
} catch {
    [System.Windows.MessageBox]::Show("Errore durante l'apertura dell'interfaccia SetupHub:`n$($_.Exception.Message)", "Errore Avvio", 'OK', 'Error') | Out-Null
}
#endregion
