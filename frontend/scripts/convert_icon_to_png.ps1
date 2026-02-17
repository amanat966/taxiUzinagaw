# Конвертация assets/icon.ico -> assets/icon.png для flutter_launcher_icons
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$icoPath = Join-Path $root "assets\icon.ico"
$pngPath = Join-Path $root "assets\icon.png"

if (-not (Test-Path $icoPath)) {
    Write-Error "File not found: $icoPath"
    exit 1
}

Add-Type -AssemblyName System.Drawing
$ico = [System.Drawing.Icon]::new($icoPath)
$bmp = $ico.ToBitmap()
# Сохраняем в PNG (1024x1024 для launcher — масштабируем если нужно)
$size = [Math]::Min(1024, [Math]::Max($bmp.Width, $bmp.Height))
if ($bmp.Width -ne $size -or $bmp.Height -ne $size) {
    $resized = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($resized)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmp, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Dispose()
    $bmp = $resized
}
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$ico.Dispose()
Write-Host "OK: $pngPath"
