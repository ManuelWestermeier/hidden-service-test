$TorExe   = "tor-exe\tor.exe"
$TorPort  = 9050
$DataDir  = ".\tor-data"
$OnionUrl = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"

if (-not (Test-Path $TorExe)) { exit 1 }
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

$Tor = Start-Process -FilePath $TorExe `
                     -ArgumentList "--SocksPort $TorPort --DataDirectory `"$DataDir`"" `
                     -PassThru -WindowStyle Hidden

while (-not (Test-NetConnection 127.0.0.1 -Port $TorPort).TcpTestSucceeded) { Start-Sleep 1 }

try {
    curl.exe --socks5-hostname "127.0.0.1:$TorPort" -s $OnionUrl
}
finally {
    if ($Tor -and !$Tor.HasExited) { $Tor.Kill() }
}
