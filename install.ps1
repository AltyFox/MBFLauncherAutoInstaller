Add-Type -AssemblyName System.Windows.Forms
$version = "v1.0.15"
# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MBF Launcher Installer $version"
$form.Size = New-Object System.Drawing.Size(800,500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Create Label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,10)
$label.Size = New-Object System.Drawing.Size(760,50)
$label.Font = New-Object System.Drawing.Font("Arial",14,[System.Drawing.FontStyle]::Bold)
$label.Text = "Welcome to the MBF Launcher Installer. Click 'Start' to begin."
$form.Controls.Add($label)

# Create TextBox for output
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Location = New-Object System.Drawing.Point(10,70)
$outputBox.Size = New-Object System.Drawing.Size(760,280)
$outputBox.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Regular)
$form.Controls.Add($outputBox)

# Create Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 360)
$progressBar.Size = New-Object System.Drawing.Size(760, 25)
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Create Start Button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10,400)
$startButton.Size = New-Object System.Drawing.Size(100,40)
$startButton.Text = "Start"
$isForceClosed = 0
$form.Controls.Add($startButton)



$form.Add_FormClosing({
    $global:isForceClosed = 1
    Log-Message "Stopping any ongoing processes and force closing the application."
    
    # Stop ADB server if running
    if ($adbExePath -and (Get-Process -Name "adb" -ErrorAction SilentlyContinue)) {
        Log-Message "Stopping ADB server..."
        & $adbExePath kill-server
        Log-Message "ADB server stopped."
    }

    # Clean up temporary files
    if (Test-Path $appDataDir) {
        Log-Message "Deleting temporary directory..."
        Remove-Item $appDataDir -Recurse -Force
        Log-Message "Temporary directory deleted."
    }

    Log-Message "Application force closed."
    [System.Environment]::Exit(0)
})

# Download JSON file and parse "launcher-download-url"
$jsonUrl = "https://raw.githubusercontent.com/AltyFox/MBFLauncherAutoInstaller/refs/heads/main/config.json"
$jsonFilePath = "$env:TEMP\config.json"
Invoke-WebRequest -Uri $jsonUrl -OutFile $jsonFilePath
$jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
$launcherDownloadUrl = $jsonContent."launcher-download-url"


# Get the icon of the current executable and set it as the form's icon
$currentExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($currentExePath)


# Helper function for logging
Function Log-Message($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $outputBox.AppendText("`r`n[$timestamp] $message")
    $outputBox.ScrollToCaret()
}
$appDataDir = Join-Path $env:APPDATA "mbf_tools"

if (-not (Test-Path $appDataDir)) {
    Log-Message "Creating application data directory at: $appDataDir"
    New-Item -ItemType Directory -Path $appDataDir | Out-Null
} else {
    Log-Message "Application data directory already exists at: $appDataDir"

    # Delete all contents of the directory
    Log-Message "Clearing contents of $appDataDir"
    Get-ChildItem -Path $appDataDir -Recurse -Force | Remove-Item -Force -Recurse
    Log-Message "Contents of $appDataDir have been cleared."
}


# Kill any running adb.exe processes
$adbProcesses = Get-Process -Name "adb" -ErrorAction SilentlyContinue
if ($adbProcesses) {
    Log-Message "Terminating running instances of adb.exe."
    $adbProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force }
    Log-Message "All running instances of adb.exe have been terminated."
} else {
    Log-Message "No running instances of adb.exe found."
}

# Function to download a file with progress


function DownloadFile($url, $targetFile)
{
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) # 15-second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = New-Object byte[] 10240  # 10KB buffer
   $count = $responseStream.Read($buffer, 0, $buffer.length)
   $downloadedBytes = $count

   # Ensure progress bar exists before modifying it
   if ($progressBar -ne $null) {
       $progressBar.Visible = $true
       $progressBar.Value = 0
   }

   while ($count -gt 0)
   {
        [System.Windows.Forms.Application]::DoEvents()
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes += $count

        # Update progress bar
        if ($progressBar -ne $null -and $totalLength -gt 0) {
            $progressBar.Value = [System.Math]::Min(100, ([System.Math]::Floor($downloadedBytes/1024) / $totalLength) * 100)
        }
   }

   # Hide progress bar after completion
   if ($progressBar -ne $null) {
       $progressBar.Value = 100
       Start-Sleep -Milliseconds 500  # Brief delay for UI update
       $progressBar.Visible = $false
   }

   # Cleanup
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}



# Main Installation Function
$startButton.Add_Click({
    $startButton.Enabled = $false
    
    Log-Message "Downloading the USB driver needed to access your Quest"
    $androidUSBPath = "$appDataDir\AndroidUSB.zip"


    DownloadFile "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" $androidUSBPath

    $androidUSBExtractPath = "$appDataDir\AndroidUSB"
    Log-Message "Extracting AndroidUSB.zip to: $androidUSBExtractPath"


    Expand-Archive -Path $androidUSBPath -DestinationPath $androidUSBExtractPath -Force
    Log-Message "Extraction completed."

    Log-Message "Installing USB driver from android_winusb.inf"
    $messageBox = [System.Windows.Forms.MessageBox]::Show(
        "This requires Admin privileges. You may see a prompt, please accept it. If you don't accept the prompt and install the drivers, this installer will be unable to install the MBF Launcher.",
        "Admin Privileges Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($messageBox -eq [System.Windows.Forms.DialogResult]::OK) {
        $infPath = "$androidUSBExtractPath\android_winusb.inf"
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"pnputil /add-driver `"$infPath`" /install`"" -Verb RunAs
        Log-Message "USB driver installed successfully."
    }


    $adbZipPath = "$appDataDir\platform-tools.zip"
    

    $platformToolsDir = "$appDataDir\platform-tools"
    if (Test-Path $platformToolsDir) {
    
        Log-Message "Deleting existing platform-tools directory"
        Remove-Item $platformToolsDir -Recurse -Force
    }
    

    Log-Message "Downloading platform-tools..."
    DownloadFile "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" $adbZipPath
    Expand-Archive -Path $adbZipPath -DestinationPath $appDataDir -Force
    $adbExePath = "$platformToolsDir\adb.exe"
    Log-Message "ADB located at: $adbExePath"

    Log-Message "Starting ADB server..."
    & $adbExePath start-server *> $null
    Log-Message "ADB server started."

    $apkPath = "$appDataDir\MBFLauncher.apk"


    Log-Message "Downloading MBF Launcher APK..."
    DownloadFile $launcherDownloadUrl $apkPath
    Log-Message "Download complete. APK saved to: $apkPath"

    Log-Message "Waiting for Quest device connection..."
    Log-Message "You may need to unplug and plug your Quest back into your computer if it was already connected"
    Log-Message "Be sure to accept the authorization prompt in the headset"
 

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastLogTime = 0

    do {
        $result = & $adbExePath devices | Out-String
        if ($result -match '(\w{14})\s+device') {
            $deviceID = $matches[1]
        }

        # Log "waiting" every 5 seconds
        if ($stopwatch.Elapsed.TotalSeconds -ge ($lastLogTime + 5)) {
            Log-Message "Waiting, please connect your Quest to your computer and accept the prompt in your headset.."
            $lastLogTime = [math]::Floor($stopwatch.Elapsed.TotalSeconds)
        }

        # Process Windows Forms events to keep UI responsive
        [System.Windows.Forms.Application]::DoEvents()

        Start-Sleep -Milliseconds 10  # Sleep briefly to prevent CPU hogging
        # Exit loop if force closed
        if ( $global:isForceClosed -eq 1) {
            Log-Message "Installation process aborted due to application closure."
            break
        }
        
    } while (-not $deviceID)
    
    Log-Message "Quest device detected and authorized (Device ID: $deviceID)."

    Log-Message "Uninstalling currently installed MBF Launcher if it's installed"
    & $adbExePath -s $deviceID uninstall com.dantheman827.mbflauncher

    Log-Message "Installing APK onto Quest device..."
    & $adbExePath -s $deviceID install $apkPath
    Log-Message "APK installed successfully!"

    Log-Message "Launching MBF Launcher on Quest device..."
    & $adbExePath -s $deviceID shell monkey -p com.dantheman827.mbflauncher 1 *> $null
    Log-Message "MBF Launcher started on device."

    Log-Message "Stopping ADB server..."
    & $adbExePath kill-server
    Log-Message "ADB server stopped."
    Log-Message "Deleting temporary directory"
    Remove-Item $appDataDir -Recurse -Force

    Log-Message "Installation process completed!"
    Log-Message "MBF Launcher should be active and running on your headset now."
    Log-Message "You may close this app"

})

# Show the form
[void]$form.ShowDialog()
