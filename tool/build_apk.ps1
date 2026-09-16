param(
    [Parameter(Position = 0)]
    [ValidateRange(1, 11)]
    [int]$Grade = 1,
    [switch]$All
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Build-Grade([int]$n) {
    $flavor = "sinf$n"
    Write-Host "Building $flavor (GRADE=$n)..."
    flutter build apk --flavor $flavor --dart-define="GRADE=$n" --release
    $apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-$flavor-release.apk"
    Write-Host "APK: $apk"
}

if ($All) {
    1..11 | ForEach-Object { Build-Grade $_ }
} else {
    Build-Grade $Grade
}
