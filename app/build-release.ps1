# Builds the release apps against production:
#   build\app\outputs\flutter-apk\app-release.apk   (signed with android\key.properties)
#   build\installer\MChart-Setup.exe                (Inno Setup, one file)
# Version comes from pubspec.yaml; bump it there (and MCHART_APP_VERSION /
# config/mchart.php on the server) for each release.
Set-Location $PSScriptRoot
$ErrorActionPreference = 'Stop'

# Same production + realtime settings as run-prod.ps1.
$defines = (Select-String -Path .\run-prod.ps1 -Pattern '--dart-define=\S+' -AllMatches).Matches.Value
$version = ((Select-String -Path .\pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value)

if (-not (Test-Path .\android\key.properties)) {
    throw 'android\key.properties missing: copy it (and app\mchart-release.jks) from the release signing backup.'
}

flutter build apk --release @defines
flutter build windows --release @defines

$iscc = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
& $iscc "/DAppVersion=$version" .\windows\installer\mchart.iss

Write-Host "Built MChart $version"
