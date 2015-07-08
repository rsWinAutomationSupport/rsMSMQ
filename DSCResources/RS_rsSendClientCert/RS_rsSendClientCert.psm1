Function Get-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure,
      [string]$NodeInfo
      )
   return @{
      'DestinationQueue' = $DestinationQueue
      'MessageLabel' = $MessageLabel
      'Name' = $Name
      'Ensure' = $Ensure
      'NodeInfo' = $NodeInfo
      
   }
}

Function Test-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure,
      [string]$NodeInfo
      )
   $bootstrapinfo = Get-Content $NodeInfo -Raw | ConvertFrom-Json

   
   #Check if PullServer has Client MOF available
   $uri = (("https://",$bootstrapinfo.PullServerName,":",$bootstrapinfo.PullServerPort,"/PSDSCPullServer.svc/Action(ConfigurationId='",$bootstrapinfo.uuid,"')/ConfigurationContent") -join '')
   try{
        if((Invoke-WebRequest $uri).StatusCode -ne '200'){return $false}
    }
   catch{return $false}
   

   return $true  
}

Function Set-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure,
      [string]$NodeInfo
      )
   $PSBoundParameters.Remove($RefreshInterval)

   if($Ensure -eq 'Present') {


   #Ensure NIC info is updated in message
   $network_adapters =  @{}

    $bootstrapinfo = Get-Content $NodeInfo -Raw | ConvertFrom-Json
      
    $Interfaces = Get-NetAdapter | Select -ExpandProperty ifAlias

    foreach($NIC in $interfaces){

            $IPv4 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv4'} | Select -ExpandProperty IPAddress
            $IPv6 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv6'} | Select -ExpandProperty IPAddress

            $Hash = @{"IPv4" = $IPv4;
                      "IPv6" = $IPv6}
    
            $network_adapters.Add($NIC,$Hash)

    }

    $bootstrapinfo.NetworkAdapters = $network_adapters

    Set-Content -Path $NodeInfo -Value ($bootstrapinfo | ConvertTo-Json -Depth 2)


    
      [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
      $publicCert = ((Get-ChildItem Cert:\LocalMachine\My | ? Subject -eq "CN=$env:COMPUTERNAME`_enc").RawData)
      $msgbody = @{'Name' = "$env:COMPUTERNAME"
         'uuid' = $($bootstrapinfo.uuid)
         'dsc_config' = $($bootstrapinfo.dsc_config)
         'shared_key' = $($bootstrapinfo.shared_key)
         'PublicCert' = "$([System.Convert]::ToBase64String($publicCert))"
         'NetworkAdapters' = $($bootstrapinfo.NetworkAdapters)
      } | ConvertTo-Json
      $msg = New-Object System.Messaging.Message
      $msg.Label = $MessageLabel
      $msg.Body = $msgbody
      $queue = New-Object System.Messaging.MessageQueue ($DestinationQueue, $False, $False)
      $queue.Send($msg)

      
      
   }
   else {
      Write-Verbose "Not Sending Messages"
   }
}


Export-ModuleMember -Function *-TargetResource