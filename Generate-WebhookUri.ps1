[Cmdletbinding()]
param (
    # Name of the automation account
    [Parameter(Mandatory = $True)]
    [string]
    $AutomationAccountName,

    # Name of the resource group where the Automation account lives
    [Parameter(Mandatory = $True)]
    [string]
    $ResourceGroupName
)

function Get-AzCachedAccessToken {
    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }

    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in (Connect-AzAccount) before calling this function."
    }

    $currentAzureContext = Get-AzContext

    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    $token.AccessToken
}

function Get-AutomationAccountWebhookURI {
    param(
        [parameter(Mandatory = $false)][string]$TokenEndpoint = "https://login.windows.net/$TenantID/oauth2/token",
        [parameter(Mandatory = $false)][string]$ARMResource = "https://management.core.windows.net/",
        [parameter(Mandatory = $true)][string]$automationaccountname,
        [parameter(Mandatory = $true)][string]$resourcegroupname,
        [parameter(Mandatory = $false)][string]$APIVersion = "2015-10-31"

    )

    # Create a Access Token for Azure with REST API call

    $Token = Get-AzCachedAccessToken
    $SubscriptionID = (Get-AzContext).Subscription.id


    # URL for generating the webhook URL
    $Uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourcegroupName/providers/Microsoft.Automation/automationAccounts/$automationaccountname/webhooks/generateUri?api-version=$APIVersion"

    # Invoke-RestMethod parameters
    $params = @{
        ContentType = "application/json"
        Headers     = @{"authorization" = "Bearer $($Token)" }
        Method      = "POST"
        URI         = $Uri
    }

    # Make the REST API call
    $WebhookURI = Invoke-RestMethod @params

    # Check the output, and write variable to Azure DevOps pipeline
    
    Return $WebhookURI
}

$WebhookURI = Get-AutomationAccountWebhookURI -automationaccountname $AutomationAccountName -resourcegroupname $ResourceGroupName
Write-Host "Generated Webhook URI: $WebhookURI"
Write-Host "##vso[task.setvariable variable=WebhookURI;]$WebhookURI"