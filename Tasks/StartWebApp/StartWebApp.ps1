[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {

	# Get inputs.
    $WebAppName = Get-VstsInput -Name WebAppName -Require
    $Slot = Get-VstsInput -Name Slot
    $StartedUrl = Get-VstsInput -Name StartedUrl

	# Initialize Azure.
	Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
	Initialize-Azure

	# Import the loc strings.
	Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json

    if ([string]::IsNullOrEmpty($WebAppName))
    {
		Throw (Get-VstsLocString -Key "Invalidwebappprovided")
	}

	# Load all dependent files for execution
	. $PSScriptRoot/AzureUtility.ps1

	# Importing required version of azure cmdlets according to azureps installed on machine
	$azureUtility = Get-AzureUtility

	Write-Verbose  "Loading $azureUtility"
	. $PSScriptRoot/$azureUtility -Force

    $resourceGroupName = Get-WebAppRGName -webAppName $WebAppName

    if ($Slot)
    {    
        Write-Verbose "[Azure Call] Starting slot: $WebAppName / $Slot"
        $result = Start-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $WebAppName -Slot $Slot -Verbose
        Write-Verbose "[Azure Call] Slot started: $WebAppName / $Slot"
    }
    else
    {
        Write-Verbose "[Azure Call] Starting Web App: $WebAppName"
        $result = Start-AzureRmWebApp -ResourceGroupName $resourceGroupName -Name $WebAppName -Verbose
        Write-Verbose "[Azure Call] Web App started: $WebAppName"
    }

    $scheme = "http"
    $hostName = $result.HostNames[0]
    foreach ($hostNameSslState in $result.HostNameSslStates)
    {
        if ($hostName -eq $hostNameSslState.Name)
        {
            if (-not $hostNameSslState.SslState -eq 0)
            {
                $scheme = "https"
            }

            break
        }
    }

    $urlValue = "${scheme}://$hostName"

    Write-Host (Get-VstsLocString -Key "WebappsuccessfullystartedatUrl0" -ArgumentList $urlValue)

    # Set ouput variable with $destinationUrl
    if (-not [string]::IsNullOrEmpty($StartedUrl))
    {
        if ([string]::IsNullOrEmpty($StartedUrl))
        {
            Throw (Get-VstsLocString -Key "Unabletoretrievewebappurlforwebapp0" -ArgumentList $webAppName)
        }

        Set-VstsTaskVariable -Name $StartedUrl -Value $urlValue
    }

	Write-Verbose "Completed Azure Web App Start Task"

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
