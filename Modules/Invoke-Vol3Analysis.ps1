param(
    [Parameter(Mandatory=$true)]
    [string]$MemoryDump,

    [string]$OutputDir
)

# --- CONFIGURATION ---
$VolScript = ".\Tools\volatility3\vol.py"
$PythonExe = "python.exe" 

# --- VALIDATION ---
if (-not (Test-Path $VolScript)) { 
    Write-Error "vol.py not found in .\Tools\volatility3\. Please check your directory."
    exit 
}
if (-not (Test-Path $MemoryDump)) { 
    Write-Error "Memory dump file not found: $MemoryDump"
    exit 
}

# --- SETUP OUTPUT ---
if ([string]::IsNullOrWhiteSpace($OutputDir)) { 
    $OutputDir = Join-Path (Split-Path $MemoryDump) "Volatility_Analysis" 
}
New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

Write-Host "[-] Starting RootGuard Memory Forensics (Volatility 3)..." -ForegroundColor Cyan
Write-Host "    Dump: $MemoryDump" -ForegroundColor Gray
Write-Host "    Out:  $OutputDir" -ForegroundColor Gray

# --- EXECUTION ENGINE ---
function Run-Vol($Plugin, $FileName, $Description) {
    Write-Host "    - Running: windows.$Plugin" -NoNewline -ForegroundColor Green
    Write-Host " ($Description)..." -ForegroundColor Gray
    
    $OutFile = Join-Path $OutputDir "$FileName.txt"
    
    # Arguments: python vol.py -f "image.mem" windows.plugin
    $ArgsList = @(
        $VolScript,
        "-f", "`"$MemoryDump`"",
        "windows.$Plugin"
    )

    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $PythonExe
    $ProcessInfo.Arguments = $ArgsList -join " "
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
    $Output = $Process.StandardOutput.ReadToEnd()
    $Errors = $Process.StandardError.ReadToEnd()
    $Process.WaitForExit()
    
    if (-not [string]::IsNullOrWhiteSpace($Output)) {
        $Output | Out-File -FilePath $OutFile -Encoding UTF8
    } elseif (-not [string]::IsNullOrWhiteSpace($Errors)) {
        $Errors | Out-File -FilePath "$OutFile.err.txt" -Encoding UTF8
        Write-Host "      [!] Plugin reported errors (see .err.txt)" -ForegroundColor Yellow
    }
}

# ==========================================================
# PHASE 1: SYSTEM OVERVIEW & PROCESSES
# ==========================================================
Write-Host "`n[Phase 1] System & Process Triage" -ForegroundColor Yellow

# 1. Image Info
Run-Vol "info" "System_Info" "Identifying OS Profile"

# 2. Process Tree (Parent/Child relationships)
Run-Vol "pstree" "Process_Tree" "Visualizing Execution Chain"

# 3. Process Scan (Finds unlinked/hidden processes - Rootkit check)
Run-Vol "psscan" "Process_Scan_Hidden" "Hunting Unlinked Processes"

# 4. Command Lines (How processes were launched)
Run-Vol "cmdline" "Command_Lines" "Extracting Launch Arguments"

# ==========================================================
# PHASE 2: NETWORK & CODE INJECTION
# ==========================================================
Write-Host "`n[Phase 2] Network & Malicious Code" -ForegroundColor Yellow

# 5. Network Scan (Active connections & Listeners)
Run-Vol "netscan" "Network_Connections" "Finding C2 Connections"

# 6. Malfind (Injected Code / Shellcode)
Run-Vol "malfind" "Injection_Malfind" "Scanning for Injected Shellcode"

# ==========================================================
# PHASE 3: PERSISTENCE & SERVICES
# ==========================================================
Write-Host "`n[Phase 3] Persistence Mechanisms" -ForegroundColor Yellow

# 7. Service Scan (List Services running in RAM)
Run-Vol "svcscan" "Services_Active" "Listing Windows Services"

# 8. Modules (Kernel Drivers - Rootkit check)
Run-Vol "modules" "Kernel_Modules" "Listing Loaded Drivers"

# 9. DLL List (Libraries loaded by processes)
Run-Vol "dlllist" "Loaded_DLLs" "Auditing Process Libraries"

# ==========================================================
# PHASE 4: FILES & HANDLES (Deep Dive)
# ==========================================================
Write-Host "`n[Phase 4] Filesystem & Indicators" -ForegroundColor Yellow

# 10. Handles (Open files, registry keys, mutexes)
Run-Vol "handles" "Open_Handles" "Listing Open Files/Mutexes"

# 11. File Scan (Find file objects in memory)
# Note: filescan can be verbose/slow, but critical for finding malware artifacts
Run-Vol "filescan" "File_Objects" "Scanning for File Objects"

# 12. Registry Hives (List loaded hives)
Run-Vol "registry.hivelist" "Registry_Hives" "Listing Loaded Registry Hives"

Write-Host "`n[+] Analysis Complete. Reports saved to $OutputDir" -ForegroundColor Cyan
Start-Process $OutputDir