#!/bin/sh
set -e

APP_DIR="$(dirname "$0")/../app"
cd "$APP_DIR"

echo "=== flutter build ipa ==="
flutter build ipa --release

ARCHIVE="build/ios/archive/Runner.xcarchive"
FRAMEWORK="$ARCHIVE/Products/Applications/Runner.app/Frameworks/objective_c.framework"

if [ -d "$FRAMEWORK" ]; then
  echo "=== Re-signing objective_c.framework ==="
  CERT=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk '{print $2}')
  codesign --force --sign "$CERT" --timestamp "$FRAMEWORK"
  echo "Signed with: $CERT"
fi

echo "=== Done ==="
echo "Archive: $APP_DIR/$ARCHIVE"
echo "IPA:     $APP_DIR/build/ios/ipa/"
