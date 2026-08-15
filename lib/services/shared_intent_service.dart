import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/group_model.dart';
import '../screens/add_expense_screen.dart';
import '../screens/extracted_expenses_screen.dart';
import '../services/ai_extraction_service.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';

class SharedIntentService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static const MethodChannel _channel =
      MethodChannel('com.example.eleghart_ledger/share');

  static String? pendingSharedImagePath;
  static bool isUnlocked = false;

  static void init() {
    // Handle method calls when app is running and receives a shared image
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onImageShared') {
        final String? path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _handleSharedImagePath(path);
        }
      }
    });

    // Handle initial shared image when app was opened fresh from OS Share Sheet
    _getInitialSharedImage();
  }

  static Future<void> _getInitialSharedImage() async {
    try {
      final String? initialPath =
          await _channel.invokeMethod<String>('getInitialSharedImage');
      if (initialPath != null && initialPath.isNotEmpty) {
        _handleSharedImagePath(initialPath);
      }
    } catch (e) {
      debugPrint("Error fetching initial shared image: $e");
    }
  }

  static Future<void> _handleSharedImagePath(String path) async {
    pendingSharedImagePath = path;
    if (isUnlocked) {
      checkPendingSharedImage();
    }
  }

  static void onAppUnlocked() {
    isUnlocked = true;
    checkPendingSharedImage();
  }

  static void checkPendingSharedImage() {
    if (pendingSharedImagePath == null) return;
    final path = pendingSharedImagePath!;
    pendingSharedImagePath = null;

    final imageFile = File(path);
    if (!imageFile.existsSync()) return;

    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    _showChoiceSheet(navContext, imageFile);
  }

  static void _showChoiceSheet(BuildContext navContext, File imageFile) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black54 : Colors.white54;

    showModalBottomSheet(
      context: navContext,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF160606),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFFCC0020), size: 24),
                const SizedBox(width: 10),
                Text('Receipt Received', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: textPrimary), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Text('How would you like to add this receipt expense?', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
            const SizedBox(height: 20),

            // Option 1: AI Auto Extraction
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _runAiExtraction(navContext, imageFile);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFCC0020), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto-Extract with AI Agent', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 2),
                          Text('AI reads receipt to extract amount, merchant & date', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCC0020), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Add Manually
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _runManualEntry(navContext, imageFile);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220C0C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isWhite ? const Color(0xFFE2E8F0) : const Color(0xFF331414),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_note_rounded, color: textPrimary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fill Details Manually', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 2),
                          Text('Enter amount, select group & category yourself', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: textSec, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Future<GroupModel?> _pickGroup(BuildContext context) async {
    final groups = await StorageService.loadGroups();
    if (groups.isEmpty) {
      return GroupModel(id: 'main', name: 'General', categories: ['General']);
    }
    if (groups.length == 1) {
      return groups.first;
    }

    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black54 : Colors.white54;

    return showModalBottomSheet<GroupModel>(
      context: context,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF160606),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_copy_rounded, color: Color(0xFFCC0020), size: 22),
                const SizedBox(width: 10),
                Text('Select Target Group', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: textPrimary), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Which group does this expense belong to?', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final g = groups[i];
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, g),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220C0C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCC0020).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group_rounded, color: Color(0xFFCC0020), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                                Text('${g.categories.length} categories / members', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCC0020)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Future<void> _runAiExtraction(BuildContext context, File imageFile) async {
    final selectedGroup = await _pickGroup(context);
    if (selectedGroup == null) return;

    List<ExtractedItem> items = [];
    try {
      items = await AIExtractionService.extractFromImage(imageFile: imageFile);
    } catch (_) {
      items = [
        ExtractedItem(
          id: const Uuid().v4(),
          description: 'Shared Receipt',
          amount: 0.0,
          category: 'General',
          date: DateTime.now(),
        ),
      ];
    }

    if (items.isEmpty) {
      items = [
        ExtractedItem(
          id: const Uuid().v4(),
          description: 'Shared Receipt',
          amount: 0.0,
          category: 'General',
          date: DateTime.now(),
        ),
      ];
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExtractedExpensesScreen(
            items: items,
            sourceName: 'Shared Receipt Image',
          ),
        ),
      );
    }
  }

  static Future<void> _runManualEntry(BuildContext context, File imageFile) async {
    final selectedGroup = await _pickGroup(context);
    if (selectedGroup == null) return;

    final categories = selectedGroup.categories.isEmpty ? ['General'] : selectedGroup.categories;

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            group: selectedGroup,
            categories: categories,
            initialImage: imageFile,
          ),
        ),
      );
    }
  }
}
