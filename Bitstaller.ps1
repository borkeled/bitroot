$repoOwner = "borkeled"          # Change this
$repoName = "bitroot"                 # Change this
$appName = "Bitware"
$exeName = "bitware.exe"
$installPath = "$env:LOCALAPPDATA\Bitware"
$versionFile = "$installPath\version.txt"

# Check/Install VC++ Runtime
function Install-VCRuntime {
    # check if VC++ Runtime is installed by looking for the DLL
    $vcInstalled = Test-Path "$env:SystemRoot\System32\vcruntime140.dll"
    
    if (-not $vcInstalled) {
        Write-Host "Installing Visual C++ Runtime..." -ForegroundColor Yellow
        
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
        
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
        Start-Process -Wait -FilePath $vcInstaller -ArgumentList "/install", "/quiet", "/norestart"
        Remove-Item $vcInstaller -ErrorAction SilentlyContinue
        
        Write-Host "VC++ Runtime installed!" -ForegroundColor Green
    } else {
        Write-Host "VC++ Runtime already installed" -ForegroundColor Gray
    }
}


# Get Latest Version from GitHub
function Get-LatestRelease {
    $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"="BitwareInstaller"}
        return $release
    } catch {
        Write-Host "Error: Could not reach GitHub. Check your internet connection." -ForegroundColor Red
        exit 1
    }
}

# Main Installation
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "    $appName Installer" -ForegroundColor Cyan  
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# check VC++ Runtime
Install-VCRuntime

# get latest release info
Write-Host "Checking for latest version..." -ForegroundColor Yellow
$release = Get-LatestRelease
$latestVersion = $release.tag_name
Write-Host "Latest version: $latestVersion" -ForegroundColor Cyan

# check current version
$currentVersion = "none"
if (Test-Path $versionFile) {
    $currentVersion = Get-Content $versionFile -Raw
    $currentVersion = $currentVersion.Trim()
}

if ($currentVersion -eq $latestVersion) {
    Write-Host ""
    Write-Host "You already have the latest version!" -ForegroundColor Green
    Write-Host "Location: $installPath\$exeName"
    Write-Host ""
    pause
    exit 0
}

if ($currentVersion -ne "none") {
    Write-Host "Updating from $currentVersion to $latestVersion..." -ForegroundColor Yellow
} else {
    Write-Host "Installing $latestVersion..." -ForegroundColor Yellow
}

# create install directory
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath | Out-Null
}

# kill running instance if updating
$running = Get-Process -Name ($exeName -replace '\.exe$','') -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Closing running instance..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# download the exe
$exeAsset = $release.assets | Where-Object { $_.name -eq $exeName }
if (-not $exeAsset) {
    Write-Host "Error: Could not find $exeName in release assets" -ForegroundColor Red
    exit 1
}

Write-Host "Downloading $exeName..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $exeAsset.browser_download_url -OutFile "$installPath\$exeName"

# download any additional files
foreach ($asset in $release.assets) {
    if ($asset.name -ne $exeName) {
        Write-Host "Downloading $($asset.name)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$installPath\$($asset.name)"
    }
}

# save version
$latestVersion | Out-File $versionFile -NoNewline -Encoding UTF8

# create shortcuts
Write-Host "Creating shortcuts..." -ForegroundColor Yellow

# desktop shortcut
$shell = New-Object -ComObject WScript.Shell
$desktopShortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\$appName.lnk")
$desktopShortcut.TargetPath = "$installPath\$exeName"
$desktopShortcut.WorkingDirectory = $installPath
$desktopShortcut.Save()

# start menu shortcut
$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$startShortcut = $shell.CreateShortcut("$startMenuPath\$appName.lnk")
$startShortcut.TargetPath = "$installPath\$exeName"
$startShortcut.WorkingDirectory = $installPath
$startShortcut.Save()

# done
Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "    Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to: $installPath" -ForegroundColor White
Write-Host "Desktop shortcut created" -ForegroundColor White
Write-Host ""

$launch = Read-Host "Launch $appName now? (y/n)"
if ($launch -eq 'y') {
    Start-Process "$installPath\$exeName"
}