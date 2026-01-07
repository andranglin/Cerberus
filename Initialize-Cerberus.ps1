<#
.SYNOPSIS
    Cerberus Toolkit Initializer
.DESCRIPTION
    Creates the required directory structure for the Cerberus Triage Toolkit.
    Since the repository does not contain binary tools (licensing), this script
    prepares the folders where the user must place them.
#>

$ErrorActionPreference = "SilentlyContinue"
$RootPath = $PSScriptRoot

Write-Host "
   CERBERUS TOOLKIT INITIALIZATION
   ===============================
   Setting up directory structure...
" -ForegroundColor Cyan

# 1. Define the required folders
$ToolFolders = @(
    "Tools\EZTools",
    "Tools\KAPE",
    "Tools\hindsight",
    "Tools\MagnetRAMCapture",
    "Tools\dumpit",
    "Tools\sysinternals"
)

# 2. Create folders and add "Read Me" placeholders
foreach ($Folder in $ToolFolders) {
    $FullPath = Join-Path $RootPath $Folder
    
    if (-not (Test-Path $FullPath)) {
        New-Item -Path $FullPath -ItemType Directory -Force | Out-Null
        Write-Host "    [+] Created: $Folder" -ForegroundColor Green
    } else {
        Write-Host "    [=] Exists:  $Folder" -ForegroundColor Gray
    }

    # Create a dummy file so the user knows what goes here
    $ReadMePath = Join-Path $FullPath "_PUT_TOOLS_HERE.txt"
    if (-not (Test-Path $ReadMePath)) {
        $Content = "Please download the executable for $Folder and place it in this directory."
        Set-Content -Path $ReadMePath -Value $Content
    }
}

# 3. Create Output Folders
$EvidencePath = Join-Path $RootPath "Evidence"
if (-not (Test-Path $EvidencePath)) { New-Item -Path $EvidencePath -ItemType Directory -Force | Out-Null }

Write-Host "
   [!] SETUP REQUIRED
   ------------------
   The folder structure is ready. You must now download the tools:

   1. EZTools:   https://ericzimmerman.github.io/
                 (Place MFTECmd.exe, PECmd.exe, etc. in \Tools\EZTools)
   
   2. KAPE:      https://www.kroll.com/en/services/cyber-risk/incident-response-litigation-support/kroll-artifact-parser-extractor-kape
                 (Place kape.exe in \Tools\KAPE)
   
   3. Hindsight: https://github.com/obsidianforensics/hindsight
                 (Place hindsight.exe in \Tools\hindsight)

   [+] Initialization Complete.
" -ForegroundColor Yellow