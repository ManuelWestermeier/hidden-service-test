

# ==============================
# Konfiguration
# ==============================

$TorExe      = "tor-exe\tor.exe"
$TorPort     = 9050
$DataDir     = ".\tor-data"                # eigenes Data-Verzeichnis
$OnionUrl    = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"
$LogFile     = "onion_log.html"
$TorLogFile  = "tor_runtime.log"
$StartupWait = 15   # Sekunden, bis Tor bereit ist

# ==============================
# Prüfen, ob Tor bereits läuft
# ==============================

$existingTor = Get-Process tor -ErrorAction SilentlyContinue
if ($existingTor) {
    Write-Host "[!] Tor läuft bereits. Bitte beende alle Tor-Prozesse und versuche es erneut."
    exit 1
}

# ==============================
# Data-Verzeichnis erstellen
# ==============================

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir | Out-Null
}

# ==============================
# Tor starten
# ==============================

if (-not (Test-Path $TorExe)) {
    Write-Error "Tor executable nicht gefunden: $TorExe"
    exit 1
}

Write-Host "[+] Starte Tor..."

$TorProcess = Start-Process `
    -FilePath $TorExe `
    -ArgumentList "--SocksPort $TorPort --DataDirectory `"$DataDir`" --Log `"notice file $TorLogFile`"" `
    -PassThru `
    -WindowStyle Hidden

# ==============================
# Warten, bis Tor bereit ist
# ==============================

Write-Host "[+] Warte auf Tor SOCKS-Port..."
$timeout = 30
$elapsed = 0
while (-not (Test-NetConnection -ComputerName 127.0.0.1 -Port $TorPort).TcpTestSucceeded) {
    Start-Sleep -Seconds 1
    $elapsed++
    if ($elapsed -ge $timeout) {
        Write-Error "Tor konnte innerhalb von $timeout Sekunden nicht gestartet werden."
        if ($TorProcess -and !$TorProcess.HasExited) { $TorProcess.Kill() }
        exit 1
    }
}

Write-Host "[+] Tor ist bereit."

# ==============================
# Onion Content abrufen
# ==============================

Write-Host "[+] Lade Onion Content..."

try {
    $content = curl.exe `
        --socks5-hostname "127.0.0.1:$TorPort" `
        --connect-timeout 60 `
        --max-time 120 `
        -A "Mozilla/5.0" `
        $OnionUrl
}
catch {
    Write-Error "Fehler beim Abrufen der Onion-Seite"
    if ($TorProcess -and !$TorProcess.HasExited) { $TorProcess.Kill() }
    exit 1
}

# ==============================
# Loggen
# ==============================

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

@"
<!-- Logged at $timestamp -->
$content
"@ | Out-File -Encoding UTF8 $LogFile

Write-Host "[+] Content gespeichert in $LogFile"

# ==============================
# Tor beenden
# ==============================

if ($TorProcess -and !$TorProcess.HasExited) {
    Write-Host "[+] Beende Tor..."
    $TorProcess.Kill()
}

Write-Host "[OK] Fertig"
