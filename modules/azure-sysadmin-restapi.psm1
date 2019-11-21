<#
.SYNOPSIS
This module can be used to retrieve information from Azure using the REST API

.DESCRIPTION
Long description

.PARAMETER TenantID
The TenantID is also known as the DirectoryID in Azure Active Directory

.PARAMETER ClientID
The ClientID is the ApplicationID from your Service Principal Account in Azure Active Directory

.PARAMETER ClientSecret
The ClientSecret is the secret created within the Service Principal Account in Azure Active Directory

.PARAMETER TokenEndpoint
Parameter description

.PARAMETER Resource
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>

function Get-AccessToken {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $true)][ValidateSet("https://vault.azure.net", "https://management.core.windows.net/", "https://api.loganalytics.io")][string]$Resource

    )

    # Create the body in JSON
    $Body = @{
        'resource'      = $Resource
        'client_id'     = $ClientID
        'grant_type'    = 'client_credentials'
        'client_secret' = $ClientSecret
    }

    # Create the REST API Call
    $params = @{
        ContentType = 'application/x-www-form-urlencoded'
        Headers     = @{'accept' = 'application/json' }
        Body        = $Body
        Method      = 'Post'
        URI         = $TokenEndpoint
    }

    # Get and return the token
    $token = Invoke-RestMethod @params
    Return $Token
}
function Get-QueryFromLogAnalytics {
    Param(
        [Parameter(Mandatory = $True)][string]$TenantID,
        [Parameter(Mandatory = $True)][string]$ClientID,
        [Parameter(Mandatory = $True)][string]$ClientSecret,
        [Parameter(Mandatory = $False)][string]$loginURL = "https://login.microsoftonline.com/$TenantId/oauth2/token",
        [Parameter(Mandatory = $False)][string]$Resource = "https://api.loganalytics.io",
        [Parameter(Mandatory = $True)][string]$WorkspaceName,
        [Parameter(Mandatory = $True)][string]$WorkspaceID,
        [Parameter(Mandatory = $True)][string]$Query
    )

    Write-Output ""
    Write-Host "* Creating an Access Token for Azure, using REST API" -ForegroundColor Yellow

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource
    $Uri = "https://api.loganalytics.io/v1/workspaces/{0}/query" -f $WorkspaceID

    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Post"
        URI         = $URI
        body        = @{query = $Query } | ConvertTo-Json
    }

    Write-Output ""
    Write-Host "* Invoking query to log analytics via REST API" -ForegroundColor Yellow

    $webresults = Invoke-RestMethod @Params

    $resultsTable = $webresults
    foreach ($table in $resultsTable.Tables) {
        $count += $table.Rows.Count
    }
    $results = New-Object object[] $count
    $i = 0;
    foreach ($table in $resultsTable.Tables) {
        foreach ($row in $table.Rows) {
            # Create a dictionary of properties
            $properties = @{ }
            for ($columnNum = 0; $columnNum -lt $table.Columns.Count; $columnNum++) {
                $properties[$table.Columns[$columnNum].name] = $row[$columnNum]
            }
            $results[$i] = (New-Object PSObject -Property $properties)
            $null = $i++
        }
    }
    Write-Output ""
    Write-Host "* Successfully queried log analytics via REST API" -ForegroundColor Yellow
    Return $results
}
function Get-UpdateJobsFromAutomation {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$automationaccountname,
        [parameter(Mandatory = $true)][string]$ResourcegroupName,
        [parameter(Mandatory = $false)][string]$APIVersion = "2015-10-31"

    )
    $Date = Get-Date
    $CurrentMonth = $Date.Month
    $CurrentYear = $Date.Year
    $CurrentMonthYear = "$CurrentMonth" + "-" + "$CurrentYear"

    #Create a Access Token for Azure with REST API call

    # Get a token, based on the REST API call
    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    
    #Get the automation jobs from the automation account
  

    $Uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourcegroupName/providers/Microsoft.Automation/automationAccounts/$automationaccountname/jobSchedules?api-version=$APIVersion"

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.Access_Token)" }
        Method      = "Get"
        URI         = $Uri
    }

    # Make the REST API call
    $AutomationJobSchedules = Invoke-RestMethod @params

    # Check the output
    $UpcomingAutomationJobs = $AutomationJobSchedules.value.properties.schedule | Where-Object { $_.Name -match "$CurrentMonthYear" }

    $UpcomingJobsTable = @()
    ForEach ($Job in $UpcomingAutomationJobs) {

        $UpcomingJobDate = $Job.name.Split("-")[3] + "-" + $Job.name.Split("-")[4] + "-" + $Job.name.Split("-")[5]
        $UpcomingJobCustomer = $Job.name.Split("-")[0]
        $UpcomingJobPhase = $Job.name.Split("_""-")[6] + " " + $Job.name.Split("_""-")[7]
        $UpcomingJobOTAP = $Job.name.Split("-")[1]

        $UpcomingJobsTable += [PSCustomObject]@{
            Date     = $UpcomingJobDate
            Customer = $UpcomingJobCustomer
            OTAP     = $UpcomingJobOTAP
            Phase    = $UpcomingJobPhase
        }
    }
    Return $UpcomingJobsTable
}
function Get-AutomationAccountJobs {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$ARMResource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$automationaccountname,
        [parameter(Mandatory = $true)][string]$ResourcegroupName,
        [parameter(Mandatory = $false)][string]$APIVersion = "2015-10-31"

    )

    # Create a Access Token for Azure with REST API call

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource


    # Get the automation jobs from the automation account


    $Uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourcegroupName/providers/Microsoft.Automation/automationAccounts/$automationaccountname/jobS?api-version=$APIVersion"

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.Access_Token)" }
        Method      = "Get"
        URI         = $Uri
    }

    # Make the REST API call
    $AutomationJobs = Invoke-RestMethod @params

    # Check the output
    Return $AutomationJobs
}
Function Get-KeyVaultSecretVersion {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://vault.azure.net",
        [parameter(Mandatory = $true)][string]$KeyVaultName,
        [parameter(Mandatory = $false)][string]$KeyVaultSecretName
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://$keyVaultName.vault.azure.net/secrets/$KeyVaultSecretName/versions?maxresults=1&api-version=7.0"

    Write-Host "$($token.access_token)"

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    # Make the REST API call
    $KeyVaultSecretVersion = Invoke-RestMethod @params
    $KeyVaultSecretVersionFinal = $KeyVaultSecretVersion.value.id.Split("/")
    Return $KeyVaultSecretVersionFinal[5]
}
Function Get-KeyVaultSecret {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://vault.azure.net",
        [parameter(Mandatory = $true)][string]$KeyVaultName,
        [parameter(Mandatory = $true)][string]$KeyVaultSecretName
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource "https://vault.azure.net"

    $KeyVaultSecretVersion = Get-KeyVaultSecretVersion -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -KeyVaultName $KeyVaultName -KeyVaultSecretName $KeyVaultSecretName

    $uri = "https://{0}.vault.azure.net/secrets/{1}/{2}?api-version=7.0" -f $KeyVaultName, $KeyVaultSecretName, $KeyVaultSecretVersion

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    # Make the REST API call
    $KeyVaultSecret = Invoke-RestMethod @params
    Return $KeyVaultSecret
}
Function Get-KeyVaultSecrets {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://vault.azure.net",
        [parameter(Mandatory = $true)][string]$KeyVaultName
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource "https://vault.azure.net"

    $uri = "https://{0}.vault.azure.net/secrets?api-version=7.0" -f $KeyVaultName

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    # Make the REST API call
    $KeyVaultSecrets = Invoke-RestMethod @params
    Return $KeyVaultSecrets
}
Function Set-KeyVaultSecret {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://vault.azure.net",
        [parameter(Mandatory = $true)][string]$KeyVaultName,
        [parameter(Mandatory = $true)][string]$KeyVaultSecretName,
        [parameter(Mandatory = $true)][string]$KeyVaultSecret
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource "https://vault.azure.net"

    $uri = "https://{0}.vault.azure.net/secrets/{1}?api-version=7.0" -f $KeyVaultName, $KeyVaultSecretName

    # Create the request body
    $body = @{
        'value' = $KeyVaultSecret
    }

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "PUT"
        URI         = $Uri
        body        = $body | ConvertTo-Json
    }

    # Make the REST API call
    $KeyVaultSecret = Invoke-RestMethod @params
    Return $KeyVaultSecret
}
function New-ResourceGroup {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$ResourceGroupName,
        [parameter(Mandatory = $true)][string]$Location
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}?api-version=2019-05-10" -f $SubscriptionID, $ResourceGroupName

    #Create the body
    $Body = @{
        'location' = $Location
    }

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Put"
        URI         = $Uri
        Body        = $Body | ConvertTo-Json
    }
    $ResourceGroup = Invoke-RestMethod @Params
    Return $ResourceGroup
}
function Get-ResourceGroups {
    param(
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$SubscriptionID
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/resourcegroups?api-version=2019-05-10" -f $SubscriptionID

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }
    $ResourceGroups = Invoke-RestMethod @Params
    Return $ResourceGroups
}
Function Get-NetworkSecurityGroups {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/"
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Network/networkSecurityGroups?api-version=2019-06-01" -f $SubscriptionID

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    $Nsgs = Invoke-RestMethod @params
    Return $Nsgs

}
Function Get-NsgSecurityRules {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$ResourceGroupName,
        [parameter(Mandatory = $true)][string]$NetworkSecurityGroupName
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/networkSecurityGroups/{2}/securityRules?api-version=2019-06-01" -f $SubscriptionID, $ResourceGroupName, $NetworkSecurityGroupName

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    $NsgSecurityRules = Invoke-RestMethod @params

    $nsgRulesOverview = @()
    foreach ($nsgRule in $NsgSecurityRules.value) {

        $nsgRuleName = $nsgRule.Name
        $nsgRuleProperties = $nsgRule.properties
        $nsgRulesOverview += [pscustomobject] @{
            priority                   = $nsgRuleProperties.priority
            nsgRuleName                = $NsgRuleName
            description                = $nsgRuleProperties.description
            access                     = $nsgRuleProperties.access
            direction                  = $nsgRuleProperties.direction
            protocol                   = $NsgRuleProperties.protocol
            sourceAddressPrefix        = $nsgRuleProperties.sourceAddressPrefix
            sourceAddressPrefixes      = ($nsgRuleProperties.sourceAddressPrefixes -join ', ')
            sourcePortRange            = $NsgRuleProperties.sourcePortRange
            sourcePortRanges           = ($nsgRuleProperties.sourcePortRanges -join ', ')
            destinationPortRange       = $nsgRuleProperties.destinationPortRange
            destinationPortRanges      = ($nsgRuleProperties.destinationPortRanges -join ', ')
            destinationAddressPrefix   = $nsgRuleProperties.destinationAddressPrefix
            destinationAddressPrefixes = ($nsgRuleProperties.destinationAddressPrefixes -join ', ')

        }
    }
    Return $NsgRulesOverview
}
Function Get-VirtualNetworks {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/"
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Network/virtualNetworks?api-version=2019-06-01" -f $SubscriptionID

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    $VirtualNetworks = Invoke-RestMethod @params
    Return $VirtualNetworks
}

Function Get-VirtualMachinesInResourceGroup {
    param(
        [parameter(Mandatory = $true)][string]$SubscriptionID,
        [parameter(Mandatory = $true)][string]$TenantID,
        [parameter(Mandatory = $true)][string]$ClientID,
        [parameter(Mandatory = $true)][string]$ClientSecret,
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$Resource = "https://management.core.windows.net/",
        [parameter(Mandatory = $false)][string]$ResourceGroupName
    )

    $Token = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -Resource $Resource

    $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualMachines?api-version=2018-06-01" -f $SubscriptionID, $ResourceGroupName

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($token.access_token)" }
        Method      = "Get"
        URI         = $Uri
    }

    $VirtualMachines = Invoke-RestMethod @params
    Return $VirtualMachines
}

Function Get-RestApiSecrets {

    $client = "hfg"
    $KeyVaultName = "rbnmkvault"
    $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName
    $clientsecrets = $secrets | Where-Object { $_.Name -match "$client" }

    $RestApiSecrets = @()

    Foreach ($Secret in $clientsecrets) {

        $TempSecret = Get-AzKeyVaultSecret -VaultName $Secret.VaultName -Name $Secret.Name

        $RestApiSecrets += [PSCustomObject] @{
            AppId          = ($TempSecret | Where-Object { $_.Name -match "appid" }).SecretValueText
            Secret         = ($TempSecret | Where-Object { $_.Name -match "secret" }).SecretValueText
            SubscriptionId = ($TempSecret | Where-Object { $_.Name -match "subscription" }).SecretValueText
            TenantId       = ($TempSecret | Where-Object { $_.Name -match "tenant" }).SecretValueText
            WorkspaceId    = ($TempSecret | Where-Object { $_.Name -match "workspaceid" }).SecretValueText
        }

    }
    $RestApiSecrets

}