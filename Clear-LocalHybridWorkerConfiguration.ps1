<#
.SYNOPSIS
Script to clear the Microsoft Monitoring Cache and remove the hybrid worker configuration from the registry.

.DESCRIPTION
This script is intended to be run from PowerShell. 
If a VM is enabled for Update Management in Azure Automation and is migrated to Azure it somehow gets corrupted (in my experience)
Use this script to: Fix "Update management is not enabled on this machine error" (while it was already enabled in the past)
Use this script to: Clear the Hybrid worker configuration
After running the script the configuration will be downloaded automatically from the required resources.

Created by RBNMK
#>

#requires -RunAsAdministrator

begin {
    try {
        Stop-Service HealthService -Verbose
    }
    catch {
        Write-Error "$($error[0].Exception.Message)"
        Write-Host "Stopping script. We need to stop the HealthService properly."
        Break
    }

    $StoppingServiceTime = (Get-Date).AddSeconds(30)
    do {
        Write-Host "Waiting for Service to be stopped completely before continuing"
        $ServiceStatus = (Get-Service -Name HealthService).Status
    } until ($ServiceStatus -eq "Stopped" -or (New-TimeSpan -End $StoppingServiceTime))

    Write-Host "HealtService is now $ServiceStatus, SCOM monitoring will be stopped as well." -ForegroundColor Yellow
}

process {
    Try {
        Remove-Item `
            -path "HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker" `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }
    catch { 
        Write-Warning "$($error[0].Exception.Message)"
    }

    Try {

        $currentuser = whoami.exe
        $acl = Get-Acl "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State"
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentuser, "FullControl", "Allow")
        $acl.SetAccessRule($AccessRule)
        $acl | Set-Acl "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State"


        Remove-Item `
            -Path "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State" `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }
    catch {
        Write-Warning "$($error[0].Exception.Message)"
    }

    $StartingServiceTime = (Get-Date).AddSeconds(30)
    Start-Service HealthService
    do {
        Write-Host "Waiting for HealthService to be started completely before continuing"
        $StartedServiceStatus = (Get-Service -Name HealthService).Status
    } until ($StartedServiceStatus -eq "Running" -or (New-TimeSpan -End $StartingServiceTime))

    Write-Host "HealtService is now $($StartedServiceStatus) , SCOM monitoring will be resumed as well." -ForegroundColor Green
}


end {
    Write-Host "Script completed. Please check the Azure Automation account SYSTEM Hybrid workers" -ForegroundColor Green
}



