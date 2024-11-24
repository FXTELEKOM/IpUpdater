#region Parameters and Configuration
[CmdletBinding()]
param (
    [string]$ConfigPath,
    [string[]]$SelectedServices,
    [switch]$All
)

# Service configuration
$ServiceConfig = @{
    "Cloudflare"         = "https://fxtelekom.org/ips/cloudflare.txt"
    "CS2"                = "https://fxtelekom.org/ips/valve-cs2.txt"
    "Websupport SK"      = "https://fxtelekom.org/ips/websupportsk.txt"
    "Gcore"              = "https://fxtelekom.org/ips/gcore.txt"
    "Hunt: Showdown EU"  = "https://fxtelekom.org/ips/hunt.txt"
    "COD"                = "https://fxtelekom.org/ips/cod.txt"
}

$DefaultIPsURL = "https://fxtelekom.org/ips/intern.txt"
$DNSIPsURL     = "https://fxtelekom.org/ips/dns.txt"

#endregion

#region Functions

function Show-InteractiveMenu {
    param (
        [array]$Services
    )
    $services = @("Select all") + $Services
    $selected = @($false) * $services.Count
    $currentIndex = 0

    function Display-Menu {
        Clear-Host
        Write-Host "Use arrow keys to navigate and space to select/deselect. Press Enter to confirm."
        for ($i = 0; $i -lt $services.Length; $i++) {
            $selectionMarker = if ($selected[$i]) { "[X]" } else { "[ ]" }
            if ($i -eq $currentIndex) {
                Write-Host ">> $selectionMarker $($services[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "   $selectionMarker $($services[$i])"
            }
        }
    }

    while ($true) {
        Display-Menu
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 {  # Up arrow key
                $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $services.Length - 1 }
            }
            40 {  # Down arrow key
                $currentIndex = if ($currentIndex -lt $services.Length - 1) { $currentIndex + 1 } else { 0 }
            }
            32 {  # Space key
                if ($currentIndex -eq 0) {
                    # Toggle "Select all" option
                    $allSelected = -not $selected[0]
                    for ($j = 0; $j -lt $selected.Length; $j++) {
                        $selected[$j] = $allSelected
                    }
                } else {
                    # Toggle the selected option
                    $selected[$currentIndex] = -not $selected[$currentIndex]
                }
            }
            13 {  # Enter key
                return $selected
            }
        }
    }
}

function Get-IPListFromURL {
    param (
        [string]$URL
    )
    Write-Verbose "Attempting to download IP list from URL: $URL"
    try {
        $ipList = Invoke-WebRequest -Uri $URL -UseBasicParsing -ErrorAction Stop
        Write-Verbose "Successfully downloaded IP list from: $URL"
        $ipAddresses = $ipList.Content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        Write-Verbose "Processed IP addresses: $($ipAddresses.Count) entries found."
        return $ipAddresses
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Error ("Failed to download IP list from {0}: {1}" -f $URL, $errorMessage)
        throw $_
    }
}

function Validate-ConfigPath {
    param (
        [string]$Path
    )
    Write-Verbose "Validating configuration file path: $Path"
    if (-Not $Path) {
        throw "The configuration file path must be provided."
    }
    if (-Not (Test-Path $Path)) {
        throw "The specified configuration file does not exist: $Path"
    }
    Write-Verbose "Configuration file path is valid."
}

function Normalize-ServiceNames {
    param (
        [string[]]$Names,
        [array]$ValidServices
    )
    Write-Verbose "Normalizing service names: $Names"
    $normalizedNames = @()
    foreach ($name in $Names) {
        $matchedService = $ValidServices | Where-Object { $_.Equals($name, [System.StringComparison]::OrdinalIgnoreCase) }
        if ($matchedService) {
            Write-Verbose "Service '$name' matched as '$matchedService'"
            $normalizedNames += $matchedService
        } else {
            Write-Warning "Unknown service: $name. Skipping."
        }
    }
    return $normalizedNames
}

function Select-Services {
    param (
        [array]$AvailableServices,
        [string[]]$SelectedServices,
        [switch]$All
    )
    if ($All) {
        Write-Host "All services selected via '-All' parameter."
        return $AvailableServices
    } elseif ($SelectedServices) {
        Write-Host "Selected services provided: $SelectedServices"
        $SelectedServiceNames = Normalize-ServiceNames -Names $SelectedServices -ValidServices $AvailableServices
        if (-Not $SelectedServiceNames) {
            Write-Error "No valid services were provided."
            exit 1
        }
        return $SelectedServiceNames
    } else {
        Write-Host "No services provided. Launching interactive menu..."
        $selection = Show-InteractiveMenu -Services $AvailableServices
        $SelectedServiceNames = @()
        for ($i = 1; $i -lt $selection.Length; $i++) {
            if ($selection[$i]) {
                $SelectedServiceNames += $AvailableServices[$i - 1]
            }
        }
        if (-Not $SelectedServiceNames) {
            Write-Error "No services were selected."
            exit 1
        }
        return $SelectedServiceNames
    }
}

function Collect-IPAddresses {
    param (
        [string[]]$SelectedServiceNames,
        [hashtable]$ServiceConfig
    )
    $ipAddresses = @()
    foreach ($service in $SelectedServiceNames) {
        Write-Host "Processing service: $service"
        try {
            $serviceIPs = Get-IPListFromURL -URL $ServiceConfig[$service]
            $ipAddresses += $serviceIPs
            Write-Verbose "Total IPs collected for '$service': $($serviceIPs.Count)"
        } catch {
            Write-Error "An error occurred while downloading the IP list for '$service': $_"
            exit 1
        }
    }
    Write-Verbose "Total IP addresses collected from services: $($ipAddresses.Count)"
    return $ipAddresses
}

function Get-DefaultAndDNSIPs {
    param (
        [string]$DefaultIPsURL,
        [string]$DNSIPsURL
    )
    try {
        Write-Host "Downloading default IPs..."
        $defaultIPs = Get-IPListFromURL -URL $DefaultIPsURL -ErrorAction Stop
        Write-Verbose "Default IPs downloaded: $($defaultIPs.Count)"

        Write-Host "Downloading DNS IPs..."
        $DNSIPs = Get-IPListFromURL -URL $DNSIPsURL -ErrorAction Stop
        Write-Verbose "DNS IPs downloaded: $($DNSIPs.Count)"

        return @{
            DefaultIPs = $defaultIPs
            DNSIPs = $DNSIPs
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Error ("Failed to download default IPs or DNS IPs: {0}" -f $errorMessage)
        exit 1
    }
}

function Update-ConfigurationFile {
    param (
        [hashtable]$Data
    )

    # Extract data from the hashtable
    $ConfigPath      = $Data.ConfigPath
    $ConfigContent   = $Data.ConfigContent
    $DefaultIPs      = $Data.DefaultIPs
    $ServiceIPs      = $Data.ServiceIPs
    $DNSIPs          = $Data.DNSIPs

    $DNSIPsString = $DNSIPs -join ", "
    $allAllowedIPs = $DefaultIPs + $ServiceIPs
    $allAllowedIPsString = $allAllowedIPs -join ", "

    $allowedIPsFound = $false
    $DNSFound = $false

    $updatedContent = $ConfigContent | ForEach-Object {
        if ($_ -match "^\s*DNS\s*=") {
            $DNSFound = $true
            Write-Verbose "Existing DNS entry found. Updating DNS IPs."
            "DNS = $DNSIPsString"
        }
        elseif ($_ -match "^\s*AllowedIPs\s*=") {
            $allowedIPsFound = $true
            Write-Verbose "Existing AllowedIPs entry found. Updating Allowed IPs."
            "AllowedIPs = $allAllowedIPsString"
        }
        else {
            $_
        }
    }

    # Fail if 'AllowedIPs' entry is not found
    if (-Not $allowedIPsFound) {
        Write-Error "No 'AllowedIPs' entry found in the configuration file. Please ensure your configuration file contains the necessary 'AllowedIPs' field."
        exit 1
    }

    # Fail if 'DNS' entry is not found
    if (-Not $DNSFound) {
        Write-Error "No 'DNS' entry found in the configuration file. Please ensure your configuration file contains the necessary 'DNS' field."
        exit 1
    }

    # Save the updated configuration file
    Write-Host "Updating configuration file..."
    Set-Content -Path $ConfigPath -Value $updatedContent -ErrorAction Stop

    Write-Host "`nThe WireGuard configuration file has been updated."
    Write-Host "DNS: $DNSIPsString"
    Write-Host "AllowedIPs: $allAllowedIPsString"
    Write-Host "`nEnjoy your faster internet! :)"
}

#endregion

#region Main Script

$logo = @"
  ________   _________ ______ _      ______ _  ______  __  __
 |  ____\ \ / /__   __|  ____| |    |  ____| |/ / __ \|  \/  |
 | |__   \ V /   | |  | |__  | |    | |__  | ' / |  | | \  / |
 |  __|   > <    | |  |  __| | |    |  __| |  <| |  | | |\/| |
 | |     / . \   | |  | |____| |____| |____| . \ |__| | |  | |
 |_|    /_/ \_\  |_|  |______|______|______|_|\_\____/|_|  |_|

"@

# Display the logo and introduction
Clear-Host
Write-Host $logo
Write-Host "This script updates your WireGuard configuration file with the IP ranges of the selected services."
Write-Host

# Validate the configuration file path
try {
    if (-Not $ConfigPath) {
        Write-Host "No configuration file path provided. Prompting for input..."
        $ConfigPath = Read-Host "Enter the full path to your WireGuard configuration file"
    }
    Validate-ConfigPath -Path $ConfigPath
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

Write-Verbose "Configuration file path: $ConfigPath"

$AvailableServices = $ServiceConfig.Keys

# Service selection
$SelectedServiceNames = Select-Services -AvailableServices $AvailableServices -SelectedServices $SelectedServices -All:$All

Write-Verbose "Services selected: $SelectedServiceNames"

# Collect IP addresses
$ipAddresses = Collect-IPAddresses -SelectedServiceNames $SelectedServiceNames -ServiceConfig $ServiceConfig

# Download default IPs and DNS IPs
$IPsData = Get-DefaultAndDNSIPs -DefaultIPsURL $DefaultIPsURL -DNSIPsURL $DNSIPsURL
$defaultIPs = $IPsData.DefaultIPs
$DNSIPs = $IPsData.DNSIPs

# Read configuration file content
$configContent = Get-Content -Path $ConfigPath -ErrorAction Stop

# Prepare data for updating the configuration file
$updateData = @{
    ConfigPath      = $ConfigPath
    ConfigContent   = $configContent
    DefaultIPs      = $defaultIPs
    ServiceIPs      = $ipAddresses
    DNSIPs          = $DNSIPs
}

# Update configuration file
Update-ConfigurationFile -Data $updateData

#endregion
