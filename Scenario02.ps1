# Define target directory and file
$OutputDir = "C:\PurpleLab"
$OutputFile = Join-Path $OutputDir "UserEnvironmentVariables.txt"
 
# Create directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}
 
# Get user environment variables and save to file
[System.Environment]::GetEnvironmentVariables("User") |
    Sort-Object Name |
    Out-File -FilePath $OutputFile -Encoding UTF8
 
Write-Host "User environment variables have been saved to: $OutputFile"
 
