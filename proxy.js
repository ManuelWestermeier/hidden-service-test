const fs = require("fs");
const http = require("http");
const { spawn } = require("child_process");

// Ordner für Hidden‑Service
const hsDir = "./hidden_service";

// Stelle sicher, dass der Ordner existiert
if (!fs.existsSync(hsDir)) {
    fs.mkdirSync(hsDir);
}

// ---- Node.js Webserver starten -----------------------------------------

const PORT = 80;

// ---- Tor Hidden Service starten ----------------------------------------

console.log("Starte Tor Hidden Service ...");

// "C:/Program Files/Tor Browser/Browser/TorBrowser/Tor/tor.exe"
// const tor = spawn("tor", [
const tor = spawn("tor.exe", [
    "--quiet",
    "--HiddenServiceDir", hsDir,
    "--HiddenServicePort", `80 manuel-westermeier.onrender.com:${PORT}`,
    "--SOCKSPort", "0",     // Kein Socks-Proxy nötig
]);

tor.stdout.on("data", data => {
    console.log("[Tor]", data.toString());
});

tor.stderr.on("data", data => {
    console.log("[Tor]", data.toString());
});

// ---- Onion-Adresse automatisch überwachen ------------------------------

const onionPath = `${hsDir}/hostname`;

function waitForOnion() {
    if (fs.existsSync(onionPath)) {
        const onion = fs.readFileSync(onionPath, "utf8").trim();
        console.log("\n=====================================");
        console.log("  Dein Hidden Service ist bereit!");
        console.log("  Adresse:", onion);
        console.log("=====================================\n");
        return;
    }
    setTimeout(waitForOnion, 500);
}

waitForOnion();
