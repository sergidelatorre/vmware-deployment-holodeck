# PowerCLI Script to Retrieve Information from VMware SDDC Manager using Bearer Token

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

# Function to obtain the Bearer Token
function Get-SDDCManagerToken {
    param (
        [string]$Username,
        [string]$Password
    )

    $body = @{
        username = $Username
        password = $Password
    }

    $headers = @{
        Accept = "application/json"
    }

    try {
        Write-Host "Attempting to obtain access token..."
        $response = Invoke-RestMethod -Uri "$SDDCManagerURL/v1/tokens" -Method "POST" -Headers $headers -Body ($body | ConvertTo-Json) -ContentType "application/json"
        
        if ($response.accessToken) {
            Write-Host "Access token retrieved successfully."
        } else {
            Write-Host "No access token received."
        }

        return $response.accessToken
    } catch {
        Write-Error "Failed to obtain access token: $_"
        return $null
    }
}

# Obtain the Bearer Token
$accessToken = Get-SDDCManagerToken -Username $SDDCManagerUsername -Password $SDDCManagerPassword

if ($null -eq $accessToken) {
    Write-Error "Failed to retrieve access token. Exiting script."
    exit
}

# Define a function to make API requests to SDDC Manager using the Bearer Token
function Invoke-SDDCManagerAPI {
    param (
        [string]$Method,
        [string]$ApiEndpoint,
        [hashtable]$Body = $null
    )
    
    $headers = @{
        Authorization = "Bearer $accessToken"
        Accept        = "application/json"
    }
    
    Write-Host "Making API call to $SDDCManagerURL$ApiEndpoint with method $Method"
    
    try {
        if ($Body -ne $null) {
            $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType "application/json"
        } else {
            $response = Invoke-RestMethod -Uri "$SDDCManagerURL$ApiEndpoint" -Method $Method -Headers $headers
        }
        
        # Debug output for the raw response
        Write-Host "Raw API response: $(ConvertTo-Json $response -Depth 10)"
        
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

    # Debug: Print the entire domain object
    Write-Host "Domain Object: $(ConvertTo-Json $domain -Depth 5)"

    # Retrieve Clusters within the Domain
    $clusters = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/domains/$($domain.id)/clusters"

    if ($null -eq $clusters) {
        Write-Error "Failed to retrieve clusters for domain $($domain.name)."
        continue
    }

    foreach ($cluster in $clusters.content) {
        Write-Host "  Cluster: $($cluster.name)"
        Write-Host "    Cluster ID: $($cluster.id)"
        
        # Debug: Print the entire cluster object
        Write-Host "Cluster Object: $(ConvertTo-Json $cluster -Depth 5)"

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

            # Debug: Print the entire host object
            Write-Host "Host Object: $(ConvertTo-Json $host -Depth 5)"
        }
    }
}
