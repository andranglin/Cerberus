
[![Stars](https://img.shields.io/github/stars/andranglin/Cerberus?style=social)](https://github.com/andranglin/Cerberus/stargazers)
[![Forks](https://img.shields.io/github/forks/andranglin/Cerberus?style=social)](https://github.com/andranglin/Cerberus/network/members)
[![License](https://img.shields.io/github/license/andranglin/Cerberus)](https://github.com/andranglin/Cerberus/blob/main/LICENSE)
[![Releases](https://img.shields.io/github/v/release/andranglin/Cerberus)](https://github.com/andranglin/Cerberus/releases)

**A modular, agentless PowerShell-based Incident Response framework for rapid evidence collection, live forensics, and remote acquisition.**

Cerberus integrates industry-standard tools (EZTools, KAPE, Volatility 3, Hindsight) into a unified automation engine. Using a "Zip & Ship" approach over WinRM, it deploys tools to remote Windows endpoints, executes collection/analysis, and retrieves evidence—all from your analyst workstation without installing agents.

Ideal for blue teamers, incident responders, and DFIR professionals needing fast, scalable triage across enterprise environments.

[Features](#-key-features) • [Requirements](#-requirements) • [Installation](#-installation) • [Usage](#-usage) • [Directory Structure](#-directory-structure) • [Troubleshooting](#-troubleshooting) • [Contributing](#-contributing) • [License](#-license)

---

## 🚀 Key Features

| Feature                  | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| 📡 **Agentless Acquisition** | One-click remote deployment via WinRM with `Invoke-RemoteForensics.ps1`.   |
| 🧠 **Smart Memory Capture**  | Auto-detects Secure Boot to select Magnet RAM Capture or DumpIt.            |
| ⚡ **Live Response Mode**    | Rapid HTML reports for processes, network connections, and logged-on users.|
| 🌐 **Browser Forensics**     | Automated Chrome/Edge history parsing with Hindsight (XLSX + HTML output).  |
| 🔎 **Volatility Integration**| Built-in Volatility 3 support for on-the-fly memory analysis.              |
| 📊 **Unified Reporting**     | Styled, interactive HTML triage report with links to all artifacts.        |

---

## ✅ Requirements

- Windows PowerShell 5.1+ (or PowerShell 7 recommended)
- WinRM enabled on target systems (common in domain environments)
- Administrative privileges on targets
- Network connectivity (ports 5985/HTTP or 5986/HTTPS for WinRM)

---

## 📦 Installation

### 1. Clone the Repository
```powershell
git clone https://github.com/andranglin/Cerberus.git
cd Cerberus
2. Initialise the Framework
This creates the required folders and placeholders:
```powerShell
.\Initialize-Cerberus.ps1
3. Populate External Tools
Download the latest versions and extract/place executables in the exact subfolders below:

EZTools → Eric Zimmerman's Tools → .\Tools\EZTools\
KAPE → Kroll Artifact Parser and Extractor → .\Tools\kape\
Hindsight → Obsidian Forensics Releases → .\Tools\hindsight\
Volatility 3 → Volatility Foundation → .\Tools\volatility3\
DumpIt → MoonSols/Comae → .\Tools\dumpit\
Magnet RAM Capture → Magnet Forensics → .\Tools\MagnetRAMCapture\

Note: Tools are not bundled to ensure you always use the latest, verified versions.

🛠 Usage
Option 1: Interactive Console (Recommended)
```PowerShell
.\Cerberus_Console.ps1
Menu-driven access to all modules.

Option 2: Remote Forensics (Direct Targeting)
```PowerShell
.\Modules\Invoke-RemoteForensics.ps1 -TargetComputer <HOSTNAME> -Credential (Get-Credential) -Mode <1-4>
Example (Full Collection):
```PowerShell
$Creds = Get-Credential
.\Modules\Invoke-RemoteForensics.ps1 -TargetComputer "WORKSTATION-01" -Credential $Creds -Mode 3

Modes:
1 (Triage): Core artifacts + browser history
2 (Deep): Triage + advanced registry/amcache
3 (Full): Everything + memory dump
4 (Live): Quick live response only

Option 3: Local Execution
```PowerShell
.\Modules\Invoke-WinArtifacts.ps1 -OutputDir "C:\Evidence"
.\Modules\Invoke-MemoryCapture.ps1 -OutputDir "C:\Evidence"

📂 Directory Structure
textCerberus/
├── Cerberus_Console.ps1
├── Initialize-Cerberus.ps1
├── Config/                       # Config files
├── Modules/                      # Core PowerShell scripts
└── Tools/                        # Third-party tools (populate manually)
    ├── EZTools/
    ├── kape/
    ├── hindsight/
    ├── volatility3/
    ├── dumpit/
    └── MagnetRAMCapture/

🐛 Troubleshooting

WinRM Errors: Run winrm quickconfig on targets or enable via GPO.
Tool Not Found: Verify exact paths and executable names in Tools/.
Execution Policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Issues? Open an Issue on GitHub.


🤝 Contributing
Contributions welcome! Please:

Fork the repo
Create a feature branch
Submit a Pull Request with a clear description

Ideas: New modules, better error handling, additional tool integrations.

⚖️ Disclaimer & License
Cerberus is provided "as is" without warranty. Ensure legal authorisation before use on systems.
MIT License – see LICENSE for details.

Acknowledgements: Built on the amazing work of Eric Zimmerman (KAPE), Obsidian Forensics (Hindsight), Volatility Foundation, and the broader DFIR community.
⭐ Star the repo if this helps your investigations!
