# Survey Contour Generator

A professional, browser-based survey contour map generator for civil engineers and surveyors. Built on Triangulated Irregular Network (TIN) methodology using Delaunay Triangulation, it produces publication-quality contour maps and exports directly to AutoCAD-compatible formats.

> **This application was generated using AI assistance.**

---

## Features

- **TIN-based contouring** — Bowyer-Watson Delaunay Triangulation with Catmull-Rom spline smoothing for accurate, smooth contour lines
- **Excel import** — Load survey point data (X, Y, RL/elevation) directly from `.xlsx` files
- **Breakline support** — Define hard breaklines to enforce terrain boundaries and sharp ridge/valley features
- **Interactive canvas** — Pan, zoom, and inspect the contour map with mouse/touch controls
- **TIN visualizer** — Animated step-by-step Delaunay triangulation construction
- **Terrain analysis** — Auto-generated engineering summary with slope distribution, area calculations, and elevation statistics
- **Offline mode** — Bundle all CDN libraries inline for fully air-gapped use
- **Multiple export formats:**

  | Format | Description |
  |--------|-------------|
  | `.dxf` | AutoCAD DXF R12 — contours and survey points |
  | `.lsp` | AutoLISP script for direct AutoCAD import |
  | `.scr` | Civil 3D command script |
  | `.png` | High-resolution raster image (3000×3000 px) |
  | `.bmp` | Bitmap image (3000×3000 px) |
  | `.xlsx` | Processed survey data export |
  | Print | Browser print dialog |

---

## Getting Started

No installation or build step required. This is a single-file application.

1. Download `contour-v12_4-tin-fixed.html`
2. Open it in any modern web browser (Chrome, Edge, Firefox recommended)
3. The app loads its dependencies from CDN on first launch — internet connection required (unless using Offline Mode)

---

## Input Format

Import survey data via an Excel (`.xlsx`) file with the following columns:

| Column | Description |
|--------|-------------|
| `X` | Easting coordinate |
| `Y` | Northing coordinate |
| `RL` or `Z` | Reduced Level / Elevation |

Additional columns (point ID, description, etc.) are ignored.

---

## Usage

1. Click **Import Excel** and select your survey point file
2. Adjust contour interval as needed
3. Optionally define breaklines via the Breakline editor
4. Click **Generate Contours**
5. Inspect the map, view the terrain summary, then export in your preferred format

---

## Libraries Used

All libraries are loaded from public CDNs at runtime — no `npm install` required.

| Library | Version | Purpose |
|---------|---------|---------|
| [React](https://react.dev) | 18 | UI framework |
| [ReactDOM](https://react.dev) | 18 | DOM rendering |
| [Babel Standalone](https://babeljs.io) | latest | In-browser JSX transpilation |
| [SheetJS (xlsx)](https://sheetjs.com) | 0.20.3 | Excel file parsing |
| [Highcharts](https://www.highcharts.com) | 11.4.8 | Slope distribution charts |
| [Anime.js](https://animejs.com) | 3.2.1 | TIN construction animation |

---

## Browser Compatibility

| Browser | Support |
|---------|---------|
| Chrome 90+ | Full |
| Edge 90+ | Full |
| Firefox 88+ | Full |
| Safari 15+ | Full |
| Mobile (Chrome/Safari) | Supported |

---

## Version

**v12.4** — Build date: 2026-01-26

---

## License

This project is provided as-is for engineering and surveying use. No warranty is expressed or implied.
