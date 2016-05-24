function Save-HTTPItemUsingBitsTransfer
{
    [CmdletBinding()]
    param(
       [Parameter(Mandatory=$true)]
       $Uri,
       [Parameter(Mandatory=$true)]
       $Destination,
       [switch]
       $noProgress
    )

    begin
    {
        $fullUri = [Uri]$Uri
        if (($fullUri.Scheme -ne 'http') -and ($fullUri.Scheme -ne 'https'))
        {
            throw "Uri: $uri is not supported. Only http or https schema are supported."
        }
    }
    
    end
    {
        $jstate = $null
        [bool] $isTransferCompleted = $false
        try
        {
            $mycurrentPath = $script:MyInvocation.MyCommand.Path
            $myCurrentDirectory = Split-Path $mycurrentPath
            $bitsCommandPath = join-path $myCurrentDirectory "BitsOnNano.exe"
            $jobNameTemp = "SH{0}" -f (get-date).Ticks
            $output = & $bitsCommandPath -Start-Transfer  -DisplayName $jobNameTemp -Source $Uri -Destination $Destination
            $le = $lastexitcode

            if (-not $noProgress) {
                $id = Write-Progress -ParentId 1 -Activity "Downloading from $Uri"
            }

            if($null -eq $id)
            {
                $id = 2
            }

            do
            {
                $jname,$jid,$jstate,$jbytesTransferred,$jbytesTotal,$null = $output -split ":"
                
                if ( (@("BG_JOB_STATE_ERROR", "BG_JOB_STATE_TRANSIENT_ERROR", "BG_JOB_STATE_CANCELLED") -contains $jstate) -or ($le))
                {
                    & $bitsCommandPath -Stop-Transfer -ID $jid | Out-Null

                     throw "Save-HTTPItem: Bits Transfer failed. Job State: $jstate ExitCode = $le"
                }
                
                if (@("BG_JOB_STATE_TRANSFERRING") -contains $jstate)
                {
                    $percentComplete = ($jbytesTransferred / $jbytesTotal) * 100  
                    $status = "Downloaded {0}MB of total {1}MB" -f ($jbytesTransferred/1mb),($jbytesTotal/1mb)  
                    if (-not $noProgress) {
                        $null = Write-Progress -Activity "Downloading from $Uri" -PercentComplete $percentComplete -Id $id
                    }
                }
                elseif (@("BG_JOB_STATE_TRANSFERRED") -contains $jstate)
                {
                    & $bitsCommandPath -Remove-Transfer -ID $jid | Out-Null
                    $isTransferCompleted = $true
                    break;
                }
                elseif (@("BG_JOB_STATE_QUEUED") -contains $jstate)
                {       
                    if (-not $noProgress) { 
                        $null = Write-Progress -Activity "QUEUED" -PercentComplete 0 -Id $id
                    }
                }
                elseif (@("BG_JOB_STATE_CONNECTING") -contains $jstate)
                {
                    if (-not $noProgress) {
                        $null = Write-Progress -Activity "CONNECTING" -PercentComplete 0 -Id $id
                    }
                }
                elseif (@("BG_JOB_STATE_ACKNOWLEDGED") -contains $jstate)
                {
                    if (-not $noProgress) {
                        $null = Write-Progress -Activity "ACKNOWLEDGED" -PercentComplete 0 -Id $id
                    }
                }

                Start-Sleep -Seconds 1
                $output = & $bitsCommandPath -Get-TransferStatus -ID $jid
                $le = $lastExitCode
            }while($true);
        }
        finally
        {
            #"Calling finally: jstate:$jstate isTC:$isTransferCompleted"
            if (-not $noProgress) {
                $null = Write-Progress -Completed -Activity "Downloading from $Uri" -Id $id
            }
            
            if ((-not $jstate)  -and (-not $isTransferCompleted))
            {
               "CleanUp:"
               & $bitsCommandPath -Stop-Transfer -ID $jid | Out-Null
            }
        }        
    }
}