Function Get-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure
   )
   return @{
      'DestinationQueue' = $DestinationQueue
      'MessageLabel' = $MessageLabel
      'Name' = $Name
      'Ensure' = $Ensure
   }
}

Function Test-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure
   )
   return $false
}

Function Set-TargetResource {
   param (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [string]$DestinationQueue,
      [string]$MessageLabel,
      [string]$Ensure
   )
   $bootstrapinfo = Get-Content "C:\Windows\Temp\bootstrapinfo.json" -Raw | ConvertFrom-Json
   if($Ensure -eq 'Present') {
      $bootstrapinfo = Get-Content "C:\Windows\Temp\bootstrapinfo.json" -Raw | ConvertFrom-Json
      [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
      $publicCert = ((Get-ChildItem Cert:\LocalMachine\Root | ? Subject -eq "CN=$env:COMPUTERNAME`_enc").RawData)
      $msgbody = @{'Name' = "$env:COMPUTERNAME"
         'uuid' = $($bootstrapinfo.MyGuid)
         'dsc_config' = $($bootstrapinfo.dsc_config)
         'shared_key' = $($bootstrapinfo.shared_key)
         'PublicCert' = "$([System.Convert]::ToBase64String($publicCert))"
      } | ConvertTo-Json
      $msg = New-Object System.Messaging.Message
      $msg.Label = 'execute'
      $msg.Body = $msgbody
      $queueName = "FormatName:DIRECT=HTTPS://$($bootstrapinfo.Name)/msmq/private$/rsdsc"
      $queue = New-Object System.Messaging.MessageQueue ($queueName, $False, $False)
      $queue.Send($msg)
   }
   else {
      Write-Verbose "Not Sending Messages"
   }
}


Export-ModuleMember -Function *-TargetResource