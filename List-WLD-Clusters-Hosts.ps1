# PowerCLI Script to Retrieve Information from VMware SDDC Manager

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
$SDDCManagerURL = "https://sddc-manager.vcf.sddc.lab" # Replace with your actual SDDC Manager URL

# Encode credentials for basic authentication
$credentials = "${SDDCManagerUsername}:${SDDCManagerPassword}"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credentials))

# Debugging: Check the base64 encoded credentials (remove or comment this in production)
# Write-Host "Base64 Encoded Credentials: $base64AuthInfo"

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
    
    Write-Host "Making API call to $SDDCManagerURL$ApiEndpoint with method $Method"
    
    try {
        if ($Body -ne $null) {
            $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType "application/json"
        } else {
            $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers
        }
        return $response
    } catch {
        Write-Error "Error making API call: $_"
        return $null
    }
}

# Retrieve Workload Domains
Write-Host "Retrieving workload domains..."
$workloadDomains = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/domains"

if ($null -eq $workloadDomains) {
    Write-Error "Failed to retrieve workload domains."
    exit
}

# Print Workload Domains and Clusters
foreach ($domain in $workloadDomains.content) {
    Write-Host "Workload Domain: $($domain.name)"
    Write-Host "  Domain ID: $($domain.id)"
    Write-Host "  Domain Type: $($domain.domainType)"

    # Retrieve Clusters within the Domain
    $clusters = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/domains/$($domain.id)/clusters"

    if ($null -eq $clusters) {
        Write-Error "Failed to retrieve clusters for domain $($domain.name)."
        continue
    }

    foreach ($cluster in $clusters.content) {
        Write-Host "  Cluster: $($cluster.name)"
        Write-Host "    Cluster ID: $($cluster.id)"
        
        # Retrieve Hosts within the Cluster
        $hosts = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/clusters/$($cluster.id)/hosts"

        if ($null -eq $hosts) {
            Write-Error "Failed to retrieve hosts for cluster $($cluster.name)."
            continue
        }

        foreach ($host in $hosts.content) {
            Write-Host "    Host: $($host.name)"
            Write-Host "      Host ID: $($host.id)"
            Write-Host "      Host Status: $($host.status)"
            Write-Host "      Host IP: $($host.managementIp)"
        }
    }
}
