# 🐕 Cerberus Triage Toolkit

<div align="center">

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg?style=flat&logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg?style=flat&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)
![Maintenance](https://img.shields.io/badge/Maintained-Yes-orange.svg)

**A modular, agentless Incident Response framework for rapid evidence collection, live analysis, and remote acquisition.**

[Features](#-key-features) • [Installation](#-installation) • [Usage](#-usage) • [Directory Structure](#-directory-structure) • [Contributing](#-contributing)

</div>

---

**Cerberus** integrates industry-standard forensic tools (**EZTools**, **KAPE**, **Volatility**, **Hindsight**) into a unified PowerShell automation engine. It uses a "Zip & Ship" architecture to push tools to remote endpoints via WinRM, execute analysis, and retrieve evidence—all without leaving your workstation.

> [!IMPORTANT]
> **Tooling & Licensing**
> This repository contains the **automation logic only**. Due to licensing restrictions, it does **not** distribute third-party binaries (KAPE, EZTools, etc.). You must populate the `./Tools/` directory using the provided instructions below.

---

## 🚀 Key Features

| Feature | Description |
| :--- | :--- |
| **📡 Agentless Acquisition** | Push-button deployment via WinRM using `Invoke-RemoteForensics`. |
| **🧠 Smart Memory Capture** | Auto-detects environment to choose between `MagnetRAMCapture` (Secure Boot) or `DumpIt`. |
| **⚡ Live Response Mode** | Instantly generate HTML reports of running processes, active connections, and logged-on users. |
| **🕵️ Browser Forensics** | Automated parsing of Chrome/Edge history using **Hindsight** (Outputs to XLSX & HTML). |
| **🔎 Volatility Integration** | Includes support for `Volatility 3` for immediate memory analysis. |
| **📊 Unified Reporting** | Generates a styled, interactive HTML Triage Report linking all collected evidence. |

---

## 📦 Installation

### 1. Clone the Repository
```bash
git clone [https://github.com/andranglin/Cerberus-Triage.git](https://github.com/andranglin/Cerberus.git)
cd Cerberus

2. Initialize the Framework
Run the setup script to create the necessary directory structure and placeholder files.
.\Initialize-Cerberus.ps1

3. Populate External Tools
Cerberus relies on specific external binaries. Download and place them in the following paths:
EZTools: Download from Eric Zimmerman's GitHub → .\Tools\EZTools\
KAPE: Download from Kroll → .\Tools\kape\
Hindsight: Download from Obsidian Forensics → .\Tools\hindsight\
Volatility 3: Download from Volatility Foundation → .\Tools\volatility3\

Memory Tools:
Magnet: Place executable in .\Tools\MagnetRAMCapture\
DumpIt: Place executable in .\Tools\dumpit\

🛠 Usage
Option 1: Main Console (Recommended)
Launch the interactive console to access all modules from a menu-driven interface.
.\Cerberus_Console.ps1

Option 2: Remote Forensics
Target a remote machine directly using the module. This handles authentication, tool deployment, and retrieval.
# Syntax
.\Modules\Invoke-RemoteForensics.ps1 -TargetComputer <NAME> -Credential (Get-Credential) -Mode <1-4>

# Example: Full Collection (Artifacts + Memory)
$Creds = Get-Credential
.\Modules\Invoke-RemoteForensics.ps1 -TargetComputer "WORKSTATION-01" -Credential $Creds -Mode 3

Collection Modes:
Mode 1 (Triage): Standard Artifacts (MFT, Registry, Evtx) + Browser History.
Mode 2 (Deep): Triage + Deep Registry Parse + Amcache.
Mode 3 (Full): All Artifacts + Memory Capture.
Mode 4 (Live): Live Response only (Processes, Network, Users) - Fastest.

Option 3: Local Standalone
Run individual modules directly on a suspect machine (e.g., via USB execution).
# Collect standard artifacts
.\Modules\Invoke-WinArtifacts.ps1 -OutputDir "C:\Evidence"

# Capture Memory Only
.\Modules\Invoke-MemoryCapture.ps1 -OutputDir "C:\Evidence"

📂 Directory Structure
Ensure your folder looks exactly like this. The scripts rely on these specific folder names to find the tools.
Cerberus/
│
├── Cerberus_Console.ps1          # Main Launcher
├── Initialize-Cerberus.ps1       # Setup Script
├── Config/                       # Configuration files
│
├── Modules/                      # PowerShell Logic
│   ├── Analyze-Results.ps1
│   ├── Invoke-KapeCollection.ps1
│   ├── Invoke-LiveResponse.ps1
│   ├── Invoke-MemoryCapture.ps1
│   ├── Invoke-RemoteForensics.ps1
│   ├── Invoke-Vol3Analysis.ps1
│   └── Invoke-WinArtifacts.ps1
│
└── Tools/                        # Third-Party Binaries
    ├── EZTools/                  # [Download Here]
    ├── kape/                     # [Download Here]
    ├── hindsight/                # [Download Here]
    ├── volatility3/              # [Download Here]
    ├── dumpit/                   # [Download Here]
    └── MagnetRAMCapture/         # [Download Here]

⚖️ Disclaimer & License
Cerberus is provided "as is" without warranty of any kind. The user is responsible for ensuring they have the necessary legal authorization to run forensic tools on the target infrastructure.

Distributed under the MIT License.