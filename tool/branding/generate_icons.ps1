# Generates all app icons (Android, web, Windows) from one vector description.
# Usage (from repo root):  powershell -File tool/branding/generate_icons.ps1
# Look: 135deg gradient #00d9ff -> #a855f7, white folded-map glyph (stand-in for the
# reference's map emoji so the result does not depend on installed emoji fonts).
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cyan = [System.Drawing.Color]::FromArgb(0x00, 0xd9, 0xff)
$purple = [System.Drawing.Color]::FromArgb(0xa8, 0x55, 0xf7)

# Glyph in a 100x100 design space: three map panels (folded map), alternating zig-zag.
$panels = @(
  @(@(21,31),@(40,24),@(40,71),@(21,78)),
  @(@(42,24),@(58,31),@(58,78),@(42,71)),
  @(@(60,31),@(79,24),@(79,71),@(60,78))
)
$alphas = @(215, 255, 215)

function New-Icon([int]$size, [bool]$rounded, [double]$glyphScale) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([System.Drawing.Color]::Transparent)
  $rect = New-Object System.Drawing.RectangleF 0, 0, $size, $size
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $cyan, $purple, 45.0
  if ($rounded) {
    $r = $size * 0.2; $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90); $path.AddArc($size - $d, 0, $d, $d, 270, 90)
    $path.AddArc($size - $d, $size - $d, $d, $d, 0, 90); $path.AddArc(0, $size - $d, $d, $d, 90, 90)
    $path.CloseFigure(); $g.FillPath($brush, $path)
  } else { $g.FillRectangle($brush, $rect) }
  $k = $size / 100.0
  for ($i = 0; $i -lt 3; $i++) {
    $pts = foreach ($p in $panels[$i]) {
      New-Object System.Drawing.PointF ((50 + ($p[0] - 50) * $glyphScale) * $k), ((50 + ($p[1] - 51) * $glyphScale) * $k)
    }
    $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alphas[$i], 255, 255, 255))
    $g.FillPolygon($fill, [System.Drawing.PointF[]]$pts)
  }
  $g.Dispose(); return $bmp
}
function Save-Png($bmp, [string]$path) {
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# Web
Save-Png (New-Icon 64 $true 1.0) "$root\web\favicon.png"
Save-Png (New-Icon 192 $true 1.0) "$root\web\icons\Icon-192.png"
Save-Png (New-Icon 512 $true 1.0) "$root\web\icons\Icon-512.png"
Save-Png (New-Icon 192 $false 0.7) "$root\web\icons\Icon-maskable-192.png"
Save-Png (New-Icon 512 $false 0.7) "$root\web\icons\Icon-maskable-512.png"

# Android legacy launcher PNGs
$dens = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
foreach ($d in $dens.Keys) { Save-Png (New-Icon $dens[$d] $true 1.0) "$root\android\app\src\main\res\mipmap-$d\ic_launcher.png" }

# Android adaptive icon (vector foreground/monochrome from the same polygons, 108dp canvas, glyph in safe zone)
$res = "$root\android\app\src\main\res"
New-Item -ItemType Directory -Force "$res\drawable", "$res\mipmap-anydpi-v26" | Out-Null
function Get-VectorPaths([string]$fillAttr) {
  $s = 0.5; $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt 3; $i++) {
    $d = ''
    for ($j = 0; $j -lt 4; $j++) {
      $p = $panels[$i][$j]
      $x = [math]::Round(54 + ($p[0] - 50) * $s * 1.08, 2); $y = [math]::Round(54 + ($p[1] - 51) * $s * 1.08, 2)
      $d += $(if ($j -eq 0) { 'M' } else { 'L' }) + "$x,$y "
    }
    $d += 'Z'
    $a = '{0:X2}' -f $alphas[$i]
    $fill = $fillAttr.Replace('AA', $a)
    [void]$sb.AppendLine("    <path android:fillColor=`"$fill`" android:pathData=`"$d`"/>")
  }
  $sb.ToString()
}
$utf8 = New-Object System.Text.UTF8Encoding $false
function Write-Vector([string]$file, [string]$fillAttr) {
  $xml = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<vector xmlns:android=`"http://schemas.android.com/apk/res/android`"`n    android:width=`"108dp`" android:height=`"108dp`"`n    android:viewportWidth=`"108`" android:viewportHeight=`"108`">`n" + (Get-VectorPaths $fillAttr) + "</vector>`n"
  [IO.File]::WriteAllText($file, $xml, $utf8)
}
Write-Vector "$res\drawable\ic_launcher_foreground.xml" '#AAFFFFFF'
Write-Vector "$res\drawable\ic_launcher_monochrome.xml" '#AAFFFFFF'
[IO.File]::WriteAllText("$res\drawable\ic_launcher_background.xml", @"
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:type="linear" android:angle="315" android:startColor="#00D9FF" android:endColor="#A855F7"/>
</shape>
"@, $utf8)
[IO.File]::WriteAllText("$res\mipmap-anydpi-v26\ic_launcher.xml", @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"@, $utf8)

# Windows .ico (PNG-compressed entries 16..256)
$sizes = 16, 24, 32, 48, 64, 128, 256
$ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$blobs = foreach ($s in $sizes) {
  $b = New-Icon $s $true 1.0; $m = New-Object System.IO.MemoryStream
  $b.Save($m, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); ,$m.ToArray()
}
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
  $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$blobs[$i].Length); $bw.Write([uint32]$offset)
  $offset += $blobs[$i].Length
}
foreach ($b in $blobs) { $bw.Write($b) }
[IO.File]::WriteAllBytes("$root\windows\runner\resources\app_icon.ico", $ms.ToArray())
Write-Host 'Icons generated.'
