﻿
Function Get-TargetResource {
   param (
      [Parameter(Mandatory)][string] $Name,
      [string] $DestinationQueue,
      [string] $MessageLabel = 'execute',
      [string] $dsc_config,
      [string] $shared_key,
      [string] $nodeinfopath
      )
      
      if($PSBoundParameters.Keys -notcontains '$nodeinfopath'){
            $nodeinfopath = ([Environment]::GetEnvironmentVariable('nodeInfoPath','Machine').ToString())
            if(!($nodeinfopath)) { $nodeinfopath = 'C:\Windows\Temp\nodeinfo.json' }
      }
   
      $nodeinfo = Get-Content -Path $nodeinfopath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json

      if(!($DestinationQueue)){ $DestinationQueue =  "FormatName:DIRECT=HTTPS://",$nodeinfo.PullServerName,"/msmq/private$/rsdsc" -join '' }
      
      if(!($dsc_config)){ $dsc_config -eq $nodeinfo.dsc_config }
      
      if(!($shared_key)){ $shared_key -eq $nodeinfo.shared_key }


   return @{
      'Name' = $Name
      'DestinationQueue' = $DestinationQueue
      'MessageLabel' = $MessageLabel
      'dsc_config' = $dsc_config
      'shared_key' = $shared_key
      'nodeinfopath' = $nodeinfopath
      
   }
}




Function Test-TargetResource {
   param (
      [Parameter(Mandatory)][string] $Name,
      [string] $DestinationQueue,
      [string] $MessageLabel = 'execute',
      [string] $dsc_config,
      [string] $shared_key,
      [string] $nodeinfopath
      )

   if($PSBoundParameters.Keys -notcontains '$nodeinfopath'){
            $nodeinfopath = ([Environment]::GetEnvironmentVariable('nodeInfoPath','Machine').ToString())
            if(!($nodeinfopath)) { $nodeinfopath = 'C:\Windows\Temp\nodeinfo.json' }
   }
   
   $nodeinfo = Get-Content -Path $nodeinfopath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json


   #Check if assigned DSC configuration or Shared Key has changed
   if($dsc_config){
        if($dsc_config -ne $nodeinfo.dsc_config){
            Write-Verbose -Message "dsc_config has changed. Test failed."
            return $false
        }
   }

   if($shared_key){
        if($shared_key -ne $nodeinfo.shared_key){
            Write-Verbose -Message "shared_key has changed. Test failed."
            return $false
        }
   }

   <#
   #Check if PullServer has Client MOF available
   $uri = (("https://",$nodeinfo.PullServerName,":",$nodeinfo.PullServerPort,"/PSDSCPullServer.svc/Action(ConfigurationId='",$nodeinfo.uuid,"')/ConfigurationContent") -join '')
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
    #>
    return $false
}




Function Set-TargetResource {
   
   param (
      [Parameter(Mandatory)][string] $Name,
      [string] $DestinationQueue,
      [string] $MessageLabel = 'execute',
      [string] $dsc_config,
      [string] $shared_key,
      [string] $nodeinfopath
      )
   
   
   if($PSBoundParameters.Keys -notcontains '$nodeinfopath'){
            $nodeinfopath = ([Environment]::GetEnvironmentVariable('nodeInfoPath','Machine').ToString())
            if(!($nodeinfopath)) { $nodeinfopath = 'C:\Windows\Temp\nodeinfo.json' }
   }
   
   $nodeinfo = Get-Content -Path $nodeinfopath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
   

   if($dsc_config){
        $nodeinfo.dsc_config = $dsc_config
   }

   if($shared_key){
        $nodeinfo.shared_key = $shared_key
   }


   #Ensure NIC info is updated in nodeinfo
   $network_adapters =  @{}
      
    $Interfaces = Get-NetAdapter | Select -ExpandProperty ifAlias

    foreach($NIC in $interfaces){

            $IPv4 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv4'} | Select -ExpandProperty IPAddress
            $IPv6 = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -eq $NIC -and $_.AddressFamily -eq 'IPv6'} | Select -ExpandProperty IPAddress

            $Hash = @{"IPv4" = $IPv4;
                      "IPv6" = $IPv6}
    
            $network_adapters.Add($NIC,$Hash)

    }


    if($nodeinfo.NetworkAdapters){
        $nodeinfo.NetworkAdapters = $network_adapters
    }
    else{
        Add-Member -InputObject $nodeinfo -MemberType NoteProperty -Name 'NetworkAdapters' -Value $network_adapters
    }
    #update bootstrapinfo on disk
   
    Set-Content -Path $nodeinfopath -Value ($nodeinfo | ConvertTo-Json -Depth 2)




    #Prep MSMQ Message
    
    if(!($DestinationQueue)){ $DestinationQueue =  "FormatName:DIRECT=HTTPS://",$nodeinfo.PullServerName,"/msmq/private$/rsdsc" -join '' }
    
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
      $publicCert = ((Get-ChildItem Cert:\LocalMachine\My | ? Subject -eq "CN=$env:COMPUTERNAME`_enc").RawData)
      $msgbody = @{'Name' = "$env:COMPUTERNAME"
         'uuid' = $($nodeinfo.uuid)
         'dsc_config' = $($nodeinfo.dsc_config)
         'shared_key' = $($nodeinfo.shared_key)
         'PublicCert' = "$([System.Convert]::ToBase64String($publicCert))"
         'NetworkAdapters' = $($nodeinfo.NetworkAdapters)
      } | ConvertTo-Json
      $msg = New-Object System.Messaging.Message
      $msg.Label = $MessageLabel
      $msg.Body = $msgbody
      $queue = New-Object System.Messaging.MessageQueue ($DestinationQueue, $False, $False)
      


   #Send message, and then check for available MOF. Will retry Send 5 times if MOF not found, sleeping 30 seconds each
   <#
   $uri = (("https://",$nodeinfo.PullServerName,":",$nodeinfo.PullServerPort,"/PSDSCPullServer.svc/Action(ConfigurationId='",$nodeinfo.uuid,"')/ConfigurationContent") -join '')
   
   $retries = 1 
   do{
        $queue.Send($msg)
        $retries ++
              try{
                    if((Invoke-WebRequest $uri).StatusCode -ne '200'){
                        Write-Verbose -Message "MOF retrieval resulted in non-200 HTTP status code. Retrying"
                        Sleep 30
                    }
                    else{ $retries -eq 6 }
                }
                catch {}
      Write-Verbose -Message "Sending MSMQ message to $DestinationQueue"
                
     }
   
   while($retries -le 5)
   
         
  #>
}


Export-ModuleMember -Function *-TargetResource