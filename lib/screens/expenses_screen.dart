import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/group_model.dart';
import '../services/ai_extraction_service.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import 'add_expense_screen.dart';
import 'extracted_expenses_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  List<GroupModel> _groups = [];
  bool _processing = false;
  double _progress = 0.0;
  String _statusText = 'Ready to extract expenses';
  late AnimationController _progressCtrl;

  // PDF toast state
  bool _pdfToastVisible = false;
  bool _pdfToastSuccess = false;
  String _pdfToastTitle = '';
  String _pdfToastSubtitle = '';
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    _loadGroups();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..addListener(() => setState(() => _progress = _progressCtrl.value));
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _loadGroups() async {
    final g = await StorageService.loadGroups();
    if (mounted) setState(() => _groups = g);
  }

  Future<void> _openAddManually() async {
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a group first!')),
      );
      return;
    }
    final isWhite = AppThemeNotifier.isWhite;
    final selectedGroup = await showModalBottomSheet<GroupModel>(
      context: context,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isWhite
                    ? const Color(0xFFCC0020).withOpacity(0.25)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Group',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isWhite ? EleghartColors.accentDark : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final g = _groups[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFCC0020).withOpacity(0.12),
                      backgroundImage: g.imagePath != null &&
                              File(g.imagePath!).existsSync()
                          ? FileImage(File(g.imagePath!))
                          : null,
                      child: g.imagePath == null
                          ? const Icon(Icons.group,
                              color: Color(0xFFCC0020), size: 18)
                          : null,
                    ),
                    title: Text(g.name,
                        style: GoogleFonts.sora(
                            color: isWhite
                                ? EleghartColors.accentDark
                                : Colors.white)),
                    onTap: () => Navigator.pop(context, g),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedGroup != null && mounted) {
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            group: selectedGroup,
            categories: selectedGroup.categories,
          ),
        ),
      );
      if (added == true && mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _progressCtrl.dispose();
    super.dispose();
  }

  // ─── file picking ─────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    final file = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 90);
    if (file != null && mounted) _runAI(File(file.path), file.name, isPdf: false);
  }

  Future<void> _pickGallery() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90);
    if (file != null && mounted) _runAI(File(file.path), file.name, isPdf: false);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final f = File(result.files.single.path!);
    final name = result.files.single.name;

    // Show password dialog
    final password = await _showPdfPasswordDialog();
    if (password == null || !mounted) return; // cancelled

    // Success toast while processing
    _triggerToast(
      success: true,
      title: 'PDF Unlocked',
      subtitle: 'AI is extracting expenses...',
    );

    try {
      await _runAI(f, name, isPdf: true);
    } catch (_) {
      if (!mounted) return;
      _dismissToast();
      _triggerToast(
        success: false,
        title: 'Extraction Failed',
        subtitle: 'Please take a photo of the PDF instead.',
        autoDismiss: true,
      );
    }
  }

  // ─── PDF password dialog ──────────────────────────────────────────────────

  Future<String?> _showPdfPasswordDialog() async {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);

    final ctrl = TextEditingController();
    bool showPwd = false;

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFCC0020).withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.18),
                    blurRadius: 28,
                    spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCC0020).withOpacity(0.12),
                        border: Border.all(
                            color: const Color(0xFFCC0020).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: Color(0xFFCC0020), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Password Protected PDF',
                              style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              'This PDF requires a password before expense extraction.',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: textSecondary)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded,
                          color: textSecondary, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Password field
                TextField(
                  controller: ctrl,
                  obscureText: !showPwd,
                  style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter PDF password',
                    hintStyle:
                        GoogleFonts.sora(fontSize: 13, color: textSecondary),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: textSecondary, size: 18),
                    suffixIcon: GestureDetector(
                      onTap: () => setLocal(() => showPwd = !showPwd),
                      child: Icon(
                          showPwd
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: textSecondary,
                          size: 18),
                    ),
                    filled: true,
                    fillColor:
                        isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1C0606),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFCC0020), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.sora(
                              fontWeight: FontWeight.w600,
                              color: textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFCC0020).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, ctrl.text.isNotEmpty
                                ? ctrl.text
                                : ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Unlock PDF',
                            style: GoogleFonts.sora(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PDF toast ────────────────────────────────────────────────────────────

  void _triggerToast({
    required bool success,
    required String title,
    required String subtitle,
    bool autoDismiss = true,
  }) {
    _toastTimer?.cancel();
    setState(() {
      _pdfToastVisible = true;
      _pdfToastSuccess = success;
      _pdfToastTitle = title;
      _pdfToastSubtitle = subtitle;
    });
    if (autoDismiss) {
      _toastTimer = Timer(const Duration(seconds: 4), _dismissToast);
    }
  }

  void _dismissToast() {
    _toastTimer?.cancel();
    if (mounted) setState(() => _pdfToastVisible = false);
  }

  // ─── AI extraction (on-device, no API key) ───────────────────────────────

  Future<void> _runAI(File file, String fileName, {required bool isPdf}) async {
    setState(() {
      _processing = true;
      _progress = 0.0;
      _statusText = 'Reading your document...';
    });
    _progressCtrl.repeat();

    List<ExtractedItem> items;
    try {
      setState(() => _statusText = 'Extracting expenses...');
      if (isPdf) {
        items = await AIExtractionService.extractFromPdf(pdfFile: file);
      } else {
        items = await AIExtractionService.extractFromImage(imageFile: file);
      }
    } catch (e) {
      _progressCtrl.stop();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusText = 'Ready to extract expenses';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().split('\n').first)),
      );
      return;
    }

    _progressCtrl.stop();
    if (!mounted) return;
    setState(() {
      _processing = false;
      _statusText = 'Ready to extract expenses';
    });

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No expenses found in document')));
      return;
    }

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExtractedExpensesScreen(items: items, sourceName: fileName),
      ),
    );

    if (added == true && mounted) Navigator.pop(context);
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final cardColor = isWhite ? Colors.white : const Color(0xFF120404);
    final borderColor =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    return Stack(
      children: [
        _buildScaffold(isWhite, cardColor, borderColor, textPrimary, textSecondary),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _pdfToastVisible ? 112 : -140,
          left: 16,
          right: 16,
          child: _pdfToastVisible
              ? _PdfToastCard(
                  success: _pdfToastSuccess,
                  title: _pdfToastTitle,
                  subtitle: _pdfToastSubtitle,
                  isWhite: isWhite,
                  onClose: _dismissToast,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildScaffold(
    bool isWhite,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) =>
      Scaffold(
      backgroundColor:
          isWhite ? const Color(0xFFF5F5F5) : Colors.black,
      appBar: AppBar(
        backgroundColor:
            isWhite ? Colors.white : const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Expense',
            style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary)),
      ),
      body: AbsorbPointer(
        absorbing: _processing,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Expense',
                  style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary)),
              const SizedBox(height: 4),
              Text('Upload a receipt or fill in manually',
                  style:
                      GoogleFonts.sora(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 20),

              // ── Upload box ─────────────────────────────────
              GestureDetector(
                onTap: _pickGallery,
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                      color: const Color(0xFFCC0020).withOpacity(0.7)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0020)
                          .withOpacity(isWhite ? 0.03 : 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            color: const Color(0xFFCC0020), size: 48),
                        const SizedBox(height: 12),
                        Text('Upload Receipt or Invoice',
                            style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                        const SizedBox(height: 6),
                        Text('PNG, JPG, PDF up to 10MB',
                            style: GoogleFonts.sora(
                                fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                  child: Text('OR',
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          color: textSecondary,
                          letterSpacing: 1.5))),
              const SizedBox(height: 12),

              // ── Take Photo ─────────────────────────────────
              _actionTile(Icons.camera_alt_outlined, 'Take Photo', cardColor,
                  borderColor, textPrimary, textSecondary, isWhite, _pickCamera),
              const SizedBox(height: 10),

              // ── Gallery ────────────────────────────────────
              _actionTile(Icons.folder_outlined, 'Choose from Gallery',
                  cardColor, borderColor, textPrimary, textSecondary, isWhite,
                  _pickGallery),
              const SizedBox(height: 10),

              // ── Upload PDF ─────────────────────────────────
              _actionTile(Icons.picture_as_pdf_outlined, 'Upload PDF Invoice',
                  cardColor, borderColor, textPrimary, textSecondary, isWhite,
                  _pickPdf),
              const SizedBox(height: 16),

              // ── AI Agent card ──────────────────────────────
              _buildAgentCard(cardColor, borderColor, textPrimary,
                  textSecondary, isWhite),
              const SizedBox(height: 20),

              // ── Add Manually divider ───────────────────────
              Row(children: [
                Expanded(child: Divider(color: textSecondary.withOpacity(0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR ADD MANUALLY',
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          color: textSecondary,
                          letterSpacing: 1.2)),
                ),
                Expanded(child: Divider(color: textSecondary.withOpacity(0.2))),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openAddManually,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFCC0020).withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCC0020).withOpacity(0.12),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: Color(0xFFCC0020), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Expense Manually',
                              style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary)),
                          Text('Select group, category & amount',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // ── Supported formats ──────────────────────────
              Text('Supported formats',
                  style: GoogleFonts.sora(
                      fontSize: 12,
                      color: textSecondary,
                      letterSpacing: 0.4)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _formatChip('PNG', Icons.image_outlined, isWhite,
                      textSecondary),
                  const SizedBox(width: 10),
                  _formatChip('JPG', Icons.photo_outlined, isWhite,
                      textSecondary),
                  const SizedBox(width: 10),
                  _formatChip('PDF', Icons.picture_as_pdf_outlined, isWhite,
                      textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );

  Widget _actionTile(
      IconData icon,
      String title,
      Color cardColor,
      Color borderColor,
      Color textPrimary,
      Color textSecondary,
      bool isWhite,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isWhite
              ? [
                  BoxShadow(
                      color: const Color(0xFFCC0020).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC0020).withOpacity(0.10)),
            child: Icon(icon, color: const Color(0xFFCC0020), size: 20),
          ),
          title: Text(title,
              style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary)),
          trailing: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: textSecondary),
        ),
      ),
    );
  }

  Widget _buildAgentCard(Color cardColor, Color borderColor, Color textPrimary,
      Color textSecondary, bool isWhite) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isWhite
            ? [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC0020).withOpacity(0.12)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/icons/eleghart_icon.png',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eleghart AI Agent',
                    style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                const SizedBox(height: 4),
                Text(
                    _statusText,
                    style:
                        GoogleFonts.sora(fontSize: 12, color: textSecondary)),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                          color: isWhite
                              ? const Color(0xFFEEEEEE)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    FractionallySizedBox(
                      widthFactor: _processing ? _progress : 0.0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFCC0020),
                              Color(0xFFFF3355)
                            ]),
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        _processing
                            ? 'AI is analysing...'
                            : 'Tap above to upload a document',
                        style: GoogleFonts.sora(
                            fontSize: 10, color: textSecondary)),
                    if (_processing)
                      Text('${(_progress * 100).toInt()}%',
                          style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFCC0020))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(
      String label, IconData icon, bool isWhite, Color textSecondary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFCC0020).withOpacity(0.35), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFCC0020), size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWhite
                        ? EleghartColors.accentDark
                        : Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const _DashedBorderPainter(
      {required this.color, this.strokeWidth = 1.5, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));
    const dashWidth = 8.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dashWidth), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => color != old.color;
}

// ─── PDF Toast Card ────────────────────────────────────────────────────────

class _PdfToastCard extends StatelessWidget {
  final bool success;
  final String title;
  final String subtitle;
  final bool isWhite;
  final VoidCallback onClose;

  const _PdfToastCard({
    required this.success,
    required this.title,
    required this.subtitle,
    required this.isWhite,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final iconBg = success
        ? const Color(0xFF22C55E).withOpacity(0.12)
        : const Color(0xFFCC0020).withOpacity(0.12);
    final iconColor =
        success ? const Color(0xFF22C55E) : const Color(0xFFCC0020);
    final borderColor = success
        ? const Color(0xFF22C55E).withOpacity(0.25)
        : const Color(0xFFCC0020).withOpacity(0.35);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: iconColor.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconBg,
                      border: Border.all(color: borderColor)),
                  child: Icon(
                      success
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      color: iconColor,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: GoogleFonts.sora(
                              fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded,
                      color: textSecondary, size: 18),
                ),
              ],
            ),
            if (success) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: isWhite
                      ? const Color(0xFFEEEEEE)
                      : Colors.white.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFCC0020)),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
