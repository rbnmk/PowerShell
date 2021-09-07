param(
    [Parameter(Mandatory = $true)]
    [string]
    $imageResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]
    $imageTemplateName
)

Write-Output ("[INFO] Installing Pre Release PS Module: Az.ImageBuilder");
Install-Module -Name "Az.ImageBuilder" -Scope CurrentUser -AllowPrerelease -Force
Import-Module Az.ImageBuilder -Force

Try {

    Write-Output ("[INFO] Looking for 1 Image template in Resource Group: {0}" -f $imageResourceGroup);

    $ImageTemplate = Get-AzImageBuilderTemplate `
        -ResourceGroupName $imageResourceGroup `
        -Name $imageTemplateName | Where-Object { $_.ProvisioningState -eq 'Succeeded' }

    if (($imageTemplateName | Measure-Object).Count -gt 1) { Write-Output "[WARNING] More than 1 Image Template was found. We are stopping script execution"; break }

    Write-Output ("[INFO] Found Image Template with name: {0}" -f $ImageTemplate.Name);
    Write-Output ("[INFO] Executing build with Azure Image Builder");
    Invoke-AzResourceAction `
        -ResourceName $ImageTemplate.Name `
        -ResourceGroupName $imageResourceGroup `
        -ResourceType Microsoft.VirtualMachineImages/imageTemplates `
        -ApiVersion "2020-02-14" `
        -Action Run `
        -Force


    $StartTime = Get-Date
    $MaximumTimeSpan = New-TimeSpan -Hours 4

    New-TimeSpan -Start $StartTime -End (Get-Date)
    $Statuses = "Canceling", "Failed", "Succeeded"

    do {
        Write-Output ("[INFO] Checking build status for: {0}" -f $ImageTemplate.Name);

        $getStatus = $(Get-AzImageBuilderTemplate `
                -ResourceGroupName $imageResourceGroup `
                -Name $imageTemplate.Name)

        Write-Output ("[INFO] LastRunStatusRunstate: {0}" -f $getStatus.LastRunStatusRunState );
        Write-Output ("[INFO] LastRunStatusRunSubState: {0}" -f $getStatus.LastRunStatusRunSubState);

        if (![string]::IsNullOrEmpty($getStatus.LastRunStatusMessage)) { Write-Output ("[INFO] LastRunStatusMessage: {0}" -f $getStatus.LastRunStatusMessage ); }

        

        $ExceededTimeSpan = ((New-TimeSpan -Start $StartTime -End (Get-Date)) -gt $MaximumTimeSpan)
        $LastRunState = $getStatus.LastRunStatusRunState
        Start-Sleep -Seconds 60
    } until ($LastRunState -in $Statuses -or $ExceededTimeSpan)


    if ($ExceededTimeSpan) {
        Write-Output ("[WARNING] The build timed out - however it could've been successfull, quitting pipeline");
        exit 0
    }

    switch ($LastRunState) {
        'Succeeded' {
            Write-Output ("[INFO] Build was executed successfully!")

            $Output = Get-AzImageBuilderRunOutput `
                -ImageTemplateName $ImageTemplate.Name `
                -ResourceGroupName $imageResourceGroup
    
            $ArtifactId = $Output.ArtifactId

            ### Azure DevOps
            Write-Output ("[INFO] Storing ImageTemplate in variable: ArtifactId for future reference")    
            Write-Output ("[INFO] Storing ImageTemplate in variable: $ArtifactId")    
            Write-Host  "##vso[task.setvariable variable=ArtifactIdOutput;isOutput=true]$ArtifactId"

            ### Bicep/ARM Deployment script
            $DeploymentScriptOutputs = @{}
            $DeploymentScriptOutputs['ArtifactId'] = $ArtifactId
            exit 0
        }
        'Failed' {
            Write-Output ("[ERROR] Image build failed please look in the packer logs for details!")

            $Output = Get-AzImageBuilderRunOutput `
                -ImageTemplateName $ImageTemplate.Name `
                -ResourceGroupName $imageResourceGroup
            exit 1
        }
        'Canceling' {
            Write-Output ("[WARNING] The build was canceled, quitting pipeline");
            exit 0
        }
        default {
            Write-Output ("[ERROR] Something unexpected happened. Quitting..");
            exit 1
        }
    }

}
catch {
    throw $_
}
 


