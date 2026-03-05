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

echo "--- Running pod install ---"
cd ios
pod install

echo "--- Done ---"
