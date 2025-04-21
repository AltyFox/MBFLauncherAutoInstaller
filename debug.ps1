# Delete test.exe if it exists
if (Test-Path "test.exe") {
    Remove-Item -Path "test.exe" -Force
}

# Convert install.ps1 to test.exe using ps2exe
ps2exe "install.ps1" "test.exe" -noConsole

# Run the generated test.exe
Start-Process -FilePath "test.exe" -Wait