param(
    [string]$TargetDrive = "C:",
    [string]$OutputDir = "C:\Temp\Cerberus_Evidence"
)

# --- CONFIGURATION ---
# Robust Pathing: Finds 'Tools' relative to this script (..\Tools)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = $PWD }

$ToolsDir   = Join-Path $ScriptRoot "..\Tools"
$EZToolsDir = Join-Path $ToolsDir "EZTools"
$ErrorActionPreference = "SilentlyContinue"

# Create Output Directory
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

Write-Host "[-] Starting Cerberus Standard Collection..." -ForegroundColor Cyan
Write-Host "    Target: $TargetDrive" -ForegroundColor Gray
Write-Host "    Output: $OutputDir" -ForegroundColor Gray

# --- HELPER FUNCTIONS ---

function Run-Tool {
    param(
        [string]$Exe,
        [string[]]$ToolArgs,
        [string]$Name
    )

    Write-Host "    Processing: $Name..." -ForegroundColor Green
    
    $ToolPath = Join-Path $EZToolsDir $Exe

    if (Test-Path $ToolPath) {
        try {
            Start-Process -FilePath $ToolPath -ArgumentList $ToolArgs -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "      [!] Failed to run $Name : $_" -ForegroundColor Red
        }
    } else {
        Write-Host "      [!] $Exe not found in $EZToolsDir" -ForegroundColor Red
    }
}

function Generate-HTMLReport {
    Write-Host "`n[8] GENERATING TRIAGE REPORT" -ForegroundColor Yellow
    $ReportPath = "$OutputDir\Cerberus_Triage_Report.html"

    $CSS = @"
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #e0e0e0; margin: 20px; }
        h1 { color: #ff5252; border-bottom: 2px solid #ff5252; padding-bottom: 10px; }
        h2 { color: #00e5ff; margin-top: 30px; border-left: 5px solid #00e5ff; padding-left: 10px; background-color: #1e1e1e; padding: 10px;}
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 0.85em; }
        th, td { padding: 8px 12px; border: 1px solid #333; text-align: left; }
        th { background-color: #2c2c2c; color: #ffffff; }
        tr:nth-child(even) { background-color: #1a1a1a; }
        tr:hover { background-color: #333; }
        .footer { margin-top: 50px; font-size: 0.8em; color: #555; text-align: center; border-top: 1px solid #333; padding-top: 10px; }
        .warning { color: #ff9800; font-style: italic; font-size: 0.8em; }
        a { color: #4fc3f7; text-decoration: none; }
    </style>
"@

    $HTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Cerberus Triage Report</title>
    $CSS
</head>
<body>
    <h1>CERBERUS TRIAGE: Standard Collection Report</h1>
    <p><strong>Target:</strong> $TargetDrive | <strong>Date:</strong> $(Get-Date) | <strong>Output:</strong> $OutputDir</p>
"@

    # --- CSV ARTIFACTS ---
    $ArtifactsToRender = @(
        @{ File="System_Info.csv"; Title="System Information"; Cols="*" },
        @{ File="Prefetch.csv"; Title="Prefetch (Execution History)"; Cols="SourceFilename","LastRun","RunCount","PreviousRun0","PreviousRun1" },
        @{ File="ShimCache.csv"; Title="ShimCache (Execution)"; Cols="Path","LastModifiedTimeUTC","Executed" },
        @{ File="Amcache.csv"; Title="Amcache (Installed Programs)"; Cols="Name","InstallDate","Publisher","ProductVersion" },
        @{ File="MFT.csv"; Title="Master File Table (Recent 50)"; Cols="FileName","FileSize","Created0x10","LastModified0x10","ParentPath" },
        @{ File="EventLogs.csv"; Title="Event Logs (System/Security)"; Cols="TimeCreated","EventId","Provider","Payload" }
    )

    foreach ($Item in $ArtifactsToRender) {
        $CSVPath = Join-Path $OutputDir $Item.File
        
        if (Test-Path $CSVPath) {
            $HTML += "<h2>$($Item.Title)</h2>"
            try {
                $RawData = Import-Csv -Path $CSVPath | Select-Object -First 50
                if ($Item.Cols -ne "*") {
                    $cols = $Item.Cols -split ","
                    $RawData = $RawData | Select-Object $cols
                }
                if ($RawData) {
                    $TableHTML = $RawData | ConvertTo-Html -Fragment -As Table
                    $TableHTML = $TableHTML -replace "<table>", "<table>"
                    $HTML += $TableHTML
                    $HTML += "<p class='warning'>* Display limited to first 50 rows. <a href='$($Item.File)'>Open Full CSV</a></p>"
                } else {
                    $HTML += "<p>File found but empty.</p>"
                }
            } catch {
                $HTML += "<p style='color:red'>Error parsing CSV: $_</p>"
            }
        }
    }

    # --- BROWSER FORENSICS ---
    $HTML += "<h2>Browser Forensics</h2>"
    $BrowserFolders = Get-ChildItem -Path $OutputDir -Directory -Filter "Browser_*"
    
    if ($BrowserFolders) {
        foreach ($BF in $BrowserFolders) {
            $HTML += "<h3>User: $($BF.Name)</h3>"
            $HTML += "<p><strong>Artifacts:</strong> <a href='$($BF.Name)/analysis.xlsx'>Open Excel Analysis</a></p>"
        }
    } else {
        $HTML += "<p>No Browser artifacts found.</p>"
    }

    $HTML += @"
    <div class='footer'>
        Generated by Cerberus Triage Toolkit | RootGuard DFIR
    </div>
</body>
</html>
"@

    $HTML | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "    [+] HTML Report Generated: $ReportPath" -ForegroundColor Green
    Start-Process $ReportPath
}

# =========================================================================
# MODULE 1: FILESYSTEM & DELETED ITEMS
# =========================================================================
Write-Host "`n[1] FILESYSTEM & DELETED ITEMS" -ForegroundColor Yellow

Run-Tool "MFTECmd.exe" @("-f", "$TargetDrive\$MFT", "--csv", "$OutputDir", "--csvf", "MFT.csv") "Master File Table ($MFT)"
Run-Tool "RBCmd.exe" @("-d", "$TargetDrive\$Recycle.Bin", "--csv", "$OutputDir") "Recycle Bin"

# =========================================================================
# MODULE 2: APPLICATION EXECUTION
# =========================================================================
Write-Host "`n[2] APPLICATION EXECUTION" -ForegroundColor Yellow

Run-Tool "PECmd.exe" @("-d", "$TargetDrive\Windows\Prefetch", "--csv", "$OutputDir", "--csvf", "Prefetch.csv", "-q") "Prefetch"
Run-Tool "AmcacheParser.exe" @("-f", "$TargetDrive\Windows\appcompat\Programs\Amcache.hve", "--csv", "$OutputDir", "--csvf", "Amcache.csv", "-i") "Amcache"
Run-Tool "AppCompatCacheParser.exe" @("--csv", "$OutputDir", "--csvf", "ShimCache.csv", "-t") "ShimCache"
Run-Tool "SrumECmd.exe" @("-f", "$TargetDrive\Windows\System32\sru\SRUDB.dat", "--csv", "$OutputDir") "SRUM Database"

Write-Host "    Searching for Timeline Databases..." -ForegroundColor Green
$TimelineFiles = Get-ChildItem -Path "$TargetDrive\Users" -Filter "ActivitiesCache.db" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like "*ConnectedDevicesPlatform*" }

if ($TimelineFiles) {
    foreach ($DB in $TimelineFiles) {
        $UserParts = $DB.FullName.Split([IO.Path]::DirectorySeparatorChar)
        $UserName = "Unknown"
        for ($i = 0; $i -lt $UserParts.Count; $i++) {
            if ($UserParts[$i] -eq "Users" -and ($i + 1) -lt $UserParts.Count) { $UserName = $UserParts[$i+1]; break }
        }
        $WxTOut = Join-Path $OutputDir "Timeline_$UserName"
        New-Item -Path $WxTOut -ItemType Directory -Force | Out-Null
        Run-Tool "WxTCmd.exe" @("-f", $DB.FullName, "--csv", $WxTOut) "Timeline ($UserName)"
    }
}

# =========================================================================
# MODULE 3: FILE & FOLDER ACCESS
# =========================================================================
Write-Host "`n[3] FILE & FOLDER ACCESS" -ForegroundColor Yellow

Run-Tool "LECmd.exe" @("-d", "$TargetDrive\Users", "--csv", "$OutputDir", "-q") "LNK Files"
Run-Tool "JLECmd.exe" @("-d", "$TargetDrive\Users", "--csv", "$OutputDir", "-q") "Jump Lists"
Run-Tool "SBECmd.exe" @("-d", "$TargetDrive\Users", "--csv", "$OutputDir") "ShellBags"

# =========================================================================
# MODULE 4: REGISTRY
# =========================================================================
Write-Host "`n[4] REGISTRY ARTIFACTS" -ForegroundColor Yellow

# Locates the Config file relative to this script
$ConfigPath = Join-Path $ScriptRoot "..\Config\Forensic_Config.reb"

if (Test-Path $ConfigPath) {
    Run-Tool "RECmd.exe" @("-d", "$TargetDrive\", "--bn", $ConfigPath, "--csv", "$OutputDir") "Registry (Batch)"
} else { 
    Write-Host "      [!] Forensic_Config.reb missing at $ConfigPath" -ForegroundColor Red 
}

# =========================================================================
# MODULE 5: EVENT LOGS
# =========================================================================
Write-Host "`n[5] EVENT LOGS" -ForegroundColor Yellow

$StagingDir = Join-Path $OutputDir "RawLogs_Staging"
New-Item -Path $StagingDir -ItemType Directory -Force | Out-Null
$LogSource = "$TargetDrive\Windows\System32\winevt\Logs"
$LogsToCollect = @("Security.evtx", "System.evtx", "Application.evtx", "Microsoft-Windows-TerminalServices-LocalSessionManager%4Operational.evtx", "Microsoft-Windows-PowerShell%4Operational.evtx")

foreach ($Log in $LogsToCollect) {
    $Source = Join-Path $LogSource $Log
    $Dest = Join-Path $StagingDir $Log
    if (Test-Path $Source) { Copy-Item -Path $Source -Destination $Dest -Force -ErrorAction SilentlyContinue }
}

Run-Tool "EvtxECmd.exe" @("-d", "$StagingDir", "--csv", "$OutputDir", "--csvf", "EventLogs.csv") "Event Logs"

# =========================================================================
# MODULE 6: BROWSER FORENSICS (HINDSIGHT)
# =========================================================================
Write-Host "`n[6] BROWSER FORENSICS (HINDSIGHT)" -ForegroundColor Yellow

# Correctly locates Hindsight one level up in ..\Tools\hindsight
$HindsightExe = Join-Path $ToolsDir "hindsight\hindsight.exe"

if (Test-Path $HindsightExe) {
    $Users = Get-ChildItem -Path "$TargetDrive\Users" -Directory | Where-Object { $_.Name -notin "All Users", "Default", "Default User", "Public" }
    
    foreach ($User in $Users) {
        $BrowserDir = Join-Path $OutputDir "Browser_$($User.Name)"
        New-Item -ItemType Directory -Force -Path $BrowserDir | Out-Null
        
        Write-Host "    Parsing Browser Data: $($User.Name)" -ForegroundColor Green
        
        $OutputPrefix = Join-Path $BrowserDir "analysis"
        $HSArgs = @("-i", $User.FullName, "-o", $OutputPrefix, "--format", "xlsx")
        
        Start-Process -FilePath $HindsightExe -ArgumentList $HSArgs -Wait -NoNewWindow
    }
} else { Write-Host "      [!] Hindsight.exe not found at $HindsightExe" -ForegroundColor Red }

# =========================================================================
# MODULE 7: SYSTEM INFO
# =========================================================================
Write-Host "`n[7] SYSTEM INFORMATION" -ForegroundColor Yellow
try {
    $SysInfo = Get-ComputerInfo | Select-Object OsName, WindowsBuildLabEx, CsName, TimeZone, BiosSeralNumber
    $SysInfo | Export-Csv -Path "$OutputDir\System_Info.csv" -NoTypeInformation
} catch { Write-Host "      [!] Failed to collect system info." -ForegroundColor Red }

# =========================================================================
# MODULE 8: REPORTING
# =========================================================================
Generate-HTMLReport

Write-Host "`n[+] Collection Complete. Data saved to: $OutputDir" -ForegroundColor Cyan