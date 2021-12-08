param(
    [string] [Parameter(Mandatory = $true)] $keyVaultName,
    [string] [Parameter(Mandatory = $true)] $virtualMachineName
)

$KeyName = $virtualMachineName + 'EncryptionKey'

$Key = Add-AzKeyVaultKey -VaultName $keyVaultName -Name $KeyName -Destination 'Software'

if ($env:AZ_SCRIPTS_AZURE_ENVIRONMENT) {
    $DeploymentScriptOutputs['vmVaultEncryptionId'] = $key.Id
}
else {
    Write-Host ("##[INFO] New KEK Created in {0} for {1} with name: {2}" -f $keyVaultName, $virtualMachineName, $KeyName)
    Write-Host ("##[INFO] KEK Id: {0})" -f $key.Id)
}