# Packages the Windows release build as a portable zip and an installer.
#   flutter build windows --release
#   ./tool/package_windows.ps1 -Version 0.1.0
# Output: dist/FlSony-<version>-windows-x64.zip and
#         dist/FlSony-<version>-windows-x64-setup.exe (needs Inno Setup 6)
param([Parameter(Mandatory)][string]$Version)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$release = 'build/windows/x64/runner/Release'
if (-not (Test-Path "$release/flsony.exe")) {
  throw "Missing $release/flsony.exe; run 'flutter build windows --release' first."
}

# Flutter apps need the Visual C++ runtime. Ship it next to the exe (Microsoft's
# "app-local" deployment) so the app starts on PCs without the redistributable.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ runtime files not found in the Visual Studio redist folder.' }
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $crt.FullName $dll) $release
}

New-Item -ItemType Directory -Force dist | Out-Null

# Portable zip with a top-level FlSony folder.
$stage = Join-Path ([IO.Path]::GetTempPath()) "flsony-$Version"
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory $stage | Out-Null
Copy-Item -Recurse $release (Join-Path $stage 'FlSony')
$zip = "dist/FlSony-$Version-windows-x64.zip"
Remove-Item -Force $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stage 'FlSony') -DestinationPath $zip
Remove-Item -Recurse -Force $stage
Write-Output $zip

# Installer.
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
  Write-Warning 'Inno Setup 6 not found; skipping the installer.'
  exit 0
}
& $iscc /Q "/DAppVersion=$Version" "/DSourceDir=$((Resolve-Path $release).Path)" `
  "/O$((Resolve-Path dist).Path)" windows/installer/flsony.iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE" }
Write-Output "dist/FlSony-$Version-windows-x64-setup.exe"
