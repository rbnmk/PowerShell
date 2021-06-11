#Get Parameters
$registrationKey = $args[0]

#Set Variables
$RootFolder = "C:\Packages\Plugins\"
$WVDAgentInstaller = $RootFolder + "WVD-Agent.msi"
$WVDBootLoaderInstaller = $RootFolder + "WVD-BootLoader.msi"

<#
.DESCRIPTION
Runs defined msi's to deploy RDAgent and Bootloader
.PARAMETER programDisplayName
.PARAMETER argumentList
.PARAMETER msiOutputLogPath
.PARAMETER isUninstall
.PARAMETER msiLogVerboseOutput
#>
function RunMsiWithRetry {
    param(
        [Parameter(mandatory = $true)]
        [string]$programDisplayName,

        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$argumentList, 

        [Parameter(mandatory = $true)]
        [string]$msiOutputLogPath,

        [Parameter(mandatory = $false)]
        [switch]$isUninstall,

        [Parameter(mandatory = $false)]
        [switch]$msiLogVerboseOutput
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    if ($msiLogVerboseOutput) {
        $argumentList += "/l*vx+ ""$msiOutputLogPath""" 
    }
    else {
        $argumentList += "/l*+ ""$msiOutputLogPath"""
    }

    $retryTimeToSleepInSec = 30
    $retryCount = 0
    $sts = $null
    do {
        $modeAndDisplayName = ($(if ($isUninstall) { "Uninstalling" } else { "Installing" }) + " $programDisplayName")

        if ($retryCount -gt 0) {
            Log  "Retrying $modeAndDisplayName in $retryTimeToSleepInSec seconds because it failed with Exit code=$sts This will be retry number $retryCount"
            Start-Sleep -Seconds $retryTimeToSleepInSec
        }

        Log ( "$modeAndDisplayName" + $(if ($msiLogVerboseOutput) { " with verbose msi logging" } else { "" }))


        $processResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $argumentList -Wait -PassThru
        $sts = $processResult.ExitCode

        $retryCount++
    } 
    while ($sts -eq 1618 -and $retryCount -lt 20) 

    if ($sts -eq 1618) {
        Log  "Stopping retries for $modeAndDisplayName. The last attempt failed with Exit code=$sts which is ERROR_INSTALL_ALREADY_RUNNING"
        throw "Stopping because $modeAndDisplayName finished with Exit code=$sts"
    }
    else {
        Log "$modeAndDisplayName finished with Exit code=$sts"
    }

    return $sts
} 

<#
.DESCRIPTION
Uninstalls any existing RDAgent BootLoader and RD Infra Agent installations and then installs the RDAgent BootLoader and RD Infra Agent using the specified registration token.
.PARAMETER AgentInstallerFolder
Required path to MSI installer file
.PARAMETER AgentBootServiceInstallerFolder
Required path to MSI installer file
#>
function InstallRDAgents {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentInstallerFolder,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentBootServiceInstallerFolder,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistrationToken,
    
        [Parameter(mandatory = $false)]
        [switch]$EnableVerboseMsiLogging
    )

    $ErrorActionPreference = "Stop"

    Log  "Boot loader folder is $AgentBootServiceInstallerFolder"
    $AgentBootServiceInstaller = $AgentBootServiceInstallerFolder + '\WVD-BootLoader.msi'

    Log  "Agent folder is $AgentInstallerFolder"
    $AgentInstaller = $AgentInstallerFolder + '\WVD-Agent.msi'

    if (!$RegistrationToken) {
        throw "No registration token specified"
    }

    $msiNamesToUninstall = @(
        @{ msiName = "Remote Desktop Services Infrastructure Agent"; displayName = "RD Infra Agent"; logPath = "$AgentInstallerFolder\AgentUninstall.txt" }, 
        @{ msiName = "Remote Desktop Agent Boot Loader"; displayName = "RDAgentBootLoader"; logPath = "$AgentInstallerFolder\AgentBootLoaderUnInstall.txt" }
    )
    
    foreach ($u in $msiNamesToUninstall) {
        while ($true) {
            try {
                $installedMsi = Get-Package -ProviderName msi -Name $u.msiName
            }
            catch {
                if ($PSItem.FullyQualifiedErrorId -eq "NoMatchFound,Microsoft.PowerShell.PackageManagement.Cmdlets.GetPackage") {
                    break
                }
    
                throw;
            }
    
            $oldVersion = $installedMsi.Version
            $productCodeParameter = $installedMsi.FastPackageReference
    
            RunMsiWithRetry -programDisplayName "$($u.displayName) $oldVersion" -isUninstall -argumentList @("/x $productCodeParameter", "/quiet", "/qn", "/norestart", "/passive") -msiOutputLogPath $u.logPath -msiLogVerboseOutput:$EnableVerboseMsiLogging
        }
    }

    Log  "Installing RD Infra Agent on VM $AgentInstaller"
    RunMsiWithRetry -programDisplayName "RD Infra Agent" -argumentList @("/i $AgentInstaller", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken") -msiOutputLogPath "C:\Users\AgentInstall.txt" -msiLogVerboseOutput:$EnableVerboseMsiLogging

    Log  "Installing RDAgent BootLoader on VM $AgentBootServiceInstaller"
    RunMsiWithRetry -programDisplayName "RDAgent BootLoader" -argumentList @("/i $AgentBootServiceInstaller", "/quiet", "/qn", "/norestart", "/passive") -msiOutputLogPath "C:\Users\AgentBootLoaderInstall.txt" -msiLogVerboseOutput:$EnableVerboseMsiLogging

    $bootloaderServiceName = "RDAgentBootLoader"
    $startBootloaderRetryCount = 0
    while ( -not (Get-Service $bootloaderServiceName -ErrorAction SilentlyContinue)) {
        $retry = ($startBootloaderRetryCount -lt 6)
        $msgToWrite = "Service $bootloaderServiceName was not found. "
        if ($retry) { 
            $msgToWrite += "Retrying again in 30 seconds, this will be retry $startBootloaderRetryCount" 
            Log  $msgToWrite
        } 
        else {
            $msgToWrite += "Retry limit exceeded" 
            Log $msgToWrite
            throw $msgToWrite
        }
            
        $startBootloaderRetryCount++
        Start-Sleep -Seconds 30
    }

    Log  "Starting service $bootloaderServiceName"
    Start-Service $bootloaderServiceName
}

#Configure logging
function log {
    param([string]$message)
    "`n`n$(Get-Date -f o)  $message" 
}


$CheckRegistry = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue
$CheckEventlog = Get-Eventlog -LogName Application -Newest 250 | Where-Object { $_.Source -eq "WVD-Agent" -and $_.Message -match "ENDPOINT_NOT_FOUND" }

Log "Checking whether VM was Registered with RDInfraAgent and if connection is healthy!"

if ($CheckRegistry -and !$CheckEventlog) {
    Log "VM was already registered with RDInfraAgent and is healthy, script execution was stopped"
}
else {
    #Create Folder structure
    if (!(Test-Path -Path $RootFolder)) { New-Item -Path $RootFolder -ItemType Directory }

    #Download all source file async and wait for completion
    log  "Download WVD Agent & bootloader"
    $files = @(
        @{url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"; path = $WVDAgentInstaller }
        @{url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"; path = $WVDBootLoaderInstaller }
    )
    $workers = foreach ($f in $files) { 
        $wc = New-Object System.Net.WebClient
        Write-Output $wc.DownloadFileTaskAsync($f.url, $f.path)
    }
    $workers.Result

    Log "Calling functions to install agent and bootloader"
    InstallRDAgents -AgentBootServiceInstallerFolder $RootFolder -AgentInstallerFolder $RootFolder -RegistrationToken $registrationKey -EnableVerboseMsiLogging:$false

    Log "Finished"
}