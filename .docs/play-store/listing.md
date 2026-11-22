# Google Play store listing - draft copy (en-US)

Everything below is ready to paste into Play Console. Character limits are Google's; counts were checked.

## App details

| Field | Limit | Draft |
|---|---|---|
| **App name** | 30 | `ContourGen: Survey Contour Map` (30) - entered in Play Console; keeps the in-app brand "ContourGen" and adds the keywords "survey contour map" |
| Alternatives | 30 | `Survey Contour Generator` (24), `ContourGen: Survey Contours` (27) |
| **Short description** | 80 | `Survey contour map maker: Excel to TIN, slope analysis, DXF and AutoLISP export` (79) |
| Alternatives | 80 | `Contour map maker for surveyors: Excel to TIN, slope, DXF and AutoCAD export` (76) |
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

## Full description (limit 4000; this SEO-optimised draft is 2,040)

Written for Play search: the first 167 characters are what shows before "Read more", so the main keywords sit there; every important term appears naturally two or three times; no keyword lists, no repeated phrases, no competitor names.

```
Survey Contour Generator is a contour map maker for land surveyors, civil engineers and site engineers. Import survey points from Excel, build a TIN surface and get clean contour lines with elevation labels, then export to AutoCAD, Civil 3D or any CAD software. It works fully offline.

WHAT YOU CAN DO
• Generate a contour map from X, Y and RL (elevation) survey data in seconds
• Build a TIN (triangulated irregular network) with Delaunay triangulation
• Set the contour interval and major contour lines, with optional smoothing
• Add breaklines to follow ridges, valleys and edges of the ground surface
• Zoom, pan and pinch on an interactive topographic map; toggle points, labels, TIN and contours
• See terrain analysis: elevation range, average and maximum slope, slope distribution and survey area, with a plain-language summary
• Watch the triangulation being built with the TIN visualizer

EXPORT TO CAD AND REPORTS
• DXF (R12) with contours, breaklines and survey points on separate layers
• AutoLISP (.lsp) and Civil 3D script (.scr) for direct import
• High-resolution PNG and BMP images (3000 x 3000), Excel export and print

IMPORT SURVEY DATA FROM EXCEL
Open an .xlsx file with columns X (Easting), Y (Northing), RL (Z, Elevation) and a point name (BH, ID, Name). Add a LineName column to define breaklines. A built-in sample data set lets you try everything first.

PRIVATE AND OFFLINE
All calculations run on your device. No account, no ads, no tracking, and the app needs no internet access, so your survey data never leaves your phone or tablet.

BUILT FOR
Topographic surveys, site plans, grading and earthwork checks, borehole and spot-level plans, and quick field verification of ground levels.

ALSO ON THE WEB
The same app runs in your browser and installs to work offline: makeshvineeth.github.io/survey-contour-generator
Open source (MIT): github.com/MakeshVineeth/survey-contour-generator

AutoCAD and Civil 3D are trademarks of Autodesk, Inc. This app is not affiliated with or endorsed by Autodesk.
```

## Search keyword plan (ASO)

Play has no keyword field: ranking comes from the title, short and full description, the app's category and tags, installs, ratings and retention. Target these phrases, in this order of priority:

| Priority | Phrase | Where it appears |
|---|---|---|
| 1 | contour map, contour lines | title ("Contour"), short, first paragraph, features |
| 1 | survey, land surveying, surveyor | title, short, first paragraph, "Built for" |
| 2 | TIN, Delaunay triangulation | short, features |
| 2 | DXF, AutoCAD, Civil 3D, AutoLISP | short, export section |
| 2 | topographic map, elevation, slope analysis | features |
| 3 | Excel (xlsx), civil engineer, site plan, grading, earthwork | import, built-for |
| 3 | offline | first paragraph, private section |

Rules that keep it policy-safe: never repeat a phrase more than 4-5 times, no lists of unrelated keywords, no emoji or symbols as decoration in the title/short description, no claims like "best", "#1", "free", and use the Autodesk names only as plain descriptive text with the disclaimer.

Other ranking levers to set in Console: category **Tools** (or Productivity), up to 5 **tags**, a clear feature graphic and first screenshot (the captions in `phone-captioned/` contain "Contour maps", "Excel", "Export to AutoCAD"), and replying to every review. Ratings matter most after launch: ask satisfied users to rate it.

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
