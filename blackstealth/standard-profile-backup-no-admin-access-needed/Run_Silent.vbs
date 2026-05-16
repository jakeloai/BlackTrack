Set WshShell = CreateObject("WScript.Shell")
' 0 hides the window, True forces the script to wait until backup finishes
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -File """ & WshShell.CurrentDirectory & "\Backup_Profile.ps1""", 0, True
MsgBox "Backup Completed Successfully!", 64, "IT Department Backup System"
