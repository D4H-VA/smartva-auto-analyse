$install_logfile = "c:\University of Melbourne\SmartVA-Auto-Analyse\install-log.txt"

#Add Date/Time stamp of current run to log file and create datetime2 variable, formatted for use with Archive Directory Creation
"`r`r`r" | Add-Content $install_logfile
$datetime = Get-Date
"$datetime `r" | Add-Content $install_logfile
"Files copied..." | Add-Content $install_logfile

"Install Path being read from Registry...." | Add-Content $install_logfile

try{
    $installPath = (Get-ItemProperty -Path "REGISTRY::HKEY_USERS\.DEFAULT\Software\UoM\SmartVA-Auto-Analyse").InstallFolder
}
catch{
    (new-object -ComObject wscript.shell).Popup("Unable to read Registry Key HKEY_USERS\.DEFAULT\Software\UoM\SmartVA-Auto-Analyse\InstallFolder`n`nMake sure it exists before running Auto-Analyse.", 48+0+4096)
    "Unable to read Registry Key HKEY_USERS\.DEFAULT\Software\UoM\SmartVA-Auto-Analyse\InstallFolder" |Add-Content $install_logfile
    Exit
}

"Install Path was detected as $installPath." | Add-Content $install_logfile

$TargetFile = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe "
$arguments = " -windowstyle hidden -file "+'"'+ $installPath + "\SmartVA-Auto-Analyse-Script v2.15.ps1" + '"'
$DesktopPath = ([Environment]::GetEnvironmentVariable("Public"))+"\Desktop"
$ShortcutFile = $DesktopPath + "\SmartVA-Auto-Analyse v2.15.lnk"


try{
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Arguments = $arguments
$Shortcut.WorkingDirectory = "$installPath"
$Shortcut.Save()
"Shortcut created..." | Add-Content $install_logfile
}
catch{
   (new-object -ComObject wscript.shell).Popup("Unable to create shortcut, please setup manually using create_shortcut_english.ps1 in the $install_path directory", 48+0+4096)
   "Unable to create Shortcut..." | Add-Content $install_logfile
   Exit
}