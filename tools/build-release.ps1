[CmdletBinding()]
param(
    [string]$Version = "0.1.50"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $projectRoot "dist"
$archive = Join-Path $dist ("Chill-Shaders-" + $Version + ".zip")

& python (Join-Path $PSScriptRoot "check_shaderpack.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }

# Compress-Archive omits directory entries on some PowerShell versions. Iris
# normally accepts inferred folders, but explicit ZIP directories are safer.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [System.IO.File]::Open($archive, [System.IO.FileMode]::CreateNew)
$zip = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
try {
    $zip.CreateEntry("shaders/", [System.IO.Compression.CompressionLevel]::NoCompression) | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "shaders") -Directory -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($projectRoot.Length + 1).Replace('\', '/') + '/'
        $zip.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::NoCompression) | Out-Null
    }
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "shaders") -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    $license = Join-Path $projectRoot "LICENSE"
    if (Test-Path -LiteralPath $license) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $license, "LICENSE", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $zip.Dispose()
    $stream.Dispose()
}
Write-Host "Created $archive"
