function Show-InteractiveMenu {
    $services = @(
        "I want it all!",
        "Cloudflare",
        "CS2",
        "Websupport SK",
        "Gcore",
        "Hunt: Showdown EU"
    )

    $selected = @($false, $false, $false, $false, $false, $false)
    $currentIndex = 0

    function Display-Menu {
        Clear-Host
        Write-Host "Use arrow keys to navigate and space to select/deselect. Press Enter to confirm."
        for ($i = 0; $i -lt $services.Length; $i++) {
            $selectionMarker = if ($selected[$i]) { "[X]" } else { "[ ]" }
    
            if ($i -eq $currentIndex) {
                Write-Host ">> $selectionMarker $($services[$i])"
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
                $selected[$currentIndex] = -not $selected[$currentIndex]
            }
            13 {  # Enter key
                return $selected
            }
        }
    }
}

function Get-IPListForService {
    param (
        [string]$service
    )
    $url = ""

    switch ($service) {
        "Cloudflare" {
            $url = "https://fxtelekom.org/ips/cloudflare.txt"
        }
        "CS2" {
            $url = "https://fxtelekom.org/ips/valve-cs2.txt"
        }
        "Websupport SK" {
            $url = "https://fxtelekom.org/ips/websupportsk.txt"
        }
        "Gcore" {
            $url = "https://fxtelekom.org/ips/gcore.txt"
        }
        "Hunt: Showdown EU" {
            $url = "https://fxtelekom.org/ips/hunt.txt"
        }
        default {
            Write-Error "Invalid service selection."
            exit 1
        }
    }

    try {
        $ipList = Invoke-WebRequest -Uri $url -UseBasicParsing
        $ipAddresses = $ipList.Content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        return $ipAddresses
    } catch {
        Write-Error "Failed to download IP list for service $service : $_"
        exit 1
    }
}

function Get-DefaultIPsFromConfig {
    param (
        [string[]]$configContent
    )

    $addressLine = $configContent | Where-Object { $_ -match "^Address\s*=" }
    $dnsLine = $configContent | Where-Object { $_ -match "^DNS\s*=" }

    if (-not $addressLine) {
        Write-Error "Address line not found in the configuration file."
        return
    }
    if (-not $dnsLine) {
        Write-Error "DNS line not found in the configuration file."
        return
    }

    $ipv4Address = $addressLine -match "Address\s*=\s*(\d+\.\d+\.\d+)\.\d+\/" | Out-Null
    if (-not $matches[1]) {
        Write-Error "Failed to extract IPv4 address from Address line."
        return
    }
    $ipv4Subnet = "$($matches[1]).1/32"

    $dnsValues = $dnsLine -replace "^DNS\s*=\s*", ""
    $dnsSubnets = ($dnsValues -split ",\s*") | ForEach-Object { "$_/32" }

    return "$ipv4Subnet, $($dnsSubnets -join ', ')"
}

$logo = @"
  ________   _________ ______ _      ______ _  ______  __  __ 
 |  ____\ \ / /__   __|  ____| |    |  ____| |/ / __ \|  \/  |
 | |__   \ V /   | |  | |__  | |    | |__  | ' / |  | | \  / |
 |  __|   > <    | |  |  __| | |    |  __| |  <| |  | | |\/| |
 | |     / . \   | |  | |____| |____| |____| . \ |__| | |  | |
 |_|    /_/ \_\  |_|  |______|______|______|_|\_\____/|_|  |_|
                                                              
                                                              
"@

Clear-Host
Write-Host @"
$logo
This script will enter the IP ranges for your selected services in your wireguard config file.
You can run it when we add a new list or update an existing one, and you want to use it for a newly added service or one of the old ranges is extended!

"@

$configPath = Read-Host "Enter the full path to the wg config file"

if (-Not (Test-Path $configPath)) {
    Write-Error "The specified wg.conf file does not exist: $configPath"
    exit 1
}

$selected = Show-InteractiveMenu

$ipAddresses = @()
$defaultIPs = Get-DefaultIPsFromConfig $configContent
$services = @(
    "I want it all!",
    "Cloudflare",
    "CS2",
    "Websupport SK",
    "Gcore",
    "Hunt: Showdown EU"
)

if ($selected[0]) {
    for ($i = 1; $i -lt $services.Length; $i++) {
        Write-Host "Processing service: $($services[$i])"
        $ipAddresses += Get-IPListForService $services[$i]
    }
} else {
    for ($i = 1; $i -lt $services.Length; $i++) {
        if ($selected[$i]) {
            Write-Host "Processing service: $($services[$i])"
            $ipAddresses += Get-IPListForService $services[$i]
        }
    }
}

$allowedIPs = $defaultIPs + "," + ($ipAddresses -join ', ')

try {
    $configContent = Get-Content -Path $configPath
    $allowedIPsFound = $false

    $updatedContent = $configContent | ForEach-Object {
        if ($_ -match "^AllowedIPs\s*=") {
            $allowedIPsFound = $true
            "AllowedIPs = $allowedIPs"
        } else {
            $_
        }
    }

    if (-not $allowedIPsFound) {
        Write-Error "'AllowedIPs =' field not found in the configuration file."
        exit 1
    }

    Set-Content -Path $configPath -Value $updatedContent
    Write-Host "`nwg.conf updated with the following IP addresses: $allowedIPs"
    Write-Host "`nHave a good time with your new fast internet :)"
} catch {
    Write-Error "Error processing the configuration file: $_"
}
