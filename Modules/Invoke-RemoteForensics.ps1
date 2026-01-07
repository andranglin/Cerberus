#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetComputer,

    [Parameter(Mandatory=$true)]
    [pscredential]$Credential,

    [ValidateSet("1","2","3","4")]
    [string]$Mode = "1", 
    # 1 = Standard Artifacts (EZTools + Hindsight)
    # 2 = KAPE Collection
    # 3 = Live Response (Scripts Only)
    # 4 = Memory Capture (Magnet/DumpIt)

    [string]$LocalOutputBase = "C:\Temp\Cerberus_Remote_Cases"
)

# --- CONFIGURATION ---
$ErrorActionPreference = "SilentlyContinue"
$RemoteStagingDir = "C:\Windows\Temp\Cerberus_Staging"
$SourceRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD }
$LocalTempZip = "$env:TEMP\Cerberus_Tools_Deploy.zip"
$LocalTempStage = "$env:TEMP\Cerberus_Stage"

# Generate Case ID
$DateStr = Get-Date -Format "yyyyMMdd_HHmmss"
$CaseID = "Remote_${TargetComputer}_$DateStr"
$LocalDest = Join-Path $LocalOutputBase $CaseID

# --- UI HEADER ---
Clear-Host
Write-Host "
   CERBERUS REMOTE ACQUISITION ENGINE (FAST DEPLOY)
   ================================================
   Target:  $TargetComputer
   Mode:    $Mode
   Case ID: $CaseID
" -ForegroundColor Cyan

# --- STEP 1: CONNECTIVITY CHECK ---
Write-Host "[-] Step 1: Checking Connectivity..." -ForegroundColor Yellow
if (-not (Test-Connection -ComputerName $TargetComputer -Count 1 -Quiet)) {
    Write-Host "    [!] Target $TargetComputer is unreachable." -ForegroundColor Red
    exit
}
Write-Host "    [+] Target is Online." -ForegroundColor Green

# --- STEP 2: AUTHENTICATION ---
Write-Host "[-] Step 2: Authenticating..." -ForegroundColor Yellow
try {
    $Session = New-PSSession -ComputerName $TargetComputer -Credential $Credential -ErrorAction Stop
    Write-Host "    [+] Session Established." -ForegroundColor Green
} catch {
    Write-Host "    [!] Authentication Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# --- STEP 3: PREPARE & DEPLOY TOOLKIT ---
Write-Host "[-] Step 3: Compressing & Deploying Toolkit..." -ForegroundColor Yellow

# Clean local temp
if (Test-Path $LocalTempStage) { Remove-Item $LocalTempStage -Recurse -Force }
if (Test-Path $LocalTempZip)   { Remove-Item $LocalTempZip -Force }
New-Item -Path "$LocalTempStage\Tools" -ItemType Directory -Force | Out-Null

# 3a. Smart Staging (Copy ONLY what we need to a temp folder locally)
$ToolsToZip = $false

switch ($Mode) {
    "1" { 
        Write-Host "    [>] Staging EZTools & Hindsight locally..." -ForegroundColor Cyan
        Copy-Item "$SourceRoot\Tools\EZTools" "$LocalTempStage\Tools" -Recurse -Force
        Copy-Item "$SourceRoot\Tools\hindsight" "$LocalTempStage\Tools" -Recurse -Force
        $ToolsToZip = $true
    }
    "2" {
        Write-Host "    [>] Staging KAPE locally..." -ForegroundColor Cyan
        Copy-Item "$SourceRoot\Tools\KAPE" "$LocalTempStage\Tools" -Recurse -Force
        $ToolsToZip = $true
    }
    "3" {
        Write-Host "    [>] Live Response selected (No heavy tools needed)." -ForegroundColor Green
        # No zipping needed
    }
    "4" {
        Write-Host "    [>] Staging Memory Tools locally..." -ForegroundColor Cyan
        if (Test-Path "$SourceRoot\Tools\MagnetRAMCapture") {
            Copy-Item "$SourceRoot\Tools\MagnetRAMCapture" "$LocalTempStage\Tools" -Recurse -Force
        }
        if (Test-Path "$SourceRoot\Tools\dumpit") {
            Copy-Item "$SourceRoot\Tools\dumpit" "$LocalTempStage\Tools" -Recurse -Force
        }
        $ToolsToZip = $true
    }
}

# 3b. Zip the staged tools (If needed)
if ($ToolsToZip) {
    Write-Host "    [>] Compressing tools to ZIP (This improves speed)..." -ForegroundColor Cyan
    Compress-Archive -Path "$LocalTempStage\Tools" -DestinationPath $LocalTempZip -Force
}

# 3c. Initialize Remote Directory
Invoke-Command -Session $Session -ScriptBlock {
    param($Path)
    if (Test-Path $Path) { Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
} -ArgumentList $RemoteStagingDir

# 3d. Upload Files
Write-Host "    [>] Uploading Scripts..." -ForegroundColor Cyan
Copy-Item -Path "$SourceRoot\*.ps1" -Destination "$RemoteStagingDir" -ToSession $Session -Force
Copy-Item -Path "$SourceRoot\Forensic_Config.reb" -Destination "$RemoteStagingDir" -ToSession $Session -Force

if ($ToolsToZip) {
    Write-Host "    [>] Uploading Tools Package (Single File Transfer)..." -ForegroundColor Cyan
    Copy-Item -Path $LocalTempZip -Destination "$RemoteStagingDir\Tools.zip" -ToSession $Session -Force
    
    # 3e. Extract on Remote
    Write-Host "    [>] Extracting Tools on Remote Target..." -ForegroundColor Cyan
    Invoke-Command -Session $Session -ScriptBlock {
        param($ZipPath, $DestPath)
        Expand-Archive -Path $ZipPath -DestinationPath $DestPath -Force
        Remove-Item $ZipPath -Force # Delete zip to save space
    } -ArgumentList "$RemoteStagingDir\Tools.zip", "$RemoteStagingDir"
}

Write-Host "    [+] Deployment Complete." -ForegroundColor Green

# --- STEP 4: EXECUTE FORENSICS ---
Write-Host "[-] Step 4: Executing Mode $Mode..." -ForegroundColor Yellow

$RemoteScriptBlock = {
    param($Mode, $StagingDir)
    
    Set-Location $StagingDir
    $EvidenceDir = Join-Path $StagingDir "Evidence"
    New-Item -Path $EvidenceDir -ItemType Directory -Force | Out-Null
    
    Write-Output "    [Remote] Working Directory: $PWD"
    
    switch ($Mode) {
        "1" { 
            Write-Output "    [Remote] Launching Standard Collection..."
            .\Invoke-WinArtifacts.ps1 -TargetDrive "C:" -OutputDir $EvidenceDir
        }
        "2" {
            Write-Output "    [Remote] Launching KAPE..."
            .\Invoke-KapeCollection.ps1 -TargetDrive "C:" -OutputDir $EvidenceDir
        }
        "3" {
            Write-Output "    [Remote] Launching Live Response..."
            .\Invoke-LiveResponse.ps1 -OutputDir $EvidenceDir
        }
        "4" {
            Write-Output "    [Remote] Launching Memory Capture..."
            .\Invoke-MemoryCapture.ps1 -OutputDir $EvidenceDir
        }
    }
}

Invoke-Command -Session $Session -ScriptBlock $RemoteScriptBlock -ArgumentList $Mode, $RemoteStagingDir

# --- STEP 5: RETRIEVE EVIDENCE ---
Write-Host "[-] Step 5: Retrieving Evidence..." -ForegroundColor Yellow

if (-not (Test-Path $LocalDest)) { New-Item -Path $LocalDest -ItemType Directory -Force | Out-Null }

try {
    # Check remote evidence
    $HasEvidence = Invoke-Command -Session $Session -ScriptBlock { param($P) Test-Path $P } -ArgumentList "$RemoteStagingDir\Evidence"
    
    if ($HasEvidence) {
        # Zip Evidence Remotely before downloading (Speeds up download too!)
        Write-Host "    [>] Compressing Evidence on Remote Target..." -ForegroundColor Cyan
        $RemoteZip = "$RemoteStagingDir\Evidence.zip"
        
        Invoke-Command -Session $Session -ScriptBlock {
            param($Src, $Dst)
            Compress-Archive -Path "$Src\*" -DestinationPath $Dst -Force
        } -ArgumentList "$RemoteStagingDir\Evidence", $RemoteZip
        
        Write-Host "    [>] Downloading Evidence Package..." -ForegroundColor Cyan
        Copy-Item -Path $RemoteZip -Destination "$LocalDest\Evidence.zip" -FromSession $Session -Force
        
        # Unzip Locally
        Write-Host "    [>] Extracting Evidence Locally..." -ForegroundColor Cyan
        Expand-Archive -Path "$LocalDest\Evidence.zip" -DestinationPath "$LocalDest" -Force
        Remove-Item "$LocalDest\Evidence.zip" -Force
        
        Write-Host "    [+] Evidence saved to: $LocalDest" -ForegroundColor Green
        Invoke-Item $LocalDest
    } else {
        Write-Host "    [!] No evidence found on target." -ForegroundColor Red
    }
} catch {
    Write-Host "    [!] Download Failed: $_" -ForegroundColor Red
}

# --- STEP 6: CLEANUP ---
Write-Host "[-] Step 6: Cleanup..." -ForegroundColor Yellow

# Clean Remote
Invoke-Command -Session $Session -ScriptBlock {
    param($Path)
    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
} -ArgumentList $RemoteStagingDir

# Clean Local Temp
if (Test-Path $LocalTempStage) { Remove-Item $LocalTempStage -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $LocalTempZip)   { Remove-Item $LocalTempZip -Force -ErrorAction SilentlyContinue }

Remove-PSSession $Session
Write-Host "[+] Operation Complete." -ForegroundColor Green