#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Cerberus Triage Console v1.0
    Central Command Interface for the Cerberus Forensic Toolkit.
.DESCRIPTION
    Orchestrates forensic modules, handles configuration loading, 
    and provides a unified dashboard for Incident Response.
.AUTHOR
    RootGuard
#>

$ErrorActionPreference = "SilentlyContinue"

# --- 1. GLOBAL PATH DEFINITIONS ---
$script:RootPath    = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD }
$script:ToolsPath   = Join-Path $script:RootPath "Tools"
$script:ModulesPath = Join-Path $script:RootPath "Modules"
$script:ConfigPath  = Join-Path $script:RootPath "Config\Forensic_Config.reb"

# --- 2. CONFIGURATION ENGINE ---
# Initialize Defaults
$script:Config = @{
    OutputBase  = "C:\Forensics_Cases"
    TargetDrive = "C:"
    CaseID      = "Case-001"
    Operator    = $env:USERNAME
}

# Load External Config if available
if (Test-Path $script:ConfigPath) {
    try {
        $ExternalConfig = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
        
        # Override defaults if keys exist in JSON
        if ($ExternalConfig.GlobalSettings.OutputBase) { $script:Config.OutputBase = $ExternalConfig.GlobalSettings.OutputBase }
        if ($ExternalConfig.GlobalSettings.DefaultTarget) { $script:Config.TargetDrive = $ExternalConfig.GlobalSettings.DefaultTarget }
        if ($ExternalConfig.GlobalSettings.OperatorName) { $script:Config.Operator = $ExternalConfig.GlobalSettings.OperatorName }
    } catch {
        # Silent fail to defaults, or you can log this
    }
}

# --- 3. UI ENGINE ---

function Set-ConsoleTheme {
    $Host.UI.RawUI.WindowTitle = "CERBERUS TRIAGE | Digital Forensics Console"
    try {
        $Host.UI.RawUI.BackgroundColor = "Black"
        $Host.UI.RawUI.ForegroundColor = "Gray"
        Clear-Host
    } catch {}
}

function Write-Banner {
    Clear-Host
    # Safe ASCII Art Banner
    Write-Host ""
    Write-Host "   .d8888b.  8888888888 8888888b.  888888b.   8888888888 8888888b.  888      888  .d8888b.  " -ForegroundColor Red
    Write-Host "  d88P  Y88b 888        888  Y88b 888  '88b  888        888  Y88b 888      888 d88P  Y88b " -ForegroundColor Red
    Write-Host "  888    888 888        888    888 888  .88P  888        888    888 888      888 Y88b.      " -ForegroundColor Red
    Write-Host "  888        8888888    888   d88P 8888888K.  8888888    888   d88P 888      888  'Y888b.   " -ForegroundColor Red
    Write-Host "  888        888        8888888P'  888  'Y88b 888        8888888P'  888      888     'Y88b. " -ForegroundColor Red
    Write-Host "  888    888 888        888 T88b   888    888 888        888 T88b   888      888       '888 " -ForegroundColor Red
    Write-Host "  Y88b  d88P 888        888  T88b  888   d88P 888        888  T88b  Y88b. .d88P Y88b  d88P " -ForegroundColor Red
    Write-Host "   'Y8888P'  8888888888 888   T88b 8888888P'  8888888888 888   T88b  'Y88888P'   'Y8888P'  " -ForegroundColor Red
    Write-Host ""
    Write-Host "                     [ THE ROOTGUARD DFIR TOOLKIT v1.0 ]" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-SectionHeader {
    param($Title)
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------------------------" -ForegroundColor DarkGray
}

function Write-Dashboard {
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm"
    $FullPath = Join-Path $script:Config.OutputBase $script:Config.CaseID
    
    Write-Host "  +==============================================================================+" -ForegroundColor DarkGray
    
    # Row 1: Time & Operator (From Config)
    Write-Host "  |  TIME : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$Date".PadRight(25) -NoNewline -ForegroundColor Cyan
    Write-Host "OPERATOR : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($script:Config.Operator)".PadRight(20) -NoNewline -ForegroundColor Cyan
    Write-Host " |" -ForegroundColor DarkGray
    
    # Row 2: Target & Case
    Write-Host "  |  CASE : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($script:Config.CaseID)".PadRight(25) -NoNewline -ForegroundColor White
    Write-Host "TARGET   : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($script:Config.TargetDrive)".PadRight(20) -NoNewline -ForegroundColor White
    Write-Host " |" -ForegroundColor DarkGray

    # Row 3: Output Path
    Write-Host "  |  PATH : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$FullPath".PadRight(62) -NoNewline -ForegroundColor DarkGray
    Write-Host " |" -ForegroundColor DarkGray

    Write-Host "  +==============================================================================+" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-MenuItem {
    param($Key, $Desc, $Tag="")
    Write-Host "    [" -NoNewline -ForegroundColor Red
    Write-Host "$Key" -NoNewline -ForegroundColor White
    Write-Host "] " -NoNewline -ForegroundColor Red
    Write-Host "$Desc " -NoNewline -ForegroundColor Gray
    if ($Tag) { Write-Host "[$Tag]" -ForegroundColor DarkGray }
    else { Write-Host "" }
}

function Pause-ForKey {
    Write-Host "`n  Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- 4. TOOL LOGIC MODULES ---

function Start-Standard {
    Write-Banner
    Write-SectionHeader "STANDARD COLLECTION"
    $fullPath = Join-Path $script:Config.OutputBase $script:Config.CaseID
    
    # Define Script Path inside Modules Folder
    $ScriptPath = Join-Path $script:ModulesPath "Invoke-WinArtifacts.ps1"

    if (-not (Test-Path $ScriptPath)) { 
        Write-Host "  [!] Error: Script not found at:" -ForegroundColor Red
        Write-Host "      $ScriptPath" -ForegroundColor DarkGray
        Pause-ForKey; return 
    }
    
    Write-Host "  [1] Run Standard Collection (Registry, ShimCache, Amcache)" -ForegroundColor Green
    Write-Host "  [B] Back" -ForegroundColor Gray
    
    $sel = Read-Host "  Select > "
    if ($sel -eq '1') {
        Start-Process powershell.exe -ArgumentList "-NoExit", "-File", "`"$ScriptPath`"", "-TargetDrive", $script:Config.TargetDrive, "-OutputDir", "`"$fullPath`""
    }
}

function Start-KAPE {
    Write-Banner
    Write-SectionHeader "KAPE FORENSICS"
    $fullPath = Join-Path $script:Config.OutputBase $script:Config.CaseID
    
    # Verify KAPE Tool
    if (-not (Test-Path "$script:ToolsPath\kape\kape.exe")) { 
        Write-Host "  [!] Error: KAPE binary missing in Tools folder." -ForegroundColor Red
        Pause-ForKey; return 
    }
    
    # Verify Module Script
    $ScriptPath = Join-Path $script:ModulesPath "Invoke-KapeCollection.ps1"
    if (-not (Test-Path $ScriptPath)) { 
        Write-Host "  [!] Error: Module Invoke-KapeCollection.ps1 missing." -ForegroundColor Red; 
        Pause-ForKey; return 
    }

    Write-Host "  [1] Run KAPE Triage (Standard Profile)" -ForegroundColor Green
    
    $sel = Read-Host "  Select > "
    if ($sel -eq '1') {
        & "$ScriptPath" -TargetDrive $script:Config.TargetDrive -OutputDir $fullPath
        Pause-ForKey
    }
}

function Start-Memory {
    Write-Banner
    Write-SectionHeader "MEMORY OPERATIONS"
    $fullPath = Join-Path $script:Config.OutputBase $script:Config.CaseID
    
    Write-Host "  [1] Capture RAM (DumpIt / Magnet)" -ForegroundColor Green
    Write-Host "  [2] Analyze Dump (Volatility 3)" -ForegroundColor Cyan
    
    $sel = Read-Host "  Select > "
    switch ($sel) {
        '1' {
            $ScriptPath = Join-Path $script:ModulesPath "Invoke-MemoryCapture.ps1"
            if (-not (Test-Path $ScriptPath)) { Write-Host "  [!] Module Missing." -ForegroundColor Red; Pause-ForKey; return }
            
            & "$ScriptPath" -OutputDir $fullPath
            Pause-ForKey
        }
        '2' {
            # Check for Volatility Tool
            if (-not (Test-Path "$script:ToolsPath\volatility3\vol.py")) { 
                Write-Host "  [!] Error: Volatility (vol.py) not found in Tools." -ForegroundColor Red; Pause-ForKey; return 
            }
            
            $ScriptPath = Join-Path $script:ModulesPath "Invoke-Vol3Analysis.ps1"
            $Dump = Read-Host "  Enter Path to Memory Dump"
            
            if (Test-Path $Dump) {
                Start-Process powershell.exe -ArgumentList "-NoExit", "-File", "`"$ScriptPath`"", "-MemoryDump", "`"$Dump`""
            } else { 
                Write-Host "  [!] File not found." -ForegroundColor Red; Pause-ForKey 
            }
        }
    }
}

function Start-Live {
    Write-Banner
    Write-SectionHeader "LIVE RESPONSE"
    $fullPath = Join-Path $script:Config.OutputBase $script:Config.CaseID
    
    Write-Host "  [1] Capture Volatile Data (Netstat, Processes, Services)" -ForegroundColor Green
    
    $sel = Read-Host "  Select > "
    if ($sel -eq '1') {
        $ScriptPath = Join-Path $script:ModulesPath "Invoke-LiveResponse.ps1"
        if (Test-Path $ScriptPath) {
            & "$ScriptPath" -OutputDir $fullPath
            Pause-ForKey
        } else {
            Write-Host "  [!] Module Missing." -ForegroundColor Red; Pause-ForKey
        }
    }
}

function Start-Remote {
    Write-Banner
    Write-SectionHeader "REMOTE ACQUISITION"
    $Target = Read-Host "  Enter Target Computer Name/IP"
    if ([string]::IsNullOrWhiteSpace($Target)) { return }
    
    $ScriptPath = Join-Path $script:ModulesPath "Invoke-RemoteForensics.ps1"
    
    Write-Host "`n  Enter Admin Credentials for $Target..." -ForegroundColor Yellow
    $Creds = Get-Credential
    
    Write-Host "`n  [1] Standard Collection" -ForegroundColor Green
    Write-Host "  [2] KAPE Collection" -ForegroundColor Yellow
    Write-Host "  [3] Live Response Only" -ForegroundColor Cyan
    
    $sel = Read-Host "  Select > "
    
    # Executes the remote wrapper script
    if ($sel -eq '1') { & "$ScriptPath" -TargetComputer $Target -Credential $Creds -Mode "1" -LocalOutputBase $script:Config.OutputBase; Pause-ForKey }
    if ($sel -eq '2') { & "$ScriptPath" -TargetComputer $Target -Credential $Creds -Mode "2" -LocalOutputBase $script:Config.OutputBase; Pause-ForKey }
    if ($sel -eq '3') { & "$ScriptPath" -TargetComputer $Target -Credential $Creds -Mode "3" -LocalOutputBase $script:Config.OutputBase; Pause-ForKey }
}

# --- 5. MAIN MENU LOOP ---

function Show-MainMenu {
    while ($true) {
        Set-ConsoleTheme
        Write-Banner
        Write-Dashboard
        
        Write-SectionHeader "COLLECTION MODULES"
        Write-MenuItem "1" "Standard Collection" "Scripted"
        Write-MenuItem "2" "KAPE Forensics" "Advanced"
        Write-MenuItem "3" "Live Response" "Volatile"
        
        Write-SectionHeader "SPECIAL OPERATIONS"
        Write-MenuItem "4" "Memory Operations" "RAM"
        Write-MenuItem "5" "Remote Acquisition" "Network"
        
        Write-SectionHeader "INTELLIGENCE"
        Write-MenuItem "6" "Analyze Results" "Reporting"
        Write-MenuItem "7" "Settings" "Config"
        Write-MenuItem "Q" "Quit"
        
        Write-Host ""
        $Choice = Read-Host "  CERBERUS > "
        
        switch ($Choice) {
            "1" { Start-Standard }
            "2" { Start-KAPE }
            "3" { Start-Live }
            "4" { Start-Memory }
            "5" { Start-Remote }
            "6" { 
                 $default = Join-Path $script:Config.OutputBase $script:Config.CaseID
                 $ScriptPath = Join-Path $script:ModulesPath "Analyze-Results.ps1"
                 
                 if (Test-Path $default) {
                     Start-Process powershell.exe -ArgumentList "-NoExit", "-File", "`"$ScriptPath`"", "-CaseDir", "`"$default`""
                 } else { 
                     Write-Host "  [!] Case folder not found." -ForegroundColor Red; Pause-ForKey 
                 }
            }
            "7" { 
                $InputCase = Read-Host "  Enter Case ID [Current: $($script:Config.CaseID)]"
                if (-not [string]::IsNullOrWhiteSpace($InputCase)) { $script:Config.CaseID = $InputCase }
                
                $InputDrive = Read-Host "  Enter Target Drive [Current: $($script:Config.TargetDrive)]"
                if (-not [string]::IsNullOrWhiteSpace($InputDrive)) { $script:Config.TargetDrive = $InputDrive }
            }
            "Q" { exit }
        }
    }
}

# Start the Engine
Show-MainMenu