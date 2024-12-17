# Polimi WiFi Certificate Configuration Script
# Author: [Roberto Reale]
# Repository: [https://github.com/RobertoReale/Configure-PolimiWifi]
# License: MIT
#
# This script automates the configuration of Politecnico di Milano's WiFi networks:
# - polimi-protected
# - polimi_protected
# - eduroam
# with certificate-based authentication (TLS) according to the official ICT Services guide.
#
# Requirements:
# - Windows operating system
# - Administrator privileges
# - Active Polimi account

#Requires -RunAsAdministrator

# Set strict error handling
$ErrorActionPreference = "Stop"

# Script version
$ScriptVersion = "1.0.0"

# Helper function to display status messages with consistent formatting
function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host "`n[*] $Message" -ForegroundColor $Color
}

# Helper function to display error messages with consistent formatting
function Write-Error {
    param([string]$Message)
    Write-Host "`n[!] $Message" -ForegroundColor Red
}

# Check if WiFi adapter is present and enabled
function Test-WifiAdapter {
    Write-Status "Checking WiFi adapter..."
    $wifiAdapter = Get-NetAdapter | Where-Object { 
        $_.Name -like "*Wi-Fi*" -and $_.Status -ne "Disabled"
    }
    if (-not $wifiAdapter) {
        throw "No enabled WiFi adapter found. Please ensure WiFi is enabled."
    }
    Write-Host "WiFi adapter found: $($wifiAdapter.Name)"
    return $wifiAdapter
}

# Verify if a valid Polimi certificate is installed
function Test-ValidCertificate {
    param([switch]$Verbose)
    
    $validCert = Get-ChildItem -Path Cert:\CurrentUser\My | 
        Where-Object { 
            ($_.Subject -like "*polimi*" -or $_.Subject -like "*politecnico*") -and
            $_.NotAfter -gt (Get-Date)
        }
    
    if ($Verbose -and $validCert) {
        Write-Host "`nValid certificate details:"
        Write-Host "Subject: $($validCert.Subject)"
        Write-Host "Expires: $($validCert.NotAfter)"
        Write-Host "Days remaining: $(($validCert.NotAfter - (Get-Date)).Days)"
    }
    
    return $null -ne $validCert
}

# Remove expired Polimi certificates
function Remove-ExpiredCertificates {
    Write-Status "Checking for expired certificates..."
    
    # Find expired certificates related to Polimi
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My | 
        Where-Object { 
            ($_.Subject -like "*polimi*" -or $_.Issuer -like "*polimi*" -or 
             $_.Subject -like "*politecnico*" -or $_.Issuer -like "*politecnico*") -and
            $_.NotAfter -lt (Get-Date)
        }
    
    if (-not $certs) {
        Write-Host "No expired Politecnico certificates found."
        return
    }
    
    # Display found certificates and prompt for removal
    Write-Host "`nExpired certificates found:"
    $certs | ForEach-Object {
        Write-Host ("`nSubject: " + $_.Subject)
        Write-Host ("Expired on: " + $_.NotAfter)
    }
    
    $choice = Read-Host "`nWould you like to remove these expired certificates? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        foreach ($cert in $certs) {
            try {
                $cert | Remove-Item -Force
                Write-Host "Removed: $($cert.Subject)" -ForegroundColor Green
            } catch {
                Write-Error "Failed to remove certificate: $($cert.Subject)`nError: $_"
            }
        }
    }
}

# Remove existing WiFi network configurations to prevent conflicts
function Remove-ExistingConfigurations {
    Write-Status "Checking existing WiFi configurations..."
    
    # Get all wireless network profiles
    $existingProfiles = netsh wlan show profiles | Select-String "Profile\s*:\s*(.+)" | ForEach-Object {
        $_.Matches.Groups[1].Value.Trim()
    }
    
    # Check for potential conflicts
    $conflictingProfiles = $existingProfiles | Where-Object {
        $_ -like "*polimi*" -or $_ -like "*politecnico*" -or $_ -like "*eduroam*"
    }
    
    if ($conflictingProfiles) {
        Write-Host "`nFound potentially conflicting profiles:" -ForegroundColor Yellow
        $conflictingProfiles | ForEach-Object {
            Write-Host "- $_"
        }
    }
    
    # Remove known network profiles
    $networks = @("polimi-protected", "polimi_protected", "eduroam")
    foreach ($network in $networks) {
        try {
            if ($network -in $existingProfiles) {
                Write-Host "`nRemoving profile: $network"
                netsh wlan delete profile name="$network"
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully removed profile: $network" -ForegroundColor Green
                }
            }
        } catch {
            Write-Error "Failed to remove profile '$network': $_"
        }
    }
    
    # Warn about remaining potential conflicts
    $remainingConflicts = $conflictingProfiles | Where-Object { $_ -notin $networks }
    if ($remainingConflicts) {
        Write-Host "`nWarning: Found other profiles that might conflict:" -ForegroundColor Yellow
        $remainingConflicts | ForEach-Object {
            Write-Host "- $_"
            Write-Host "  Consider removing this profile manually if you experience connection issues."
        }
    }
}

# Guide the user through certificate installation process
function Install-Certificate {
    Write-Status "Certificate installation..."
    
    if (Test-ValidCertificate -Verbose) {
        $choice = Read-Host "`nA valid certificate is already installed. Install new one anyway? (Y/N)"
        if ($choice -ne 'Y' -and $choice -ne 'y') {
            Write-Host "Keeping existing certificate."
            return
        }
    }
    
    try {
        # Open certificate generation page in default browser
        Start-Process "https://aunicalogin.polimi.it/aunicalogin/getservizio.xml?id_servizio=2108"
    } catch {
        throw "Failed to open certificate generation page: $_"
    }
    
    Write-Host "`nPlease follow these steps:" -ForegroundColor Yellow
    Write-Host "1. Log in to the Polimi portal"
    Write-Host "2. Download and save the certificate file"
    Write-Host "3. Double-click the downloaded certificate"
    Write-Host "4. Click 'Next'"
    Write-Host "5. Enter the certificate password when prompted"
    Write-Host "6. Accept default settings and click 'Next'"
    Write-Host "7. Click 'Finish'"
    
    Read-Host "`nPress Enter after completing the certificate installation"
    
    if (-not (Test-ValidCertificate)) {
        throw "No valid certificate detected. Please try the installation again."
    }
}

# Configure a WiFi network with certificate authentication
function Set-WifiNetwork {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NetworkName,
        [string]$ServerName = "wifi.polimi.it"
    )
    
    Write-Status "Configuring $NetworkName network..."
    
    # XML profile template following official ICT Services guide specifications
    $xmlProfile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$NetworkName</name>
    <SSIDConfig>
        <SSID>
            <hex>$(([System.Text.Encoding]::UTF8.GetBytes($NetworkName) | ForEach-Object { '{0:x2}' -f $_ }) -join '')</hex>
            <name>$NetworkName</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>false</autoSwitch>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2</authentication>
                <encryption>AES</encryption>
                <useOneX>true</useOneX>
            </authEncryption>
            <OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
                <cacheUserData>true</cacheUserData>
                <authMode>machineOrUser</authMode>
                <EAPConfig>
                    <EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                        <EapMethod>
                            <Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type>
                            <VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId>
                            <VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType>
                            <AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId>
                        </EapMethod>
                        <Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                            <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
                                <Type>13</Type>
                                <EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1">
                                    <CredentialsSource>
                                        <CertificateStore>
                                            <SimpleCertSelection>true</SimpleCertSelection>
                                        </CertificateStore>
                                    </CredentialsSource>
                                    <ServerValidation>
                                        <DisableUserPromptForServerValidation>true</DisableUserPromptForServerValidation>
                                        <ServerNames>$ServerName</ServerNames>
                                        <TrustedRootCA>D1EB23A46D17D68FD92564C2F1F1601764D8E349</TrustedRootCA> <!-- AAA Certificate Services -->
                                    </ServerValidation>
                                    <DifferentUsername>true</DifferentUsername>
                                    <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</PerformServerValidation>
                                    <AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</AcceptServerName>
                                    <TLSExtensions xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">
                                        <FilteringInfo xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV3">
                                            <CAHashList Enabled="true">
                                                <IssuerHash>D1EB23A46D17D68FD92564C2F1F1601764D8E349</IssuerHash> <!-- AAA Certificate Services -->
                                            </CAHashList>
                                        </FilteringInfo>
                                    </TLSExtensions>
                                </EapType>
                            </Eap>
                        </Config>
                    </EapHostConfig>
                </EAPConfig>
            </OneX>
        </security>
    </MSM>
</WLANProfile>
"@

    try {
        # Create temporary file for XML profile
        $xmlPath = [System.IO.Path]::GetTempFileName()
        $xmlProfile | Out-File -FilePath $xmlPath -Encoding UTF8
        
        # Add wireless network profile
        $result = netsh wlan add profile filename="$xmlPath" user=all
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add network profile: $result"
        }
        
        Write-Host "Successfully configured $NetworkName" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure ${NetworkName}: $_"
        throw
    }
    finally {
        if (Test-Path $xmlPath) {
            Remove-Item $xmlPath -ErrorAction SilentlyContinue
        }
    }
}

# Main execution function
function Main {
    $startTime = Get-Date
    
    Write-Host @"
Polimi WiFi Certificate Configuration Script v$ScriptVersion
================================================
"@ -ForegroundColor Green
    
    try {
        # Core functionality
        Test-WifiAdapter
        Remove-ExpiredCertificates
        Remove-ExistingConfigurations
        Install-Certificate
        
        # Configure all networks
        Set-WifiNetwork -NetworkName "polimi-protected"
        Set-WifiNetwork -NetworkName "polimi_protected"
        Set-WifiNetwork -NetworkName "eduroam"
        
        $duration = (Get-Date) - $startTime
        Write-Status "Configuration completed successfully! ($([math]::Round($duration.TotalSeconds, 1)) seconds)" -Color "Green"
        
        Write-Host @"
Important Notes:
- Certificate expires after 2 years
- Email notification sent 15 days before expiration
- Connection stops working after certificate expiration
- Visit wifi.polimi.it for certificate status/revocation
"@ -ForegroundColor Yellow
    }
    catch {
        Write-Error "Script failed: $_"
        Write-Host "Please try running the script again or configure networks manually." -ForegroundColor Yellow
        exit 1
    }
}

# Execute main function
Main