


$version = "localTesting"
$debugging = $false
Add-Type -AssemblyName System.Windows.Forms

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MBF Launcher Installer $version"
$form.Size = New-Object System.Drawing.Size(800, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false


# Create Label
$label = [System.Windows.Forms.Label]@{
    Location = [System.Drawing.Point]::new(10, 10)
    Size     = [System.Drawing.Size]::new(760, 30)
    Font     = [System.Drawing.Font]::new("Arial", 12, [System.Drawing.FontStyle]::Bold)
    Text     = "Welcome to the MBF Launcher Installer. Click 'Start' to begin."
}
$form.Controls.Add($label)

# Create TextBox for output
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Location = New-Object System.Drawing.Point(10, 70)
$outputBox.Size = New-Object System.Drawing.Size(760, 280)
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
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
$startButton.Location = New-Object System.Drawing.Point(10, 400)
$startButton.Size = New-Object System.Drawing.Size(100, 40)
$startButton.Text = "Start"
$isForceClosed = 0
$form.Controls.Add($startButton)

$throbber = New-Object System.Windows.Forms.Label
$throbber.Location = New-Object System.Drawing.Point(120, 410)
$throbber.Size = New-Object System.Drawing.Size(650, 20)
$throbber.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)
$throbber.Text = ""
$form.Controls.Add($throbber)

# Create CheckBox for Debug Mode
$debugCheckBox = New-Object System.Windows.Forms.CheckBox
$debugCheckBox.Location = New-Object System.Drawing.Point(10, 40) # Moved up 10
$debugCheckBox.Size = New-Object System.Drawing.Size(200, 40)
$debugCheckBox.Text = "Testing mode, don't use unless you know what you're doing"
$debugCheckBox.Checked = $false
$form.Controls.Add($debugCheckBox)

# Create CheckBox for Force Driver Install
$forceDriverCheckBox = New-Object System.Windows.Forms.CheckBox
$forceDriverCheckBox.Location = New-Object System.Drawing.Point(220, 40) # Moved up 10
$forceDriverCheckBox.Size = New-Object System.Drawing.Size(200, 40)
$forceDriverCheckBox.Text = "Force Driver Install if already installed"
$forceDriverCheckBox.Checked = $false
$form.Controls.Add($forceDriverCheckBox)


$form.Add_FormClosing({
        $throbber.Text = ""
        $progressBar.Visible = $false
        $global:isForceClosed = 1
        Show-Message "Stopping any ongoing processes and force closing the application."
    
        # Stop ADB server if running
        if ($adbExePath -and (Get-Process -Name "adb" -ErrorAction SilentlyContinue)) {
            Show-Message "Stopping ADB server..."
            & $adbExePath kill-server
            Show-Message "ADB server stopped."
        }

        # Clean up temporary files
        if (Test-Path $appDataDir) {
            Show-Message "Deleting temporary directory..."
            Remove-Item $appDataDir -Recurse -Force
            Show-Message "Temporary directory deleted."
        }

        Show-Message "Application force closed."
        [System.Environment]::Exit(0)
    })



# Get the icon of the current executable and set it as the form's icon
$currentExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($currentExePath)
# Create a spinning throbber


# Helper function for logging
Function Show-Message($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $outputBox.AppendText("`r`n[$timestamp] $message")
    $outputBox.ScrollToCaret()
}


$appDataDir = Join-Path $env:APPDATA "mbf_tools"

if (-not (Test-Path $appDataDir)) {
    Show-Message "Creating application data directory at: $appDataDir"
    New-Item -ItemType Directory -Path $appDataDir | Out-Null
}
else {
    Show-Message "Application data directory already exists at: $appDataDir"

    # Delete all contents of the directory
    Show-Message "Clearing contents of $appDataDir"
    Get-ChildItem -Path $appDataDir -Recurse -Force | Remove-Item -Force -Recurse
    Show-Message "Contents of $appDataDir have been cleared."
}


# Kill any running adb.exe processes
$adbProcesses = Get-Process -Name "adb" -ErrorAction SilentlyContinue
if ($adbProcesses) {
    Show-Message "Terminating running instances of adb.exe."
    $adbProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force }
    Show-Message "All running instances of adb.exe have been terminated."
}
else {
    Show-Message "No running instances of adb.exe found."
}

# Function to download a file with progress
$throbber.Text = "Ready to begin! Click 'Start' to begin the installation process."

function DownloadFile($url, $targetFile) {
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) # 15-second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = New-Object byte[] 10240  # 10KB buffer
    $count = $responseStream.Read($buffer, 0, $buffer.length)
    $downloadedBytes = $count

    # Ensure progress bar exists before modifying it
    if ($null -ne $progressBar) {
        $progressBar.Visible = $true
        $progressBar.Value = 0
    }

    while ($count -gt 0) {
        [System.Windows.Forms.Application]::DoEvents()
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes += $count

        # Update progress bar
        if ($null -ne $progressBar -and $totalLength -gt 0) {
            $progressBar.Value = [System.Math]::Min(100, ([System.Math]::Floor($downloadedBytes / 1024) / $totalLength) * 100)
        }
    }

    # Hide progress bar after completion
    if ($null -ne $progressBar) {
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
        # Update form title based on checkbox states
        $debugging = $debugCheckBox.Checked
        $forceDriverInstall = $forceDriverCheckBox.Checked
        if ($debugging) {
            $form.Text += " (Debug Mode)"
        }
        if ($forceDriverInstall) {
            $form.Text += " (Force Driver Install)"
        }
        $startButton.Enabled = $false
        $driverRegistryKey = "HKCU:\Software\MBFLauncherAutoInstaller"
        $driverRegistryValueName = "USBDriverInstalled"

        if (-not (Test-Path $driverRegistryKey)) {
            New-Item -Path $driverRegistryKey -Force | Out-Null
        }

        $isDriverInstalled = Get-ItemProperty -Path $driverRegistryKey -Name $driverRegistryValueName -ErrorAction SilentlyContinue
        if ($forceDriverInstall) {
            $isDriverInstalled = $false
        }

        if (-not $isDriverInstalled) {
            $throbber.Text = "Installing USB Driver.."
            Show-Message "Downloading the USB driver needed to access your Quest"
            $androidUSBPath = "$appDataDir\AndroidUSB.zip"

            DownloadFile "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" $androidUSBPath

            $androidUSBExtractPath = "$appDataDir\AndroidUSB"
            Show-Message "Extracting AndroidUSB.zip to: $androidUSBExtractPath"

            Expand-Archive -Path $androidUSBPath -DestinationPath $androidUSBExtractPath -Force
            Show-Message "Extraction completed."

            Show-Message "Installing USB driver from android_winusb.inf"
            $messageBox = [System.Windows.Forms.MessageBox]::Show(
                "This requires Admin privileges. You may see a prompt, please accept it. If you don't accept the prompt and install the drivers, this installer will be unable to install the MBF Launcher.",
                "Admin Privileges Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

            if ($messageBox -eq [System.Windows.Forms.DialogResult]::OK) {
                $infPath = "$androidUSBExtractPath\android_winusb.inf"
                Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"pnputil /add-driver `"$infPath`" /install`"" -Verb RunAs | Wait-Process
                Show-Message "USB driver installed successfully."

                # Mark the driver as installed in the registry
                Set-ItemProperty -Path $driverRegistryKey -Name $driverRegistryValueName -Value $true
            }
        }
        else {
            Show-Message "USB driver is already installed. Skipping installation."
        }


        $adbZipPath = "$appDataDir\platform-tools.zip"
    
        $throbber.Text = "Downloading ADB binaries to talk to your Quest"
        $platformToolsDir = "$appDataDir\platform-tools"
        if (Test-Path $platformToolsDir) {
    
            Show-Message "Deleting existing platform-tools directory"
            Remove-Item $platformToolsDir -Recurse -Force
        }
    

        Show-Message "Downloading platform-tools..."
        DownloadFile "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" $adbZipPath
        Expand-Archive -Path $adbZipPath -DestinationPath $appDataDir -Force
        $adbExePath = "$platformToolsDir\adb.exe"
        Show-Message "ADB located at: $adbExePath"

        Show-Message "Starting ADB server..."
        & $adbExePath start-server *> $null
        Show-Message "ADB server started."


        $throbber.Text = "Fetching latest MBF Launcher APK from GitHub"

        $apkPath = "$appDataDir\MBFLauncher.apk"
        # Fetch the latest release information from the GitHub API
        $repoOwner = "DanTheMan827"
        $repoName = "mbf-launcher"
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases"

        # Set User-Agent header to avoid 403 errors
        $headers = @{
            "User-Agent"           = "MBFLauncherAutoInstaller"
            "Accept"               = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

        Show-Message "Fetching all releases information from GitHub..."
        try {
            $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
            $latestRelease = $releases | Sort-Object { $_.published_at } -Descending | Select-Object -First 1
            $latestReleaseUrl = $latestRelease.assets | Where-Object { $_.name -like "*.apk" } | Select-Object -ExpandProperty browser_download_url
            if (-not $latestReleaseUrl) {
                throw "No APK asset found in the latest release."
            }
            $launcherDownloadUrl = $latestReleaseUrl
            Show-Message "Latest release APK URL: $launcherDownloadUrl"
        }
        catch {
            Show-Message "Error fetching the releases: $_"
            throw
        }

        Show-Message "Downloading MBF Launcher APK..."
        DownloadFile $launcherDownloadUrl $apkPath
        Show-Message "Download complete. APK saved to: $apkPath"

        Show-Message "Waiting for Quest device connection..."
        Show-Message "You may need to unplug and plug your Quest back into your computer if it was already connected"
        Show-Message "Be sure to accept the authorization prompt in the headset"
    
        $throbber.Text = "Waiting for Quest device connection..."
    
        # Create a text field for IP:PORT input
        $ipTextBox = New-Object System.Windows.Forms.TextBox
        $ipTextBox.Location = New-Object System.Drawing.Point(430, 50) # Positioned to the right of the checkboxes
        $ipTextBox.Size = New-Object System.Drawing.Size(200, 20)
        $ipTextBox.Visible = $false
        $form.Controls.Add($ipTextBox)

        if ($debugCheckBox.Checked) {
            $ipTextBox.Visible = $true
            $ipTextBox.Focus()
        }
        else {
            $ipTextBox.Visible = $false
        }

        # Handle Enter key press in the IP text box
        $ipTextBox.Add_KeyDown({
                if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                    $ip = $ipTextBox.Text
                    if ($ip -match '^\d{1,3}(\.\d{1,3}){3}:\d+$') {
                        Show-Message "Attempting to connect to device at $ip..."
                        $connectResult = & $adbExePath connect $ip | Out-String
                        Show-Message $connectResult
                        if ($connectResult -match 'connected to') {
                            Show-Message "Successfully connected to $ip."
                            $debugging = $true
                            $ipTextBox.Visible = $false
                        }
                        else {
                            Show-Message "Failed to connect to $ip. Please check the IP:PORT and try again."
                        }
                    }
                    else {
                        Show-Message "Invalid IP:PORT format. Please enter a valid IP:PORT."
                    }
                }
            })

        do {

            $result = & $adbExePath devices | Out-String
            if ($debugging) {
                $lines = $result -split "`r`n"
                if ($lines.Count -gt 1 -and $lines[1] -match '^\s*(\S+)') {
                    $deviceID = $matches[1]
                }
            }
            else {
                if ($result -match '(\w{14})\s+device') {
                    $deviceID = $matches[1]
                }
            }      
            # Update the progress bar to simulate an indeterminate scrolling effect
            if ($progressBar.Style -ne "Marquee") {
                $progressBar.Style = "Marquee"
                $progressBar.MarqueeAnimationSpeed = 30
                $progressBar.Visible = $true
            }
        
            # Process Windows Forms events to keep UI responsive
            [System.Windows.Forms.Application]::DoEvents()

            # Remove the throbber when the device is found
            if ($deviceID) {
                $progressBar.Visible = $false
                $progressBar.Style = "Continuous"
            }

            # Process Windows Forms events to keep UI responsive
            [System.Windows.Forms.Application]::DoEvents()

            Start-Sleep -Milliseconds 10  # Sleep briefly to prevent CPU hogging
            # Exit loop if force closed
            if ( $global:isForceClosed -eq 1) {
                Show-Message "Installation process aborted due to application closure."
                break
            }   
        
        } while (-not $deviceID)
    
        Show-Message "Quest device detected and authorized (Device ID: $deviceID)."
    
    
        $throbber.Text = "Installing MBF Launcher to your Quest device"
        Show-Message "Uninstalling currently installed MBF Launcher if it's installed"
        & $adbExePath -s $deviceID uninstall com.dantheman827.mbflauncher

        Show-Message "Installing APK onto Quest device..."
        & $adbExePath -s $deviceID install $apkPath
        Show-Message "APK installed successfully!"

        Show-Message "Granting necessary permissions to the MBF Launcher..."
        & $adbExePath -s $deviceID shell pm grant com.dantheman827.mbflauncher android.permission.WRITE_SECURE_SETTINGS
        & $adbExePath -s $deviceID shell pm grant com.dantheman827.mbflauncher android.permission.READ_LOGS
        Show-Message "Permissions granted successfully."

        Show-Message "Launching MBF Launcher on Quest device..."
        & $adbExePath -s $deviceID shell monkey -p com.dantheman827.mbflauncher 1 *> $null
        Show-Message "MBF Launcher started on device."

        Show-Message "Switching ADB to TCP/IP mode on port 5555..."
        & $adbExePath -s $deviceID tcpip 5555
        Show-Message "ADB is now in TCP/IP mode on port 5555."
        Show-Message "This should make MBF Launcher auto connect to itself quickly."

        $throbber.Text = "Finishing up..."
        Show-Message "Stopping ADB server..."
        & $adbExePath kill-server
        Show-Message "ADB server stopped."


        Show-Message "Deleting temporary directory"
        Remove-Item $appDataDir -Recurse -Force

        Show-Message "Installation process completed!"
        Show-Message "If you need help, ask in #quest-standalone-help in BSMG. Join the Discord at: http://discord.gg/beatsabermods"
        Show-Message "You may also DM @alteran for assistance."
        Show-Message "MBF Launcher should be active and running on your headset now."
        Show-Message "You will see more ADB authorization prompts in the headset, please accept them."
        Show-Message "You can now close this window."

        $throbber.Text = ""

    })

# Show the form
[void]$form.ShowDialog()
