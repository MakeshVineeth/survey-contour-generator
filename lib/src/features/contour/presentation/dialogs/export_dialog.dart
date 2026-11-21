import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_modal.dart';
import '../controllers/contour_controller.dart';
import '../widgets/map/map_image_export.dart';

/// Opens the "Export Options" modal.
Future<void> showExportDialog(BuildContext context) =>
    showAppModal<void>(context, builder: (_) => const ExportDialog());

/// Reference export modal (lines 4074–4164). Each option triggers the matching
/// [ContourController] export and closes the dialog when it succeeded
/// (the Excel export keeps it open, as in the reference).
class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _busy = false;

  ContourController get _contours => context.read<ContourController>();

  Future<bool> _png() => _image('png', MapImageExport.png);
  Future<bool> _bmp() => _image('bmp', MapImageExport.bmp);

  Future<bool> _image(
    String format,
    Future<Uint8List> Function(BuildContext) render,
  ) async {
    final contours = _contours;
    final bytes = await render(context);
    return contours.saveImage(bytes, format);
  }

  Future<bool> _print() async {
    final contours = _contours;
    final bytes = await MapImageExport.printPng(context);
    return contours.printPng(bytes);
  }

  Future<void> _run(
    Future<bool> Function() action, {
    bool closes = true,
  }) async {
    if (_busy) return;
    _busy = true;
    var ok = false;
    try {
      ok = await action();
    } on Object catch (e) {
      if (mounted) _contours.showToast('✕ Export failed: $e');
    } finally {
      _busy = false;
    }
    if (ok && closes && mounted) Navigator.of(context).pop();
  }

  void _start(Future<bool> Function() action, {bool closes = true}) =>
      unawaited(_run(action, closes: closes));

  @override
  Widget build(BuildContext context) {
    final contours = _contours;
    return AppModal(
      title: 'Export Options',
      maxWidth: 600,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TipBox(),
          _ExportOption(
            tag: '.lsp',
            color: AppColors.accentGreen,
            title: 'AutoLISP Script',
            description: 'Most reliable method. Run IMPORT-ALL in AutoCAD.',
            onTap: () => _start(contours.exportAutoLisp),
          ),
          _ExportOption(
            tag: '.scr',
            color: AppColors.accentCyan,
            title: 'Civil 3D Script',
            description: 'AutoCAD command script. Run with SCRIPT command.',
            onTap: () => _start(contours.exportCivil3dScript),
          ),
          _ExportOption(
            tag: '.dxf',
            color: AppColors.accentOrange,
            title: 'DXF R12',
            description: 'Maximum compatibility with all CAD software.',
            onTap: () => _start(contours.exportDxf),
          ),
          _ExportOption(
            tag: '.png',
            color: AppColors.accentPurple,
            title: 'PNG Image',
            description: 'High-resolution 3000×3000 for presentations.',
            onTap: () => _start(_png),
          ),
          _ExportOption(
            tag: '.bmp',
            color: AppColors.textMuted,
            title: 'BMP Bitmap',
            description: 'Uncompressed 3000×3000 bitmap format.',
            onTap: () => _start(_bmp),
          ),
          _ExportOption(
            tag: '⎙',
            color: AppColors.textSecondary,
            title: 'Print',
            description: 'Print the contour map directly.',
            tagSize: 16,
            mono: false,
            onTap: () => _start(_print),
          ),
          _ExportOption(
            tag: '.xlsx',
            color: AppColors.excelGreen,
            title: 'Breaklines to Excel',
            description: 'Export breakline coordinates to spreadsheet.',
            last: true,
            onTap: () => _start(contours.exportBreaklinesXlsx, closes: false),
          ),
          const _DwgNote(),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text.rich(
      TextSpan(
        style: AppText.ui(11, color: AppColors.textSecondary),
        children: [
          TextSpan(
            text: 'Tip:',
            style: AppText.ui(
              11,
              color: AppColors.accentGreen,
              weight: FontWeight.w700,
            ),
          ),
          const TextSpan(
            text: ' Use AutoLISP Script for most reliable AutoCAD/Civil 3D import',
          ),
        ],
      ),
    ),
  );
}

class _DwgNote extends StatelessWidget {
  const _DwgNote();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text.rich(
      TextSpan(
        style: AppText.ui(11, color: AppColors.textSecondary),
        children: [
          TextSpan(
            text: 'DWG:',
            style: AppText.ui(
              11,
              color: AppColors.accentCyan,
              weight: FontWeight.w700,
            ),
          ),
          const TextSpan(
            text: ' Export DXF/LISP → Open in AutoCAD → Save As DWG',
          ),
        ],
      ),
    ),
  );
}

/// `.export-option`: icon tile + title/description, hover lift with glow.
class _ExportOption extends StatefulWidget {
  const _ExportOption({
    required this.tag,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
    this.tagSize = 11,
    this.mono = true,
    this.last = false,
  });

  final String tag;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  final double tagSize;
  final bool mono;
  final bool last;

  @override
  State<_ExportOption> createState() => _ExportOptionState();
}

class _ExportOptionState extends State<_ExportOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: widget.last ? 0 : 12),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? AppColors.bgPrimary : AppColors.bgTertiary,
            border: Border.all(
              color: _hover ? AppColors.accentCyan : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AppColors.accentCyan.withAlpha(0x33),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _tile(),
              const SizedBox(width: 12),
              Expanded(child: _texts()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tile() => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: widget.color, width: 1.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      widget.tag,
      style: widget.mono
          ? AppText.mono(
              widget.tagSize,
              color: widget.color,
              weight: FontWeight.w600,
            )
          : AppText.ui(widget.tagSize, color: widget.color),
    ),
  );

  Widget _texts() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          widget.title,
          style: AppText.ui(14, weight: FontWeight.w600),
        ),
      ),
      Text(
        widget.description,
        style: AppText.ui(11, color: AppColors.textSecondary, height: 1.4),
      ),
    ],
  );
}
