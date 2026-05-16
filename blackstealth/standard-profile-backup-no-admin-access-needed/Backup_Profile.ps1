# Define common department user paths
$SourcePaths = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Pictures"
)

# Detect current folder name to exclude it from copying (prevents infinite loops)
$CurrentFolderName = Split-Path $pwd.Path -Leaf

foreach ($Source in $SourcePaths) {
    if (Test-Path $Source) {
        # Automatically create structured subfolders at destination
        $SubFolder = New-Item -ItemType Directory -Path (Join-Path . (Split-Path $Source -Leaf)) -Force
        
        # Copy items silently
        Get-ChildItem -Path "$Source\*" -Exclude $CurrentFolderName | Copy-Item -Destination $SubFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}
