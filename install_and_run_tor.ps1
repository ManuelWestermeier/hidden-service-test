$ErrorActionPreference = "Stop"

$BaseDir = Join-Path $PSScriptRoot "tor-exe"
$Archive = Join-Path $PSScriptRoot "tor-expert.tar.gz"
$TorExe  = Join-Path $BaseDir "tor.exe"
$OnionUrl = "http://6ksaeabbzftfoimauqq2c6j3z544il3xiy7btx2fze4jx44aty22owad.onion"

$TorUrl = "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.3/tor-expert-bundle-windows-x86_64-15.0.3.tar.gz"

if (-not (Test-Path $TorExe)) {

    Write-Host "[INFO] tor.exe nicht gefunden - lade Tor Expert Bundle (Archiv)"

    Invoke-WebRequest -Uri $TorUrl -OutFile $Archive

    if ((Get-Item $Archive).Length -lt 5MB) {
        throw "Download fehlgeschlagen (Archiv zu klein)"
    }

    if (-not (Test-Path $BaseDir)) {
        New-Item -ItemType Directory -Path $BaseDir | Out-Null
    }

    Write-Host "[INFO] Entpacke Tor Expert Bundle"

    tar -xzf $Archive -C $BaseDir --strip-components=1

    Remove-Item $Archive -Force
}

if (-not (Test-Path $TorExe)) {
    throw "tor.exe nach Entpacken nicht gefunden"
}

Write-Host "[OK] Starte tor.exe lokal"
Start-Process -FilePath $TorExe -WindowStyle Minimized

Write-Host "[INFO] Warte auf SOCKS-Port 9050"

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep 1
    if (Get-NetTCPConnection -LocalPort 9050 -ErrorAction SilentlyContinue) {
        $ready = $true
        break
    }
}

if (-not $ready) {
    throw "Tor SOCKS-Port nicht erreichbar"
}

Write-Host "[OK] Tor ist bereit"
Write-Host "===== WEBSITE CONTENT ====="

curl.exe --socks5-hostname 127.0.0.1:9050 $OnionUrl

Write-Host "===== ENDE ====="
Pause
