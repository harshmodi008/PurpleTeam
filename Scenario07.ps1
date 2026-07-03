#Requires -Version 5.1

$ErrorActionPreference = "Stop"

#=========================================================
# Configuration
#=========================================================

$GitHubZipUrl = "https://github.com/harshmodi008/PurpleTeam/archive/refs/heads/main.zip"
$PasswordUrl  = "https://raw.githubusercontent.com/harshmodi008/PurpleTeam/refs/heads/main/password.txt"

$SevenZipInstallerUrl = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.exe"

$WorkingFolder = Join-Path $env:TEMP "PurpleTeam"
$RepoZip       = Join-Path $WorkingFolder "PurpleTeam.zip"
$RepoFolder    = Join-Path $WorkingFolder "Repository"
$ExtractFolder = Join-Path $WorkingFolder "Extracted"
$Installer     = Join-Path $WorkingFolder "7zip.exe"

$Cleanup = $true

#=========================================================
# Helper Functions
#=========================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO ] $Message" -ForegroundColor Cyan
}

function Write-Good {
    param([string]$Message)
    Write-Host "[ OK  ] $Message" -ForegroundColor Green
}

function Write-Bad {
    param([string]$Message)
    Write-Host "[FAIL ] $Message" -ForegroundColor Red
}

function Invoke-Download {

    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $Retries = 3

    for ($i = 1; $i -le $Retries; $i++) {

        try {

            Invoke-WebRequest `
                -Uri $Url `
                -OutFile $Destination

            return

        }
        catch {

            if ($i -eq $Retries) {
                throw
            }

            Write-Host "Retrying download ($i/$Retries)..."
            Start-Sleep 2
        }
    }
}

#=========================================================
# Prepare folders
#=========================================================

Write-Info "Preparing working folder..."

Remove-Item $WorkingFolder -Force -Recurse -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $WorkingFolder | Out-Null
New-Item -ItemType Directory -Path $RepoFolder | Out-Null
New-Item -ItemType Directory -Path $ExtractFolder | Out-Null

#=========================================================
# Download repository
#=========================================================

Write-Info "Downloading GitHub repository..."

Invoke-Download `
    -Url $GitHubZipUrl `
    -Destination $RepoZip

Write-Good "Repository downloaded."

#=========================================================
# Extract repository
#=========================================================

Write-Info "Extracting repository..."

Expand-Archive `
    -Path $RepoZip `
    -DestinationPath $RepoFolder `
    -Force

Write-Good "Repository extracted."

#=========================================================
# Download password
#=========================================================

Write-Info "Downloading password..."

$Password = (
    Invoke-WebRequest `
        -Uri $PasswordUrl
).Content.Trim()

if ([string]::IsNullOrWhiteSpace($Password)) {
    throw "Password is empty."
}

Write-Good "Password retrieved."

#=========================================================
# Locate multipart ZIP
#=========================================================

Write-Info "Searching for multipart archive..."

$ZipFile = Get-ChildItem `
    -Path $RepoFolder `
    -Recurse `
    -Filter *.zip |
    Select-Object -First 1

if (!$ZipFile) {
    throw "No ZIP archive found."
}

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipFile.Name)

Write-Good "Found archive: $($ZipFile.Name)"

#=========================================================
# Verify split parts
#=========================================================

$Folder = $ZipFile.DirectoryName

$Parts = Get-ChildItem `
    -Path $Folder `
    -Filter "$BaseName.z*"

if ($Parts.Count -eq 0) {
    throw "No split archive parts (.z01, .z02, ...) were found."
}

Write-Good "$($Parts.Count) archive part(s) detected."

#=========================================================
# Locate 7-Zip
#=========================================================

$SevenZip = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "$env:ProgramFiles(x86)\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

#=========================================================
# Install 7-Zip if necessary
#=========================================================

if (!$SevenZip) {

    Write-Info "7-Zip not installed."

    Write-Info "Downloading 7-Zip..."

    Invoke-Download `
        -Url $SevenZipInstallerUrl `
        -Destination $Installer

    Write-Info "Installing 7-Zip..."

    Start-Process `
        -FilePath $Installer `
        -ArgumentList "/S" `
        -Wait

    $SevenZip = "$env:ProgramFiles\7-Zip\7z.exe"

    if (!(Test-Path $SevenZip)) {

        $SevenZip = "$env:ProgramFiles(x86)\7-Zip\7z.exe"

        if (!(Test-Path $SevenZip)) {
            throw "7-Zip installation failed."
        }
    }

    Write-Good "7-Zip installed."
}
else {

    Write-Good "Using existing 7-Zip installation."
}

#=========================================================
# Extract archive
#=========================================================

Write-Info "Extracting archive..."

& $SevenZip x `
    $ZipFile.FullName `
    "-p$Password" `
    "-o$ExtractFolder" `
    -y

if ($LASTEXITCODE -ne 0) {
    throw "Extraction failed. Check the password or archive integrity."
}

Write-Good "Archive extracted successfully."

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Extraction Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output Folder:"
Write-Host "  $ExtractFolder" -ForegroundColor Yellow

#=========================================================
# Cleanup
#=========================================================

if ($Cleanup) {

    Write-Info "Cleaning temporary files..."

    Remove-Item $RepoZip -Force -ErrorAction SilentlyContinue
    Remove-Item $Installer -Force -ErrorAction SilentlyContinue

    Write-Good "Cleanup completed."
}
