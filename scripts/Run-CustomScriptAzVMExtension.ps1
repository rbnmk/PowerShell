<#
.SYNOPSIS
Script to run a Powershell script that resides on a storage account in the same subscription on a given VM. You can also apply a parameter name and value by modifying the run part. Default it just runs the script.
Microsoft docs: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows

.DESCRIPTION
This script is intended to be run from PowerShell in your current AzContext

.EXAMPLE
.\Run-CustomScriptAzVMExtension.ps1 `
-vmName vm01 -vmResourceGroupName virtualmachines `
-FileName Install-IIS.ps1 `
-storageAccountName deploymentstorage -storageResourceGroupName storage -containerName scripts 

.EXAMPLE
.\Run-CustomScriptAzVMExtension.ps1 `
-vmName vm01 -vmResourceGroupName virtualmachines -FileName Install-IIS.ps1 `
-storageAccountName deploymentstorage -storageResourceGroupName storage -containerName scripts `
-parameterName WebsiteName -parameterValue defaultwebsite

Created by RBNMK
#>

param (
    [Parameter(Mandatory = $true)]$storageAccountName,
    [Parameter(Mandatory = $true)]$storageResourceGroupName,
    [Parameter(Mandatory = $true)]$containerName,
    [Parameter(Mandatory = $true)]$vmResourceGroupName,
    [Parameter(Mandatory = $true)]$vmName,
    [Parameter(Mandatory = $true)]$FileName,
    [Parameter(Mandatory = $false)]$ParameterName,
    [Parameter(Mandatory = $false)]$ParameterValue

)

$vm = Get-AzVM `
    -ResourceGroupName $irtResourceGroupName `
    -Name $VmName

$storageAccountKey = (Get-AzStorageAccountKey `
        -Name $storageAccountName `
        -ResourceGroupName $storageResourceGroupName)[0].Value

$scriptParams = @{
    'ResourceGroupName'  = $vmResourceGroupName
    'VMName'             = $vmName
    'Name'               = $fileName
    'Location'           = $vm.Location
    'StorageAccountName' = $storageAccountName
    'StorageAccountKey'  = $storageAccountKey
    'FileName'           = $fileName
    'ContainerName'      = $containerName
    'Run'                = '{0}' -f $FileName
    #'Run'                = '{0} -{1} {2}' -f $fileName, $ParameterName, $ParameterValue

}

#run command on the vm
Set-AzVMCustomScriptExtension @scriptParams