Set objShell = CreateObject("Shell.Application")
Set WshShell = CreateObject("WScript.Shell")

' "runas" triggers the Windows UAC prompt for Admin elevation. 
' 0 ensures the resulting PowerShell window runs completely hidden.
objShell.ShellExecute "powershell.exe", "-ExecutionPolicy Bypass -File """ & WshShell.CurrentDirectory & "\Backup_FullSystem.ps1""", "", "runas", 0
