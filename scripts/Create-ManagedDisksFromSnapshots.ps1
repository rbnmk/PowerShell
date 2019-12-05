<#
.SYNOPSIS
Script for creating Managed Disks by supplying the name of one or more snapshots. Can be used in conjunction with Create-AzVmSnapshots.

.DESCRIPTION
This script is intended to be run from PowerShell in your current AzContext.

.EXAMPLE
.\Create-ManagedDisksFromSnapshots.ps1 -Snapshots $Snapshots -resourceGroupName snapshotrg

.EXAMPLE
.\Create-ManagedDisksFromSnapshots.ps1 -Snapshots FILESERVER_SNAPSHOT -resourceGroupName snapshotrg

.EXAMPLE
https://github.com/rbnmk/posh/blob/master/scripts/Create-ManagedDisksFromSnapshots.ps1

Created by RBNMK
#>

[Cmdletbinding()]
param (
    [parameter(mandatory = $true)]$Snapshots,
    [parameter(mandatory = $true)]$resourceGroupName
)

Try {
    Get-AzResourceGroup $resourceGroupName -ErrorAction Stop
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Break
}


foreach ($existingSnapshot in $Snapshots) {

    Try {
        $Snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $existingSnapshot -ErrorAction Stop
    }
    catch {
        Write-Warning "$($Error[0].Exception.Message)"
        Break
    }

    Try {
        $diskConfig = New-AzDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy -ErrorAction Stop
    }
    catch {
        Write-Warning "$($Error[0].Exception.Message)"
        Break
    }
    

    $diskName = Read-Host -Prompt "Enter the required diskname for the snapshot $($Snapshot.Name)"
    #$diskName = $createdsnapshot.Split("_")[0]
    #$diskName = $DiskName.Replace("", "")

    $managedDisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $DiskName

    Write-Host "Created $($managedDisk.Name)" -ForegroundColor Green

}