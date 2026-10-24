#!/usr/bin/env bash
# Lance l'APK de test (fonction « autotest ») dans l'émulateur déjà démarré, attend la fin du parcours, récupère le rapport et les captures.
# Usage : tools/emulator_test.sh <apk> <dossier de sortie>
set -uo pipefail
APK="$1"; OUT="$2"; PKG=com.altopia.game
mkdir -p "$OUT"
adb wait-for-device
adb shell getprop ro.build.version.release | tee "$OUT/android_version.txt"
adb shell wm size | tee "$OUT/screen.txt"
adb install -r "$APK"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
for i in $(seq 1 90); do      # jusqu'à 15 minutes
  if adb shell run-as "$PKG" ls files/autotest/done >/dev/null 2>&1; then break; fi
  sleep 10
done
adb shell dumpsys gfxinfo "$PKG" > "$OUT/gfxinfo.txt" 2>&1
adb shell dumpsys meminfo "$PKG" > "$OUT/meminfo.txt" 2>&1
adb exec-out screencap -p > "$OUT/screen_final.png" || true
adb logcat -d > "$OUT/logcat.txt" 2>&1
for f in $(adb shell run-as "$PKG" ls files/autotest 2>/dev/null | tr -d '\r'); do
  adb exec-out run-as "$PKG" cat "files/autotest/$f" > "$OUT/$f"
done
echo "=== Rapport ==="
cat "$OUT/report.txt" 2>/dev/null || { echo "Aucun rapport : le parcours n'a pas fini"; exit 2; }
FAILS=$(cat "$OUT/done" 2>/dev/null || echo 99)
echo "Échecs : $FAILS"
[ "$FAILS" = "0" ]
