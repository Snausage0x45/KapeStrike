function Invoke-Kape {
    param (
        [Parameter(Mandatory)]
        [string[]]$Hosts,

        [string]$ClientID,

        [string]$ClientSecret,

        [string]$OutPath
    )
<#
    .SYNOPSIS
      Utilizes Falcon RTR to place KAPE and execute a triage collection. Handles single or multihost and online/offline. 
    .EXAMPLE
     Invoke-Kape -Hosts Host1,Host2,Host3 -ClientID CLIENTID -ClientSecret CLIENTSECRET
#>
    #It wasn't writing confirm to console correctly so had to a little string stuff
    function Write-HashTable {
        param (
            [Parameter(Mandatory)]
            $HashTable
        )
                 $confirmStr = $HashTable | Out-String
                 Write-Host $confirmStr
    }

    function Invoke-CSCommandBatch {
        param (
            [Parameter(Mandatory)]
            [string]$CSCommand,

            [Parameter(Mandatory)]
            [string]$Arguments,

            [switch]$IgnoreConfirm

        )

        $Command = Invoke-FalconAdminCommand -Command $CSCommand -Arguments $Arguments -BatchId $Batch.batch_id # -OptionalHostIds $offlineBatchAids
        sleep 5
    }

    function Write-BulkHostOut {
        param (
            [string]$name,

            [string]$status
        )
        #Check to see if the csv is already there, if not then try to create it.


        if ($null -eq (gci $outpath -ErrorAction SilentlyContinue)) {
            
            try {
                New-Item $outpath | Out-Null 
            }
            catch {
                Write-Host "ERROR could not create CSV at supplied location: " $outpath -ErrorAction Continue
            }
        }

        #lil ps object for export
        $csvFormat =[pscustomobject]@{
            'Hostname' = $name
            'Status' = $status
        }

        Export-Csv -Path $outpath -Append -InputObject $csvFormat
        }

    #Runs the comannds needed to get everything set up, checks to wait to see if it complete and then runs the next command
    function Invoke-CSCommandSingle {
        param (
            [Parameter(Mandatory)]
            [string]$CSCommand,

            [Parameter(Mandatory)]
            [string]$Arguments,

            [switch]$IgnoreConfirm

        )
        
        if ($session.offline_queued -eq $false) {

            $Command = Invoke-FalconAdminCommand -Command $CSCommand -Arguments $Arguments -SessionId $Session.session_id 
            sleep 5
            $confirm = Confirm-FalconAdminCommand -CloudRequestId $Command.cloud_request_id 

            if ($confirm.complete -eq $false -and $null -eq $IgnoreConfirm -or $IgnoreConfirm -eq "" -or $IgnoreConfirm -eq $false ) {
                do {
                    Write-Host "Waiting for Command to complete - sleeping for 5 seconds" -BackgroundColor Black -ForegroundColor Yellow
                    sleep 5
                    $confirm = Confirm-FalconCommand -CloudRequestId $Command.cloud_request_id 
                    $i++
    
                    #The timeout is 10 minutes, so this refreshes the session every 8 minutes
                    if ($i % 96 -eq 0) {
                        Update-FalconSession -SessionId $Session.session_id 
                    }
    
                } until ($confirm.complete -eq $true) 
                    if ($confirm.complete -eq $true) {
    
                        Write-HashTable $confirm
                    }  
    
            }elseif ($IgnoreConfirm -eq $true) {
                #We still have to actually confirm once despite the name of the flag but we don't loop on it to be finished
                sleep 5
                Confirm-FalconCommand -CloudRequestId $Command.cloud_request_id
            }
             else {
    
                Write-HashTable $confirm
    
            }
        }else {
            $Command = Invoke-FalconAdminCommand -Command $CSCommand -Arguments $Arguments -SessionId $Session.session_id 
            sleep 5
            Write-HashTable $Command
        }

        
    }

        #Generate PS Token
        Import-Module PSFalcon
        Request-FalconToken -ClientId $ClientID -ClientSecret $ClientSecret
    
    
        #Convert Hostnames to CS Info
        foreach ($HostName in $Hosts) {
            [array] $CSInfo += Get-FalconHost -Detailed -Filter "hostname:'$($hostname)'" | select device_id, hostname, last_seen
            $i = 0

            if($null -eq $CSInfo[$i]){
                Write-Host $HostName "Is NOT in CS" -BackgroundColor Black -ForegroundColor red
                 
               }else{
               
                  Write-Host $HostName  "Is in CS" -BackgroundColor Black -ForegroundColor Green
               }
               $i++
        }

        Write-Host "`n"

    #Depending on the number of hosts and online/offline status each scenario gets handled differently

    switch ($Hosts.Count) {
        {$_ -eq 0} { 
            #This shouldn't be possible

            throw 

        }
        {$_ -eq 1} { 
            #Single Host RTR Sesion
            
            $Session = Start-FalconSession -HostId $CSInfo.device_id -QueueOffline $true

            if ($Session.offline_queued -eq $true) {
                Write-Host $HostName "Is offline. Commands will be queued" -ForegroundColor yellow -BackgroundColor black
            }else {
                Write-Host $HostName "is Online. Running Commands" -ForegroundColor green -BackgroundColor black
            }
                    Invoke-CSCommandSingle -CSCommand mkdir -Arguments "C:\temp\Kape"
                    Write-host "Creating Temp directory C:\temp\kape" -BackgroundColor Black -ForegroundColor Green

                    Invoke-CSCommandSingle -CSCommand cd -Arguments "C:\temp\Kape"
                    Write-host "CDing into the the dir" -BackgroundColor Black -ForegroundColor Green

                    Invoke-CSCommandSingle -CSCommand put -Arguments "KAPE.zip"
                    Write-host "Putting the file KAPE.zip" -BackgroundColor Black -ForegroundColor Green

                    Invoke-CSCommandSingle -CSCommand put -Arguments "7za.exe"
                    Write-host "Putting the file 7za.exe" -BackgroundColor Black -ForegroundColor Green

                    Invoke-CSCommandSingle -CSCommand runscript -Arguments "-CloudFile='Invoke-Kape-Remote.ps1'  -timeout='9000'" -IgnoreConfirm
                    Write-host "Running the Kape collection script on the host, capture will be uploaded Azure" -BackgroundColor Black -ForegroundColor Green

        }
        {$_ -ge 2} { 
            # Multiple Hosts
            
        $Batch = Start-FalconSession -HostIds $CSInfo.device_id -QueueOffline $true

        #Check to see which host is online or offline and adds the offline ones to 
        foreach($sesh in $Batch.hosts.getenumerator()) {
            
            for ($i = 0 ; $i -lt $CSInfo.device_id.Count; $i++) {

                if ($sesh.aid -match $CSInfo[$i].device_id -eq $true) {

                    switch ($sesh.offline_queued) {

                        $false { Write-Host $CSInfo[$i].hostname "is Online, running commands!" -BackgroundColor Black -ForegroundColor Green
                                 
                                Write-BulkHostOut -name $CSInfo[$i].hostname -status "Online" 
                            }

                        $true { Write-Host $CSInfo[$i].hostname "is Offline, queuing commands!"  -BackgroundColor Black -ForegroundColor Yellow

                                [array]$offlineBatchAids += $sesh.aid

                                Write-BulkHostOut -name $CSInfo[$i].hostname -status "Offline"
                        }
                    }
                }
                
                    }
                } 

        #Do the commands
        Invoke-CSCommandBatch -CSCommand mkdir -Arguments "C:\temp\Kape"
        Write-host "Creating Temp directory C:\temp\kape" -BackgroundColor Black -ForegroundColor Green

        Invoke-CSCommandBatch -CSCommand cd -Arguments "C:\temp\Kape"
        Write-host "CDing into the the dir" -BackgroundColor Black -ForegroundColor Green

        Invoke-CSCommandBatch -CSCommand put -Arguments "KAPE.zip"
        Write-host "Putting the file KAPE.zip" -BackgroundColor Black -ForegroundColor Green

        Invoke-CSCommandBatch -CSCommand put -Arguments "7za.exe"
        Write-host "Putting the file 7za.exe" -BackgroundColor Black -ForegroundColor Green

        Invoke-CSCommandBatch -CSCommand runscript -Arguments "-CloudFile='Invoke-Kape-Remote.ps1'  -timeout='9000'" -IgnoreConfirm
        Write-host "Running the Kape collection script on the host, capture will be uploaded Azure" -BackgroundColor Black -ForegroundColor Green


        Write-Host "Creating output CSV at: " $outpath

    }

}
}
