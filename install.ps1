# Ensure the script runs with elevated privileges
Write-Host "`n`n`n`n`n`n`n`n"
Function Elevate-Script {
    Clear-Host
    Add-Newlines
    Write-Host "[INFO]: Checking for Administrator privileges..." -ForegroundColor Cyan
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Add-Newlines
        Write-Host "[INFO]: Script is not running as Administrator. Restarting with elevated privileges..." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command iex(iwr bsquest.xyz/mbflauncher)" -Verb RunAs
        exit
    }
}

Elevate-Script

Function Check-Quest-Device {
    Write-Info "Checking for connected devices..."
    do {
        $deviceList = & $adbExePath devices | Select-String "device"
        $devices = $deviceList -match "^([A-Za-z0-9]+)\s+device$"
        if ($devices.Count -gt 1) {
            Write-Error "Multiple Android devices detected. Please disconnect all devices except your Quest and press Enter to continue."
            Read-Host "Press Enter to retry"
        }
        Start-Sleep -Seconds 1
    } while ($devices.Count -gt 1)
    Write-Success "Quest device detected and ready!"
}



# Helper functions for clean output
Function Write-Info($message) {
    Write-Host "[INFO]: $message" -ForegroundColor Cyan
}

Function Write-Success($message) {
    Write-Host "[SUCCESS]: $message" -ForegroundColor Green
}

Function Write-Error($message) {
    Write-Host "[ERROR]: $message" -ForegroundColor Red
}

Function ClearSection($sectionName) {
    Write-Host "[SECTION]: $sectionName" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# Function to check if adb.exe is available on PATH
Function Check-ADB {
    Write-Info "Checking if adb.exe is available on the system PATH..."
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) {
        Write-Success "adb.exe found on PATH at: $($adbCommand.Source)"
        return $adbCommand.Source
    } else {
        Write-Info "adb.exe not found on PATH. Proceeding to download ADB..."
        return $null
    }
}


# Main Script Logic

# Step 1: Download the AndroidUSB.zip file to a temporary directory
ClearSection "Downloading AndroidUSB.zip File"
$tempDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
$androidUSBPath = "$tempDir\AndroidUSB.zip"

Write-Info "Downloading AndroidUSB.zip file. This ZIP contains the necessary driver to enable communication between your PC and Quest device."
try {
    Invoke-WebRequest -Uri "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" -OutFile $androidUSBPath
    Write-Success "Downloaded AndroidUSB.zip successfully!"
} catch {
    Write-Error "Failed to download AndroidUSB.zip file. Please check your internet connection or the URL."
    exit
}

# Step 2: Extract the ZIP file (replace files if they already exist)
ClearSection "Extracting AndroidUSB.zip File"
Write-Info "Extracting AndroidUSB.zip file..."
try {
    Expand-Archive -Path $androidUSBPath -DestinationPath $tempDir -Force
    Write-Success "Extracted AndroidUSB.zip successfully!"
} catch {
    Write-Error "Failed to extract AndroidUSB.zip file."
    exit
}

# Step 3: Install the driver mentioned in android_winusb.inf
ClearSection "Installing Driver"
$infPath = "$tempDir\android_winusb.inf"
Write-Info "Installing driver from android_winusb.inf. This driver is required for your PC to communicate with the Quest device effectively."
try {
    pnputil /add-driver $infPath /install
    Write-Success "Driver installed successfully!"
} catch {
    Write-Error "Failed to install the driver. Please ensure you have administrator privileges."
    exit
}

# Step 4: Check if adb.exe exists or download and extract ADB
ClearSection "Checking or Downloading ADB"
$adbExePath = Check-ADB
if (-not $adbExePath) {
    $adbZipPath = "$tempDir\platform-tools.zip"
    Write-Info "Downloading platform tools (ADB). This tool is necessary for communicating with your Quest device and installing the MBF Launcher application."
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $adbZipPath
        Write-Success "Downloaded platform tools (ADB) successfully!"
    } catch {
        Write-Error "Failed to download platform tools (ADB)."
        exit
    }

    ClearSection "Extracting Platform Tools (ADB)"
    Write-Info "Extracting platform tools (ADB)..."
    try {
        Expand-Archive -Path $adbZipPath -DestinationPath $tempDir -Force
        Write-Success "Extracted platform tools (ADB) successfully!"
        $adbExePath = "$tempDir\platform-tools\adb.exe"
    } catch {
        Write-Error "Failed to extract platform tools (ADB)."
        exit
    }
}

# Step 5: Start ADB server, disconnect/reconnect Quest, check authorization, and listen for device
ClearSection "Starting ADB Server"
Write-Info "Starting ADB server..."
try {
    & $adbExePath start-server
    Write-Success "ADB server started successfully!"
} catch {
    Write-Error "Failed to start ADB server."
    exit
}

ClearSection "Reconnect Quest Device"
Write-Info "Please unplug your Quest device from your PC and then plug it back in."
Write-Info "Once you have reconnected the device, type 'y' and press Enter to continue."
do {
    $input = Read-Host "Have you reconnected the device? (y/n)"
} while ($input.ToLower() -ne "y")

Check-Quest-Device

Write-Info "Checking for authorization and listening for your Quest device..."
do {
    $result = & $adbExePath devices | Out-String
    Start-Sleep -Seconds 5
} while ($result -notmatch "device\s*$")
Write-Success "Device connected and authorized successfully!"

# Step 6: Download and extract the MBF Launcher ZIP
ClearSection "Downloading MBF Launcher ZIP"
$mbfLauncherPath = "$tempDir\artifact.zip"
Write-Info "Downloading MBF Launcher ZIP. This ZIP contains the MBF Launcher application, which will be installed on your Quest device."
try {
    Invoke-WebRequest -Uri "https://nightly.link/DanTheMan827/mbf-launcher/actions/runs/14140766015/artifact.zip" -OutFile $mbfLauncherPath
    Write-Success "Downloaded MBF Launcher ZIP successfully!"
} catch {
    Write-Error "Failed to download MBF Launcher ZIP."
    exit
}

ClearSection "Extracting MBF Launcher ZIP"
Write-Info "Extracting MBF Launcher ZIP..."
try {
    Expand-Archive -Path $mbfLauncherPath -DestinationPath $tempDir -Force
    Write-Success "Extracted MBF Launcher ZIP successfully!"
} catch {
    Write-Error "Failed to extract MBF Launcher ZIP."
    exit
}

# Step 7: Install the APK file
ClearSection "Installing APK"
Write-Info "Installing APK file. This is the MBF Launcher application, which enables new functionality on your Quest device."
$apkPath = Get-ChildItem -Path $tempDir -Filter "*.apk" | Select-Object -ExpandProperty FullName
try {
    Check-Quest-Device
    & $adbExePath install $apkPath
    Write-Success "APK installed successfully!"
    & $adbExePath shell monkey -p com.dantheman827.mbflauncher 1
} catch {
    Write-Error "Failed to install APK. Please ensure your device is connected and authorized."
    exit
}

ClearSection "Process Complete"
Write-Info "All steps executed successfully."
