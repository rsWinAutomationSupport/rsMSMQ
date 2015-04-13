function Get-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [string]$TriggerName,
        [string]$RuleName,
        [string]$RuleCondition,
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
        [string]$TriggerName,
        [string]$RuleName,
        [string]$RuleCondition,
        [string]$RuleAction,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    if( $Ensure -eq 'Present') {
        if( ((trigadm /request:GetTriggersList) | Select-String $TriggerName).count -eq 0 -OR ((trigadm /request:GetRulesList) | Select-String $RuleName).count -eq 0 ){
            return $false
        }
        else { return $true }
    }
    else {
        if( ((trigadm /request:GetTriggersList) | Select-String $TriggerName).count -eq 0 -AND ((trigadm /request:GetRulesList) | Select-String $RuleName).count -eq 0 ){
            return $true
        }
        else { return $false }
    }
}

function Set-TargetResource {
    param (
        [parameter(Mandatory = $true)][string]$QueueName,
        [string]$TriggerName,
        [string]$RuleName,
        [string]$RuleCondition,
        [string]$RuleAction,
        [ValidateSet("Absent","Present")][string]$Ensure = 'Present'
    )
    if( $Ensure -eq 'Present') {
        if( ((trigadm /request:GetRulesList) | Select-String $RuleName).count -ne 0 ) {
            $ruleID = (((trigadm /request:GetRulesList) | Select-String $RuleName) -split "\s+")[0]
            trigadm /request:DeleteRule /ID:$ruleID
        }
        if( ((trigadm /request:GetTriggersList) | Select-String $TriggerName).count -ne 0 ) {
            $triggerID = (((trigadm /request:GetTriggersList) | Select-String $TriggerName) -split "\s+")[0]
            trigadm /request:DeleteTrigger /ID:$triggerID
        }
        #$rule = trigadm /request:AddRule /Name:$RuleName /Cond:"`$MSG_LABEL_CONTAINS=execute" /Action:"EXE$("`t")C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe$("`t" + "\" + '"')-Command$("\" + '"' + "`t" + "\" + '"')Get-ScheduledTask -TaskName MSMQTrigger | Start-ScheduledTask$("\" + '"' + "`t")"
        $rule = trigadm /request:AddRule /Name:$RuleName /Cond:"$RuleCondition" /Action:"$RuleAction"
        $trigger = trigadm /request:AddTrigger /Name:$TriggerName /Queue:$env:COMPUTERNAME\private$\$QueueName /Enabled:true
        trigadm /request:AttachRule /TriggerID:$trigger /RuleID:$rule
    }
    else {
        if( ((trigadm /request:GetRulesList) | Select-String $RuleName).count -ne 0 ) {
            $ruleID = (((trigadm /request:GetRulesList) | Select-String $RuleName) -split "\s+")[0]
            trigadm /request:DeleteRule /ID:$ruleID
        }
        if( ((trigadm /request:GetTriggersList) | Select-String $TriggerName).count -ne 0 ) {
            $triggerID = (((trigadm /request:GetTriggersList) | Select-String $TriggerName) -split "\s+")[0]
            trigadm /request:DeleteTrigger /ID:$triggerID
        }
    }
}
Export-ModuleMember -Function *-TargetResource