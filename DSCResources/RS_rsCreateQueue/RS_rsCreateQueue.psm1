Get-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName
  )
  
}

Test-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName
  )
  if( (Get-MsmqQueue -Name $queueName).MessageCount -ne 0 ){
    return $false
  }
  else{ return $true }
}

Set-TargetResource {
  param (
    [parameter(Mandatory = $true)][string]$queueName
  )

}

<#
  do {
  $msg = Get-MsmqQueue -Name 'rsdsc' | Receive-MsmqQueue -Count 1 -RetrieveBody
  $msg = $msg.Body | ConvertFrom-Json

  $store = Get-Item Cert:\LocalMachine\Root
  $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadWrite")
  $store.Add( $(New-Object System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @(,[System.Convert]::fromBase64String($msg.PublicCert))) )
  $store.Close()
  } while ( (Get-MsmqQueue -Name 'rsdsc').MessageCount -ne 0 )
#>