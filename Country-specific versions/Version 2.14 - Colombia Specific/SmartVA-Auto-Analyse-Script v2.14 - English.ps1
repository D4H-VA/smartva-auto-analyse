<#
Name: SmartVA-Auto-Analyse script
Version: 2.14 - Colombia - English
Date: 8 January 2019
Author: Bryan Richards
Organisation: University of Melbourne
#>

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null

Add-Type -assembly System.Windows.Forms

    ## -- Create The Progress-Bar
    $ObjForm = New-Object System.Windows.Forms.Form
    $ObjForm.Text = "SmartVA-Auto-Analyse Processing Entries..."
    $ObjForm.Height = 100
    $ObjForm.Width = 500
    $ObjForm.BackColor = "white"
    $ObjForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $ObjForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    
    ## -- Create The Label
    $ObjLabel = New-Object System.Windows.Forms.Label
    $ObjLabel.Text = "Starting. Please wait ... "
    $ObjLabel.Left = 5
    $ObjLabel.Top = 10
    $ObjLabel.Width = 500 - 20
    $ObjLabel.Height = 15
    $ObjLabel.Font = "Tahoma"

    ## -- Add the label to the Form
    $ObjForm.Controls.Add($ObjLabel)
    $PB = New-Object System.Windows.Forms.ProgressBar
    $PB.Name = "PowerShellProgressBar"
    $PB.Value = 1
    $PB.Style="Continuous"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Width = 500 - 40
    $System_Drawing_Size.Height = 20
    $PB.Size = $System_Drawing_Size
    $PB.Left = 5
    $PB.Top = 40
    $ObjForm.Controls.Add($PB)
    
    # -- Show the Progress-Bar and Start The PowerShell Script
    $ObjForm.TopMost = $True
    $PB.Value = 5
    $ObjForm.Show() | Out-Null
    $ObjForm.Focus() | Out-NUll
    $ObjLabel.Text = "Starting Auto-Analyze. Please wait ... 5%"
    $ObjForm.Refresh()
    Start-Sleep -milliseconds 500

#Load Install Path from Registry
$installPath = Get-ItemPropertyValue -Path REGISTRY::HKEY_USERS\.DEFAULT\Software\UoM\SmartVA-Auto-Analyse -Name "InstallFolder"

#Load Parameters from configuration file
Get-Content $installPath\config_english.txt | foreach-object -begin {$config=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $config.Add($k[0], $k[1]) } }


#Variables
$AggregateURL = $config.AggregateURL
$counter = 1
$errors = $null
$line = $null
$errorcount = 0
$allresults= $null
$resultcount = 0
$archiveResultErrorCount = 0
$archiveErrorMsg = $null
$object = $null
$displayResults = $config.DisplayResults
$logfiledir = $config.ProcessDir + "\Logs"
$logfile = $logfiledir + "\log.txt"
$collectDir = $config.ProcessDir + "\CollectFiles"
$collectFormsDir = $collectDir + "\" + $config.FormsDir
$collectInstancesDir = $collectDir + "\" + $config.InstancesDir
$collectArchiveDir = $config.ArchiveDir + "\Archive"
$processedArchiveFormsDir = $collectArchiveDir + "\Processed\forms"
$processedArchiveInstancesDir = $collectArchiveDir + "\Processed\instances"
$resultsfile = $collectArchiveDir + "\results.csv"
$odkbcdir = $config.ProcessDir + "\ODK Briefcase Storage"
$odkdir = $config.ODKDir
$briefcasefile = "ODK-Briefcase-v1.13.0.jar"
$briefcaseFormID = $config.FormID
$briefcaseStorageDir = $config.ProcessDir
$briefcaseExportDir = $config.ProcessDir + "\Export"
$briefcaseConvertedFile = "TariffReadyFile.csv"
$briefcaseArgumentListExport = "-jar $briefcasefile -e -id $briefcaseFormID -oc -em -sd " + '"' + $briefcaseStorageDir + '"' + " -ed " + '"' + $briefcaseExportDir + '"' + " -f $briefcaseConvertedFile"
$tariffOutput = $config.ProcessDir + "\TariffFiles"
$tariffCountry = $config.country
$tariffHIV = $config.hiv
$tariffMalaria = $config.malaria
$tariffHCE = $config.hce
$tariffFreetext = $config.freetext
$tariffFigures = $config.figures
$tariffLang = $config.language
$tariffInput = $briefcaseExportDir + "\" + $briefcaseConvertedFile
$tariffError = $null
$PhdUCod = $null

#Add Date/Time stamp of current run to log file and create datetime2 variable, formatted for use with Archive Directory Creation
"`r`r`r" | Add-Content $logfile
$datetime = Get-Date
"$datetime `r" | Add-Content $logfile
$datetime2 = "{0:yyyyMMdd}" -f (get-date)

#Check Language setting in config file for running Tariff and assign to variable
if($config.language -eq ""){
    $language = ""
}else{
    $language = "--language " + $config.language
}

#Check for Processing Directory and if it does not exist, create it and associated sub-directories
if(!(Test-Path $config.ProcessDir)){
    New-Item $config.ProcessDir -ItemType directory
}
if(!(Test-Path $logfiledir)){
    New-Item $logfiledir -ItemType directory
}
if(!(Test-Path $collectArchiveDir)){
    New-Item $collectArchiveDir -ItemType directory
}
if(!(Test-Path $briefcaseExportDir)){
    New-Item $briefcaseExportDir -ItemType directory
}
if($config.Aggregate -ne "1"){
    if(!(Test-Path $collectDir)){
        New-Item $collectDir -ItemType directory
    }
    if(!(Test-Path $processedArchiveFormsDir)){
        New-Item $processedArchiveFormsDir -ItemType directory
    }
    if(!(Test-Path $processedArchiveInstancesDir)){
        New-Item $processedArchiveInstancesDir -ItemType directory
    }
}

#Remove Results File if config.txt retainResults set to 0
if(($config.retainResults -eq 0) -and (Test-Path $resultsfile)){

    try{
        Remove-Item $resultsfile -Force -ErrorAction Stop
        "Results File successfully removed" | Add-Content $logfile
    }
    catch{
        (new-object -ComObject wscript.shell).Popup("Unable to remove results file due to: $_.Exception",0,"Error!", 48+0+4096)
        "Unable to remove results file due to: $_.Exception.  Correct this error and re-run analysis." | Add-Content $logfile
        $ObjForm.Close()
        $ObjForm.Dispose()
        exit
    }
}

if(!(Test-Path $resultsfile)){
    #create results file and add headers
    "VA_ID," + "National_ID," + "ID Type," + "Surname," + "Second_Surname," + "First_Name," + "Other_Name," + "Date_of_Death," + "Age," + "Sex," + "CoD1," + "Lh1," + "CoD2," + "Lh2," + "CoD3," + "Lh3," + "All_Symptoms," + "Date_Entered," + "PCoD," | Add-Content $resultsfile
}

if($config.Aggregate -eq '1'){
    #Check if URL value is null and display error, otherwise continue processing.
    if(!($config.AggregateURL)){
    (new-object -ComObject wscript.shell).Popup("No URL specified for Aggregate server, check the config.txt file has the correct values set for Aggregate and AggregateURL config items",0,"Error!", 48+0+4096)
        "No URL specified for Aggregate server, check the config.txt file has the correct values for Aggregate and AggregateURL" | Add-Content $logfile
        $ObjForm.Close()
        $ObjForm.Dispose()
        exit
    }elseif(!($config.AggregateUser) -OR !($config.AggregatePass)){
        "AggregateURL is $aggregateURL" | Add-Content $logfile
        (new-object -ComObject wscript.shell).Popup("No Username or Password specified for Aggregate server, check the config.txt file has the correct values set for Aggregate, AggregateUser and AggregatePass",0,"Error!", 48+0+4096)
        "No Username specified for Aggregate server, check the config.txt file has the correct values for Aggregate and AggregateUser" | Add-Content $logfile
        $ObjForm.Close()
        $ObjForm.Dispose()
        exit
    }else{
        $AggregateUser = $config.AggregateUser
        $AggregatePass = $config.AggregatePass
        $briefcaseArgumentListPull = "-jar $briefcasefile --pull_aggregate --aggregate_url $AggregateUrl --odk_username $AggregateUser --odk_password $AggregatePass --storage_directory " + '"' + $briefcaseStorageDir + '"' + " --form_id $briefcaseFormID"
    }
}else{
    $briefcaseArgumentListPull = "-jar $briefcasefile --pull_collect --storage_directory " + '"' + $briefcaseStorageDir + '"' + " --odk_directory " + '"' + "$collectDir" + '"' + " --form_id $briefcaseFormID"
     
    #If Android 2.0 with USB Mass Storage capability - set AndroidOld setting in Config.txt to 1
	if($config.AndroidOld -eq 1){

		#Get Drive Letters of all USB attached devices (used for older Android 2.0 devices with USB Mass Storage capability)
		$diskdrive = gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB"}
		$letters = $diskdrive | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}

		#Check if USB attached (used for older Android 2.0 devices with USB Mass Storage capability)
		if ([string]::IsNullOrEmpty($letters)){
			(new-object -ComObject wscript.shell).Popup("No USB Drive attached`n`nCheck that you have a USB Drive connected.  If using a tablet with Android 4.x or above installed, check that the setting 'AndroidOld' is set to '0' in the config.txt file",0,"Error!", 48+0+4096)
			"No USB Drive attached" | Add-Content $logfile
			$ObjForm.Close()
			$ObjForm.Dispose()
			exit 
		}else{

			#create array of drive letters found
			$usbattached = gwmi win32_volume | ? {$letters -contains ($_.name -replace "\\")} | select name

			#check for odk folder on USB device
			ForEach ($device in $usbattached){
				$letter = $($device.name)
				$odkpath = $letter + $config.ODKDir
				if(Test-Path $odkpath){
					$pathfound = "1"
					break
				}
			}

			if($pathfound -eq 1){
	
				"ODK Folder found at $odkpath`r" | Add-Content $logfile
		
				#Lookup folder/directory names for all completed forms on the Tablet
				$odkdirs = Get-ChildItem -Path $odkpath -Recurse -include forms,instances | Where-Object { $_.PSIsContainer }
		
				#Check if the Tablet form files already exist in Processing\CollectFiles Directory, delete previous files if found, and if not found, copy across for further processing
				 ForEach ($dir in $odkdirs){
					$dirname = $collectDir + "\" + $dir.Name
					if((Test-Path $dirname)){
						Remove-Item $dirname -Force -Recurse
						Copy-Item -Path $dir.Fullname -Destination $collectDir -Recurse -Container
						"Directory $dirName copied from device`r" | Add-Content $logfile
					}else{
						Copy-Item -Path $dir.Fullname -Destination $collectDir -Recurse -Container
						"Directory $dirName copied from device`r" | Add-Content $logfile
					}
				}
			}else{
				"ODK folder not found on attached USB Device.  Check config.txt file has correct location of ODK folder set and ODK Collect is installed on the device" | Add-Content $logfile
				(new-object -ComObject wscript.shell).Popup("ODK folder not found on attached USB Device. Check config.txt file has correct location of ODK folder set and ODK Collect is installed on the device",0,"Error!", 48+0+4096)
				$ObjForm.Close()
				$ObjForm.Dispose()
				exit
			}
		}
	}else{

        #Check if Android Device is connected and in device mode ready for copy.  If not, throw error, if ready, copy files from ODK location to local PC
        if((adb ($config.DeviceType) get-state) -eq "device"){
            "Android Device found....`r" | Add-Content $logfile
       
            #Check for old CollectFiles Folder from previous run, remove if found. Check forms and instances folders exist after copy from device and perform ODK Briefcase export ready for Tariff processing
        
            #Lookup folder/directory name on local PC
            if((Test-Path $collectDir)){
                $localodkdirs = Get-ChildItem -Path $collectdir -Recurse -include forms,instances | Where-Object { $_.PSIsContainer }

                #Check if local Processing\CollectFiles Directory contains forms and instances and delete ready for processing
                    ForEach ($localdir in $localodkdirs){
                        $localdirname = $collectDir + "\" + $localdir.Name
                        if((Test-Path $localdirname)){
                            Remove-Item $localdirname -Force -Recurse
                            "Directory $localdirName removed, ready for new entries from Device`r" | Add-Content $logfile
                        }
                    }
            }
            
            #use adbpull to get files from tablet/emulator
            $adbpull = Start-Process -FilePath adb.exe -ArgumentList "pull /sdcard/$odkdir/ $collectDir" -NoNewWindow -Wait -PassThru -RedirectStandardError $logfiledir\adblog.txt
            $adbpull
            
            if($adbpull.ExitCode -eq 1){
                ForEach ($line in (Get-Content $logfiledir\adblog.txt | Where-Object {$_ -like '*does not exist*'})) {
                    $errors += $line
                    "$errors : Unable to locate ODK Folder on the Android Device, Check ODKDir setting in config.txt matches the name of the ODK folder on the device`r" | Add-Content $logfile
                    (new-object -ComObject wscript.shell).Popup("$errors `n`nUnable to locate ODK Folder on the Android Device, Check ODKDir setting in config.txt matches the name of the ODK folder on the device",0,"Error!", 48+0+4096)
                    $ObjForm.Close()
                    $ObjForm.Dispose()
                    exit
                }
            }else{
                ForEach ($object in (Get-Content $logfiledir\adblog.txt | Where-Object {$_ -like '*files pulled.*'})) {
                    $copyinfo += $object
                    "$copyinfo `r" | Add-Content $logfile
                    break
                }
            }

        }else{
            "Android Device not found. Check that it is connected, that Developer Options is enabled on the tablet (with USB Debugging mode turned on) and that the ADB drivers are up-to-date`r" | Add-Content $logfile
            (new-object -ComObject wscript.shell).Popup("Android Device not found. Check that it is connected, that Developer Options is enabled on the tablet (with USB Debugging mode turned on) and that the ADB drivers are up-to-date",0,"Error!", 48+0+4096)        
            $ObjForm.Close()
            $ObjForm.Dispose()
            exit
        }
    }
}

#Confirm Files copied from device
if($config.Aggregate -ne '1'){

    #Lookup folder/directory name on local PC
    $localodkdirs = Get-ChildItem -Path $collectDir -Recurse -include forms,instances | Where-Object { $_.PSIsContainer }

    #Check if local Processing\CollectFiles Directory contains forms and instances folders after copy from device
        ForEach ($localdir in $localodkdirs){
             $localdirname = $collectDir + "\" + $localdir.Name
             if((Test-Path $localdirname)){
                 "Directory $localdirName confirmed available for conversion`r" | Add-Content $logfile
             }else{
                 $localpathfound = "0"
                 "Directory $localdirName not found, check that files have copied from device successfully`r" | Add-Content $logfile
                 (new-object -ComObject wscript.shell).Popup("Directory $localdirName not found, check that files have copied from device successfully",0,"Error!", 48+0+4096)
                 $ObjForm.Close()
                 $ObjForm.Dispose()
                 exit
             }
        }
    
    $ObjLabel.Text = "Files Copied from device ... 20%"
    $PB.Value = 20
    $ObjForm.Refresh()
    Start-Sleep -Milliseconds 1000
}
 
    #remove ODK Briefcase Storage folder if processing directly from a Tablet, otherwise retain Storage Folder to reduce Aggregate data sync time.
    if($config.Aggregate -ne '1'){
        if(Test-Path $odkbcdir){
            Remove-Item $odkbcdir -Force -Recurse -ErrorAction Stop
            "ODK Briefcase Storage Directory cleared ready for processing`r" | Add-Content $logfile
        }
    }

    #remove briefcase.log file.  This clears all previous errors so that only current run-time issues can be assessed/captured
    if(Test-Path briefcase.log){
        try{
            Remove-Item briefcase.log -Force -ErrorAction Stop
            "briefcase log file successfully removed" | Add-Content $logfile
        }
        catch{
            (new-object -ComObject wscript.shell).Popup("Unable to remove briefcase log file due to: $_.Exception",0,"Error!", 48+0+4096)
            "Unable to briefcase log file due to: $_.Exception.  Correct this error and re-run analysis." | Add-Content $logfile
            $ObjForm.Close()
            $ObjForm.Dispose()
            exit
        }
    }

    $ObjLabel.Text = "ODK Briefcase Conversion Started ... 22%"
    $PB.Value = 22
    $ObjForm.Refresh()
    
    #Run ODK Briefcase Pull with specified Arguments    
    $bprocPull = Start-Process -FilePath java.exe -ArgumentList "$briefcaseArgumentListPull" -NoNewWindow -PassThru -RedirectStandardError $logfiledir\BriefcaseOutput.txt

    "ODK Briefcase pull started with the following arguments: $briefcaseArgumentListPull`r" | Add-Content $logfile

    $bprocPull
    start-sleep 3
    $ProcessList = "java"
    Do {
        $Percentage = $PB.Value
	    $ProcessesFound = Get-Process | ? {$ProcessList -contains $_.Name} | Select-Object -ExpandProperty Name
	        If ($ProcessesFound) {
                
                $counter++
                $ObjLabel.Text = "ODK Briefcase Conversion Started ... $Percentage% "
                [int]$PB.Value = 22 + ($counter/3)
                $ObjForm.Refresh()
                if($counter -lt 12){
                    Start-Sleep 10
                }else{
                    Start-Sleep 2
                }
	        }
    } Until (!$ProcessesFound)

    $ObjLabel.Text = "ODK Briefcase Export Started ... 35%"
    $PB.Value = 35
    $ObjForm.Refresh()
    Start-Sleep -Milliseconds 150

    #Reset counter for Tariff progress bar updates.
    $counter = 1
             
    "bprocpull exit code is $($bprocPull.ExitCode) `r" | Add-Content $logfile


    #Run ODK Briefcase Export with specified Arguments    
    $bprocExport = Start-Process -FilePath java.exe -ArgumentList "$briefcaseArgumentListExport" -NoNewWindow -Wait -PassThru -RedirectStandardError $logfiledir\BriefcaseOutput.txt
    
    "ODK Briefcase Export started with the following arguments: $briefcaseArgumentListExport`r" | Add-Content $logfile

    $bprocExport
    
    "bprocExport exit code is $($bprocExport.ExitCode) `r" | Add-Content $logfile

   
    if(!(Test-Path $odkbcdir)){
        "ODK Briefcase conversion is unable to run.  Check the BriefcaseOutput.txt file for the error and/or confirm Java is installed and that the system PATH environment variable is set.`r" | Add-Content $logfile
        (new-object -ComObject wscript.shell).Popup("ODK Briefcase conversion is unable to run.  Check the BriefcaseOutput.txt file for the error and/or confirm Java is installed and that the system PATH environment variable is set.",0,"Error!", 48+0+4096)
        $ObjForm.Close()
        $ObjForm.Dispose()
        exit
    }
    if(($bprocPull.ExitCode -eq 1) -or ($bprocExport.ExitCode -eq 1) ){
        
        ForEach ($line in (Get-Content briefcase.log | Where-Object {($_ -like '*error*')})) {
            $errors += $line
            $errors += "`r"
            break
        }

        ForEach ($line in (Get-Content $logfiledir\BriefcaseOutput.txt | Where-Object {($_ -like '*SEVERE*') -or ($_ -like '*ERROR*')})) {
            $errors += $line
            $errors += "`r"
            break
        }
        if($config.Aggregate -eq "1"){
            (new-object -ComObject wscript.shell).Popup("$errors `n`nCheck Aggregate Server Information section in the config.txt file is correct.",0,"Error!", 48+0+4096)
            "$errors : Check Aggregate Server Information section in the config.txt file is correct`r" | Add-Content $logfile
            $ObjForm.Close()
            $ObjForm.Dispose()
            exit
        }else{
            (new-object -ComObject wscript.shell).Popup("$errors `n`nCheck the config.txt file settings for ODK Briefcase Storage location matches script expected location, or that the FormID is correct",0,"Error!", 48+0+4096)
            "$errors : Check ODK Briefcase Storage locations match script expected location and that the FormID is correct`r" | Add-Content $logfile
            $ObjForm.Close()
            $ObjForm.Dispose()
            exit
        }
    }else{
        ForEach ($line in (Get-Content $logfiledir\BriefcaseOutput.txt | Where-Object {($_ -like '*SEVERE*') -or ($_ -like '*ERROR*')})) {
            $errors += $line
            (new-object -ComObject wscript.shell).Popup("$errors `n`nCheck config.txt file for correct FormID value",0,"Error!", 48+0+4096)
            "$errors : Check config.txt file for correct FormID value and that the Forms and Instances Locations on the device match the config.txt file entries`r" | Add-Content $logfile
            $ObjForm.Close()
            $ObjForm.Dispose()
            exit
        }
        
        if($errors -eq $null){
            
            $ObjLabel.Text = "ODK Briefcase Export completed ... 38%"
            $PB.Value = 38
            $ObjForm.Refresh()
            Start-Sleep -Milliseconds 150

            "Export File $briefcaseExportDir\$briefcaseConvertedFile created`r" | Add-Content $logfile
            "ODK Briefcase conversion completed....`r" | Add-Content $logfile
            
            #Clear Tariff Folder of old files for processing new tablet entries
            if(Test-Path $tariffOutput){
                
                try{
                    Remove-Item $tariffOutput -Force -Recurse
                    "Tariff Directory cleared ready for processing`r" | Add-Content $logfile
                }
                catch{
                    (new-object -ComObject wscript.shell).Popup("Unable to remove Tariff output directory due to: $_.Exception",0,"Error!", 48+0+4096)
                    "Unable to remove Tariff output directory due to: $_.Exception.  Correct this error and re-run analysis." | Add-Content $logfile
                    $ObjForm.Close()
                    $ObjForm.Dispose()
                    exit
                }
            }
            
            New-Item $tariffOutput -ItemType directory              
            
            #check Briefcase output file has any entries.  If not, advise the user and exit processing.
            if((Import-Csv $tariffInput) -eq $null){
                (new-object -ComObject wscript.shell).Popup("No data was found after the ODK Briefcase export.`n`nThis may be because there are no entries on the tablet or Aggregate server for the specified form, or due to an export error.`n`nConfirm entries exist, that the FormID is correct in the config.txt file, or check the BriefcaseOutput.txt log for additional information.",0,"Error!", 48+0+4096)
                "No data was found after the ODK Briefcase export.`n`nThis may be because there are no entries on the tablet or Aggregate server for the specified form, or due to an export error.`n`nConfirm entries exist, that the FormID is correct in the config.txt file, or check the BriefcaseOutput.txt log for additional information." | Add-Content $logfile
                $ObjForm.Close()
                $ObjForm.Dispose()
                exit
            }
            
            "Tariff Analysis started at $(Get-date)`r" | Add-Content $logfile

            $ObjLabel.Text = "Tariff Analysis Started ... 43%"
            $PB.Value = 43
	        $ObjForm.Refresh()
                      
            $tproc = Start-Process -FilePath .\SmartVA-Analyze-cli.exe -ArgumentList "--country $tariffCountry --hiv $tariffHIV --malaria $tariffMalaria --hce $tariffHCE --freetext $tariffFreetext --figures $tariffFigures $language `"$tariffInput`" $tariffOutput" -NoNewWindow -PassThru -RedirectStandardError $logfiledir\TariffOutput.txt
            $tproc
     
            $ProcessList = "SmartVA-Analyze-cli"
            Do {
                $Percentage = $PB.Value
	            $ProcessesFound = Get-Process | ? {$ProcessList -contains $_.Name} | Select-Object -ExpandProperty Name
	                If ($ProcessesFound) {
                        $counter++
                        $ObjLabel.Text = "Tariff Analysis Processing ... $Percentage% "
                        [int]$PB.Value = 100 - ((50/($counter*.5)))
                        $ObjForm.Refresh()
                        if($counter -lt 6){
                            Start-Sleep 10
                        }else{
                            Start-Sleep 2
                        }
	                }
                $ObjForm.Refresh()
            } Until (!$ProcessesFound)
            
            #Show copmleted process bar
            $ObjLabel.Text = "Analysis Completed ... 100%"
            $PB.Value = 100
	        $ObjForm.Refresh()
            Start-Sleep 2
            $ObjForm.Close()
            $ObjForm.Dispose()
            
            #Check TariffOutput file for success or failure and store Archive copy of tablet files in Errors or Processed
            if(!(Get-Content $logfiledir\TariffOutput.txt | Where-Object {$_ -like '*Process Completed*'})){
                
                if((Get-Item $logfiledir\TariffOutput.txt).Length -eq 0){
                    
                    $tariffError = "SmartVA failed to run.  Check that SmartVA-Analyze-cli.exe exists in the installation directory"
                    
                }else{
                    $tariffError = Get-Content $logfiledir\TariffOutput.txt
                }

                (new-object -ComObject wscript.shell).Popup("SmartVA did not complete due to:`n`n$TariffError`n`nNo SmartVA Output is possible at this time and no items have been archived.`n`nPlease review error in $logfile and correct the issue before re-trying analysis.",0,"Error!", 48+0+4096)
                "$TariffError`r" | Add-Content $logfile
                $ObjForm.Close()
                $ObjForm.Dispose()
                exit
            
            }else{
                
                "Tariff analysis completed at $(Get-date)`r" | Add-Content $logfile
                
                #Update Archive with Forms/Instances that are new or have been updated since last Archive run if in offline mode.  If using Aggregate server, the raw VA data is not retained in the archive.  
                #Backups of raw VA data should be performed at the server level where Aggregate is installed.  Only Results and CSMF data will be retained in the archive if using aggregate.
                
                if($config.Aggregate -ne "1"){
                    
                    # get collectfiles form information (copy of Tablet form file)
	                $collectFormFile = Get-childitem $collectFormsDir -filter "$briefcaseFormID.xml"
	            
                    # get archived form information (returns NULL if file is not found)
                    $archiveFormFile = Get-childitem "$processedArchiveFormsDir" -filter "$briefcaseFormID.xml"

                    #If no archive form file is found, copy form file to archive. If archive form file found, check tablet form file against existing archive file and update if a newer version is found on the tablet (to maintain Archive current version).  Alert user if tablet form file of the same name is older than existing archive file (may indicate only some users have updated the tablet form definitions to the latest version).
                    if($archiveFormFile.Fullname -ne $null){
                        "Archive form file found, checking for newer version..." | Add-Content $logfile
                    
                        if(($collectFormFile.LastWriteTime.Date -gt $archiveFormFile.LastWriteTime.Date) -or ($collectFormFile.LastWriteTime.Date -eq $archiveFormFile.LastWriteTime.Date -and $collectFormFile.LastWriteTime.TimeofDay -gt $archiveFormFile.LastWriteTime.TimeofDay)){
                        
                            "Source Form file is newer than an existing Archive Form file of the same name...updating archive" | Add-Content $logfile
                        
                            try{
                                Copy-Item -Path $collectFormFile.FullName -Destination "$processedArchiveFormsDir" -Force -ErrorAction Stop
                                "Form File successfully Archived to $processedArchiveFormsDir" | Add-Content $logfile
                            }
                            catch{
                                (new-object -ComObject wscript.shell).Popup("An issue was encountered while copying to the Archive.  Please see $($logfile) for additional information",0,"Error!", 48+0+4096)                       
                                "Unable to complete Archive Form update due to: $_.Exception.  Correct this error and re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet." | Add-Content $logfile
                            }

                        }elseif(($collectFormFile.LastWriteTime.Date -eq $archiveFormFile.LastWriteTime.Date -and $collectFormFile.LastWriteTime.TimeofDay -lt $archiveFormFile.LastWriteTime.TimeofDay)){
                            "Source Form file is older than an existing Archive Form file.  No archive action required" | Add-Content $logfile
                        }else{
                            "Source Form file being used is identical to archive form file, no archive action required" | Add-Content $logfile
                        }
                    }else{
	                    
                        "Archive Form file not found.  Copying form file from Tablet to Archive" | Add-Content $logfile
                        
                        try{
                            Copy-Item -Path $collectFormFile.FullName -Destination "$processedArchiveFormsDir" -Force -ErrorAction Stop
                            "Form File successfully Archived to $processedArchiveFormsDir" | Add-Content $logfile
                        }
                        catch{
                            (new-object -ComObject wscript.shell).Popup("An issue was encountered while copying to the Archive.  Please see $($logfile) for additional information",0,"Error!", 48+0+4096)                       
                            "Unable to complete Archive Form update due to: $_.Exception.  Correct this error and re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet." | Add-Content $logfile
                        }

                    }


                    # get collectfiles instances information (copy of Tablet instances files/folders)
	                $collectInstanceFiles = Get-childitem $collectInstancesDir -filter "$briefcaseFormID*" | Where-Object { $_.PSIsContainer }
	            
                    # get archived instances information (returns NULL if files/folders are not found)
                    $archiveInstanceFiles = Get-childitem "$processedArchiveInstancesDir" -filter "$briefcaseFormID*" | Where-Object { $_.PSIsContainer }
                
                    #If no archive instances are found, copy instances to archive. If archive instances found, check collect instances against existing archive instances and update if a newer version is found (to maintain Archive current version).  Alert user if tablet instance of the same name is older than existing archive file (may indicate old data being reviewed).
                    if($archiveInstanceFiles -ne $null){
                        "Archive instances found, check what needs to be copied..." | Add-Content $logfile

                        ForEach($collectInstanceFile in $collectInstanceFiles){
                            if(!(Get-childitem $processedArchiveInstancesDir -filter $collectInstanceFile | Where-Object { $_.PSIsContainer })){
                                try{
                                    Copy-Item -Path $collectInstanceFile.FullName -Destination "$processedArchiveInstancesDir" -Recurse -Force -ErrorAction Stop
                                    "Instance $collectInstanceFile successfully Archived to $processedArchiveInstancesDir" | Add-Content $logfile
                                }
                                catch{
                                    "Unable to complete Archive Instance update of $collectInstanceFile due to: $_.Exception.  Correct this error and re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet." | Add-Content $logfile
                                    $errorcount ++                       
                                }
                            }else{
                                $archiveInstanceFile = Get-childitem $processedArchiveInstancesDir -filter $collectInstanceFile | Where-Object { $_.PSIsContainer }
                            
                                if(($collectInstanceFile.LastWriteTime.Date -gt $archiveInstanceFile.LastWriteTime.Date) -or ($collectInstanceFile.LastWriteTime.Date -eq $archiveInstanceFile.LastWriteTime.Date -and $collectInstanceFile.LastWriteTime.TimeofDay -gt $archiveInstanceFile.LastWriteTime.TimeofDay)){
                        
                                    "Source Instance $collectInstanceFile is newer than an existing Archive Instance file of the same name...updating archive to reflect changes" | Add-Content $logfile
                        
                                    try{
                                        Copy-Item -Path $collectInstanceFile.FullName -Destination "$processedArchiveInstancesDir" -Recurse -Force -ErrorAction Stop
                                        "Instance $collectInstanceFile successfully Archived to $processedArchiveInstancesDir" | Add-Content $logfile
                                    }
                                    catch{
                                        "Unable to complete Archive Instance update of $collectInstanceFile due to: $_.Exception.  Correct this error and re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet." | Add-Content $logfile
                                        $errorcount ++
                                    }

                                }elseif(($collectInstanceFile.LastWriteTime.Date -eq $archiveInstanceFile.LastWriteTime.Date -and $collectInstanceFile.LastWriteTime.TimeOfDay -lt $archiveInstanceFile.LastWriteTime.TimeOfDay)){
                                    "Source Instance $collectInstanceFile is older than an existing Archive Instance file.  Please check your dataset to ensure you have the latest copy of all data." | Add-Content $logfile
                                    $errorcount ++
                                }else{
                                    "Source Instance File $collectInstanceFile is identical to existing archive instance file, no archive action required" | Add-Content $logfile
                                }
                            }
                        }
                        if($errorcount -gt 0){
                            "Number of Files in Error: $errorcount" | Add-Content $logfile
                            (new-object -ComObject wscript.shell).Popup("An issue was encountered while copying to the Archive.`n`nReview and correct the error then re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet.`n`nFor error details see $($logfile).",0,"Error!", 48+0+4096)
                        }
                    }else{
                        try{
                            ForEach($collectInstanceFile in $collectInstanceFiles){
                                Copy-Item -Path $collectInstanceFile.Fullname -Destination "$processedArchiveInstancesDir" -Recurse -Force -ErrorAction Stop
                                "Instances $($collectInstanceFile.Fullname) successfully Archived to $processedArchiveInstancesDir" | Add-Content $logfile
                            }
                        }
                        catch{
                            (new-object -ComObject wscript.shell).Popup("An issue was encountered while copying to the Archive.  Please see $($logfile) for additional information",0,"Error!", 48+0+4096)                       
                            "Unable to complete Archive Instances update due to: $_.Exception.  Correct this error and re-run analysis to ensure Archive data is updated BEFORE removing VA's from the Tablet." | Add-Content $logfile
                        }
                    }
                }
                if($config.figures -eq "true"){
                    
                    $source = $tariffOutput + "\2-csmf"
                    $destination = $collectArchiveDir + "\2-csmf"
                    
                    #Clear old CSMF Figures so that the most current figures are available.
                    if(Test-Path $destination){
                        Remove-Item $destination -Force -Recurse
                        "Archive Figures Directory cleared ready for updated version`r" | Add-Content $logfile
                    }
                    
                    try{
                        Copy-Item -Path $source -Destination "$($destination)\$($datetime2)" -Recurse -Force -ErrorAction Stop
                        "CSMF Figuries successfully Archived to $destination" | Add-Content $logfile
                    }
                    catch{
                        "Unable to complete Archive of CSMF files due to: $_.  Correct this error and re-run analysis to attempt rewrite of CSMF figures" | Add-Content $logfile
                        (new-object -ComObject wscript.shell).Popup("Unable to complete Archive of CSMF files due to: $($_).  Correct this error and re-run analysis to attempt rewrite of CSMF figures.`n`nFor error details see $($logfile).",0,"Error!", 48+0+4096)
                    }
                }

                #Lookup file names for all Tariff Predictions and current archive results. Display Tariff Predictions to screen (if enabled) and add to archive results.csv file if not already existing.
                                
                $tariff_liklihood_files = get-childitem "$tariffOutput" -Recurse | where {$_.name -like '*likelihoods.csv'}
                                
                $archiveResults = Import-Csv "$resultsfile"

                if($tariff_liklihood_files -ne $null){
                
                    $tariff_export_file = get-childitem $config.ProcessDir -Recurse | where {$_.name -like $briefcaseConvertedFile}
                     
                    $raw_data_file_path =  $tariff_export_file.FullName

                    $raw_data = Import-Csv "$raw_data_file_path" 
                                       
                    ForEach ($liklihood_file in $tariff_liklihood_files){
                        $liklihood_path = $liklihood_file.FullName
                        $VAs = Import-Csv "$liklihood_path"
                        
                        ForEach ($VA in $VAs){
                            $results = $null
                            $x = 0
                            $sid = $($VA.sid)
                            $age = $($VA.age)
                            $sex = $($VA.sex)
                           
                            switch($sex){
                                1 {$gender = "Male" ; break}
                                2 {$gender = "Female" ; break}
                                3 {$gender = "Third Gender" ; break}
                                8 {$gender = "Don't Know" ; break}
                                9 {$gender = "Refused To Answer" ; break}
                                default{$gender = $sex}
                            }
                                                       
                            $cod1 = $($VA.cause1)
                            $lh1 = $($VA.likelihood1)
                            
                            $cod2 = $($VA.cause2)
                            $lh2 = $($VA.likelihood2)
                            
                            $cod3 = $($VA.cause3)
                            $lh3 = $($VA.likelihood3)
                            
                            $as = $($VA.all_symptoms)
                            $as_repl = $as -replace ";", ", "

                                                     
                            ForEach ($entry in $raw_data){
                                if($sid -eq $entry.'Generalmodule-sid'){
                                    $NatID = $entry.'general5-gen_5_2b0_es-gen_5_2b3_es'
                                    $Surname = $entry.'general5-name-gen_5_0a'
                                    $Second_Surname = $entry.'general5-name-gen_5_0a_es1'
                                    $First_Name = $entry.'general5-name-gen_5_0'
                                    $Other_Name = $entry.'general5-name-gen_5_0c'
                                    $Death_Date = $entry.'deathDate-gen_5_3d'
                                    $ID_Type_No = $entry.'general5-gen_5_2b0_es-gen_5_2b2_es'
                                    
                                    switch($ID_Type_No){
                                        1 {$ID_Type = "Civil Registration" ; break}
                                        2 {$ID_Type = "National Identity Card" ; break}
                                        3 {$ID_Type = "Citizenship Card" ; break}
                                        4 {$ID_Type = "Foreign Resident Card" ; break}
                                        5 {$ID_Type = "Passport" ; break}
                                        6 {$ID_Type = "Other" ; break}
                                        7 {$ID_Type = "Dont Know" ; break}
                                        8 {$ID_Type = "None" ; break}
                                        9 {$ID_Type = "Citizenship Card of the mother" ; break}
                                        10 {$ID_Type = "National Identity Card of the mother" ; break}
                                        default {$ID_Type = "ID Type Not Found"}
                                    }                                   
                                    break
                                }
                            }
                                            
                            $results += "VA ID:  " + $sid + "`nNat_ID:  " + $NatID + "`nID Type:  " + $ID_Type + "`nSurname:  " + $Surname + "`nSecond Surname:  " + $Second_Surname + "`nFirst Name:  " + $First_Name + "`nOther Name:  " + $Other_Name + "`nDate of Death:  " + $Death_Date + "`nAge:  " + $age + "`nSex:  " + $gender + "`n`nCause of Death 1:  " + $cod1 + "`nLikelihood:  " + $lh1 + "`n`nCause of Death 2:  " + $cod2 + "`nLikelihood:  " + $lh2 + "`n`nCause of Death 3:  " + $cod3 + "`nLikelihood:  " + $lh3 + "`n`n" + "All Symptoms:`n" + $as_repl
                                                    
                            
                            #add to results file
                            #Check if archive file contains any existing entries

                            if($archiveResults -ne $null){
                                
                                #Check if current sid from smartVA already exists in archive file and increment 'x' if result found
                                ForEach ($archiveResult in $archiveResults){
                                    if ($sid -eq $archiveResult.VA_ID ){
                                        $x++
                                        break
                                    }
                                }
                                #If no VA result found then request information and write to results file
                                if($x -eq 0){
                                    if($displayResults -eq 1){
                                        $PhdUCoD = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter Physician cause of death for the following:`n`n$results", "Physician Cause of Death", "")
                                    }
                                    try{
                                        $sid + "," + $NatID + "," + $ID_Type + "," + $Surname + "," + $Second_Surname + "," + $First_Name + "," + $Other_Name + "," + $Death_Date + "," + $age + "," + $gender + "," + $cod1 + "," + $lh1 + "," + $cod2 + "," + $lh2 + "," + $cod3 + "," + $lh3 + "," + $as + "," + $datetime + "," + $PhdUCoD + "," | Add-Content -Encoding UTF8 $resultsfile -ErrorAction Stop
                                        "Result with VA_ID $sid successfully Archived to $resultsfile" | Add-Content $logfile
                                        $resultcount ++
                                    }
                                    catch{
                                        $archiveResultErrorCount++
                                        $archiveErrorMsg = $null
                                        $archiveErrorMsg = $_
                                    }
                                }
                            }else{
                                    #No results in archive file at all, therefore request information and write to archive file.
                                    
                                    if($displayResults -eq 1){
                                        $PhdUCoD = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter Physician cause of death for the following:`n`n$results", "Physician Cause of Death", "")
                                    }
                                    try{
                                        $sid + "," + $NatID + "," + $ID_Type + "," + $Surname + "," + $Second_Surname + "," + $First_Name + "," + $Other_Name + "," + $Death_Date + "," + $age + "," + $gender + "," + $cod1 + "," + $lh1 + "," + $cod2 + "," + $lh2 + "," + $cod3 + "," + $lh3 + "," + $as + "," + $datetime + "," + $PhdUCoD + ","| Add-Content -Encoding UTF8 $resultsfile -ErrorAction Stop
                                        "Result with VA_ID $sid successfully Archived to $resultsfile" | Add-Content $logfile
                                        $resultcount ++
                                    }
                                    catch{
                                        $archiveResultErrorCount++
                                        $archiveErrorMsg = $null
                                        $archiveErrorMsg = $_
                                    }
                            }
                        }
                        if($archiveResultErrorCount -gt 0){
                            (new-object -ComObject wscript.shell).Popup("Could not write results to Archive file $resultsfile due to: `n`n$archiveErrorMsg`n`n If this file is open, please close it and repeat analysis to capture results in the archive", 0,"Error", 48+0+4096)
                            "Could not write results to Archive file $resultsfile due to: $archiveErrorMsg" | Add-content $logfile
                            $ObjForm.Close()
                            $ObjForm.Dispose()
                            exit
                        }
                        $allresults += $results
                    }
                    if($x -gt 0){
                        (new-object -ComObject wscript.shell).Popup("No results to display.  All results are already in the archive results file.",0,"SmartVA-Auto-Analyse Results", 64+0+4096)
                    }elseif($displayResults -eq 0){
                        (new-object -ComObject wscript.shell).Popup("$resultcount result(s) added to archive",0,"SmartVA-Auto-Analyse Results", 64+0+4096)
                    }
                }else{
                    (new-object -ComObject wscript.shell).Popup("No results to display.  This is normal if processed VA's had no age information, or consent was not provided.", 0,"SmartVA-Auto-Analyse Results", 64+0+4096)
                }
            }
        } 
    }