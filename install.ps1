# Step 1: Download the AndroidUSB.zip file to a temporary directory
$tempDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
$androidUSBPath = "$tempDir\AndroidUSB.zip"
Invoke-WebRequest -Uri "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" -OutFile $androidUSBPath

# Step 2: Extract the ZIP file
Expand-Archive -Path $androidUSBPath -DestinationPath $tempDir

# Step 3: Install the driver mentioned in android_winusb.inf
$infPath = "$tempDir\android_winusb.inf"
pnputil /add-driver $infPath /install

# Step 4: Download and extract the platform tools (ADB)
$adbPath = "$tempDir\platform-tools.zip"
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $adbPath
Expand-Archive -Path $adbPath -DestinationPath $tempDir

# Step 5: Run ADB and prompt user for authorization
$adbExePath = "$tempDir\platform-tools\adb.exe"
Start-Process -FilePath $adbExePath -ArgumentList "devices"
Write-Host "Please accept the authorization prompt on your device."
Write-Host "Checking for authorization..."
do {
    $result = & $adbExePath devices | Out-String
    Start-Sleep -Seconds 5
} until ($result -match "device\s*$")

# Step 6: Download and extract the MBF Launcher ZIP
$mbfLauncherPath = "$tempDir\artifact.zip"
Invoke-WebRequest -Uri "https://nightly.link/DanTheMan827/mbf-launcher/actions/runs/14140766015/artifact.zip" -OutFile $mbfLauncherPath
Expand-Archive -Path $mbfLauncherPath -DestinationPath $tempDir

# Step 7: Install the APK file
$apkPath = Get-ChildItem -Path $tempDir -Filter "*.apk" | Select-Object -ExpandProperty FullName
& $adbExePath install $apkPath
Write-Host "APK installation complete."
