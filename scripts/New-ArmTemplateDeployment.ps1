<#
.SYNOPSIS
Script to easily deploy an local arm template with parameter file to an Resource Group in your current AzContext.

.DESCRIPTION
This script is intended to be run from PowerShell in your current AzContext

.EXAMPLE
.\New-ArmTemplateDeployment.ps1 -resourceGroupName rg-we-ivm-p -location WestEurope -TemplateFile "template.json"-TemplateParameterFile "parameters.json"

Created by RBNMK
#>
[CmdletBinding()]
param(
  [parameter(mandatory = $true)] [string] $resourceGroupName,
  [parameter(mandatory = $true)] [string] $location,
  [parameter(mandatory = $true)] [string] $TemplateFile,
  [parameter(mandatory = $true)] [string] $TemplateParameterFile
    
)

Try {
  New-AzResourceGroup -Name $resourceGroupName `
    -Location $location `
    -ErrorAction Stop
}
catch {
  Write-Warning "$($Error[0].Exception.Message)"
  Break
}

Try {
  New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -Name PowerShellDeploy$(Get-Random) `
    -TemplateFile $TemplateFile `
    -TemplateParameterFile $TemplateParameterFile `
    -ErrorAction Stop
}
catch {
  Write-Warning "$($Error[0].Exception.Message)"
  Break
}