function Get-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    return @{
        "QueueName" = $QueueName
        "Ensure" = if((Get-MsmqQueue -Name $QueueName).count){'Present'}else {'Absent'}
}
  
}

function Test-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    if( $Ensure -eq 'Present') {
        try{
            if( (Get-MsmqQueue -Name $QueueName).count -ge 0 ){
                return $true
            }
        }
        catch { return $false }
    }
    else {
        try{
            if( (Get-MsmqQueue -Name $QueueName).count -ge 0 ){
                return $false
            }
        }
        catch { return $true }
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
