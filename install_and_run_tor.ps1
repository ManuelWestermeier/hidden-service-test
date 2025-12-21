cls
# Stop on any error
$ErrorActionPreference = "Stop"

# -----------------------
# Konfiguration
# -----------------------
$P = $PSScriptRoot
$BaseDir   = Join-Path $P "tor-exe"
$Archive   = Join-Path $P "tor-expert.tar.gz"
$TorExe    = Join-Path $BaseDir "tor.exe"
# Falls du eine andere onion-Adresse verwenden willst, editiere die Zeile unten:
$OnionUrl  = "https://6ksaeabbzftfoimauqq2c6j3z544il3xiy7btx2fze4jx44aty22owad.onion/"

# Die von dir genannte Archiv-URL (statisch / Archiv)
$TorUrl = "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.3/tor-expert-bundle-windows-x86_64-15.0.3.tar.gz"

# -----------------------
# Helper: Ausführen und ExitCode prüfen
# -----------------------
function Run-Curl {
    param(
        [string[]] $Args
    )
    & curl.exe @Args
    return $LASTEXITCODE
}

# -----------------------
# 1) Herunterladen & Entpacken (falls nötig)
# -----------------------
if (-not (Test-Path $TorExe)) {

    Write-Host "[INFO] tor.exe nicht gefunden - lade Tor Expert Bundle (Archiv)" -ForegroundColor Cyan

    # Download
    Invoke-WebRequest -Uri $TorUrl -OutFile $Archive -UseBasicParsing

    if ((Get-Item $Archive).Length -lt 5MB) {
        throw "Download fehlgeschlagen (Archiv zu klein)."
    }

    if (-not (Test-Path $BaseDir)) {
        New-Item -ItemType Directory -Path $BaseDir | Out-Null
    }

    Write-Host "[INFO] Entpacke Tor Expert Bundle ..." -ForegroundColor Cyan
    # tar ist unter Windows 10+ verfügbar
    tar -xzf $Archive -C $BaseDir --strip-components=1

    Remove-Item $Archive -Force

    if (-not (Test-Path $TorExe)) {
        throw "tor.exe nach Entpacken nicht gefunden."
    }

    Write-Host "[OK] Tor wurde installiert in: $BaseDir" -ForegroundColor Green
}
else {
    Write-Host "[OK] tor.exe gefunden: $TorExe" -ForegroundColor Green
}

# -----------------------
# 2) Tor starten (mit SOCKS-Port 19050)
# -----------------------
# Wir setzen DataDirectory in tor-exe\data, damit tor seine Laufzeitdaten dort ablegt.
$DataDir = Join-Path $BaseDir "data"
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

# Argument-Liste für tor.exe
# WICHTIG: wir geben explizit einen SocksPort, damit curl später über 127.0.0.1:19050 gehen kann.
$torArgs = @(
    "--quiet",
    "--DataDirectory", "`"$DataDir`"",
    "--SocksPort", "127.0.0.1:19050",
    "--Log", "notice stdout"
)

Write-Host "[INFO] Starte tor.exe (SocksPort 127.0.0.1:19050) ..." -ForegroundColor Cyan

# Start-Process mit Redirect der Ausgabe ist komplizierter; wir starten minimiert und nicht-gewinnbringend.
$torProcess = Start-Process -FilePath $TorExe -ArgumentList $torArgs -WindowStyle Minimized -PassThru

# -----------------------
# 3) Auf SOCKS-Port warten
# -----------------------
Write-Host "[INFO] Warte auf Tor SOCKS-Port 19050 ..." -ForegroundColor Cyan

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    try {
        # Get-NetTCPConnection benötigt evtl. Admin-Rechte; wir fangen Fehler still
        $conn = Get-NetTCPConnection -LocalPort 19050 -ErrorAction SilentlyContinue
        if ($conn) { $ready = $true; break }
        # alternativ: Test-NetConnection
        $tn = Test-NetConnection -ComputerName 127.0.0.1 -Port 19050 -WarningAction SilentlyContinue
        if ($tn.TcpTestSucceeded) { $ready = $true; break }
    } catch {
        # ignore
    }
}

if (-not $ready) {
    # versuche den Prozess-Output zu zeigen falls vorhanden, dann abbrechen
    Write-Host "[FEHLER] Tor SOCKS-Port 19050 nicht erreichbar nach Wartezeit." -ForegroundColor Red
    Write-Host "Tor-Prozess läuft? " ($torProcess -and -not $torProcess.HasExited)
    throw "Tor SOCKS-Port nicht erreichbar"
}

Write-Host "[OK] Tor ist bereit (Socks: 127.0.0.1:19050)" -ForegroundColor Green

# -----------------------
# 4) Fetch-Strategie: mehrere Versuche / Fallbacks
# -----------------------
Write-Host "===== VERSUCHE, die Onion-Adresse abzurufen =====" -ForegroundColor Yellow

# Curl Basis-Args
$baseSocks = "--socks5-hostname"
$socksAddr = "127.0.0.1:19050"
$uaBrowser = "Mozilla/5.0 (Windows NT 10.0; rv:128.0) Gecko/20100101 Firefox/128.0"

# Versuche 1: plain HTTP, Browser-UA, Follow redirects
Write-Host "`n[TRY 1] HTTP (plain) mit Browser-UserAgent..." -ForegroundColor Cyan
$tryArgs = @($baseSocks, $socksAddr, "-L", "-A", $uaBrowser, $OnionUrl)
$code = Run-Curl -Args $tryArgs

if ($code -eq 0) {
    Write-Host "`n[OK] Inhalt erfolgreich empfangen (Try 1)" -ForegroundColor Green
    Pause
    exit 0
}

# Versuche 2: HTTPS (Browser-UA), Follow redirects
$httpsUrl = $OnionUrl -replace '^http:', 'https:'
Write-Host "`n[TRY 2] HTTPS mit Browser-UserAgent..." -ForegroundColor Cyan
$tryArgs = @($baseSocks, $socksAddr, "-L", "-A", $uaBrowser, $httpsUrl)
$code = Run-Curl -Args $tryArgs

if ($code -eq 0) {
    Write-Host "`n[OK] Inhalt erfolgreich empfangen (Try 2 https)" -ForegroundColor Green
    Pause
    exit 0
}

# Versuche 3: HTTPS, Ignore cert errors (-k)
Write-Host "`n[TRY 3] HTTPS mit -k (ignoriere Zertifikat) und Browser-UserAgent..." -ForegroundColor Cyan
$tryArgs = @($baseSocks, $socksAddr, "-L", "-k", "-A", $uaBrowser, $httpsUrl)
$code = Run-Curl -Args $tryArgs

if ($code -eq 0) {
    Write-Host "`n[OK] Inhalt erfolgreich empfangen (Try 3 https -k)" -ForegroundColor Green
    Pause
    exit 0
}

# Falls alles fehlschlägt: detaillierte Diagnose
Write-Host "`n[FEHLER] Alle Abrufversuche fehlgeschlagen. Detaillierte Diagnose:" -ForegroundColor Red

Write-Host "`n--- Tor Prozessinfo ---"
$torProc = Get-Process -Id $torProcess.Id -ErrorAction SilentlyContinue
if ($torProc) {
    Write-Host "PID: $($torProc.Id), StartTime: $($torProc.StartTime)"
} else {
    Write-Host "Tor-Prozess nicht gefunden oder bereits beendet."
}

Write-Host "`n--- Netzstat (19050) ---"
netstat -an | Select-String "19050" | ForEach-Object { Write-Host $_ }

Write-Host "`n--- curl verbose attempt (http) ---"
# verbose Versuch zeigen (ExitCode ignorieren)
& curl.exe --socks5-hostname 127.0.0.1:19050 -v -L -A $uaBrowser $OnionUrl 2>&1 | Out-Host

Write-Host "`n--- Ende Diagnose ---"
Pause
exit 1
