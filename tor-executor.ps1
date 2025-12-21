$ErrorActionPreference = "Stop"

# -----------------------
# Configuration
# -----------------------
$P = $PSScriptRoot
$BaseDir = Join-Path $P "tor-exe"
$Archive = Join-Path $P "tor-expert.tar.gz"
$TorExe = Join-Path $BaseDir "tor.exe"
$DataDir = Join-Path $P "tor-data"
$IndexFile = Join-Path $P "index.data"
$OnionUrl = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"
$TorUrl = "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.3/tor-expert-bundle-windows-x86_64-15.0.3.tar.gz"
$TorPort = 9050

$CurlConnectTimeout = 15
$CurlMaxTime = 60
$PortWaitTimeoutSec = 60
$PortPollIntervalSec = 1

# -----------------------
# Helper functions
# -----------------------
function Run-Curl {
    param(
        [string[]] $Args,
        [switch] $VerboseOutput,
        [string] $OutFile
    )

    $common = @(
        "--socks5-hostname", "127.0.0.1:$TorPort",
        "--connect-timeout", $CurlConnectTimeout.ToString(),
        "--max-time", $CurlMaxTime.ToString(),
        "--fail"
    )
    $fullArgs = $common + $Args

    if ($OutFile) {
        $outDir = Split-Path $OutFile -Parent
        if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
        $fullArgs += @("-o", $OutFile)
    }

    if ($VerboseOutput) {
        & curl.exe @fullArgs 2>&1 | Out-Host
    }
    else {
        & curl.exe @fullArgs | Out-Null
    }

    return $LASTEXITCODE
}

function Wait-For-Port {
    param(
        [string] $TargetHost = "127.0.0.1",
        [int] $Port,
        [int] $TimeoutSec = 60,
        [int] $PollIntervalSec = 1
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $async = $client.BeginConnect($TargetHost, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($PollIntervalSec))) {
                $client.EndConnect($async)
                $client.Close()
                return $true
            }
            else {
                $client.Close()
            }
        }
        catch {
            # ignore and retry
        }
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
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe not found. Please install curl or use a Windows 10+ system with curl included."
    }

    # Download & extract Tor if needed
    if (-not (Test-Path $TorExe)) {
        Write-Host "Downloading Tor expert bundle..."
        Invoke-WebRequest -Uri $TorUrl -OutFile $Archive -UseBasicParsing

        if ((Get-Item $Archive).Length -lt 5MB) {
            Remove-Item -Force $Archive -ErrorAction SilentlyContinue
            throw "Download failed or archive too small."
        }

        New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
        tar.exe -xzf $Archive -C $BaseDir --strip-components=1
        Remove-Item $Archive -Force

        if (-not (Test-Path $TorExe)) { throw "tor.exe not found after extraction." }
        Write-Host "Tor extracted to $BaseDir"
    }
    else {
        Write-Host "Tor executable already present: $TorExe"
    }

    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force -Path $DataDir | Out-Null }

    # -----------------------
    # Start Tor process directly
    # -----------------------
    $torArgs = @("--SocksPort", $TorPort, "--DataDirectory", "`"$DataDir`"", "--Log", "notice stdout")
    Write-Host "Starting tor.exe..."
    $torProcess = Start-Process -FilePath $TorExe -ArgumentList $torArgs -PassThru -NoNewWindow

    # print content of the side $OnionUrl    
}
catch {
    Write-Error "Error: $_"
    exit 1
}
finally {
    # Stop Tor process
    if ($torProcess -and -not $torProcess.HasExited) {
        Write-Host "Stopping Tor..."
        try { $torProcess.Kill() } catch { Stop-Process -Id $torProcess.Id -ErrorAction SilentlyContinue }
    }
}
