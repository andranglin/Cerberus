Description: Cerberus Triage Registry Map
Author: RootGuard DFIR
Version: 1.0
Id: 1e999999-0000-0000-0000-000000000001
Keys:
  - Description: Run Keys (HKLM)
    HiveType: Software
    Category: Persistence
    KeyPath: Microsoft\Windows\CurrentVersion\Run
    Recursive: false
    
  - Description: RunOnce Keys (HKLM)
    HiveType: Software
    Category: Persistence
    KeyPath: Microsoft\Windows\CurrentVersion\RunOnce
    Recursive: false

  - Description: Run Keys (HKCU)
    HiveType: NtUser
    Category: Persistence
    KeyPath: Software\Microsoft\Windows\CurrentVersion\Run
    Recursive: false

  - Description: USB Storage Devices
    HiveType: System
    Category: Devices
    KeyPath: ControlSet001\Enum\USBSTOR
    Recursive: true

  - Description: Mounted Devices
    HiveType: System
    Category: Devices
    KeyPath: MountedDevices
    Recursive: false

  - Description: UserAssist (Program Execution)
    HiveType: NtUser
    Category: Execution
    KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist
    Recursive: true

  - Description: Typed URLs (Internet Explorer/Explorer)
    HiveType: NtUser
    Category: Browser
    KeyPath: Software\Microsoft\Internet Explorer\TypedURLs
    Recursive: false

  - Description: Services
    HiveType: System
    Category: System
    KeyPath: ControlSet001\Services
    Recursive: true