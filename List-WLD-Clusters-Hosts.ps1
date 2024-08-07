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

# Function to retrieve workload domains
function Get-WorkloadDomains {
    Write-Host "Retrieving workload domains..."
    $domains = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/domains"

    if ($null -eq $domains) {
        Write-Error "Failed to retrieve workload domains."
        return @()
    }

    return $domains.elements
}

# Function to retrieve cluster details
function Get-ClusterDetails {
    param (
        [string]$ClusterId
    )

    $clusterDetails = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/clusters/$ClusterId"

    if ($null -eq $clusterDetails) {
        Write-Error "Failed to retrieve details for cluster $ClusterId."
        return $null
    }

    return $clusterDetails
}

# Function to retrieve NSX cluster details
function Get-NSXClusterDetails {
    param (
        [string]$NSXClusterId
    )

    $NSXclusterDetails = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/nsxt-clusters/$NSXClusterId"

    if ($null -eq $NSXclusterDetails) {
        Write-Error "Failed to retrieve details for NSX cluster $NSXClusterId."
        return $null
    }

    return $NSXclusterDetails
}

# Function to retrieve host details
function Get-HostDetails {
    param (
        [string]$HostId
    )

    $hostDetails = Invoke-SDDCManagerAPI -Method "GET" -ApiEndpoint "/v1/hosts/$HostId"

    if ($null -eq $hostDetails) {
        Write-Error "Failed to retrieve details for host $HostId."
        return $null
    }

    return $hostDetails
}

# Main script execution
$domains = Get-WorkloadDomains

foreach ($domain in $domains) {
    Write-Host "`nWorkload Domain: $($domain.name)"
    Write-Host "  Domain ID: $($domain.id)"
    Write-Host "  Organization Name: $($domain.orgName)"
    Write-Host "  Status: $($domain.status)"
    Write-Host "  Upgrade State: $($domain.upgradeState)"
    Write-Host "  VRA Integration Status: $($domain.vraIntegrationStatus)"
    Write-Host "  VROPS Integration Status: $($domain.vropsIntegrationStatus)"
    Write-Host "  VRLI Integration Status: $($domain.vrliIntegrationStatus)"
    Write-Host "  SSO Name: $($domain.ssoName)"
    Write-Host "  Is Management SSO Domain: $($domain.isManagementSsoDomain)"
    Write-Host "  Lifecycle Management Mode: $($domain.lifecycleManagementMode)"

    # Print licensing info
    Write-Host "  Licensing Info:"
    Write-Host "    Licensing Mode: $($domain.licensingInfo.licensingMode)"
    Write-Host "    Subscription Status: $($domain.licensingInfo.subscriptionStatus)"
    Write-Host "    Is Registered: $($domain.licensingInfo.isRegistered)"
    Write-Host "    Is Subscribed: $($domain.licensingInfo.isSubscribed)"

    # Print capacity details
    Write-Host "  Capacity:"
    Write-Host "    CPU: Used - $($domain.capacity.cpu.used.value)$($domain.capacity.cpu.used.unit), Total - $($domain.capacity.cpu.total.value)$($domain.capacity.cpu.total.unit)"
    Write-Host "    Memory: Used - $($domain.capacity.memory.used.value)$($domain.capacity.memory.used.unit), Total - $($domain.capacity.memory.total.value)$($domain.capacity.memory.total.unit)"
    Write-Host "    Storage: Used - $($domain.capacity.storage.used.value)$($domain.capacity.storage.used.unit), Total - $($domain.capacity.storage.total.value)$($domain.capacity.storage.total.unit)"

    Write-Host " ----------------------------------------------------------- "
    Write-Host " NSX-T Cluster"
    Write-Host " ----------------------------------------------------------- "
    Write-Host "`nRetrieving information for NSX Cluster ID: $($domain.nsxtCluster.id)"
    $NSXclusterDetails = Get-NSXClusterDetails -NSXClusterId $domain.nsxtCluster.id    

    if ($null -eq $NSXclusterDetails) {
        continue
    }
    Write-Host "  VIP FQDN: $($NSXclusterDetails.vipFqdn)"
    $NSXManagerURL = $NSXclusterDetails.vipFqdn
    Write-Host " ----------------------------------------------------------- "

    # Retrieve Clusters within the Domain
    foreach ($cluster in $domain.clusters) {
        Write-Host "`nRetrieving information for Cluster ID: $($cluster.id)"
        $clusterDetails = Get-ClusterDetails -ClusterId $cluster.id

        if ($null -eq $clusterDetails) {
            continue
        }

        Write-Host "  Cluster Name: $($clusterDetails.name)"
        Write-Host "  Cluster Status: $($clusterDetails.status)"
        Write-Host "  Primary Datastore: $($clusterDetails.primaryDatastoreName)"
        Write-Host "  Primary Datastore Type: $($clusterDetails.primaryDatastoreType)"
        Write-Host "  Is Stretched: $($clusterDetails.isStretched)"
        Write-Host "  Failures To Tolerate: $($clusterDetails.failuresToTolerate)"
        Write-Host "  Is Image Based: $($clusterDetails.isImageBased)"

        # Print cluster capacity
        Write-Host "  Cluster Capacity:"
        Write-Host "    CPU: Used - $($clusterDetails.capacity.cpu.used.value)$($clusterDetails.capacity.cpu.used.unit), Total - $($clusterDetails.capacity.cpu.total.value)$($clusterDetails.capacity.cpu.total.unit)"
        Write-Host "    Memory: Used - $($clusterDetails.capacity.memory.used.value)$($clusterDetails.capacity.memory.used.unit), Total - $($clusterDetails.capacity.memory.total.value)$($clusterDetails.capacity.memory.total.unit)"
        Write-Host "    Storage: Used - $($clusterDetails.capacity.storage.used.value)$($clusterDetails.capacity.storage.used.unit), Total - $($clusterDetails.capacity.storage.total.value)$($clusterDetails.capacity.storage.total.unit)"

        # Retrieve Hosts within the Cluster
        foreach ($esxi in $clusterDetails.hosts) {
            Write-Host "  Host ID: $($esxi.id)"
            $hostDetails = Get-HostDetails -HostId $esxi.id

            if ($null -eq $hostDetails) {
                continue
            }

            Write-Host "    Host Name: $($hostDetails.name)"
            Write-Host "    Host Status: $($hostDetails.status)"
            Write-Host "    Host IP: $($hostDetails.managementIp)"
        }
    }
}
