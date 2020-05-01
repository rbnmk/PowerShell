[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]$MSIDownloadURL = "https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_4.0.7184.1%20(64-bit).msi",
    [Parameter(Mandatory = $false)]$MSIDownloadPath = "C:\Temp",
    [Parameter(Mandatory = $false)]$MSIFileName = "IntegrationRuntime.msi",
    [Parameter(Mandatory = $false)]$MSIDownloadFullPath = "$MSIDownloadPath\$MSIFileName",
    [Parameter(Mandatory = $true)]$GatewayKey
)

#region MSI install
#Create temporary folder if it does not exist
if (-not (Test-Path $MSIDownloadPath)) {
    New-Item -Path $MSIDownloadPath -ItemType Directory | Out-Null
}

#Remove previous file
$FileAlreadyExists = Get-ChildItem -Path $MSIDownloadPath | Where-Object { $_.Name -match $MSIFileName }
if ($FileAlreadyExists) { $FileAlreadyExists | Remove-Item -Force }

#Download to the temporary folder
if (!($MSIDownloadURL)) {
    Write-Host "Not downloading file, installing $MSIFilename from $MSIDownloadPath"
}
else {
    Write-Host "Downloading the MSI... $MSIDownloadPath on $ENV:COMPUTERNAME" -ForegroundColor Cyan
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $MSIDownloadURL -UseBasicParsing -OutFile $MSIDownloadFullPath | Out-Null
    $ProgressPreference = 'Continue'
}

#Install the MSI
Write-Host "Installing the MSI... on $ENV:COMPUTERNAME" -ForegroundColor Cyan
Set-Location -Path $MSIDownloadPath
Start-Process msiexec.exe -Wait -ArgumentList "/I Integrationruntime.msi /qn"
Write-Host "Installing MSI on $ENV:COMPUTERNAME completed!" -ForegroundColor Green

#endregion MSI install

#region configure IRT
$IntegrationService = Get-Service | Where-Object { $_.Name -match "DIAHostService" }
If ($IntegrationService.Status -eq "Stopped") { Start-Service $IntegrationService.Name }
Set-Location "C:\Program Files\Microsoft Integration Runtime"
$IntegrationRuntimeScriptLocation = Get-ChildItem -Recurse | Where-Object { $_.Name -like "*.ps1" -and $_.Name -match "Register" }
Set-Location $IntegrationRuntimeScriptLocation.Directory
.\RegisterIntegrationRuntime.ps1 -gatewayKey $GatewayKey
#endregion configure IRT
