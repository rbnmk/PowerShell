<#
.SYNOPSIS
Script for to convert a .pfx certificate file to base64 and add it as a secret to the KeyVault.

.DESCRIPTION
This script is intended to be run from PowerShell in your current AzContext or inside your Azure DevOps to use in your ARM templates where you need to provide a base64. You can pull this information inside the deployment, from the keyvault.

.EXAMPLE
.\Create-ManagedDisksFromSnapshots.ps1 -Snapshots $Snapshots -resourceGroupName snapshotrg

Created by RBNMK
#>

param(
    [Parameter(Mandatory = $True)][string]$keyVaultName,
    [Parameter(Mandatory = $True)][string]$pfxFile,
    [Parameter(Mandatory = $True)][securestring]$pfxPassword
    
)

#Convert the PFX
try {
    $pfx_file = Get-Content $pfxFile `
        -Encoding Byte `
        -ErrorAction Stop
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Break
}

$base64 = [System.Convert]::ToBase64String($pfx_file)

#Convert the passwords to securestring
$secretvalue = ConvertTo-SecureString $base64 `
    -AsPlainText `
    -Force `

$secretvalue2 = ConvertTo-SecureString $pfxPassword `
    -AsPlainText `
    -Force `

#Add the values to the keyvault
try {
    $secret = Set-AzKeyVaultSecret `
        -VaultName $KeyVaultName `
        -Name 'pfxCertificateBase64' `
        -SecretValue $secretvalue `
        -ErrorAction Stop

    Write-Host "Successfully added $($Secret.Name) to Keyvault: $keyVaultName" -ForegroundColor Green
    
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Return
}

try {
    $secret2 = Set-AzKeyVaultSecret `
        -VaultName $KeyVaultName `
        -Name 'pfxCertificatePassword' `
        -SecretValue $secretvalue2 `
        -ErrorAction Stop

    Write-Host "Successfully added $($Secret2.Name) to Keyvault: $keyVaultName" -ForegroundColor Green
}
catch {
    Write-Warning "$($Error[0].Exception.Message)"
    Return
}

Write-Host "Script completed" -ForegroundColor Green