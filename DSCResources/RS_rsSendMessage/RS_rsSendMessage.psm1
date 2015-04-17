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
     [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
     $msg = New-Object System.Messaging.Message
     $msg.Label = $MessageLabel
     $msg.Body = @{
     "Name" = $env:COMPUTERNAME;
     "uuid" = $bootstrapinfo.MyGuid;
     "dsc_config" = $bootstrapinfo.dsc_config;
     "shared_key" = $bootstrapinfo.shared_key;
     "PublicCert" = $([System.Convert]::ToBase64String($((Get-ChildItem Cert:\LocalMachine\Root | ? Subject -eq "CN=$env:COMPUTERNAME`_enc").RawData)))
        }
    $queue = New-Object System.Messaging.MessageQueue ($DestinationQueue, $False, $False)
    $queue.Send($msg)
  }
  else {
    Write-Verbose "Not Sending Messages"
  }
}


Export-ModuleMember -Function *-TargetResource