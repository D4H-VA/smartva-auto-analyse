$install_logfile = "c:\University of Melbourne\SmartVA-Auto-Analyse\install-log.txt"

"Checking for Java Prefs entry in Registry..." | Add-Content $install_logfile

if(Test-Path 'HKLM:\SOFTWARE\JavaSoft\Prefs'){
   "Java Prefs entry found Registry..." | Add-Content $install_logfile
}else{

    try{
        New-Item -Path HKLM:\Software\JavaSoft -Name Prefs -Force -ErrorAction Stop
        "Added entry for Java Prefs in Registry..." | Add-Content $install_logfile
    }catch{
        write-host $_
        "Unable to create Java Prefs in Registry...$_" | Add-Content $install_logfile
        exit
    }
}