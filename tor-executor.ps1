Clear-Host
$ErrorActionPreference = "Stop"

# -----------------------
# Configuration
# -----------------------
$P           = $PSScriptRoot
$BaseDir     = Join-Path $P "tor-exe"
$Archive     = Join-Path $P "tor-expert.tar.gz"
$TorExe      = Join-Path $BaseDir "tor.exe"
$DataDir     = Join-Path $P "tor-data"
$OnionUrl    = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"
$TorUrl      = "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.3/tor-expert-bundle-windows-x86_64-15.0.3.tar.gz"
$TorPort     = 9050

# curl timeouts (seconds)
$CurlConnectTimeout = 15
$CurlMaxTime = 60

# wait settings
$PortWaitTimeoutSec = 60
$PortPollIntervalSec = 1

# -----------------------
# Helper: robust curl
# -----------------------
function Run-Curl {
    param([string[]] $Args, [switch] $VerboseOutput)
    $common = @(
        "--socks5-hostname", "127.0.0.1:$TorPort",
        "--connect-timeout", $CurlConnectTimeout.ToString(),
        "--max-time", $CurlMaxTime.ToString(),
        "--fail"
    )
    $fullArgs = $common + $Args

    if ($VerboseOutput) {
        Write-Host "[DEBUG] curl.exe " ($fullArgs -join " ")
        & curl.exe @fullArgs 2>&1 | Out-Host
    } else {
        & curl.exe @fullArgs | Out-Null
    }

    return $LASTEXITCODE
}

# -----------------------
# Helper: wait for local port
# -----------------------
function Wait-For-Port {
    param([string] $Host="127.0.0.1", [int] $Port, [int] $TimeoutSec=60, [int] $PollIntervalSec=1)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $res = Test-NetConnection -ComputerName $Host -Port $Port -WarningAction SilentlyContinue
        if ($res.TcpTestSucceeded) { return $true }
        Start-Sleep -Seconds $PollIntervalSec
    }
    return $false
}

# -----------------------
# Main
# -----------------------
$torProcess = $null
$uaBrowser = "Mozilla/5.0 (Windows NT 10.0; rv:128.0) Gecko/20100101 Firefox/128.0"

try {
    # -----------------------
    # Download Tor if missing
    # -----------------------
    if (-not (Test-Path $TorExe)) {
        Write-Host "[INFO] tor.exe not found. Downloading Tor Expert Bundle ..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $TorUrl -OutFile $Archive

        if ((Get-Item $Archive).Length -lt 5MB) {
            throw "Download failed or archive too small."
        }

        New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
        Write-Host "[INFO] Extracting Tor Expert Bundle ..." -ForegroundColor Cyan
        tar.exe -xzf $Archive -C $BaseDir --strip-components=1
        Remove-Item $Archive -Force

        if (-not (Test-Path $TorExe)) {
            throw "tor.exe not found after extraction."
        }
    }

    # -----------------------
    # Ensure data dir exists
    # -----------------------
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force -Path $DataDir | Out-Null }

    # -----------------------
    # Start Tor
    # -----------------------
    Write-Host "[INFO] Starting tor.exe ..." -ForegroundColor Cyan
    $argString = "--SocksPort $TorPort --DataDirectory `"$DataDir`""
    $torProcess = Start-Process -FilePath $TorExe -ArgumentList $argString -PassThru -WindowStyle Hidden

    # Wait for SOCKS port
    Write-Host "[INFO] Waiting for SOCKS port 127.0.0.1:$TorPort ..." -ForegroundColor Cyan
    if (-not (Wait-For-Port -Port $TorPort -TimeoutSec $PortWaitTimeoutSec -PollIntervalSec $PortPollIntervalSec)) {
        throw "Timeout waiting for SOCKS port."
    }
    Write-Host "[OK] SOCKS port open." -ForegroundColor Green

    # -----------------------
    # Fetch onion URL
    # -----------------------
    Write-Host "`n===== Fetching onion URL =====" -ForegroundColor Yellow
    $code = Run-Curl -Args @("-L", "-A", $uaBrowser, $OnionUrl)

    if ($code -eq 0) {
        Write-Host "[OK] Content successfully retrieved." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[ERROR] Fetch failed with exit code $code — showing verbose output:" -ForegroundColor Red
        Run-Curl -Args @("-L", "-A", $uaBrowser, $OnionUrl) -VerboseOutput
        exit 1
    }
}
catch {
    Write-Host "[EXCEPTION] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($torProcess -and -not $torProcess.HasExited) {
        Write-Host "[INFO] Stopping Tor process ..." -ForegroundColor Cyan
        try { $torProcess.Kill() } catch { Stop-Process -Id $torProcess.Id -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host "[INFO] Done." -ForegroundColor Cyan