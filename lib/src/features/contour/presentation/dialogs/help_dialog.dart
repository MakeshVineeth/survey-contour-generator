import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_info.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_modal.dart';

/// Opens the "Help & Documentation" modal.
Future<void> showHelpDialog(BuildContext context) =>
    showAppModal<void>(context, builder: (_) => const HelpDialog());

/// Reference help modal (lines 3774–3965) without the offline/online version
/// texts.
class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) => AppModal(
    title: 'Help & Documentation',
    maxWidth: 600,
    bodyMaxHeightFactor: 0.7,
    onClose: () => Navigator.of(context).pop(),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DataImport(),
        _SettingsHelp(),
        _DrawHelp(),
        _EditHelp(),
        _NavigationHelp(),
        _StatisticsHelp(),
        _AnalysisHelp(),
        _LayersHelp(),
        _ExportHelp(),
        _VersionInfo(),
        _TechnicalDetails(),
        _Footer(),
      ],
    ),
  );
}

// ---- building blocks -------------------------------------------------------

TextStyle get _body =>
    AppText.ui(12, color: AppColors.textSecondary, height: 1.6);

InlineSpan _t(String text) => TextSpan(text: text);

InlineSpan _b(String text) => TextSpan(
  text: text,
  style: const TextStyle(fontWeight: FontWeight.w700),
);

InlineSpan _colored(String text, Color color) => TextSpan(
  text: text,
  style: TextStyle(color: color),
);

InlineSpan _code(String text) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text, style: AppText.mono(10, color: AppColors.accentGreen)),
  ),
);

InlineSpan _kbd(String text) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text, style: AppText.mono(11, color: AppColors.textSecondary)),
  ),
);

/// `.help-section`: cyan `h4` title above its content, 16px below.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: AppText.ui(
              13,
              color: AppColors.accentCyan,
              weight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _Para extends StatelessWidget {
  const _Para(this.spans, {this.size = 12, this.bottom = 0});

  final List<InlineSpan> spans;
  final double size;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: Text.rich(
      TextSpan(
        style: AppText.ui(size, color: AppColors.textSecondary, height: 1.6),
        children: spans,
      ),
    ),
  );
}

/// `<ul>` / `<ol>` with 12px items.
class _ListBlock extends StatelessWidget {
  const _ListBlock(
    this.items, {
    this.ordered = false,
    this.top = 6,
    this.bottom = 0,
  });

  final List<List<InlineSpan>> items;
  final bool ordered;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 20, top: top, bottom: bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ordered ? 18 : 12,
                child: Text(ordered ? '${i + 1}.' : '•', style: _body),
              ),
              Expanded(
                child: Text.rich(TextSpan(style: _body, children: items[i])),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Callout extends StatelessWidget {
  const _Callout({required this.color, required this.spans});

  final Color color;
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withAlpha(0x1A),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text.rich(
      TextSpan(
        style: AppText.ui(10, color: color),
        children: spans,
      ),
    ),
  );
}

// ---- sections ---------------------------------------------------------------

class _DataImport extends StatelessWidget {
  const _DataImport();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Data Import',
    children: [
      _Para([
        _t(
          'Upload Excel files (.xlsx) containing survey data. The application '
          'automatically detects columns based on common naming conventions:',
        ),
      ]),
      _ListBlock([
        [_b('Point ID:'), _t(' BoreholeID, BH, ID, Name, Point')],
        [_b('X Coordinate:'), _t(' X, Easting, E')],
        [_b('Y Coordinate:'), _t(' Y, Northing, N')],
        [_b('Elevation:'), _t(' RL, Z, Elevation, Elev')],
        [_b('Breaklines:'), _t(' LineName, BreakLine, Line (with X, Y, RL)')],
      ]),
    ],
  );
}

class _SettingsHelp extends StatelessWidget {
  const _SettingsHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Settings Tab',
    children: [
      _Para([_t('Configure contour generation parameters:')]),
      _ListBlock([
        [
          _b('Contour Interval:'),
          _t(' Vertical spacing between contour lines (default: 1m)'),
        ],
        [
          _b('Major Contour Every:'),
          _t(' Frequency of bold/major contours (default: every 5th)'),
        ],
        [
          _b('Smoothing:'),
          _t(' Contour curve smoothness (0=angular, 10=very smooth)'),
        ],
      ]),
    ],
  );
}

class _DrawHelp extends StatelessWidget {
  const _DrawHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Draw Tab - Manual Breaklines',
    children: [
      _Para([
        _t(
          'Create and edit breaklines to control contour flow along terrain features:',
        ),
      ]),
      _ListBlock(ordered: true, [
        [_t('Click "Start Drawing Breakline"')],
        [_t('Click on the canvas to add points (minimum 2 required)')],
        [_t('Use "Undo" to remove the last point')],
        [_t('Click "Finish" to save or "Cancel" to discard')],
      ]),
      _Callout(
        color: AppColors.accentGreen,
        spans: [
          _b('Smart RL Extrapolation:'),
          _t(
            ' Elevation (RL) is automatically calculated using TIN '
            'interpolation or nearest borehole + slope gradient.',
          ),
        ],
      ),
    ],
  );
}

class _EditHelp extends StatelessWidget {
  const _EditHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Edit Breaklines',
    children: [
      _Para([_t('Modify existing breakline coordinates:')]),
      _ListBlock([
        [
          _b('View/Edit Points:'),
          _t(' Click the eye icon next to any breakline name'),
        ],
        [
          _b('Edit Coordinates:'),
          _t(' Modify X, Y, or RL values directly in the table'),
        ],
        [
          _b('Save Changes:'),
          _t(' Changes save automatically on blur or Enter key'),
        ],
        [
          _b('Numeric Only:'),
          _t(' Input fields accept numbers only (no alphabets)'),
        ],
        [
          _b('Delete Breakline:'),
          _t(' Click the trash icon to remove entire breakline'),
        ],
      ]),
    ],
  );
}

class _NavigationHelp extends StatelessWidget {
  const _NavigationHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Navigation Controls',
    children: [
      _Para(size: 11, bottom: 8, [_b('Normal Mode:')]),
      _ListBlock(top: 0, bottom: 12, [
        [_b('Zoom:'), _t(' Mouse scroll wheel or pinch gesture (mobile)')],
        [
          _b('Pan:'),
          _t(' Click and drag on canvas (desktop) or touch drag (mobile)'),
        ],
        [
          _b('Fit View:'),
          _t(' Click '),
          _kbd('⛶ Fit'),
          _t(' button to frame all data'),
        ],
      ]),
      _Para(size: 11, bottom: 8, [_b('Draw Mode (while drawing breaklines):')]),
      _ListBlock(top: 0, [
        [_b('Add Point:'), _t(' Click on canvas to place breakline point')],
        [
          _b('Pan (Desktop):'),
          _t(' Hold '),
          _kbd('Space'),
          _t(' key + Click & Drag'),
        ],
        [
          _b('Pan (Mobile):'),
          _t(' Use mode toggle buttons — switch between '),
          _colored('Add', AppColors.accentCyan),
          _t(' and '),
          _colored('Pan', AppColors.accentGreen),
          _t(' modes'),
        ],
        [_b('Zoom:'), _t(' Scroll wheel or pinch (works in both modes)')],
      ]),
      _Callout(
        color: AppColors.accentCyan,
        spans: [
          _b('Tip:'),
          _t(
            ' On mobile, tap the toggle buttons frequently to switch between '
            'adding points and panning the view',
          ),
        ],
      ),
    ],
  );
}

class _StatisticsHelp extends StatelessWidget {
  const _StatisticsHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Statistics (Data Tab)',
    children: [
      _Para(bottom: 8, [
        _t(
          'Click any of the four statistics cards to view detailed information:',
        ),
      ]),
      _ListBlock([
        [
          _b('📍 Boreholes:'),
          _t(
            ' Survey point details, elevation range, relief, purpose in TIN generation',
          ),
        ],
        [
          _b('〰️ Breaklines:'),
          _t(
            ' Total line segments, lengths, function in terrain modeling, '
            'constrained triangulation',
          ),
        ],
        [
          _b('△ Triangles:'),
          _t(
            ' TIN mesh coverage area, triangle size statistics, Delaunay '
            'algorithm explanation',
          ),
        ],
        [
          _b('🗺 Contours:'),
          _t(
            ' Interval settings, elevation coverage span, real-world applications',
          ),
        ],
      ]),
      _Callout(
        color: AppColors.accentGreen,
        spans: [
          _b('Interactive:'),
          _t(
            ' Each modal provides live calculations and surveying context '
            'specific to your data',
          ),
        ],
      ),
    ],
  );
}

class _AnalysisHelp extends StatelessWidget {
  const _AnalysisHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Analysis Tab',
    children: [
      _Para([
        _t('Comprehensive terrain analysis with animated visualizations:'),
      ]),
      _ListBlock([
        [
          _b('TIN Construction Visualizer:'),
          _t(
            ' Advanced animated visualization showing Delaunay triangulation '
            'process with timeline sequencing, elastic bouncing, staggered '
            'morphing from center, and continuous loop animations (powered by Anime.js)',
          ),
        ],
        [
          _b('Slope Gauge:'),
          _t(
            ' Animated average slope indicator with color-coded severity levels',
          ),
        ],
        [
          _b('Terrain Classification:'),
          _t(
            ' Flat, Gentle, Moderate, Steep, Extreme with real-time assessment',
          ),
        ],
        [
          _b('Elevation Statistics:'),
          _t(' Min, Max, Average, Range with animated counters'),
        ],
        [
          _b('Slope Analysis:'),
          _t(' Distribution and classification across survey area'),
        ],
        [
          _b('Interactive Charts:'),
          _t(' Click expand icon for full-screen detailed view'),
        ],
        [
          _b('AI Smart Summary:'),
          _t(
            ' Intelligent terrain interpretation and construction recommendations',
          ),
        ],
      ]),
      _Callout(
        color: AppColors.accentPurple,
        spans: [
          _b('Animations:'),
          _t(
            ' Smooth, physics-based animations enhance data comprehension. '
            'Optimized for both desktop and mobile.',
          ),
        ],
      ),
    ],
  );
}

class _LayersHelp extends StatelessWidget {
  const _LayersHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Layers Tab',
    children: [
      _Para([_t('Toggle visibility of map elements:')]),
      _ListBlock([
        [_b('TIN Mesh:'), _t(' Triangulated Irregular Network')],
        [_b('Contour Lines:'), _t(' Minor and major elevation lines')],
        [_b('Breaklines:'), _t(' Terrain feature lines')],
        [_b('Labels:'), _t(' Point IDs and RL values')],
      ]),
    ],
  );
}

class _ExportHelp extends StatelessWidget {
  const _ExportHelp();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Export Options',
    children: [
      _Para([
        _t('Click the '),
        _b('Export'),
        _t(' button to access all export formats:'),
      ]),
      _ListBlock([
        [
          _b('AutoLISP Script (.lsp):'),
          _t(' Most reliable method. Load in AutoCAD with '),
          _code('(load "file.lsp")'),
          _t(' then run '),
          _code('IMPORT-ALL'),
        ],
        [
          _b('Civil 3D Script (.scr):'),
          _t(
            ' AutoCAD command script. Run with SCRIPT command or paste into command line',
          ),
        ],
        [
          _b('DXF R12:'),
          _t(
            ' Maximum compatibility format. Works with virtually all CAD software',
          ),
        ],
        [_b('PNG Image:'), _t(' High-resolution (3000×3000) raster export')],
        [_b('BMP Bitmap:'), _t(' Uncompressed bitmap format (3000×3000)')],
        [_b('Print:'), _t(' Opens print dialog with contour map')],
        [
          _b('Breaklines to Excel:'),
          _t(' Export breakline coordinates to spreadsheet'),
        ],
      ]),
      _Callout(
        color: AppColors.accentCyan,
        spans: [
          _b('DWG Export:'),
          _t(
            ' DWG is proprietary. Export DXF or AutoLISP → Open in AutoCAD → Save As DWG',
          ),
        ],
      ),
    ],
  );
}

/// Two-column monospace grid (`gridTemplateColumns: '1fr 1fr'`, gap 8).
class _InfoGrid extends StatelessWidget {
  const _InfoGrid(this.rows);

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  rows[i].$1,
                  style: AppText.mono(10, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(rows[i].$2, style: AppText.mono(10))),
            ],
          ),
        ),
    ],
  );
}

class _VersionInfo extends StatelessWidget {
  const _VersionInfo();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Version Information',
            style: AppText.ui(
              12,
              color: AppColors.accentCyan,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const _InfoGrid([
          ('Application:', 'ContourGen v${AppInfo.version}'),
          ('Build Date:', AppInfo.buildDate),
        ]),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: const _InfoGrid([
            ('Algorithm:', 'Constrained Delaunay TIN'),
            ('Contour Method:', 'Marching Squares'),
            ('DXF Format:', 'R12 (AC1009)'),
            ('Image Export:', '3000×3000 PNG/BMP'),
          ]),
        ),
      ],
    ),
  );
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.accentCyan.withAlpha(0x0D),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.accentCyan.withAlpha(0x33)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '🔧 Technical Details',
            style: AppText.ui(
              11,
              color: AppColors.accentCyan,
              weight: FontWeight.w600,
            ),
          ),
        ),
        for (final line in const [
          'Triangulation: Bowyer-Watson algorithm with constrained edges',
          "Smoothing: Chaikin's corner-cutting algorithm (configurable iterations)",
          'Coordinate System: Survey coordinates (Easting/Northing)',
          'Data Format: Excel (.xlsx) with auto-column detection',
          'Export: DXF R12, AutoLISP, Civil 3D Script, PNG, BMP, Excel',
        ])
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '• $line',
              style: AppText.ui(10, color: AppColors.textSecondary),
            ),
          ),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      'Survey Contour Generator | Professional Surveying Tool',
      textAlign: TextAlign.center,
      style: AppText.ui(10, color: AppColors.textMuted),
    ),
  );
}
