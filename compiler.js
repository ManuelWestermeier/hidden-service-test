// compiler.js
const fs = require('fs');
const path = require('path');

// Files to embed
const filesToEmbed = [
  'client/run-tor-exectuor.bat',
  'client/run.vbs',
  'client/tor-executor.ps1'
];

// Output BAT file
const outputBat = 'output/compiled-tor.bat';

// Helper function to encode content to Base64
function encodeBase64(filePath) {
  const content = fs.readFileSync(filePath);
  return content.toString('base64');
}

// Start building the BAT content
let batContent = `@echo off
:: Extract embedded files
setlocal enabledelayedexpansion
`;

// Add extraction code for each file
filesToEmbed.forEach(filePath => {
  const base64 = encodeBase64(filePath);
  const dir = path.dirname(filePath);
  const filename = path.basename(filePath);

  // Ensure directory exists
  if (dir !== '.') {
    batContent += `
if not exist "${dir}" mkdir "${dir}"
`;
  }

  // Write the file
  batContent += `
echo Extracting ${filePath}...
powershell -Command "[System.IO.File]::WriteAllBytes('${filePath.replace(/\\/g,'/')}', [System.Convert]::FromBase64String('${base64}'))"
`;
});

// Run the main BAT
batContent += `
:: Run the main BAT file
call client/run-tor-exectuor.bat

:: Cleanup extracted files
`;

// Cleanup commands
filesToEmbed.forEach(filePath => {
  batContent += `del "${filePath}"\n`;
});

// End local environment
batContent += 'endlocal\n';

// Ensure output directory exists
const outDir = path.dirname(outputBat);
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

// Write the compiled BAT file
fs.writeFileSync(outputBat, batContent, { encoding: 'utf8' });
console.log(`Compiled BAT file created: ${outputBat}`);
