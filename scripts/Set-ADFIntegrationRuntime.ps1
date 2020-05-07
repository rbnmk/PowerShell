param(
    #[string]$SubscriptionName,
	[string]$ResourceGroupName,
	[string]$DataFactoryName,
	[string]$IntegrationRuntimeName
)

function ExistAzureResource($ResourceGroupName, $ResourceName) {

	try {
		$doesResourceExist = Get-AzResource -ResourceName $ResourceName -ResourceGroupName $ResourceGroupName;
	}
	catch {
		Write-Host ("##vso[task.logissue type=error;] Error getting Azure resource {0} in resource group {1}" -f $ResourceName, $ResourceGroupName);
		return $false;
	}

	if (!($doesResourceExist)){
		return $false;
	} else {
		return $true;
	}
}

# Select the appropriate subscription
#Select-AzSubscription -SubscriptionName $SubscriptionName

$doesADFExist = ExistAzureResource -ResourceGroupName $ResourceGroupName -ResourceName $DataFactoryName;
if (!($doesADFExist)){
	Write-Host ("##vso[task.logissue type=error;] Azure Data Factory {0} not found in resource group {1}" -f $DataFactoryName, $ResourceGroupName);
	exit(1);
}

Write-Host ("Looking for Integration Runtime {0}" -f $IntegrationRuntimeName) -NoNewline;
$irRuntime = Get-AzDataFactoryV2IntegrationRuntime -name $IntegrationRuntimeName -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Status -ErrorAction SilentlyContinue;
if($irRuntime) {
	Write-Host "... Found";
} else {
	Write-Host "... Not found";
}

if(!$irRuntime) {
	Write-Host ("Creating Integration Runtime ""{0}"" " -f $IntegrationRuntimeName);
	Set-AzDataFactoryV2IntegrationRuntime -Name $IntegrationRuntimeName -Type SelfHosted -DataFactoryName $DataFactoryName -ResourceGroupName $ResourceGroupName -Force

	#
	# Retrieve the status of the created integration runtime. Confirm that the value of the State property is set to NeedRegistration.
	#
	$irRuntime = Get-AzDataFactoryV2IntegrationRuntime -name $IntegrationRuntimeName -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Status
}

if($irRuntime.State -eq "NeedRegistration") {
	#
	# Retrieve the authentication keys used to register the self-hosted integration runtime with Azure Data Factory service in the cloud.
	#
	Write-Host ("Creating Integration Runtime Key's");
	$irKeys = Get-AzDataFactoryV2IntegrationRuntimeKey -Name $IntegrationRuntimeName -DataFactoryName $DataFactoryName -ResourceGroupName $ResourceGroupName

	if ( (Get-Member -InputObject $irKeys -Name "AuthKey1" -MemberType Properties) -And (Get-Member -InputObject $irKeys -Name "AuthKey2" -MemberType Properties) ) {
		Write-Output ("Registering parameter adfIntegrationRuntimeKey1 with value {0}" -f $irKeys.AuthKey1)
		Write-Host "##vso[task.setvariable variable=adfIntegrationRuntimeKey1;]$($irKeys.AuthKey1)"

		Write-Output ("Registering parameter adfIntegrationRuntimeKey2 with value {0}" -f $irKeys.AuthKey2)
		Write-Host "##vso[task.setvariable variable=adfIntegrationRuntimeKey2;]$($irKeys.AuthKey2)"
	} else {
		Write-Host ("##vso[task.logissue type=warning;] Warning: Incorrect JSON format. Cannot find ""AuthKey1"" or ""AuthKey2"" properties. Skipping key creation.");
	}
} else {
	Write-Host ("##vso[task.logissue type=warning;] Warning: Integration Runtime status not equal to ""NeedRegistration"". Skipping key creation.");
}
