param(
    [string]$CaseDir
)

# --- CONFIGURATION ---
$ErrorActionPreference = "SilentlyContinue"

# Check Input
if ([string]::IsNullOrWhiteSpace($CaseDir) -or -not (Test-Path $CaseDir)) {
    Write-Host "[!] Error: Case Directory not found." -ForegroundColor Red
    Write-Host "    Usage: .\Analyze-Results.ps1 -CaseDir 'C:\Temp\Cerberus_Cases\Case-001'" -ForegroundColor Yellow
    exit
}

Write-Host "[-] Starting Cerberus Analysis Module..." -ForegroundColor Cyan
Write-Host "    Case: $CaseDir" -ForegroundColor Gray

# --- HTML REPORTING ENGINE ---

function Generate-AnalysisReport {
    $ReportPath = Join-Path $CaseDir "Cerberus_Master_Analysis.html"
    
    # CSS Styling (Cerberus Dark Theme)
    $CSS = @"
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #e0e0e0; margin: 20px; }
        h1 { color: #d50000; border-bottom: 2px solid #d50000; padding-bottom: 10px; text-transform: uppercase; letter-spacing: 2px; }
        h2 { color: #00b0ff; margin-top: 40px; border-left: 5px solid #00b0ff; padding-left: 15px; background-color: #1f1f1f; padding: 10px; }
        h3 { color: #00e676; margin-top: 20px; }
        .meta { background-color: #1e1e1e; padding: 15px; border: 1px solid #333; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 0.85em; box-shadow: 0 4px 8px rgba(0,0,0,0.5); }
        th, td { padding: 10px 12px; border: 1px solid #333; text-align: left; }
        th { background-color: #263238; color: #ffffff; text-transform: uppercase; font-size: 0.8em; }
        tr:nth-child(even) { background-color: #1a1a1a; }
        tr:hover { background-color: #37474f; transition: 0.2s; }
        .warning { color: #ffab00; font-style: italic; font-size: 0.8em; margin-top: 5px; }
        a { color: #40c4ff; text-decoration: none; font-weight: bold; }
        a:hover { text-decoration: underline; }
        .footer { margin-top: 50px; font-size: 0.8em; color: #555; text-align: center; border-top: 1px solid #333; padding-top: 20px; }
        .stat-box { display: inline-block; background: #263238; padding: 10px; margin-right: 10px; border-radius: 4px; min-width: 150px; text-align: center; }
        .stat-num { font-size: 1.5em; font-weight: bold; display: block; color: #fff; }
        .stat-label { font-size: 0.8em; color: #aaa; text-transform: uppercase; }
    </style>
"@

    # HTML Header
    $HTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Cerberus Master Analysis</title>
    $CSS
</head>
<body>
    <h1>Cerberus Master Analysis Report</h1>
    
    <div class='meta'>
        <strong>Case Directory:</strong> $CaseDir <br>
        <strong>Generated:</strong> $(Get-Date) <br>
        <strong>Analyst:</strong> $env:USERNAME
    </div>
"@

    # --- SECTION 1: SYSTEM OVERVIEW ---
    $SysInfoPath = Join-Path $CaseDir "System_Info.csv"
    if (Test-Path $SysInfoPath) {
        $SysInfo = Import-Csv $SysInfoPath | Select-Object -First 1
        $HTML += "<h2>System Overview</h2>"
        $HTML += "<div style='display:flex; flex-wrap:wrap;'>"
        
        $Props = @("OsName", "CsName", "TimeZone", "BiosSeralNumber")
        foreach ($P in $Props) {
            if ($SysInfo.$P) {
                $HTML += "<div class='stat-box'><span class='stat-num'>$($SysInfo.$P)</span><span class='stat-label'>$P</span></div>"
            }
        }
        $HTML += "</div>"
    }

    # --- SECTION 2: EVIDENCE ANALYSIS ---
    # Defines which CSVs to process and which columns are relevant
    $Artifacts = @(
        @{ File="Prefetch.csv"; Title="Execution: Prefetch (Top 50)"; Cols="SourceFilename","LastRun","RunCount","PreviousRun0" },
        @{ File="ShimCache.csv"; Title="Execution: ShimCache (Recent)"; Cols="Path","LastModifiedTimeUTC","Executed" },
        @{ File="Amcache.csv"; Title="Installed Software (Amcache)"; Cols="Name","InstallDate","Publisher","ProductVersion" },
        @{ File="EventLogs.csv"; Title="Security & System Events"; Cols="TimeCreated","EventId","Provider","Payload" },
        @{ File="MFT.csv"; Title="File System (MFT - Recent Files)"; Cols="FileName","FileSize","Created0x10","LastModified0x10","ParentPath" },
        @{ File="LNK Files_LECmd_Output.csv"; Title="LNK Files (User Access)"; Cols="SourceFile","TargetAbsolutePath","SourceCreated","SourceModified" }
    )

    foreach ($Item in $Artifacts) {
        $Path = Join-Path $CaseDir $Item.File
        
        # Check if file exists (Exact name) OR if generated file has timestamp appended (Wildcard check)
        if (-not (Test-Path $Path)) {
            $WildcardPath = Join-Path $CaseDir "$($Item.File.Replace('.csv','*'))"
            $Found = Get-ChildItem -Path $WildcardPath -Filter "*.csv" | Select-Object -First 1
            if ($Found) { $Path = $Found.FullName }
        }

        if (Test-Path $Path) {
            $HTML += "<h2>$($Item.Title)</h2>"
            
            try {
                # Import, Select Columns, Limit Rows
                $RawData = Import-Csv -Path $Path | Select-Object -First 50
                
                # Filter Columns if specified
                if ($Item.Cols -ne "*") {
                    $cols = $Item.Cols -split ","
                    # Verify columns exist before selecting to avoid empty tables
                    $Header = $RawData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    $ValidCols = $cols | Where-Object { $Header -contains $_ }
                    if ($ValidCols) { $RawData = $RawData | Select-Object $ValidCols }
                }

                if ($RawData) {
                    $Table = $RawData | ConvertTo-Html -Fragment -As Table
                    $Table = $Table -replace "<table>", "<table>" # Hook for CSS if needed
                    $HTML += $Table
                    $HTML += "<p class='warning'>* Display limited to first 50 rows. <a href='$($Path)'>[Open Full CSV]</a></p>"
                } else {
                    $HTML += "<p>Artifact exists but contains no data rows.</p>"
                }
            } catch {
                $HTML += "<p style='color:red'>Error parsing CSV: $_</p>"
            }
        }
    }

    # --- SECTION 3: BROWSER ARTIFACTS ---
    $HTML += "<h2>Browser Forensics</h2>"
    $Browsers = Get-ChildItem -Path $CaseDir -Directory -Filter "Browser_*"
    
    if ($Browsers) {
        $HTML += "<ul>"
        foreach ($B in $Browsers) {
            $HTML += "<li><strong>$($B.Name)</strong>: <a href='$($B.Name)/analysis.xlsx'>Open Excel Analysis</a></li>"
        }
        $HTML += "</ul>"
    } else {
        $HTML += "<p>No Browser artifacts found.</p>"
    }

    # --- SECTION 4: TIMELINE ANALYSIS ---
    # Check for Windows 10 Timeline folders
    $Timelines = Get-ChildItem -Path $CaseDir -Directory -Filter "Timeline_*"
    if ($Timelines) {
        $HTML += "<h2>Windows Activity Timeline</h2>"
        $HTML += "<ul>"
        foreach ($T in $Timelines) {
             # Look for CSV inside
             $CSV = Get-ChildItem -Path $T.FullName -Filter "*.csv" | Select-Object -First 1
             if ($CSV) {
                 $HTML += "<li>User <strong>$($T.Name.Replace('Timeline_',''))</strong>: <a href='$($T.Name)/$($CSV.Name)'>Open Timeline CSV</a></li>"
             }
        }
        $HTML += "</ul>"
    }

    # Footer
    $HTML += @"
    <div class='footer'>
        Generated by Cerberus Triage Toolkit | RootGuard DFIR
    </div>
</body>
</html>
"@

    $HTML | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "    [+] Report Generated: $ReportPath" -ForegroundColor Green
    Start-Process $ReportPath
}

# --- EXECUTION ---
Generate-AnalysisReport
Write-Host "[-] Analysis Complete." -ForegroundColor Cyan