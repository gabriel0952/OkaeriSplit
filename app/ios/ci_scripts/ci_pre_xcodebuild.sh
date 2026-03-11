#!/bin/sh
set -e

echo "--- Installing Flutter ---"
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    -b stable \
    "$FLUTTER_HOME"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"
flutter --version

echo "--- Running flutter pub get ---"
FLUTTER_APP_DIR="$CI_PRIMARY_REPOSITORY_PATH/app"
cd "$FLUTTER_APP_DIR"
flutter pub get

echo "--- Writing dart_defines.json ---"
cat > dart_defines.json <<EOF
{
  "SUPABASE_URL": "${SUPABASE_URL}",
  "SUPABASE_ANON_KEY": "${SUPABASE_ANON_KEY}"
}
EOF

echo "--- Running flutter build ios ---"
flutter build ios --dart-define-from-file=dart_defines.json --no-codesign

echo "--- Running pod install ---"
cd ios
pod install

echo "--- Done ---"
