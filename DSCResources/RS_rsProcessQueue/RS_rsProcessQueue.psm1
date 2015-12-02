Function clearStaleRecords {
    param (
        [UInt32]$scavengeTime
    )
    ### Scavenge stale records
    $nodesJson = Get-Content $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Raw | ConvertFrom-Json
    foreach($currentNode in $nodesJson.Nodes) {
        if($currentNode.timeStamp -le (Get-Date).AddDays(-$scavengeTime)) {
            $nodesJson.Nodes = $nodesJson.Nodes -notmatch $currentNode
        }
    }
    Set-Content -Path $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Value ($nodesJson | ConvertTo-Json) 
}
Function Get-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$queueName,
        [System.UInt32]$scavengeTime

    )
    return @{ 
        queueName = $queueName
        scavengeTime = $scavengeTime
    }
}

Function Test-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$queueName,
        [System.UInt32]$scavengeTime
    )
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    $q = New-Object System.Messaging.MessageQueue ".\private$\$queueName"
    if( $q.GetAllMessages().Length -ne 0 ){
        return $false
    }
    else{
        ### Scavenge stale records
        clearStaleRecords -scavengeTime $scavengeTime
        return $true 
    }
}

Function Set-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$queueName,
        [System.UInt32]$scavengeTime
    )
    $DSCSettingsFile = $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'DSCAutomationSettings.xml')
    $SharedKey = (Get-DSCSettingValue -Path $DSCSettingsFile -Key "SharedKey").SharedKey
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    $q = New-Object System.Messaging.MessageQueue ".\private$\$queueName"
    $q.Formatter.TargetTypeNames = ,"System.String"    
    do {
        $timeStamp = Get-Date
        $msg = $q.Receive()
        $msg = $msg.Body | ConvertFrom-Json
        $nodeRecord = @{'NodeName' = "$($msg.Name)";'uuid' = "$($msg.uuid)";'dsc_config' = "$($msg.dsc_config)";'NetworkAdapters' = "$($msg.NetworkAdapters)";'timeStamp' = "$timeStamp"}

        if($SharedKey -eq $msg.shared_key) {
            $nodesJson = Get-Content $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Raw | ConvertFrom-Json
            if($nodesJson.Nodes.uuid -notcontains $msg.uuid) {
                $nodesJson.Nodes += $nodeRecord
                Set-Content -Path $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Value ($nodesJson | ConvertTo-Json)
            }
            else {
                $currentNode = $nodesJson.Nodes | ? uuid -eq $($msg.uuid)
                foreach($property in $currentNode.PSObject.Properties) {
                    if($msg.PSObject.Properties.Name -contains $property.Name) {

                        ($nodesJson.Nodes  | ? uuid -eq $($msg.uuid)).$($property.Name) = $msg.$($property.Name)
                    }
                    ($nodesJson.Nodes  | ? uuid -eq $($msg.uuid)).timeStamp = "$timeStamp"
                    Set-Content -Path $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Value ($nodesJson | ConvertTo-Json)
                }
            }
            $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @(,[System.Convert]::fromBase64String($msg.PublicCert))
      
            #Create Certificates Folder if it does not exist yet
            $CertificatesPath = Join-Path -Path ([System.Environment]::GetEnvironmentVariable('defaultPath', 'Machine')) -ChildPath Certificates
            If (!(Test-Path -Path $CertificatesPath -PathType Container)) {
                New-Item -Path $CertificatesPath -Type Container
            }
            
            #build Base64 encoded PEM certificate using StringBuilder and write to file
            #called <uuid>.cer
            $NodeCertPath = Join-Path -Path $CertificatesPath -ChildPath "$($msg.uuid).cer"
            $builder = New-Object System.Text.StringBuilder
            $builder.AppendLine("-----BEGIN CERTIFICATE-----")
            $builder.AppendLine([System.Convert]::ToBase64String($Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)))
            $builder.AppendLine("-----END CERTIFICATE-----")
            $builder.ToString() | Out-File -FilePath $NodeCertPath
        
            $store = Get-Item Cert:\LocalMachine\Root
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadWrite")
            $store.Add($Certificate)
            $store.Close()
  
        }
      
    } while ( $q.GetAllMessages().Length -ne 0 )
  
    ### Scavenge stale records
    clearStaleRecords -scavengeTime $scavengeTime

}

Export-ModuleMember -Function *-TargetResource
