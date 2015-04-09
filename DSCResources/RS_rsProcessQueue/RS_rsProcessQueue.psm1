Function Get-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName,
    [System.UInt32]$scavengeTime

  )
  return {
    @{ 'queueName' = $queueName;
      'scavengeTime' = $scavengeTime
    }
  }
}

Function Test-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName,
    [System.UInt32]$scavengeTime
  )
  if( (Get-MsmqQueue -Name $queueName).MessageCount -ne 0 ){
    return $false
  }
  else{ return $true }
}

Function Set-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName,
    [System.UInt32]$scavengeTime
  )
  $d = Get-Content $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'secrets.json') -Raw | ConvertFrom-Json
  do {
    $timeStamp = Get-Date
    $msg = Get-MsmqQueue -Name $queueName | Receive-MsmqQueue -Count 1 -RetrieveBody
    $msg = $msg.Body | ConvertFrom-Json
    $nodeRecord = 
    @"
{
'NodeName' : "$($msg.NodeName)",
'uuid' : "$($msg.uuid)",
'dsc_config' : "$($msg.dsc_config)",
'timeStamp' : "$timeStamp"
}
"@ | ConvertFrom-Json

    if($d.Shared_key -eq $msg.shared_key) {
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
        
      $store = Get-Item Cert:\LocalMachine\Root
      $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadWrite")
      $store.Add( $(New-Object System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @(,[System.Convert]::fromBase64String($msg.PublicCert))) )
      $store.Close()
      
  
    }
      
  } while ( (Get-MsmqQueue -Name $queueName).MessageCount -ne 0 )
  
  ### Scavenge stale records
  $nodesJson = Get-Content $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') | ConvertFrom-Json
  foreach($currentNode in $nodesJson.Nodes) {
    if($currentNode.timeStamp -le (Get-Date).AddDays(-$scavengeTime)) {
      $nodesJson.Nodes = $nodesJson.Nodes -notmatch $currentNode
    }
  }
  Set-Content -Path $(Join-Path ([Environment]::GetEnvironmentVariable('defaultPath','Machine')) 'nodes.json') -Value ($nodesJson | ConvertTo-Json)

}

Export-ModuleMember -Function *-TargetResource
