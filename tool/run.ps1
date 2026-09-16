param(
    [Parameter(Position = 0)]
    [ValidateRange(1, 11)]
    [int]$Grade = 1
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$flavor = "sinf$Grade"
Write-Host "Running $flavor (GRADE=$Grade) — API https://book.1week.tj"
flutter run --flavor $flavor --dart-define="GRADE=$Grade"
