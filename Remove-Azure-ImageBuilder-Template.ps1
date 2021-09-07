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

Write-Output ("[INFO] Removing any Image Template in resource group {0}" -f $imageResourceGroup);
Write-Output "[WARNING] THIS STEP COULD POTENTIALLY BE REMOVED. DURING INITIAL DEVELOPMENT IT WAS NOT POSSIBLE TO UPDATE TEMPLATES."

Try {
    Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -ImageTemplateName $imageTemplateName | Remove-AzImageBuilderTemplate -ErrorAction Stop
}
catch {
    throw $_
}