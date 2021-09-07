param(
    [Parameter(Mandatory = $true)]
    [string]
    $imageResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]
    $imageTemplateName
)


Write-Output ("[INFO] Installing Pre Release PS Module: Az.ImageBuilder")
Install-Module -Name "Az.ImageBuilder" -Scope CurrentUser -AllowPrerelease -Force
Import-Module Az.ImageBuilder -Force


Try {
    $ArtifactOutput = (Get-AzImageBuilderRunOutput -ResourceGroupName $imageResourceGroup -ImageTemplateName $imageTemplateName)

    $DeploymentScriptOutputs = @{}
    $DeploymentScriptOutputs['ArtifactId'] = $ArtifactOutput.ArtifactId
}
catch {
    throw $_
}