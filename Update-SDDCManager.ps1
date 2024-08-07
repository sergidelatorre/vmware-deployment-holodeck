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

# Define SDDC Manager URL
$SDDCManagerURL = "https://sddc-manager.example.com" # Replace with your actual SDDC Manager URL

# Connect to SDDC Manager
Write-Host "Connecting to SDDC Manager..."
$connection = Connect-VIServer -Server $SDDCManagerURL -User $SDDCManagerUsername -Password $SDDCManagerPassword

if ($connection) {
    Write-Host "Connected to SDDC Manager at $SDDCManagerURL"
} else {
    Write-Error "Failed to connect to SDDC Manager"
    exit
}

# Retrieve Available Updates
Write-Host "Retrieving available updates..."
$apiUrl = "$SDDCManagerURL/v1/update/available"

try {
    $availableUpdates = Invoke-RestMethod -Method Get -Uri $apiUrl -Credential (New-Object System.Management.Automation.PSCredential($SDDCManagerUsername, (ConvertTo-SecureString $SDDCManagerPassword -AsPlainText -Force)))
} catch {
    Write-Error "Failed to retrieve updates: $_"
    Disconnect-VIServer -Server $SDDCManagerURL -Confirm:$false
    exit
}

# Check if updates are available
if ($availableUpdates.updates.Count -eq 0) {
    Write-Host "No updates available."
    Disconnect-VIServer -Server $SDDCManagerURL -Confirm:$false
    exit
}

# List Available Updates
Write-Host "Available Updates:"
$availableUpdates.updates | ForEach-Object {
    Write-Host "Release Name: $($_.releaseName), Version: $($_.version), Released On: $($_.releasedDate)"
}

# Get the latest update
$latestUpdate = $availableUpdates.updates | Sort-Object -Property releasedDate -Descending | Select-Object -First 1

Write-Host "Latest Update Available:"
Write-Host "Release Name: $($latestUpdate.releaseName), Version: $($latestUpdate.version), Released On: $($latestUpdate.releasedDate)"

# Confirm update execution
$confirmUpdate = Read-Host "Do you want to apply the latest update? (yes/no)"
if ($confirmUpdate -ne "yes") {
    Write-Host "Update canceled."
    Disconnect-VIServer -Server $SDDCManagerURL -Confirm:$false
    exit
}

# Execute Update
Write-Host "Executing update to latest release: $($latestUpdate.releaseName)"
$updateApiUrl = "$SDDCManagerURL/v1/update/execute"
$updateBody = @{
    releaseId = $latestUpdate.id
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post -Uri $updateApiUrl -Credential (New-Object System.Management.Automation.PSCredential($SDDCManagerUsername, (ConvertTo-SecureString $SDDCManagerPassword -AsPlainText -Force))) -Body $updateBody -ContentType "application/json"
} catch {
    Write-Error "Failed to execute update: $_"
    Disconnect-VIServer -Server $SDDCManagerURL -Confirm:$false
    exit
}

# Check update response
if ($response.status -eq "success") {
    Write-Host "Update executed successfully. Please monitor the update progress in SDDC Manager."
} else {
    Write-Error "Update execution failed: $($response.errorMessage)"
}

# Disconnect from SDDC Manager
Disconnect-VIServer -Server $SDDCManagerURL -Confirm:$false