#!/usr/bin/env bash
# Télécharge Godot dans tools/godot/ (ignoré par Git) et affiche son chemin.
set -euo pipefail
VERSION="${GODOT_VERSION:-4.3-stable}"
DIR="$(cd "$(dirname "$0")" && pwd)/godot"
BIN="$DIR/Godot_v${VERSION}_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  curl -sSL -o "$DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -oq "$DIR/godot.zip" -d "$DIR" && rm "$DIR/godot.zip"
  chmod +x "$BIN"
fi
echo "$BIN"
