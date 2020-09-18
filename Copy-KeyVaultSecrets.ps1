<#
.SYNOPSIS
    This script can be used in PowerShell within your current AzContext. 
    If you have secrets in a certain keyvault that you need to copy to another you can use this script.
.DESCRIPTION
    This script can be used in PowerShell within your current AzContext. 
    If you have secrets in a certain keyvault that you need to copy to another you can use this script.
.EXAMPLE
    PS C:\>.\Copy-KeyVaultSecrets.ps1 -SourceVaultName "kev-we-rbnmk-p-001" -DestVaultName "kev-we-rbnmk-p-001"
    Copy all secrets from kev-we-rbnmk-p-001 to kev-we-rbnmk-p-001
.EXAMPLE
    PS C:\>.\Copy-KeyVaultSecrets.ps1 -SourceVaultName "kev-we-rbnmk-p-001" -DestVaultName "kev-we-rbnmk-p-001" -SecretsToCopy @("Secret1", "Secret2")
    Copy Secret1 and Secret2 from kev-we-rbnmk-p-001 to kev-we-rbnmk-p-001
.NOTES
    version 0.1: Released by Robin Makkus, System Engineer @ Macaw
#>

[cmdletbinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$SourceVaultName,
    [Parameter(Mandatory = $true)]
    [string]$DestVaultName,
    [Parameter(Mandatory = $false)]
    [array]$SecretsToCopy = @()
)

if ($SecretsToCopy) {
    Write-Verbose "Copying provided secret names from $SourceVaultName to $DestVaultName"

    $secretNames = (Get-AzKeyVaultSecret -VaultName $sourceVaultName).Name | Where-Object { $_ -in $secretsToCopy }

    $secretNames.foreach{
        Write-Verbose "Copying $_ ..."
        Set-AzKeyVaultSecret -VaultName $destVaultName -Name $_ `
            -SecretValue (Get-AzKeyVaultSecret -VaultName $sourceVaultName -Name $_).SecretValue
        Write-Verbose "Copied $_"
    }
}

else {
    Write-Verbose "Copying provided secret names from $SourceVaultName to $DestVaultName"

    $secretNames = (Get-AzKeyVaultSecret -VaultName $sourceVaultName).Name

    $secretNames.foreach{
        Write-Verbose "Copying $_ ..."
        Set-AzKeyVaultSecret -VaultName $destVaultName -Name $_ `
            -SecretValue (Get-AzKeyVaultSecret -VaultName $sourceVaultName -Name $_).SecretValue
        Write-Verbose "Copied $_"
    }
}

