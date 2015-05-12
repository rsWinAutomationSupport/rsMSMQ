function Get-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    return @{
        "QueueName" = $QueueName
        "Ensure" = if([System.Messaging.MessageQueue]::Exists(".\private$\$QueueName")){'Present'}else {'Absent'}
    }
  
}

function Test-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    if( $Ensure -eq 'Present') {
        if( [System.Messaging.MessageQueue]::Exists(".\private$\$QueueName") ){
            return $true
        }
        else{
            return $false
        }
    }
    else {
        if( [System.Messaging.MessageQueue]::Exists(".\private$\$QueueName")){
            return $false
        }
        else{
            return $true
        }
    }
}

function Set-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
    if( $Ensure -eq 'Present') {
        New-MsmqQueue -Name $QueueName -Verbose | Set-MsmqQueueACL -UserName "BUILTIN\Administrators" -Allow FullControl -Verbose
    }
    else {
        [System.Messaging.MessageQueue]::Delete(".\private$\$QueueName")
    }
}
Export-ModuleMember -Function *-TargetResource
