$install_logfile = "c:\University of Melbourne\SmartVA-Auto-Analyse\install-log.txt"

"Rename check started...." | Add-Content $install_logfile

$datetime = "{0:yyyyMMdd}" -f (get-date)
$source = "C:\SmartVA"
$destination = "C:\SmartVA-" + $datetime

if(Test-Path $source){
    
    (new-object -ComObject wscript.shell).Popup("An existing $source folder exists which may not be compatible with this version of Auto-Analyse.`n`nThis will be renamed to $destination and all old data can be found in this location if needed.",0,"Information", 64+0+4096)

    try{
        Rename-Item -Path $source -NewName $destination -Force -ErrorAction Stop
        "Folder rename completed...." | Add-Content $install_logfile
    }
    catch{
        (new-object -ComObject wscript.shell).Popup("Unable to rename $source due to:`n`n$_`n`nPlease close any open files and rename this folder manually to prevent issues with running the new version of Auto-Analyse",0,"Error!", 48+0+4096)
        "Unable to rename folder due to $_...." | Add-Content $install_logfile
        exit
    }
}else{
    "Old Directory not found, ok to continue..." | Add-Content $install_logfile
}