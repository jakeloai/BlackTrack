# BlackStealth

Silent Windows collection toolkit designed for authorized red team operations, internal security assessments, and controlled enterprise environments.

---

# Modules

| Module                  | Description                                      | Admin |
| ----------------------- | ------------------------------------------------ | ----- |
| `Backup_Profile.ps1`    | Collects Desktop, Downloads, Documents, Pictures | No    |
| `Backup_FullSystem.ps1` | Copies most accessible data from `C:\`           | Yes   |

---

# Execution

## Standard Profile Collection

```text
Run_Silent.vbs
```

* Hidden PowerShell execution
* No visible console window
* No admin rights required

---

## Full System Collection

```text
Run_Full_Silent.vbs
```

* Requests UAC elevation
* Executes fully hidden
* Excludes protected Windows infrastructure folders

---

# Features

* Silent VBScript launcher
* Generic deployment across Windows devices
* No hardcoded usernames
* Recursive loop protection
* Silent error handling
* Compatible with:

  * Dell
  * HP
  * Lenovo
  * ASUS
  * MSI
  * Acer

---

# Disclaimer

BlackStealth is intended strictly for:

* Authorized red team operations
* Internal enterprise security assessments
* Approved forensic collection
* Controlled lab environments
* Device migration workflows

Unauthorized deployment against systems, users, or networks without explicit written authorization may violate computer misuse laws, privacy regulations, and organizational security policies.

The operator assumes full responsibility for all usage, deployment, and legal compliance.
