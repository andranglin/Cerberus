param(
    [string]$OutputDir = "C:\Temp\Cerberus_Evidence"
)

# --- Configuration ---
$ErrorActionPreference = "SilentlyContinue"
$ScriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD }

# Ensure Output Directory Exists
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Generate Output Filename
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$MemFile = Join-Path $OutputDir "Memory_$Date.raw"

# --- TOOL DETECTION ---

# 1. Check for Magnet RAM Capture (Priority 1 - Best for Secure Boot)
$MagnetTool = Join-Path $ScriptPath "Tools\MagnetRAMCapture\MagnetRAMCapture.exe"

# 2. Check for DumpIt (Priority 2 - Fast)
$DumpitTool = Join-Path $ScriptPath "Tools\dumpit\dumpit.exe"

Write-Host "[-] Starting Memory Acquisition..." -ForegroundColor Cyan

if (Test-Path $MagnetTool) {
    # ==========================================
    # EXECUTE MAGNET RAM CAPTURE
    # ==========================================
    Write-Host "    Engine: Magnet RAM Capture" -ForegroundColor Green
    Write-Host "    Path:   $MagnetTool" -ForegroundColor Gray
    Write-Host "    Output: $MemFile" -ForegroundColor Gray

    try {
        # /AcceptEULA = Skip license
        # /Go = Start immediately
        # /Silent = Hide GUI (If supported by your version)
        $ArgsList = "/AcceptEULA /Go `"$MemFile`""
        
        $Process = Start-Process -FilePath $MagnetTool -ArgumentList $ArgsList -Wait -PassThru -NoNewWindow
        
        if (Test-Path $MemFile) {
            $Size = (Get-Item $MemFile).Length / 1GB
            Write-Host "`n[+] Memory Captured Successfully ({0:N2} GB)." -f $Size -ForegroundColor Green 
        } else {
            Write-Host "`n[!] Capture Failed." -ForegroundColor Red
            Write-Host "    Note: Magnet GUI may require manual interaction if /Go failed." -ForegroundColor Gray
        }
    }
    catch { Write-Host "    [!] Execution Error: $_" -ForegroundColor Red }

} elseif (Test-Path $DumpitTool) {
    # ==========================================
    # EXECUTE DUMPIT
    # ==========================================
    Write-Host "    Engine: DumpIt" -ForegroundColor Green
    Write-Host "    Path:   $DumpitTool" -ForegroundColor Gray
    Write-Host "    Output: $MemFile" -ForegroundColor Gray

    try {
        # /O = Output Path
        # /Q = Quiet (No prompts)
        $ArgsList = "/O `"$MemFile`" /Q"

        $Process = Start-Process -FilePath $DumpitTool -ArgumentList $ArgsList -Wait -PassThru -NoNewWindow
        
        if (Test-Path $MemFile) {
            $Size = (Get-Item $MemFile).Length / 1GB
            Write-Host "`n[+] Memory Captured Successfully ({0:N2} GB)." -f $Size -ForegroundColor Green 
        } else {
            Write-Host "`n[!] Capture Failed." -ForegroundColor Red
        }
    }
    catch { Write-Host "    [!] Execution Error: $_" -ForegroundColor Red }

} else {
    # ==========================================
    # NO TOOL FOUND
    # ==========================================
    Write-Host "    [!] No Memory Tool Found!" -ForegroundColor Red
    Write-Host "        Checked locations:" -ForegroundColor Gray
    Write-Host "        1. $MagnetTool" -ForegroundColor Gray
    Write-Host "        2. $DumpitTool" -ForegroundColor Gray
}