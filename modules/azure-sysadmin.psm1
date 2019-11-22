<#
.SYNOPSIS
This module can be used to complete general tasks as a sysadmin in Microsoft Azure

.DESCRIPTION
Long description

.NOTES
General notes
#>

Function Get-RmAzContext {
    $azContext = Get-AzContext
    Write-Host "This is your current AzContext" -ForegroundColor Cyan
    $azContext | Select-Object Name, Account, Subscription, Tenant | Format-List
}
Function Set-RmAzContext {
    $azContext = Get-AzSubscription | Out-GridView -PassThru
    Set-AzContext $azContext
}
Function Pip {
    #Checks your Public IP address and copies it to your clipboard
    $PIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    Write-Host "Current external IP: [$PIP]" -ForegroundColor Green
    Set-Clipboard -Value $PIP
}