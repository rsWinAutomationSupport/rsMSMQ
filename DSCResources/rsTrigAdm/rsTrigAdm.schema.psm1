Configuration rsTrigAdm
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )
    Script GetTrigAdmZIP {
        SetScript = {(New-Object -TypeName System.Net.webclient).DownloadFile('http://download.microsoft.com/download/6/e/6/6e6f28eb-e3c3-4327-8692-4b15cd5cf1a6/trigadm_xp.zip', 'C:\Windows\temp\trigadm.zip')}

        TestScript = {Test-Path -Path 'C:\Windows\temp\trigadm.zip'}

        GetScript = {
            return @{
                'Result' = $(Join-Path 'C:\Windows\temp\trigadm.zip')
            }
        }
    }
    Archive UnzipTrigAdm {
        Path = 'C:\Windows\temp\trigadm.zip'
        Destination = 'C:\Windows\temp'
        Ensure = $Ensure
        DependsOn = '[Script]GetTrigAdmZIP'
    }
    File MoveTrigAdmnEXE {
        SourcePath = 'C:\Windows\temp\trigadm.exe'
        DestinationPath = 'C:\Windows\system32'
        Ensure = $Ensure
        Type = 'File'
        DependsOn = '[Archive]UnzipTrigAdm'
    }
}
       
