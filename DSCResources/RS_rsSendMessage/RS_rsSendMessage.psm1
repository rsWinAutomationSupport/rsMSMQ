Function Get-TargetResource {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    [string]$DestinationQueue,
    [string]$MessageLabel,
    [Microsoft.Management.Infrastructure.CimInstance[]]$MessageBody,
    [string]$Ensure
  )
  return @{
    'DestinationQueue' = $DestinationQueue
    'MessageLabel' = $MessageLabel
    'MessageBody' = $MessageBody
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
    [Microsoft.Management.Infrastructure.CimInstance[]]$MessageBody,
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
    [Microsoft.Management.Infrastructure.CimInstance[]]$MessageBody,
    [string]$Ensure
  )
  if($Ensure -eq 'Present') {
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    $msg = New-Object System.Messaging.Message
    $msg.Label = $MessageLabel
    $msg.Body = $MessageBody
    $queue = New-Object System.Messaging.MessageQueue ($DestinationQueue, $False, $False)
    $queue.Send($msg)
  }
  else {
    Write-Verbose "Not Sending Messages"
  }
}


Export-ModuleMember -Function *-TargetResource