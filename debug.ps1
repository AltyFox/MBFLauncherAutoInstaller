# Delete test.exe if it exists
if (Test-Path "debug.exe") {
    Remove-Item -Path "debug.exe" -Force
}

# Convert install.ps1 to test.exe using ps2exe
ps2exe "install.ps1" "debug.exe" -noConsole

# Run the generated test.exe
Start-Process -FilePath "debug.exe" -Wait