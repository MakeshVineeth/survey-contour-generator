# 8. Import fix for zero values and CAD label sanitization

Status: Accepted

## Context
1. The reference resolved column aliases with `a || b || c`, so a legitimate X, Y or RL of `0` was
   treated as missing.
2. Borehole and line names from the spreadsheet are written into AutoLISP (`.lsp`), Civil 3D (`.scr`) and
   DXF text. A crafted name (quotes, parentheses, newlines) could inject commands into the user's CAD session.

## Decision
- `SurveyRowParser` picks the first alias whose value is neither null nor an empty string, so `0` is kept.
  Accepted aliases: X/Easting/E, Y/Northing/N, RL/Z/Elevation/Elev, BoreholeID/BH/ID/Name/Point/Borehole,
  LineName/BreakLine/Line.
- `cad_text.dart` sanitizes labels before any exporter writes them.

## Consequences
- Output differs from the JS reference only for rows containing `0` (intentional) and for unsafe labels.
- Parity fixtures must avoid these two cases or be updated deliberately.
