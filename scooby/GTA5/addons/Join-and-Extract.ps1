# Download EVERY numbered part beside this script, then run it with PowerShell.
# No administrator access or game-file modification is required.
$ErrorActionPreference = 'Stop'
$parts = @(
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.001'; Bytes = 95000000; Sha = '2d25ec105fa31bbf21e65f10815fbd64f23e2fa1d7f85a83b943aca2489dbf52' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.002'; Bytes = 95000000; Sha = '967b7675c263702e591ca387d8cf2ce97d533ceb320f323acee34b8820791689' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.003'; Bytes = 95000000; Sha = '913035d50d1cfbd267bc19ed647b08edc69887d35afa16df52ba8309843e8aae' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.004'; Bytes = 95000000; Sha = '0bf1bd184959f324d3dae38bb5f894881e6539d0ef26758cf36c9ee8a3560474' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.005'; Bytes = 95000000; Sha = '07a6c2ec54cc0fb96336038c83dfa3f14dc9a2730591a43bcaa1d7b04657bbf5' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.006'; Bytes = 95000000; Sha = '4a083102ca993c2624c6c370ea3f66c2d51abd7ec50452414cc51bfce585bc43' }
    @{ Name = 'Scooby-GTA-V-Addons-20261027.zip.007'; Bytes = 90392564; Sha = '1ee18b8c93454da0d6e38a3cbc0055a2d8d52e3ff9db38c2eaed24b799fa6e4c' }
)
$archiveName = 'Scooby-GTA-V-Addons-20261027.zip'
$archiveSha = 'a9348cfb6a0efb85a88a35c6b2fc988af65e7d9c40e4867dcee482f5358c670b'
$zipPath = Join-Path $PSScriptRoot $archiveName
$destination = Join-Path $PSScriptRoot 'Scooby-GTA-V-Addons-Extracted'
if ((Test-Path -LiteralPath $zipPath) -or (Test-Path -LiteralPath $destination)) {
    throw 'The joined ZIP or extraction folder already exists. Use a new folder to preserve your files.'
}
foreach ($part in $parts) {
    $path = Join-Path $PSScriptRoot $part.Name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing part: $($part.Name)" }
    if ((Get-Item -LiteralPath $path).Length -ne $part.Bytes) { throw "Incomplete part: $($part.Name)" }
    Write-Host "Checking $($part.Name)..."
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $part.Sha) { throw "Hash mismatch: $($part.Name). Download that part again." }
}
$target = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
try {
    foreach ($part in $parts) {
        $source = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot $part.Name))
        try { $source.CopyTo($target) } finally { $source.Dispose() }
    }
} finally { $target.Dispose() }
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $archiveSha) { throw 'Joined ZIP verification failed. Extraction stopped.' }
Write-Host 'Verified. Extracting...'
Expand-Archive -LiteralPath $zipPath -DestinationPath $destination
Write-Host "Extracted to: $destination"
Write-Host 'Open Scooby > Addons/Replacements > Import Folder and select the content you want.'
Write-Host 'Keep all parts until extraction is complete. Read README.md before importing.'
