param(
    [string]$Device = "AUXH9X5916G00077"
)

Write-Host "🚀 Launching Red Taxis Driver App on device: $Device (Filtering OEM log spam)..." -ForegroundColor Cyan

flutter run -d $Device | Where-Object { 
    $_ -notmatch "HwForceDarkManager" -and 
    $_ -notmatch "isAppInDarkMode" 
}
