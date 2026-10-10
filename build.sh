#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$(pwd)/flutter"
API_BASE_URL="${API_BASE_URL:-https://btp-plateforme-backend.onrender.com/api}"

if [ ! -d "$FLUTTER_DIR" ]; then
  git init "$FLUTTER_DIR"
  git -C "$FLUTTER_DIR" remote add origin https://github.com/flutter/flutter.git
fi

git -C "$FLUTTER_DIR" fetch --depth 1 origin stable
git -C "$FLUTTER_DIR" checkout --detach FETCH_HEAD

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
