Function Get-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure,
      [string]$NodeInfo,
      [string]$dsc_config,
      [string]$shared_key
      )

      $bootstrapinfo = Get-Content $NodeInfo -Raw | ConvertFrom-Json

      if!($dsc_config){ $dsc_config -eq $bootstrapinfo.dsc_config }
      if!($shared_key){ $shared_key -eq $bootstrapinfo.shared_key }


   return @{
      'DestinationQueue' = $DestinationQueue
      'MessageLabel' = $MessageLabel
      'Name' = $Name
      'Ensure' = $Ensure
      'NodeInfo' = $NodeInfo
      'dsc_config' = $dsc_config
      'shared_key' = $shared_key
      
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
      [string]$NodeInfo,
      [string]$dsc_config,
      [string]$shared_key
      )
   $bootstrapinfo = Get-Content $NodeInfo -Raw | ConvertFrom-Json

   if($dsc_config){
        if($dsc_config -ne $bootstrapinfo.dsc_config){
            Write-Verbose -Message "dsc_config has changed. Test failed."
            return $false
        }
   }

   if($shared_key){
        if($shared_key -ne $bootstrapinfo.shared_key){
            Write-Verbose -Message "shared_key has changed. Test failed."
            return $false
        }
   }

   
   #Check if PullServer has Client MOF available
   $uri = (("https://",$bootstrapinfo.PullServerName,":",$bootstrapinfo.PullServerPort,"/PSDSCPullServer.svc/Action(ConfigurationId='",$bootstrapinfo.uuid,"')/ConfigurationContent") -join '')
   try{
        if((Invoke-WebRequest $uri).StatusCode -ne '200'){
            Write-Verbose -Message "MOF retrieval resulted in non-200 HTTP status code. Test failed."
            return $false
        }
    }
   catch{
       Write-Verbose -Message "Web request failed. Test failed."
       return $false
   }
   

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
      [string]$NodeInfo,
      [string]$dsc_config,
      [string]$shared_key
      )
   

   if($Ensure -eq 'Present') {


   $bootstrapinfo = Get-Content $NodeInfo -Raw | ConvertFrom-Json


   #Ensure NIC info is updated in message
   $network_adapters =  @{}
      
    $Interfaces = Get-NetAdapter | Select -ExpandProperty ifAlias

    foreach($NIC in $interfaces){

            $IPv4 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv4'} | Select -ExpandProperty IPAddress
            $IPv6 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv6'} | Select -ExpandProperty IPAddress

            $Hash = @{"IPv4" = $IPv4;
                      "IPv6" = $IPv6}
    
            $network_adapters.Add($NIC,$Hash)

    }


    
    $bootstrapinfo.NetworkAdapters = $network_adapters

    #update bootstrapinfo on disk
   
    
    if($dsc_config){
        $bootstrapinfo.dsc_config = $dsc_config
   }

   if($shared_key){
        $bootstrapinfo.shared_key = $shared_key
   }

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
      Write-Verbose -Message "Sending MSMQ message to $DestinationQueue"
      $queue.Send($msg)

      
      
   }
   else {
      Write-Verbose "Not Sending Messages"
   }
}


Export-ModuleMember -Function *-TargetResource