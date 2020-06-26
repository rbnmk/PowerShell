[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]$PBIDownloadURL = "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe",
    [Parameter(Mandatory = $false)]$DownloadPath = "C:\Temp",
    [Parameter(Mandatory = $false)]$PBIFileName = "PBIDesktopSetup_x64.exe",
    [Parameter(Mandatory = $false)]$PBIDownloadFullPath = "$DownloadPath\$PBIFileName"
)

#region EXE install
#Create temporary folder if it does not exist
if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory | Out-Null
}

#Remove previous file
$FileAlreadyExists = Get-ChildItem -Path $DownloadPath | Where-Object { $_.Name -match $PBIFileName }
if ($FileAlreadyExists) { $FileAlreadyExists | Remove-Item -Force }

#Download to the temporary folder
if (!($PBIDownloadURL)) {
    Write-Host "Not downloading new file, installing $PBIFilename from $DownloadPath"
}
else {
    Write-Host "Downloading the installer... $DownloadPath on $ENV:COMPUTERNAME" -ForegroundColor Cyan
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $PBIDownloadURL -UseBasicParsing -OutFile $PBIDownloadFullPath | Out-Null
    $ProgressPreference = 'Continue'
}

#Install the MSI
Write-Host "Installing PBI... on $ENV:COMPUTERNAME" -ForegroundColor Cyan
Set-Location -Path $DownloadPath
Start-Process ".\PBIDesktopSetup_x64.exe" -Wait -ArgumentList "-quiet ACCEPT_EULA=1 INSTALLDESKTOPSHORTCUT=1 DISABLE_UPDATE_NOTIFICATION=1 LANGUAGE=en-US"
Write-Host "Installing PBI on $ENV:COMPUTERNAME completed!" -ForegroundColor Green
#endregion MSI install