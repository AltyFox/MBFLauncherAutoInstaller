param(
    [switch]$Silent
)

# Only show the prompt if -Silent is NOT provided
if (-not $Silent) {
    Write-Host "`n============================================================" -ForegroundColor Yellow
    Write-Host "Before you begin, this application will request admin privileges" -ForegroundColor Cyan
    Write-Host "if you have not already granted them." -ForegroundColor Cyan
    Write-Host "`nYou will need to grant `"PowerShell`" administrator privileges." -ForegroundColor Green
    Write-Host "This is required to install the necessary driver." -ForegroundColor Green
    Write-Host "`nEnsure that no other applications on your headset are open." -ForegroundColor Magenta
    Write-Host "============================================================`n" -ForegroundColor Yellow

    do {
        $response = Read-Host "Do you understand? (y/n)"
    } while ($response -notmatch "^[yY]$")

    Write-Host "`n[INFO]: Proceeding with the installation..." -ForegroundColor Green
}

# Function to elevate the script with admin privileges
Function Elevate-Script {
    Write-Host "[INFO]: Checking for Administrator privileges..." -ForegroundColor Cyan
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "[INFO]: Script is not running as Administrator. Restarting with elevated privileges..." -ForegroundColor Cyan
        
        $tempPath = [System.IO.Path]::GetTempFileName()
        $tempScript = "$tempPath.ps1"
        Invoke-WebRequest -Uri "https://bsquest.xyz/mbflauncher" -OutFile $tempScript
        
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`" -Silent" -Verb RunAs
        
        exit
    }
}

Elevate-Script

function DownloadFile($url, $targetFile)
{
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) # 15-second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = new-object byte[] 10KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   
   $fileName = $url.Split('/') | Select -Last 1
   Write-Host "Downloading file: $fileName ($totalLength KB)"
   
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes += $count
       
       $percentComplete = ([System.Math]::Floor($downloadedBytes/1024) / $totalLength) * 100
       Write-Host -NoNewline "`rProgress: $([System.Math]::Floor($downloadedBytes/1024)) KB / $totalLength KB ($([System.Math]::Floor($percentComplete))%)   "
   }
   
   Write-Host "`nDownload complete: $fileName"
   
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
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
    Write-Host "`n`n[SECTION]: $sectionName" -ForegroundColor Yellow
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
    DownloadFile https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip $androidUSBPath
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
        DownloadFile "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"  $adbZipPath
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






Write-Host "[INFO]: Checking for authorization and listening for your Quest device..." -ForegroundColor Cyan
Write-Host "[INFO]: In your headset, be sure to 'Always allow' the debugging prompt" -ForegroundColor Cyan
Write-Host "[INFO]: You may need to disconnect your Quest from USB and reconnect it again." -ForegroundColor Cyan

do {
    $result = & $adbExePath devices | Out-String
    if ($result -match '(\w{14})\s+device') {
        $deviceID = $matches[1]
    }
    Start-Sleep -Seconds 1
} while (-not $deviceID)

Write-Host "[SUCCESS]: Device connected and authorized successfully! (Device ID: $deviceID)" -ForegroundColor Green

$adbArgs = @("-s", $deviceID)

# Example usage of adb with the selected device
# & $adbExePath shell
do {
    $result = & $adbExePath @adbArgs devices | Out-String
    Start-Sleep -Seconds 1
} while ($result -notmatch "device\s*$")
Write-Success "Device connected and authorized successfully!"

# Step 6: Download and extract the MBF Launcher ZIP
ClearSection "Downloading MBF Launcher ZIP"
$mbfLauncherPath = "$tempDir\artifact.zip"
Write-Info "Downloading MBF Launcher ZIP. This ZIP contains the MBF Launcher application, which will be installed on your Quest device."
try {
    DownloadFile "https://nightly.link/DanTheMan827/mbf-launcher/actions/runs/14140766015/artifact.zip" $mbfLauncherPath
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
    & $adbExePath @adbArgs install $apkPath
    Write-Success "APK installed successfully!"
    Write-Success "Launching the new MBF launcher.  You may disconnect your headset now.  Follow the instructions on the launcher to continue"
    Write-Success "This window will close in 10 seconds"
    & $adbExePath @adbArgs shell monkey -p com.dantheman827.mbflauncher 1 *> $null
    Start-Sleep -Seconds 10
} catch {
    Write-Error "Failed to install APK. Please ensure your device is connected and authorized."
    Start-Sleep -Seconds 10
    exit
}
