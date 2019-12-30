[Cmdletbinding()]
param(
    [parameter(Mandatory = $true)] [string]$virtualMachineName,
    [parameter(Mandatory = $true)] [string]$VMSize,
    [parameter(Mandatory = $true)] [string]$virtualNetworkName,
    [parameter(Mandatory = $true)] [string]$virtualNetworkResourceGroupName,
    [parameter(Mandatory = $true)] [string]$Location,
    [parameter(Mandatory = $true)] [string]$osDiskName,
    [parameter(Mandatory = $true)] [string]$resourceGroupName
)

#Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig `
    -VMName $virtualMachineName `
    -VMSize $VMSize

$disk = Get-AzDisk `
    -DiskName $osDiskName

#Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
$VirtualMachine = Set-AzVMOSDisk `
    -VM $VirtualMachine `
    -ManagedDiskId $disk.Id `
    -CreateOption Attach `
    -Windows

#Add provided data disks
Foreach ($DataDisk in $DataDisks) { 

    $dd = Get-AzDisk `
        -DiskName $DataDisk.Name `
        -ResourceGroupName $DataDisk.ResourceGroupName

    $VirtualMachine = Set-AzVMDataDisk `
        -VM $VirtualMachine `
        -ManagedDiskId $dd.Id
}

#Create a public IP for the VM
$publicIp = New-AzPublicIpAddress `
    -Name "pip-$($VirtualMachineName.ToLower())" `
    -ResourceGroupName $resourceGroupName `
    -Location $snapshot.Location `
    -AllocationMethod Dynamic

#Get the virtual network where virtual machine will be hosted
$vnet = Get-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $virtualNetworkResourceGroupName

# Create NIC in the first subnet of the virtual network
$nic = New-AzNetworkInterface `
    -Name "nic-$($VirtualMachineName.ToLower())" `
    -ResourceGroupName $resourceGroupName `
    -Location $Location `
    -SubnetId if (!($subnet)) { $vnet.Subnets[0].Id } else { $SubnetId }
-PublicIpAddressId $publicIp.Id

$VirtualMachine = Add-AzVMNetworkInterface `
    -VM $VirtualMachine `
    -Id $nic.Id

#Create the virtual machine with Managed Disk
New-AzVM `
    -VM $VirtualMachine `
    -ResourceGroupName $resourceGroupName `
    -Location $Location