# PowerCLI Script to Update VMware SDDC Manager

# Define Credentials
$CloudBuilderUsername = "admin"
$CloudBuilderPassword = "VMware123!"

$SDDCManagerUsername = "administrator@vsphere.local"
$SDDCManagerPassword = "VMware123!"

$vCenterServerUsername = "root"
$vCenterServerPassword = "VMware123!"

$vSphereClientUsername = "administrator@vsphere.local"
$vSphereClientPassword = "VMware123!"

$NSXManagerUsername = "admin"
$NSXManagerPassword = "VMware123!VMware123!"

$ESXiHostsUsername = "root"
$ESXiHostsPassword = "VMware123!"

# PowerCLI Script to Update VMware SDDC Manager

# Define Credentials for SDDC Manager
$SDDCManagerUsername = "administrator@vsphere.local"
$SDDCManagerPassword = "VMware123!"

# Define SDDC Manager URL
$SDDCManagerURL = "https://sddc-manager.vcf.sddc.lab" # Replace with your actual SDDC Manager URL

# Generate a function that connects to vcenter server

# Encode credentials for basic authentication
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${SDDCManagerUsername}:${SDDCManagerPassword}"))


# Define a function to make API requests to SDDC Manager
function Invoke-SDDCManagerAPI {
    param (
        [string]$Method,
        [string]$ApiEndpoint,
        [hashtable]$Body = $null
    )
    
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        Accept        = "application/json"
    }
    
    if ($Body -ne $null) {
        $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType "application/json"
    } else {
        $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers
    }
    
    return $response
}

# Retrieve Available Updates
Write-Host "Retrieving available updates..."
try {
    $availableUpdates = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/api/update/available"
} catch {
    Write-Error "Failed to retrieve updates: $_"
    exit
}

# Check if updates are available
if ($availableUpdates.items.Count -eq 0) {
    Write-Host "No updates available."
    exit
}

# List Available Updates
Write-Host "Available Updates:"
$availableUpdates.items | ForEach-Object {
    Write-Host "Release Name: $($_.releaseName), Version: $($_.version), Released On: $($_.releaseDate)"
}

# Get the latest update
$latestUpdate = $availableUpdates.items | Sort-Object -Property releaseDate -Descending | Select-Object -First 1

Write-Host "Latest Update Available:"
Write-Host "Release Name: $($latestUpdate.releaseName), Version: $($latestUpdate.version), Released On: $($latestUpdate.releaseDate)"

# Confirm update execution
$confirmUpdate = Read-Host "Do you want to apply the latest update? (yes/no)"
if ($confirmUpdate -ne "yes") {
    Write-Host "Update canceled."
    exit
}

# Execute Update
Write-Host "Executing update to latest release: $($latestUpdate.releaseName)"
try {
    $updateBody = @{
        updateId = $latestUpdate.updateId
    }

    $updateResponse = Invoke-SDDCManagerAPI -Method "POST" -ApiEndpoint "/v1/api/update/execute" -Body $updateBody
} catch {
    Write-Error "Failed to execute update: $_"
    exit
}

# Check update response
if ($updateResponse.status -eq "success") {
    Write-Host "Update executed successfully. Please monitor the update progress in SDDC Manager."
} else {
    Write-Error "Update execution failed: $($updateResponse.errorMessage)"
}