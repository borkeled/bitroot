$repoOwner = "borkeled"          
$repoName = "bitroot"                 
$appName = "Bitware"
$exeName = "bitware.exe"
$installPath = "$env:LOCALAPPDATA\Bitware"
$versionFile = "$installPath\version.txt"

# Check/Install VC++ Runtime
function Install-VCRuntime {
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

# get Latest Version from GitHub
function Get-LatestRelease {
    # first try to get the latest release
    $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
    
    Write-Host "[DEBUG] Trying API URL: $apiUrl" -ForegroundColor DarkGray
    
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"="BitwareInstaller"}
        Write-Host "[DEBUG] Found latest release: $($release.tag_name)" -ForegroundColor DarkGray
        return $release
    } catch {
        Write-Host "[DEBUG] No 'latest' release found, getting all releases..." -ForegroundColor Yellow
        
        # if no "latest" release get all releases and pick the first one
        $allReleasesUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases"
        try {
            $releases = Invoke-RestMethod -Uri $allReleasesUrl -Headers @{"User-Agent"="BitwareInstaller"}
            
            if ($releases.Count -eq 0) {
                Write-Host "Error: No releases found in repository!" -ForegroundColor Red
                Write-Host "Make sure you've created a release on GitHub" -ForegroundColor Red
                exit 1
            }
            
            # Get the first most recent release
            $release = $releases[0]
            Write-Host "[DEBUG] Found release: $($release.tag_name)" -ForegroundColor DarkGray
            Write-Host "[DEBUG] Release name: $($release.name)" -ForegroundColor DarkGray
            Write-Host "[DEBUG] Assets count: $($release.assets.Count)" -ForegroundColor DarkGray
            
            # list all assets for debugging
            Write-Host "[DEBUG] Available assets:" -ForegroundColor DarkGray
            foreach ($asset in $release.assets) {
                Write-Host "  - $($asset.name) ($('{0:N2}' -f ($asset.size/1MB)) MB)" -ForegroundColor DarkGray
            }
            
            return $release
        } catch {
            Write-Host "Error: Could not reach GitHub API" -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# main Installation
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
    Write-Host "Looking for: $exeName" -ForegroundColor Red
    Write-Host "Available files:" -ForegroundColor Yellow
    foreach ($asset in $release.assets) {
        Write-Host "  - $($asset.name)" -ForegroundColor Yellow
    }
    Write-Host "" -ForegroundColor Red
    Write-Host "Make sure you uploaded $exeName to the GitHub release!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Downloading $exeName..." -ForegroundColor Yellow
Write-Host "[DEBUG] Download URL: $($exeAsset.browser_download_url)" -ForegroundColor DarkGray
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
