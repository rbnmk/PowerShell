<#
.SYNOPSIS
Script for creating Snapshots of all disks of a single VM and create a variable for you to use. 
You can use this to create a managed disk by using an other command after creating the snapshot.

.DESCRIPTION
This script is intended to be run from PowerShell in your current AzContext

.EXAMPLE
$Snapshots = .\Create-AzVmSnapshots.ps1 -vmName FILESERVER -resourceGroupName Servers

.EXAMPLE
$osDiskSnapshot = .\Create-AzVmSnapshots.ps1 -vmName FILESERVER -resourceGroupName Servers -osDiskOnly

Created by RBNMK
#>

[CmdletBinding()]
param(
    [parameter(mandatory = $true)] [string] $vmName,
    [parameter(mandatory = $true)] [string] $resourceGroupName,
    [parameter(mandatory = $false)] [switch] $osDiskOnly
    
)

#Remove Azure warning message, see https://aka.ms/azps-changewarnings for more info
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

### Try to get all needed resources and declare variables
$Snapshots = @()

Try {
    $Location = (Get-AzResourceGroup $resourceGroupName -ErrorAction Stop).Location
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Break
}

Try {
    $virtualMachine = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -ErrorAction Stop
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Break
}

$vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
if ($vmStatus.Statuses.displaystatus -match "VM Running") { Write-Warning -Message "The VM is currently running. It is recommended that you turn off the VM first!" }

### Create the snapshot for the OS Disk of the supplied VM
$Snapshot = New-AzSnapshotConfig -SourceUri $virtualMachine.StorageProfile.OsDisk.ManagedDisk.Id -Location $Location -CreateOption copy
$osDiskSnapshot = New-AzSnapshot -Snapshot $Snapshot -SnapshotName "$($virtualMachine.StorageProfile.OsDisk.Name)_snapshot_$(Get-Date -Format filedate) " -ResourceGroupName $resourceGroupName
Write-Host "Creating snapshot.. $($osDiskSnapshot.Name)" -ForegroundColor Green

$Snapshots += $osDiskSnapshot.Name

### Create the snapshot(s) for the Data disks of the supplied VM

if ($osDiskOnly) { 
    Write-Host "Skipping datadisks..." 
}
else {
    if (!($virtualMachine.StorageProfile.DataDisks)) { 
        Write-Host "No datadisks found for $($VirtualMachine.Name)" -ForegroundColor Cyan 
    }
    else {
        foreach ($datadisk in $virtualMachine.StorageProfile.DataDisks) {

            $Snapshot = New-AzSnapshotConfig -SourceUri $datadisk.ManagedDisk.Id-Location $Location -CreateOption copy

            $dataDiskSnapshot = New-AzSnapshot -Snapshot $Snapshot -SnapshotName "$($datadisk.name)_snapshot_$(Get-Date -Format filedate)" -ResourceGroupName $resourceGroupName

            Write-Host "Creating snapshot.. $($dataDiskSnapshot.Name)" -ForegroundColor Green
            $Snapshots += $dataDiskSnapshot.Name
        }
    }
}

$Snapshots

#Enable Azure warning messages again, for more info see: https://aka.ms/azps-changewarnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"