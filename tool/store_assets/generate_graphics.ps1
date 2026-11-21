# Generates the Google Play icon (512x512, RGBA, full-bleed) and the feature graphic
# (1024x500, opaque 24-bit RGB) into .docs/play-store/assets/.
# Usage (repo root, PowerShell 7):  pwsh -File tool/store_assets/generate_graphics.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$out = Join-Path $root '.docs\play-store\assets'
New-Item -ItemType Directory -Force $out | Out-Null
$D = [System.Drawing.Color]
$cyan = $D::FromArgb(0x00, 0xd9, 0xff)
$purple = $D::FromArgb(0xa8, 0x55, 0xf7)
$ink = $D::FromArgb(0x0a, 0x0e, 0x14)

# Same glyph polygons as tool/branding/generate_icons.ps1 (100x100 design space).
$panels = @(
  @(@(21,31),@(40,24),@(40,71),@(21,78)),
  @(@(42,24),@(58,31),@(58,78),@(42,71)),
  @(@(60,31),@(79,24),@(79,71),@(60,78))
)
$alphas = @(215, 255, 215)

# Draws the gradient tile + glyph into $g at ($x,$y) with edge length $size.
# The glyph spans 58% of the tile width and is centred on (50, 51) like the launcher icon.
function Draw-Logo($g, [double]$x, [double]$y, [double]$size, [double]$radiusFrac) {
  $rect = New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single]$size), ([single]$size)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $cyan, $purple, 45.0
  if ($radiusFrac -gt 0) {
    $r = $size * $radiusFrac; $dia = $r * 2
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $dia, $dia, 180, 90); $p.AddArc($x + $size - $dia, $y, $dia, $dia, 270, 90)
    $p.AddArc($x + $size - $dia, $y + $size - $dia, $dia, $dia, 0, 90); $p.AddArc($x, $y + $size - $dia, $dia, $dia, 90, 90)
    $p.CloseFigure(); $g.FillPath($brush, $p)
  } else { $g.FillRectangle($brush, $rect) }
  $k = $size / 100.0
  for ($i = 0; $i -lt 3; $i++) {
    $pts = foreach ($q in $panels[$i]) {
      New-Object System.Drawing.PointF ([single]($x + $q[0] * $k)), ([single]($y + ($q[1] - 1) * $k))
    }
    $fill = New-Object System.Drawing.SolidBrush ($D::FromArgb($alphas[$i], 255, 255, 255))
    $g.FillPolygon($fill, [System.Drawing.PointF[]]$pts)
  }
}

# ---- 1. icon-512.png : full-bleed square, 32-bit RGBA ----------------------------------------
$icon = New-Object System.Drawing.Bitmap 512, 512, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($icon)
$g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
Draw-Logo $g 0 0 512 0
$g.Dispose()
$icon.Save((Join-Path $out 'icon-512.png'), [System.Drawing.Imaging.ImageFormat]::Png); $icon.Dispose()

# ---- 2. feature-graphic-1024x500.png : opaque 24-bit RGB -------------------------------------
$W = 1024; $H = 500
$bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$bgRect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $bgRect, $ink, ($D::FromArgb(0x13,0x1b,0x27)), 20.0
$g.FillRectangle($bg, $bgRect)

function Draw-Glow($g, [double]$cx, [double]$cy, [double]$rad, $color, [int]$alpha) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse([single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))
  $pb = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
  $pb.CenterColor = $D::FromArgb($alpha, $color); $pb.SurroundColors = @($D::FromArgb(0, $color))
  $g.FillPath($pb, $path)
}
Draw-Glow $g 180 150 420 $cyan 26
Draw-Glow $g 900 420 380 ($D::FromArgb(0xff,0x6b,0x35)) 16

# Contour artwork: smooth closed curves around hills (green) and hollows (red).
function Draw-Contours($g, [double]$cx, [double]$cy, [double]$r0, [double]$step, [int]$n, [double]$ph, $color, [int]$alpha, [double]$wid) {
  for ($i = 1; $i -le $n; $i++) {
    $r = $r0 + $i * $step
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($t = 0; $t -lt 180; $t++) {
      $a = $t * 2 * [math]::PI / 180
      $k = 1 + 0.13 * [math]::Sin(2 * $a + $ph + $i * 0.07) + 0.07 * [math]::Sin(3 * $a + 1.7 * $ph) + 0.03 * [math]::Sin(5 * $a + $i * 0.2)
      $pts.Add((New-Object System.Drawing.PointF ([single]($cx + $r * $k * 1.35 * [math]::Cos($a))), ([single]($cy + $r * $k * [math]::Sin($a)))))
    }
    $pen = New-Object System.Drawing.Pen ($D::FromArgb($alpha, $color)), ([single]$wid)
    $pen.LineJoin = 'Round'
    $g.DrawClosedCurve($pen, $pts.ToArray(), 0.5, [System.Drawing.Drawing2D.FillMode]::Winding)
  }
}
$green = $D::FromArgb(0x00, 0xff, 0x88); $red = $D::FromArgb(0xff, 0x47, 0x57)
Draw-Contours $g 760 190 14 26 12 0.4 $green 46 1.6
Draw-Contours $g 960 420 10 24 9 2.0 $green 34 1.4
Draw-Contours $g 560 440 8 20 8 4.1 $red 38 1.4
Draw-Contours $g 90 40 6 22 7 1.1 $red 24 1.2
# Calm the area behind the text so the headline stays legible.
$scrim = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 760, $H), ($D::FromArgb(235, 0x0a,0x0e,0x14)), ($D::FromArgb(0, 0x0a,0x0e,0x14)), 0.0
$g.FillRectangle($scrim, 0, 0, 760, $H)

# Logo tile (safe area: >= 60px from every edge).
$tile = 164; $tileX = 80; $tileY = ($H - $tile) / 2
Draw-Logo $g $tileX $tileY $tile 0.2

# Fonts from the bundled Outfit files.
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in 'Outfit-SemiBold.ttf', 'Outfit-Regular.ttf') { $pfc.AddFontFile((Join-Path $root "assets\fonts\outfit\$f")) }
$famSemi = $pfc.Families | Where-Object { $_.Name -like '*SemiBold*' } | Select-Object -First 1
if (-not $famSemi) { $famSemi = $pfc.Families[0] }
$famReg = $pfc.Families | Where-Object { $_.Name -eq 'Outfit' } | Select-Object -First 1
if (-not $famReg) { $famReg = $pfc.Families[0] }
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

$textX = 290; $maxW = ($W - 60) - $textX
$size = 62
$parts = @(@('Survey ', [System.Drawing.Color]::White), @('Contour', $cyan), @(' Generator', [System.Drawing.Color]::White))
do {
  $fontH = New-Object System.Drawing.Font $famSemi, ([single]$size), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
  $total = 0; foreach ($p in $parts) { $total += $g.MeasureString($p[0], $fontH, 4000, $fmt).Width }
  $size -= 1
} while ($total -gt $maxW)
$hy = $H / 2 - 62
$cx = [double]$textX
foreach ($p in $parts) {
  $g.DrawString($p[0], $fontH, (New-Object System.Drawing.SolidBrush $p[1]), [single]$cx, [single]$hy, $fmt)
  $cx += $g.MeasureString($p[0], $fontH, 4000, $fmt).Width
}
$fontT = New-Object System.Drawing.Font $famReg, ([single]30), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('TIN contour maps from survey points', $fontT, (New-Object System.Drawing.SolidBrush ($D::FromArgb(0x8b,0x94,0x9e))), [single]$textX, [single]($hy + $fontH.Size * 1.3), $fmt)
$ul = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle $textX, 0, 120, 4), $cyan, $purple, 0.0
$g.FillRectangle($ul, $textX, [int]($hy + $fontH.Size * 1.3 + 58), 120, 4)
Write-Host ('Headline size {0}px, families: {1}' -f ($size + 1), (($pfc.Families | ForEach-Object Name) -join ', '))
$g.Dispose()
$bmp.Save((Join-Path $out 'feature-graphic-1024x500.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host 'Icon and feature graphic generated.'
