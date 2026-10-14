Add-Type -AssemblyName System.Drawing

$srcPath = "D:\redtaxis\src\mobile\customer_app\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png"
$destPath = "D:\redtaxis\src\mobile\customer_app\assets\images\app_icon_512x512.png"

$src = [System.Drawing.Image]::FromFile($srcPath)
$dest = New-Object System.Drawing.Bitmap(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($dest)

$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$graphics.DrawImage($src, 0, 0, 512, 512)

$dest.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$dest.Dispose()
$src.Dispose()

Write-Output "Successfully generated: $destPath"
