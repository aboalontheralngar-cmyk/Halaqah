#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

missing=0
for font in assets/fonts/Tajawal-400.ttf assets/fonts/Tajawal-700.ttf; do
  if [ ! -f "$font" ]; then
    echo "Missing required font binary: $font" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  cat >&2 <<'MSG'
This source-upgrade package intentionally does not redistribute font binaries.
Apply the modified-files package over your existing project, or restore the
existing Tajawal font files before running Flutter builds.
MSG
  exit 2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH." >&2
  exit 3
fi

if [ ! -f pubspec.lock ]; then
  echo "pubspec.lock is missing; generating it from the pinned direct dependencies..."
  flutter pub get
fi

if [ ! -f pubspec.lock ]; then
  echo "pubspec.lock was not generated. Stop before building a release." >&2
  exit 4
fi

echo "Flutter source prerequisites passed."
