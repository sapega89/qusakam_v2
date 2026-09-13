$zips = Get-ChildItem -Path . -Filter *.zip
foreach ($zip in $zips) {
    $dest = Join-Path (Get-Location).Path $zip.BaseName
    if (-not (Test-Path $dest)) {
        Write-Host "Extracting $($zip.Name)..."
        try {
            Expand-Archive -LiteralPath $zip.FullName -DestinationPath $dest -Force -ErrorAction Stop
        } catch {
            Write-Host "Error extracting $($zip.Name): $_"
        }
    } else {
        Write-Host "Skipping $($zip.Name) (destination exists)"
    }
}
