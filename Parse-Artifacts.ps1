
function Parse-Artifacts {
    param (
        [Parameter(Mandatory)]
        [string]$Drive,

        [Parameter(Mandatory)]
        [string]$OutPath,

        [Parameter()]
        [string]$StartDate,

        [Parameter()]
        [string]$EndDate
    )

    <#
    .SYNOPSIS
      Parses a variety of artifacts from a mounted VHDX drive 
    .EXAMPLE
     Parse-Artifacts -Drive Z -OutPath G:\cases\Example_Investigation
     The drive letter is the mount point for the evidence VHDX, do not include a trailing slash for the outpath
#>
    
    #Tools Drive, Set this to your Drive letter and path - do NOT include the trailing '\' eg C:\tools
    $toolsDrivePath = "XXXX_REPALCE_ME_XXXX"

    $evtxeCmd = $toolsDrivePath + '\EvtxExplorer\EvtxECmd.exe'
    $chainSaw = $toolsDrivePath + "\chainsaw\chainsaw.exe"
    $AmCache = $toolsDrivePath + "\AmcacheParser.exe" 
    $ShimCache = $toolsDrivePath + "\AppCompatCacheParser.exe" 
    $Prefetch = $toolsDrivePath + '\PECmd.exe'
    $RegExplorer = $toolsDrivePath + "\RegistryExplorer\RECmd.exe"
    $MFTeCMD = $toolsDrivePath + "\MFTECmd"
    

    #validate the drive exists
    if ($true -eq (Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue)) {
        Write-Host "Using drive $Drive for processing" -BackgroundColor Green -ForegroundColor Black
    } else {
        Write-Host "Drive $Drive not found, please double check the mounted letter and ensure you are passing the letter only (pass I and not I:\)" -BackgroundColor Red -ForegroundColor Black
    }
    #set some Variables
    $linuxOutPath = wsl wslpath -u ($Outpath.Replace('\','\\'))
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    #make the log file
    if ($null -eq (Test-Path "$OutPath\Parse-Artifacts_runLog.txt") ) {
        New-item -Name Parse-Artifacts_runLog.txt -Path $OutPath
    }
    $logPath = $OutPath + "/Parse-Artifacts_runLog.txt"

    

########################################################### Windows Events ###################################################################
    
    Add-Content -Path $logPath -Value "##################### Starting Windows Logs Section ###################################### `n"
    #Parse windows events with evtxECmd
    try {
        #create evtx path
        $evtxPath = $Drive + ":\" + "C\Windows\System32\winevt\logs"
        Write-host "Parsing windows event logs"
        & $evtxeCmd -d $evtxPath --csv $OutPath --csvf allEventLogsParsed.csv

        Add-Content -Path $logPath -Value "Successfully parsed all evtx logs in the supplied directory with EvtxECmd `n"
        
    }
    catch {
        Add-Content -Path $logPath -Value "Error with evtxecmd, please double check the output and try manually `n"
    }

    
    Write-Host "Finished parsing all windows logs, moving onto windows log detections `n"


    #Detect sus activity in windows logs with chainsaw
    try {
        #make chainsaw output folder
        if ($false -eq (test-path "$OutPath\chainsawOutput")) {
            New-Item -ItemType Directory -Path $OutPath -Name "chainsawOutPut"
        }else {
        }
        #create evtx path
        $evtxPath = $Drive + ":\" + "C\Windows\System32\winevt\logs"
        Write-host "Running chainsaw against windows logs"

        #chainsaw was being a fussy little baby so had to break some things out and redirect everything to stdout 
        $chainsawRules = $toolsDrivePath + "\chainsaw\sigma_rules"
        $chainsawMapping = $toolsDrivePath + "\chainsaw\mapping_files\sigma-mapping.yml"

        & "$chainSaw" hunt $evtxPath.ToString() --rules $chainsawRules.ToString() --mapping $chainsawMapping.ToString() --csv "$OutPath\chainsawOutput" --lateral-all *>1

        Add-Content -Path $logPath -Value "Successfully parsed all evtx logs in the supplied directory with chainsaw, output is in ($OutPath + '\chainsawOutPut') `n"
    }
    catch {
        Add-Content -Path $logPath -Value "Error with chainsaw, please double check the output and try manually `n"
    }

    ###################################################### Evidence of Execution ###############################################################
    Add-Content -Path $logPath -Value "##################### Starting Evidence of Execution Section ###################################### `n"

    #Hash table of various Evidence of Execution artifacts, can be expanded easily
    $EoEPathHash=@{
        "AmCache" = ("$drive" + ":\" + "C\Windows\AppCompat\Programs\Amcache.hve")
        "ShimCache" = ("$drive" + ":\" + "C\Windows\System32\config\SYSTEM")
        "Prefetch" = ("$drive" + ":\" + "c\Windows\prefetch\")
      }

    #Runs through each value, checks that the path or artifact is present then processes them if they exist 
    $EoEPathHash.GetEnumerator() | ForEach-Object {
        if ($true -eq (Test-Path $_.Value)) {
            $artifact = $_.Key.ToString()
            Write-host $artifact " was found, processing artifact" -ForegroundColor Black -BackgroundColor green
            Add-Content -Path $logPath -Value "$artifact Was found and will be processed `n"

            switch ($_.Key.ToString()) {
                AmCache { & "$AmCache" -f ("$drive" + ":\" + "C\Windows\AppCompat\Programs\Amcache.hve") -i on --csv $OutPath --csvf amcacheParsed.csv}
                ShimCache { & "$ShimCache" -f("$drive" + ":\" + "C\Windows\System32\config\SYSTEM") --csv $OutPath --csvf shimcacheParsed.csv }
                Prefetch { & "$Prefetch" -d ("$drive" + ":\" + "c\Windows\prefetch\") --csv $OutPath --csvf prefetchParsed.csv }
            }

        }else {
            $artifact = $_.Key.ToString()
            Write-Host "$artifact was not found and will be skipped" -ForegroundColor Black -BackgroundColor Yellow
            Add-Content -Path $logPath -Value "$artifact Was NOT found and won't be processed `n"
        }
        
    }

    try {
        $UserProfs = $drive + ":\" +"c\Users"
        if ($true -eq (test-path $UserProfs)) {
            & "$RegExplorer" -d "$UserProfs" --bn ($toolsDrivePath + "\RegistryExplorer\BatchExamples\AllRegExecutablesFoundOrRun.reb") --csv $OutPath --csvf AllRegExes.csv 
        }
    }
    catch {
    }
    
####################################### MFT Section #######################################
    Add-Content -Path $logPath -Value "##################### Starting MFT Section ###################################### `n"

    try {
        Write-Host "Parsing MFT"
        Add-Content -Path $logPath -Value " Parsed MFT items as CSV `n"
        #Parses the MFT in an item by item fashion
        & "$MFTeCMD" -f ("$Drive" + ":\" + 'C\$MFT') --csv $OutPath --csvf "C_MFT_Parsed.csv"

    }
    catch {
    }

    try {
        #Creates a bodyfile then parses and outputs as a system timeline
        Write-Host "Creating bodyfile from MFT"
        Add-Content -Path $logPath -Value "Created bodyfile from MFT `n"
        & "$MFTeCMD" -f ("$Drive" + ":\" + 'C\$MFT') --body $OutPath --bodyf "C_MFT_Timeline.body" --bld --bdl C:
    }
    catch {
        
    }

    try {
        $MFTbodyFileName = $linuxOutPath + "/C_MFT_Timeline.body"
        $mactimeMFTOutPath = $linuxOutPath + "/C_MFT_timeline.csv"
        
        Add-Content -Path $logPath -Value "Created MFT filesystem timeline  `n"
        wsl /bin/bash -c  "mactime -d -b $MFTbodyFileName -z UTC > $mactimeMFTOutPath"
    }
    catch {
        
    }
    
####################################################################### Super Timeline Section #########################################################
    Add-Content -Path $logPath -Value "##################### Starting Super Timeline Section ###################################### `n"

    try {

    $l2tDumpPath = $linuxOutPath + "/plaso.dump"
    $kapeVhdxLocation = (Get-volume -DriveLetter $Drive | Get-DiskImage | select ImagePath).ImagePath
    $kapeVhdxLocationDoubleWhack = $kapeVhdxLocation.replace('\','\\')
    $kapeVhdxLocationLinux = wsl wslpath $kapeVhdxLocationDoubleWhack

    Add-Content -Path $logPath -Value "Creating UTC body file from mounted VHDX `n"
    wsl /bin/bash -c "log2timeline.py -z UTC --storage-file $l2tDumpPath $kapeVhdxLocationLinux"
    }catch{
    }


$l2tDumpPath = $linuxOutPath + "/plaso.dump"
    if ($false -eq $EndDate -or $null -eq $EndDate -and $null -eq $StartdDate -or $false -eq $StartDate) {
        $Lt2FullPath = $linuxOutPath + "/C_Supertimeline.csv"
        wsl psort.py --output_time_zone UTC -o l2tcsv $l2tdumppath -w $Lt2FullPath

        Add-Content -Path $logPath -Value " Created full super-timeline with no date ranges `n"

    }elseif ($true -eq $StartDate -and $true -eq $EndDate) {
        $L2tSlicePath = $linuxOutPath + "/C_Supertimeline_" + $StartDate + "_" + $EndDate + "Slice" + ".csv"
         wsl psort.py --output_time_zone `'UTC`' -o l2tcsv $l2tdumppath "date > `'$startDate`' AND date < `'$endDate`'" -w $l2tslicepath
            
        Add-Content -Path $logPath -Value "Created super-timeline slice between dates $StartDate and $EndDate `n"
    }elseif ($false -eq $EndDate -or $null -eq $EndDate -and $true -eq $StartDate ) {
        $L2tSlicePath = $linuxOutPath + "/C_Supertimeline_" + "After_" +$StartDate + "Slice" + ".csv"
            
        wsl psort.py --output_time_zone UTC -o L2tcsv $l2tDumpPath "date > `'$startDate`'"  -w $l2tSlicePath

        Add-Content -Path $logPath -Value "Created super-timeline slice starting at $StartDate `n"

    }elseif ($false -eq $StartDate -or $null -eq $StartDate -and $true -eq $EndDate) {
        $L2tSlicePath = $linuxOutPath + "/C_Supertimeline_" + "Before_" + $EndDate + "Slice" + ".csv"
        
        wsl psort.py --output_time_zone UTC -o L2tcsv $l2tDumpPath "date < `'$endDate`'" -w $l2tSlicePath

        Add-Content -Path $logPath -Value "Created super-timeline slice ending on $EndDate `n"
    }

    $stopWatch.Stop()
    $Runtime = $stopWatch.Elapsed.TotalMinutes.ToString()
    Add-Content -Path $logPath -Value "Script Exection took: $Runtime minutes to complete `n"
}
