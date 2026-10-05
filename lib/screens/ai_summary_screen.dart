import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT AI SUMMARY THEME & COLORS RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class AiSummaryTheme {
  static const Color pageBg = Colors.white; // Pure White Canvas
  static const Color rubyRed = Color(0xFFE11D48); // Deep Ruby Red Primary
  static const Color darkRuby = Color(0xFFBE123C); // Dark Ruby
  static const Color pastelPink = Color(0xFFFECDD3); // Soft Pastel Pink Fill
  static const Color roseTint = Color(0xFFFFF1F2); // Soft Rose Canvas Tint
  static const Color pinkBorder =
      Color(0xFFFDA4AF); // Crisp Pink Border Outline
  static const Color goldenAccent = Color(0xFFF59E0B); // Radiant Gold
  static const Color textDark = Color(0xFF1E1348); // Deep Navy Black Text
  static const Color textMuted = Color(0xFF64748B); // Slate Muted Text

  // Specific Button Colors:
  static const Color shortButtonRed = Color(0xFFE11D48); // "Short" Button: Red
  static const Color detailedButtonWhite =
      Colors.white; // "Detailed" Button: White
  static const List<Color> generateButtonGold = [
    Color(0xFFFFD600), // Pure Radiant Gold
    Color(0xFFF59E0B), // Warm Golden Amber
  ];
}

class AiSummaryScreen extends StatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  final _aiService = AiService();
  final _inputController = TextEditingController();

  String? _summary;
  bool _isLoading = false;
  String? _error;

  String _summaryFormat = 'short'; // 'short' or 'detailed'

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // ── Generate AI Summary ───────────────────────────────────────────────────
  Future<void> _generateSummary() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      _snack('Please paste or write lecture notes first.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _summary = null;
    });

    try {
      final result = await _aiService.generateSummary(
        text,
        format: _summaryFormat,
      );
      setState(() => _summary = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save to User's Local Device (PDF Document) ────────────────────────────
  Future<void> _saveToLocalDevice() async {
    if (_summary == null || _summary!.trim().isEmpty) return;

    try {
      final pdf = pw.Document();
      final timestamp = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AI Student Productivity Ecosystem',
                    style: pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.pink800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${timestamp.year}-${timestamp.month}-${timestamp.day}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Lecture Note Summary (${_summaryFormat.toUpperCase()})',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.pink700),
            pw.SizedBox(height: 12),
            pw.Text(
              _summary!,
              style: const pw.TextStyle(fontSize: 11, height: 1.6),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Lecture_Summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      _snack('Summary prepared for local saving!', Colors.green);
    } catch (e) {
      _snack('Could not save to local device: $e', Colors.red);
    }
  }

  void _copyToClipboard() {
    if (_summary == null) return;
    Clipboard.setData(ClipboardData(text: _summary!));
    _snack('Copied summary to clipboard!', AiSummaryTheme.rubyRed);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiSummaryTheme.pageBg,
      body: Stack(
        children: [
          // ── Atmospheric Pastel Pink Ambient Circles ──
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiSummaryTheme.pastelPink.withOpacity(0.45),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiSummaryTheme.roseTint.withOpacity(0.8),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Input Box
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AiSummaryTheme.pinkBorder, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: AiSummaryTheme.rubyRed.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _inputController,
                      maxLines: 7,
                      style: const TextStyle(
                          color: AiSummaryTheme.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText:
                            'Paste or extract note text here to generate an executive summary…',
                        hintStyle: TextStyle(color: AiSummaryTheme.textMuted),
                        contentPadding: EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Format Selector (Short = Red, Detailed = White)
                  const Text(
                    'Summary Format',
                    style: TextStyle(
                      color: AiSummaryTheme.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Short Button: Red
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _summaryFormat = 'short'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _summaryFormat == 'short'
                                  ? AiSummaryTheme.shortButtonRed
                                  : AiSummaryTheme.roseTint,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AiSummaryTheme.rubyRed,
                                width: _summaryFormat == 'short' ? 2 : 1,
                              ),
                              boxShadow: _summaryFormat == 'short'
                                  ? [
                                      BoxShadow(
                                        color: AiSummaryTheme.rubyRed
                                            .withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                  color: _summaryFormat == 'short'
                                      ? Colors.white
                                      : AiSummaryTheme.rubyRed,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Short',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _summaryFormat == 'short'
                                        ? Colors.white
                                        : AiSummaryTheme.rubyRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Detailed Button: White
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _summaryFormat = 'detailed'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: AiSummaryTheme.detailedButtonWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _summaryFormat == 'detailed'
                                    ? AiSummaryTheme.rubyRed
                                    : AiSummaryTheme.pinkBorder,
                                width: _summaryFormat == 'detailed' ? 2 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                  color: AiSummaryTheme.rubyRed,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Detailed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _summaryFormat == 'detailed'
                                        ? AiSummaryTheme.rubyRed
                                        : AiSummaryTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Generate Button: Radiant Gold
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: AiSummaryTheme.generateButtonGold,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AiSummaryTheme.goldenAccent.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _generateSummary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: AiSummaryTheme.textDark,
                                  strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: AiSummaryTheme.textDark, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _summaryFormat == 'short'
                                      ? 'Generate Short Summary'
                                      : 'Generate Detailed Summary',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AiSummaryTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Error Banner
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Colors.red.shade800, fontSize: 13)),
                    ),
                  ],

                  // ── Summary Output View ──
                  if (_summary != null) ...[
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Executive Summary',
                              style: TextStyle(
                                color: AiSummaryTheme.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AiSummaryTheme.pastelPink,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _summaryFormat.toUpperCase(),
                                style: const TextStyle(
                                  color: AiSummaryTheme.rubyRed,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              color: AiSummaryTheme.rubyRed, size: 20),
                          tooltip: 'Copy',
                          onPressed: _copyToClipboard,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AiSummaryTheme.pinkBorder, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AiSummaryTheme.rubyRed.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        _summary!,
                        style: const TextStyle(
                          color: AiSummaryTheme.textDark,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveToLocalDevice,
                        icon: const Icon(Icons.download_rounded,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Save',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AiSummaryTheme.rubyRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AiSummaryTheme.textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        Column(
          children: const [
            Text(
              'AI Summary Studio',
              style: TextStyle(
                color: AiSummaryTheme.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Ruby Red & Pastel Pink Theme',
              style: TextStyle(
                color: AiSummaryTheme.rubyRed,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}
