# Deterministic resolution exports only. Artwork is authored by image_gen.
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$artPath = Join-Path $projectRoot 'assets\refugio\launcher-foreground-source.png'
$source = [Drawing.Image]::FromFile($artPath)
function Save-RefugioIcon([int]$pixels, [string]$relativePath, [bool]$transparent, [double]$scale) {
  $target = Join-Path $projectRoot $relativePath
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
  $pixelFormat = if ($transparent) { [Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [Drawing.Imaging.PixelFormat]::Format24bppRgb }
  $bitmap = [Drawing.Bitmap]::new($pixels,$pixels,$pixelFormat)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  if ($transparent) { $graphics.Clear([Drawing.Color]::Transparent) }
  else { $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#285747')) }
  $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
  $edge = [int]($pixels*$scale)
  $offset = [int](($pixels-$edge)/2)
  $graphics.DrawImage($source,[Drawing.Rectangle]::new($offset,$offset,$edge,$edge))
  $graphics.Dispose()
  $bitmap.Save($target,[Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}
try {
  Save-RefugioIcon 1024 'assets\refugio\app-icon-1024.png' $false 1.22
  Save-RefugioIcon 512 'assets\refugio\app-icon-512.png' $false 1.22
  Save-RefugioIcon 1024 'assets\refugio\app-icon-foreground-1024.png' $true .90
  foreach ($density in @(@('mdpi',48,108),@('hdpi',72,162),@('xhdpi',96,216),@('xxhdpi',144,324),@('xxxhdpi',192,432))) {
    Save-RefugioIcon $density[1] "android\app\src\main\res\mipmap-$($density[0])\ic_launcher.png" $false 1.22
    Save-RefugioIcon $density[2] "android\app\src\main\res\mipmap-$($density[0])\ic_launcher_foreground.png" $true .90
  }
  $catalog = Join-Path $projectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
  $contents = Get-Content -LiteralPath (Join-Path $catalog 'Contents.json') -Raw | ConvertFrom-Json
  foreach ($entry in $contents.images) {
    $points = [double]($entry.size.Split('x')[0])
    $factor = [double]($entry.scale.TrimEnd('x'))
    Save-RefugioIcon ([int]($points*$factor)) "ios\Runner\Assets.xcassets\AppIcon.appiconset\$($entry.filename)" $false 1.22
  }
} finally { $source.Dispose() }
