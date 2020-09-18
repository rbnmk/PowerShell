<#
.SYNOPSIS
    This script can be used on Azure DevOps agents with pwsh. 
    If you have a Key Vault or Storage account with firewall enabled you can use this script.
.DESCRIPTION
    If you have a Key Vault or Storage account with firewall enabled you can use this script.
    This script will whitelist the agent on the Key Vault and Storageaccount firewalls. 
    This can come in handy when using the Azure File Copy Task in Azure DevOps or Adding secrets to the keyvault from Azure DevOps pipelines.
.EXAMPLE
    PS C:\>.\Allow-Hosted-Agent.ps1 -KeyVaultName "kev-we-rbnmk-p-001" -StorageAccountName "stawediagrbnmkp001"
    Get the Public IP Address of the hosted agent, whitelist on given storage account and keyvault.
.EXAMPLE
    PS C:\>.\Allow-Hosted-Agent.ps1 -KeyVaultName "kev-we-rbnmk-p-001"
    Get the Public IP Address of the hosted agent, whitelist on given keyvault.
.EXAMPLE
    PS C:\>.\Allow-Hosted-Agent.ps1 -KeyVaultName "kev-we-rbnmk-p-001" -StorageAccountName "stawediagrbnmkp001" -RemoveACL
    Get the Public IP Address of the hosted agent, remove ACL on given storage account and keyvault.
.EXAMPLE
    PS C:\>.\Allow-Hosted-Agent.ps1 -KeyVaultName "kev-we-rbnmk-p-001" -RemoveACL
    Get the Public IP Address of the hosted agent, remove ACL on given keyvault.
.NOTES
    version 0.1: Released by Robin Makkus, System Engineer @ Macaw
#>

param(
    # Name of the Key Vault
    [Parameter(Mandatory = $false)]
    [string]
    $KeyVaultName,

    # Name of the Storage Account
    [Parameter(Mandatory = $false)]
    [string]
    $StorageAccountName,

    # If provided ACLs will be removed
    [Parameter(Mandatory = $false)]
    [switch]
    $RemoveACL
)

#region functions
Function Get-PublicIpAddress {
    $PublicIP = Invoke-WebRequest `
        -Uri "http://ifconfig.me/ip" `
        -UseBasicParsing

    Write-Verbose "Public IP Address is $PublicIP"

    Return $PublicIP
}
Function AddAclToKeyVault ($KeyVaultName) {

    $PublicIPAddress = Get-PublicIpAddress

    $KeyVaultACL = Get-AzKeyVault `
        -VaultName $KeyVaultName `

    if ($KeyVaultACL.NetworkAcls.IpAddressRanges -match $PublicIPAddress) {

        Write-Verbose "The IP $PublicIPAddress is already allowed on the Key Vault $KeyVaultName"

    }
    else {

        Write-Verbose "Adding $PublicIPAddress to $KeyVaultName ACLs"
        
        Add-AzKeyVaultNetworkRule `
            -VaultName $KeyVaultName `
            -IpAddressRange $PublicIPAddress
    }

    
}
Function RemoveAclFromKeyVault ($KeyVaultName) {

    $PublicIPAddress = Get-PublicIpAddress

    $PublicIPAddress = "$PublicIPAddress/32"

    $KeyVaultACL = Get-AzKeyVault `
        -VaultName $KeyVaultName `

    Write-Verbose "Checking all ACL entries on $KeyVaultName"

    $KeyVaultACL.NetworkAcls.IpAddressRanges | ForEach-Object {

        if ($_ -notmatch $PublicIPAddress) {

            Write-Verbose "Found $_ - will not remove this IP"
        
        }
        else {
            Write-Verbose "Removing IP $PublicIPAddress from $KeyVaultName ACLs"

            Remove-AzKeyVaultNetworkRule `
                -VaultName $KeyVaultName `
                -IpAddressRange $PublicIPAddress
        }

    }
}
Function RemoveAclFromStorageAccount ($StorageAccountName, $StorageAccountResourceGroupName) {

    $PublicIPAddress = Get-PublicIpAddress

    $StorageACL = Get-AzStorageAccountNetworkRuleSet `
        -Name $StorageAccountName `
        -ResourceGroupName $StorageAccountResourceGroupName
    
    Write-Verbose "Checking all ACL entries on $StorageAccountName"

    $StorageACL.IpRules.IPAddressOrRange | ForEach-Object {

        if ($_ -notmatch $PublicIPAddress) {

            Write-Verbose "Found $_ - will not remove this IP"

        }
        else {
            Write-Verbose "Removing IP $PublicIPAddress from $StorageAccountName ACLs"

            Remove-AzStorageAccountNetworkRule `
                -Name $StorageAccountName `
                -ResourceGroupName $StorageAccountResourceGroupName `
                -IPAddressOrRange $PublicIPAddress `
            | Out-Null
        }
    }
}
Function AddAclToStorageAccount ($StorageAccountName, $StorageAccountResourceGroupName) {

    $PublicIPAddress = Get-PublicIpAddress

    $StorageACL = Get-AzStorageAccountNetworkRuleSet `
        -Name $StorageAccountName `
        -ResourceGroupName $StorageAccountResourceGroupName
    
    if ($StorageACL.IpRules.IPAddressOrRange -match $PublicIPAddress) {

        Write-Verbose "The IP $PublicIPAddress is already allowed on the storage account $StorageAccountName"

    }
    else {

        Write-Verbose "Adding $PublicIPAddress to $StorageAccountName ACLs"

        Add-AzStorageAccountNetworkRule `
            -Name $StorageAccountName `
            -ResourceGroupName $StorageAccountResourceGroupName `
            -IPAddressOrRange $PublicIPAddress `
        | Out-Null
    }
}

#endregion functions
 
#region script execution
if ($RemoveACL) {

    if ($StorageAccountName) {

        Write-Verbose "Step 1: Checking Storage Account availabiltity"

        try {
            $StorageAccountResourceGroupName = (Get-AzResource -ResourceName $StorageAccountName).ResourceGroupName

            $StorageAccount = Get-AzStorageAccount `
                -ResourceGroupName $StorageAccountResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like "*was not found. For*") {
                Write-Error "$StorageAccountName could not be found in $StorageAccountResourceGroupName"
            }
            if ($_.Exception.Message -like "*Resource group*could not be found*") {
                Write-Error "$StorageAccountResourceGroupName could not be found."
            }
            else {
                Write-Error $_
            }
        }

        Write-Verbose "Step 2: Adding ACL to Storage Account for Hosted Agent"
        RemoveAclFromStorageAccount -StorageAccountName $StorageAccount.StorageAccountName -StorageAccountResourceGroupName $StorageAccount.ResourceGroupName
    }

    if ($KeyVaultName) {

        Write-Verbose "Step 1: Checking Key Vault availabiltity"

        try {
            $KeyVault = Get-AzKeyVault `
                -VaultName $KeyVaultName `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like "*was not found. For*") {
                Write-Error "$KeyVaultName could not be found in"
            }
            else {
                Write-Error $_
            }
        }

        Write-Verbose "Step 2: Removing ACL to Key Vault for Hosted Agent"

        RemoveAclFromKeyVault -KeyVaultName $KeyVault.VaultName
    }

}
else {
    if ($StorageAccountName) {

        Write-Verbose "Step 1: Checking Storage Account availabiltity"

        try {
            $StorageAccountResourceGroupName = (Get-AzResource -ResourceName $StorageAccountName).ResourceGroupName

            $StorageAccount = Get-AzStorageAccount `
                -ResourceGroupName $StorageAccountResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like "*was not found. For*") {
                Write-Error "$StorageAccountName could not be found in $StorageAccountResourceGroupName"
            }
            if ($_.Exception.Message -like "*Resource group*could not be found*") {
                Write-Error "$StorageAccountResourceGroupName could not be found."
            }
            else {
                Write-Error $_
            }
        }

        Write-Verbose "Step 2: Adding ACL to Storage Account for Hosted Agent"
        AddAclToStorageAccount -StorageAccountName $StorageAccount.StorageAccountName -StorageAccountResourceGroupName $StorageAccount.ResourceGroupName
    }

    if ($KeyVaultName) {

        Write-Verbose "Step 1: Checking Key Vault availabiltity"

        try {
            $KeyVault = Get-AzKeyVault `
                -VaultName $KeyVaultName `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like "*was not found. For*") {
                Write-Error "$KeyVaultName could not be found in"
            }
            else {
                Write-Error $_
            }
        }

        Write-Verbose "Step 2: Adding ACL to Key Vault for Hosted Agent"

        AddAclToKeyVault -KeyVaultName $KeyVault.VaultName
    }
}
#endregion script execution