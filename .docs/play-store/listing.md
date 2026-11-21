# Google Play store listing - draft copy (en-US)

Everything below is ready to paste into Play Console. Character limits are Google's; counts were checked.

## App details

| Field | Limit | Draft |
|---|---|---|
| **App name** | 30 | `Survey Contour Generator` (24) |
| Alternatives | 30 | `ContourGen: Survey Contours` (27) |
| **Short description** | 80 | `Turn survey points into TIN contour maps and export to AutoCAD. Works offline.` (78) |
| Alternatives | 80 | `Survey contour maps from Excel data. DXF, AutoLISP & Civil 3D export. Offline.` (78) |
| **Default language** | | English (United States) - en-US |
| **App or game** | | App |
| **Free or paid** | | Free (a free app can never be switched to paid later) |
| **Category** | | Tools (alternative: Productivity or Business). Pick one primary category. |
| **Tags** | up to 5 | choose from Console's list, e.g. Utility / Maps / Productivity tools |
| **Website** | | https://makeshvineeth.github.io/survey-contour-generator/ |
| **Privacy policy URL** | | https://makeshvineeth.github.io/survey-contour-generator/privacy.html (page is in this repo, `web/privacy.html`) |
| **Support email** | required, public | use a dedicated address you are happy to show publicly - **decide before submitting** |
| Phone / address | optional | leave blank for a personal account |

Naming rules to respect: no emoji or ALL CAPS, no "best / #1 / free / new", no price or ranking claims, no keyword stuffing, and nothing that implies endorsement by Autodesk.

## Full description (limit 4000, this draft is about 1900)

```
Survey Contour Generator turns your survey points into clear contour maps on your phone, tablet or laptop. Import an Excel sheet, set the contour interval, and get a TIN-based map you can inspect, analyse and export to AutoCAD.

KEY FEATURES
• TIN contouring - Delaunay triangulation with optional smoothing for clean contour lines
• Excel import - load X, Y and RL (elevation) from .xlsx files; common column names are recognised automatically
• Breaklines - import or draw breaklines so the surface follows ridges and valleys
• Interactive map - pan, zoom and pinch; show or hide points, labels, TIN and contours
• Terrain analysis - elevation range, slope distribution, survey area and a plain-language summary
• TIN visualizer - watch the triangulation being built step by step
• Export - DXF (R12), AutoLISP script, Civil 3D script, PNG and BMP images (3000 x 3000), Excel, and print

WORKS OFFLINE, PRIVATE BY DESIGN
Everything is calculated on your device. The app has no internet access, no account, no ads and no tracking. Your survey data never leaves your device.

BUILT FOR SURVEYORS AND ENGINEERS
Use it for site surveys, topographic plans, grading studies and quick checks in the field. Export to AutoCAD, Civil 3D or any CAD software that reads DXF.

INPUT FORMAT
An Excel (.xlsx) file with columns X (or Easting), Y (or Northing), RL (or Z, Elevation) and a point name (BH, ID, Name, Point). Add a LineName column to define breaklines. Tip: the app includes a sample data set so you can try it first.

ALSO ON THE WEB AND WINDOWS
The same app runs in your browser and can be installed to work offline: makeshvineeth.github.io/survey-contour-generator
Open source (MIT): github.com/MakeshVineeth/survey-contour-generator

AutoCAD and Civil 3D are trademarks of Autodesk, Inc. This app is not affiliated with or endorsed by Autodesk.
```

## Release notes

First release (what to put in "Release notes" for 13.0.0, limit 500, this is 363):

```
Survey Contour Generator 13.0
• Rebuilt as a native app with the same familiar interface
• TIN contour maps from Excel (.xlsx) survey points
• Export DXF, AutoLISP, Civil 3D script, PNG, BMP, Excel
• Terrain analysis: slope, elevation, summary
• Fixes: slope chart, contour label placement, version info
• Private by design: works fully offline, no network access
```

For the Play Console wrapper use `<en-US> ... </en-US>` only if you paste several languages; for a single language paste the text as is.

## Graphics (files are in `.docs/play-store/assets/`)

| Slot | Spec | File |
|---|---|---|
| App icon | 512 x 512 px, 32-bit PNG with alpha, up to 1 MB, full-bleed square (Google applies the mask) | `icon-512.png` |
| Feature graphic | 1024 x 500 px, JPEG or 24-bit PNG, no transparency | `feature-graphic-1024x500.png` |
| Phone screenshots | 2-8 images, JPEG or 24-bit PNG (no alpha), each side 320-3840 px, up to 8 MB, 16:9 or 9:16 | `phone-captioned/*.png` (1080 x 1920) |
| 7-inch tablet | optional, same rules | `tablet-7in/*.png` |
| 10-inch tablet | optional, same rules | `tablet-10in/*.png` |

Screenshot order = the order shown on the store page. Put the map first. Use the captioned set; keep the raw `phone/` set for updates.

Icon and screenshot do's: show the real app UI, keep text inside the safe area, no device frames that imply another brand, no "download now" calls to action, no badges or rankings.

## Iconography reference

| Item | Value |
|---|---|
| Concept | folded map glyph (three panels) on a diagonal gradient |
| Gradient | 135 degrees, `#00D9FF` (cyan) to `#A855F7` (purple) |
| Glyph | white, outer panels 84% opacity, centre panel solid; centred, about 58% of the width |
| Typeface | Outfit (headings, UI), JetBrains Mono (numbers) |
| UI colours | background `#0A0E14`, panels `#111820`, accent cyan `#00D9FF`, orange `#FF6B35`, green `#00FF88`, red `#FF4757` |
| Source of truth | `tool/branding/generate_icons.ps1` (launcher, web, Windows) and `lib/src/features/contour/presentation/widgets/shell/logo_mark.dart` (in-app) |

## Optional extras

- **Promo video** (YouTube URL, optional): a 30-45 s screen recording - import sample, contours appear, Analysis tab, Export. Must be public or unlisted, not age-restricted, monetisation off.
- **Custom store listings / other languages**: add later; the app UI is English-only today.
- **Localised listing**: translate title, short and full description only after the app UI supports that language.

Sources for the field limits: Google's [store listing guidance](https://support.google.com/googleplay/android-developer/answer/13393723) and [preview assets](https://support.google.com/googleplay/android-developer/answer/9866151).
