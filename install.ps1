param(
    [switch]$Silent
)

Write-Host "Starting the MBF Launcher installer script." -ForegroundColor Green

add-type -name user32 -namespace win32 -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
$consoleHandle = (get-process -id $pid).mainWindowHandle

# load your form or whatever ...

# hide console
[win32.user32]::showWindow($consoleHandle, 0)

Add-Type -AssemblyName System.Windows.Forms

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MBF Launcher Installer"
$form.Size = New-Object System.Drawing.Size(800,500)
$form.StartPosition = "CenterScreen"

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
$form.Controls.Add($startButton)





# Only show the prompt if -Silent is NOT provided
if (-not $Silent) {
    $adminWarning = [System.Windows.Forms.MessageBox]::Show(
        "Before you begin, this application will request admin privileges if you have not already granted them.`n`n" +
        "You may see a prompt to allow admin privledges to Windows PowerShell.  Grant the permissions or this application won't be able to install the nessecary drivers.`n`n" +
        "Ensure that no other applications on your headset are open.",
        "Administrator Privileges Required",
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    # Exit if user clicks 'Cancel'
    if ($adminWarning -ne [System.Windows.Forms.DialogResult]::OK) {
        exit
    }
}




Function Elevate-Script {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {        
        $tempPath = [System.IO.Path]::GetTempFileName()
        $tempScript = "$tempPath.ps1"
        Invoke-WebRequest -Uri "https://bsquest.xyz/mbflauncher" -OutFile $tempScript
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`" -Silent" -Verb RunAs
        exit
    }
}

Elevate-Script


# Helper function for logging
Function Log-Message($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $outputBox.AppendText("`r`n[$timestamp] $message")
    $outputBox.ScrollToCaret()
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
    
    $tempDir = [System.IO.Path]::GetTempPath()
    Log-Message "Downloading the USB driver needed to access your Quest"
    $androidUSBPath = "$tempDir\AndroidUSB.zip"
    DownloadFile "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" $androidUSBPath
    
    Log-Message "Extracting AndroidUSB.zip to: $tempDir\AndroidUSB"
    Expand-Archive -Path $androidUSBPath -DestinationPath $tempDir\AndroidUSB -Force
    Log-Message "Extraction completed."
    
    Log-Message "Installing USB driver from android_winusb.inf"
    $infPath = "$tempDir\AndroidUSB\android_winusb.inf"
    pnputil /add-driver $infPath /install
    Log-Message "USB driver installed successfully."
    
    Log-Message "Checking if adb.exe is available..."
    $adbExePath = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
    if (-not $adbExePath) {
        $adbZipPath = "$tempDir\platform-tools.zip"
        Log-Message "ADB not found. Downloading platform-tools..."
        DownloadFile "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" $adbZipPath
        Expand-Archive -Path $adbZipPath -DestinationPath $tempDir -Force
        $adbExePath = "$tempDir\platform-tools\adb.exe"
    }
    Log-Message "ADB located at: $adbExePath"
    
    Log-Message "Starting ADB server..."
    & $adbExePath start-server
    Log-Message "ADB server started."
    
    Log-Message "Waiting for Quest device connection..."
    Log-Message "You may need to unplug and plug your Quest back into your computer if it was already connected"
    Log-Message "Be sure to accept the authorization prompt in the headset"
    do {
        $result = & $adbExePath devices | Out-String
        if ($result -match '(\w{14})\s+device') {
            $deviceID = $matches[1]
        }
        Start-Sleep -Seconds 1
    } while (-not $deviceID)
    Log-Message "Quest device detected and authorized (Device ID: $deviceID)."
    
    $mbfLauncherPath = "$tempDir\artifact.zip"
    Log-Message "Downloading MBF Launcher ZIP..."
    DownloadFile "https://nightly.link/DanTheMan827/mbf-launcher/actions/runs/14140766015/artifact.zip" $mbfLauncherPath
    
    Log-Message "Extracting MBF Launcher ZIP..."
    Expand-Archive -Path $mbfLauncherPath -DestinationPath $tempDir\mbf-launcher -Force
    Log-Message "MBF Launcher extracted successfully."
    
    Log-Message "Searching for APK file in extracted contents..."
    $apkPath = Get-ChildItem -Path $tempDir\mbf-launcher -Filter "*.apk" | Select-Object -ExpandProperty FullName
    Log-Message "Found APK: $apkPath"
    
    Log-Message "Installing APK onto Quest device..."
    & $adbExePath -s $deviceID install $apkPath
    Log-Message "APK installed successfully!"
    
    Log-Message "Launching MBF Launcher on Quest device..."
    & $adbExePath -s $deviceID shell monkey -p com.dantheman827.mbflauncher 1 *> $null
    Log-Message "MBF Launcher started on device."
    
    Log-Message "Stopping ADB server..."
    & $adbExePath kill-server
    Log-Message "ADB server stopped."
    
    Log-Message "Installation process completed!"
    Log-Message "MBF Launcher should be active and running on your headset now."
    Log-Message "You may close this app"
})

# Show the form
[void]$form.ShowDialog()
