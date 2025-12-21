Clear-Host

# -----------------------
# Configuration
# -----------------------
$TorExe = "tor-exe\tor.exe"
$TorPort = 9050
$DataDir = ".\tor-data"
$OnionUrl = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"

# Ensure Tor executable exists
if (-not (Test-Path $TorExe)) {
    Write-Error "tor.exe not found at $TorExe"
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
# Fetch onion site content
# -----------------------
try {
    Write-Host "Fetching $OnionUrl via Tor..."
    curl.exe --socks5-hostname "127.0.0.1:$TorPort" -s $OnionUrl
}
finally {
    # -----------------------
    # Stop Tor process
    # -----------------------
    if ($Tor -and !$Tor.HasExited) { 
        Write-Host "Stopping Tor..."
        $Tor.Kill() 
    }
}
