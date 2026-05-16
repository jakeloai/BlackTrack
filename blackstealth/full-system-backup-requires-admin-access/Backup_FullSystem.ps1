# Detect current folder name to exclude it from copying
$CurrentFolderName = Split-Path $pwd.Path -Leaf

# Copy entire C drive while filtering out locked windows infrastructure files and the backup destination
Get-ChildItem -Path "C:\*" -Exclude "System Volume Information", "Config.Msi", "`$Recycle.Bin", "Windows", $CurrentFolderName | Copy-Item -Destination . -Recurse -Force -ErrorAction SilentlyContinue
