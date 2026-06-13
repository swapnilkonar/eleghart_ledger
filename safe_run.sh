#!/bin/bash
# safe_run.sh
# Use instead of `flutter run` when INSTALL_FAILED_INSUFFICIENT_STORAGE occurs.
# Backs up all app SharedPreferences, uninstalls to free space,
# installs the new build, then restores the backed-up data.

PACKAGE="com.example.eleghart_ledger"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
TMP="/data/local/tmp"
BACKUP="/tmp/eleghart_prefs_backup"

mkdir -p "$BACKUP"

# ─── Step 1: Backup SharedPreferences ────────────────────────────────────────
echo ""
echo "📦  Backing up SharedPreferences..."
PREFS=$("$ADB" shell run-as "$PACKAGE" ls shared_prefs/ 2>/dev/null | tr -d '\r')

if [ -z "$PREFS" ]; then
  echo "    No existing preferences found (fresh install)."
else
  for f in $PREFS; do
    "$ADB" shell run-as "$PACKAGE" cat "shared_prefs/$f" > "$BACKUP/$f"
    echo "    ✓  $f"
  done
  echo "    Backup saved to $BACKUP"
fi

# ─── Step 2: Uninstall old APK to free storage ───────────────────────────────
echo ""
echo "🗑   Uninstalling old APK to free device storage..."
"$ADB" uninstall "$PACKAGE"

# ─── Step 3: flutter run (blocks until user presses q) ───────────────────────
echo ""
echo "🚀  Starting flutter run — press q in this terminal to quit when done."
echo ""
flutter run

# ─── Step 4: Restore SharedPreferences ───────────────────────────────────────
echo ""
echo "🔁  Restoring SharedPreferences..."

RESTORED=0
for f in "$BACKUP"/*.xml; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")

  # Push to world-readable tmp, then copy into app sandbox
  "$ADB" push "$f" "$TMP/$fname" > /dev/null 2>&1
  "$ADB" shell run-as "$PACKAGE" mkdir -p shared_prefs 2>/dev/null
  "$ADB" shell run-as "$PACKAGE" cp "$TMP/$fname" "shared_prefs/$fname"
  "$ADB" shell rm "$TMP/$fname" 2>/dev/null
  echo "    ✓  $fname"
  RESTORED=$((RESTORED + 1))
done

if [ "$RESTORED" -eq 0 ]; then
  echo "    Nothing to restore."
else
  echo ""
  echo "✅  Done — $RESTORED preference file(s) restored. Hot restart the app to see your data."
fi
echo ""
