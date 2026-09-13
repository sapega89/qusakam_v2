$location = "C:\Users\user\OneDrive\Документы\new-game-project\raw_assets"
Set-Location $location

$zips = Get-ChildItem -Filter *.zip
foreach ($zip in $zips) {
    $dest = Join-Path $location $zip.BaseName
    if (-not (Test-Path $dest)) {
        Write-Host "Extracting $($zip.Name)..."
        Expand-Archive -LiteralPath $zip.FullName -DestinationPath $dest -Force
    } else {
        Write-Host "Skipping $($zip.Name) (destination exists)"
    }
}
