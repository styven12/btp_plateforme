#!/usr/bin/env bash
set -euo pipefail

FLUTTER_CHANNEL="stable"
FLUTTER_VERSION="3.47.7"
FLUTTER_DIR="$(pwd)/flutter"
API_BASE_URL="${API_BASE_URL:-https://btp-plateforme-backend.onrender.com/api}"

echo "Installing Flutter $FLUTTER_VERSION from the $FLUTTER_CHANNEL channel"

if [ ! -d "$FLUTTER_DIR" ]; then
  git init "$FLUTTER_DIR"
  git -C "$FLUTTER_DIR" remote add origin https://github.com/flutter/flutter.git
fi

git -C "$FLUTTER_DIR" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION"
git -C "$FLUTTER_DIR" checkout --detach FETCH_HEAD

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
