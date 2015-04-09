function Get-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    return @{
        "QueueName" = $QueueName
        "Ensure" = $(if((Get-MsmqQueue -Name $QueueName).count){return 'Present'}else {return 'Absent'})
    }
  
}

function Test-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    if( $Ensure -eq 'Present') {
        if( (Get-MsmqQueue -Name $QueueName).count -eq 0 ){
            return $false
        }
        else{ return $true }
    }
    else {
        if( (Get-MsmqQueue -Name $QueueName).count -ne 0 ){
            return $false
        }
        else{ return $true }
    }
}

function Set-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    if( $Ensure -eq 'Present') {
        New-MsmqQueue -Name $QueueName -Verbose | Set-MsmqQueueACL -UserName "BUILTIN\Administrators" -Allow FullControl -Verbose
    }
    else {
        Get-MsmqQueue -Name $QueueName | Remove-MsmqQueue -Verbose
    }
}
Export-ModuleMember -Function *-TargetResource