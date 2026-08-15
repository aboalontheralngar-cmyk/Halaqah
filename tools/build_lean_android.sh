#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

"$project_root/tools/verify_source_prerequisites.sh"

: "${SUPABASE_URL:?Set SUPABASE_URL for a production build}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY for a production build}"

mkdir -p build/symbols

flutter clean
flutter pub get
flutter build apk \
  --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=HALAQAH_ENV=production \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"

echo "Split APK files: build/app/outputs/flutter-apk/"
echo "Archive build/symbols with this exact release for crash decoding."
