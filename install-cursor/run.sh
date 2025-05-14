#!/usr/bin/env bash

set -e

# === Constants ===
JSON_URL="https://raw.githubusercontent.com/oslook/cursor-ai-downloads/refs/heads/main/version-history.json"
EXPECTED_JSON_HOST="raw.githubusercontent.com"
EXPECTED_DOWNLOAD_HOST="downloads.cursor.com"
TMP_DIR=$(mktemp -d)

# === Validate JSON host ===
JSON_HOST=$(echo "$JSON_URL" | awk -F/ '{print $3}')
if [ "$JSON_HOST" != "$EXPECTED_JSON_HOST" ]; then
  echo "❌ Error: Unexpected JSON host: $JSON_HOST"
  exit 1
fi

# === Download JSON ===
echo "📥 Fetching version list..."
curl -fsSL "$JSON_URL" -o "$TMP_DIR/version-history.json"

# === Show versions and prompt ===
echo "🧭 Available Cursor Versions:"
VERSIONS=$(jq -r '.versions[].version' "$TMP_DIR/version-history.json")
VERSION_ARRAY=($VERSIONS) # convert to bash array

# Insert "Latest (default)" at the top visually
PS3=$'\n#? '
select USER_CHOICE in "Latest (default)" "${VERSION_ARRAY[@]}"; do
  if [[ "$REPLY" == "1" || -z "$REPLY" ]]; then
    VERSION="${VERSION_ARRAY[0]}"
    echo "🆕 Using latest version: $VERSION"
    break
  elif [[ "$REPLY" =~ ^[0-9]+$ && "$REPLY" -le $((${#VERSION_ARRAY[@]} + 1)) ]]; then
    VERSION="${VERSION_ARRAY[$((REPLY-2))]}"
    echo "📦 Using version: $VERSION"
    break
  else
    echo "❌ Invalid selection. Try again."
  fi
done

# === Detect platform ===
UNAME_OUT="$(uname -s)"
ARCH_OUT="$(uname -m)"
OS=""
PLATFORM=""

case "$UNAME_OUT" in
  Darwin)
    OS="macos"
    case "$ARCH_OUT" in
      arm64) PLATFORM="darwin-arm64" ;;
      x86_64) PLATFORM="darwin-x64" ;;
      *) PLATFORM="darwin-universal" ;;
    esac
    ;;
  Linux)
    OS="linux"
    case "$ARCH_OUT" in
      x86_64) PLATFORM="linux-x64" ;;
      aarch64|arm64) PLATFORM="linux-arm64" ;;
      *) echo "❌ Unsupported Linux architecture: $ARCH_OUT"; exit 1 ;;
    esac
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS="windows"
    case "$ARCH_OUT" in
      x86_64) PLATFORM="win32-x64-user" ;;
      aarch64|arm64) PLATFORM="win32-arm64-user" ;;
      *) echo "❌ Unsupported Windows architecture: $ARCH_OUT"; exit 1 ;;
    esac
    ;;
  *)
    echo "❌ Unsupported OS: $UNAME_OUT"
    exit 1
    ;;
esac

# === Extract URL ===
VERSION_INDEX=$(jq ".versions | map(.version == \"$VERSION\") | index(true)" "$TMP_DIR/version-history.json")
DOWNLOAD_URL=$(jq -r ".versions[$VERSION_INDEX].platforms[\"$PLATFORM\"]" "$TMP_DIR/version-history.json")

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  echo "❌ No binary for $PLATFORM in version $VERSION"
  exit 1
fi

DOWNLOAD_HOST=$(echo "$DOWNLOAD_URL" | awk -F/ '{print $3}')
if [ "$DOWNLOAD_HOST" != "$EXPECTED_DOWNLOAD_HOST" ]; then
  echo "❌ Untrusted host: $DOWNLOAD_HOST"
  exit 1
fi

echo "🔗 Downloading: $DOWNLOAD_URL"

# === Download binary ===
FILENAME="${TMP_DIR}/cursor_download"
curl -fsSL "$DOWNLOAD_URL" -o "$FILENAME"

# === Install ===
if [ "$OS" == "macos" ]; then
  echo "💿 Mounting DMG..."
  MOUNT_POINT="/Volumes/CursorInstaller"
  hdiutil attach "$FILENAME" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
  APP_PATH=$(find "$MOUNT_POINT" -name "*.app" | head -n 1)

  echo "🔍 Verifying app signature..."
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  if [ $? -ne 0 ]; then
    echo "❌ Signature verification failed. Aborting install."
    hdiutil detach "$MOUNT_POINT" -quiet
    exit 1
  else
    echo "✅ App is properly signed and verified."
  fi

  echo "🛡️ Checking notarization status with spctl..."
  spctl --assess --type execute --verbose=4 "$APP_PATH"
  if [ $? -ne 0 ]; then
    echo "⚠️ Warning: App failed notarization check (spctl). It may still run, but could be blocked by Gatekeeper."
  else
    echo "✅ App is notarized and passes Gatekeeper checks."
  fi

  if [ -z "$APP_PATH" ]; then
    echo "❌ .app not found"
    hdiutil detach "$MOUNT_POINT" -quiet
    exit 1
  fi

  echo "🔐 Requesting admin rights to install to /Applications..."
  echo "🧼 Cleaning up existing installation (if any)..."
  sudo rm -rf "/Applications/$(basename "$APP_PATH")"
  echo "📦 Installing with ditto..."
  sudo ditto "$APP_PATH" "/Applications/$(basename "$APP_PATH")"

  if [ -d "/Applications/$(basename "$APP_PATH")" ]; then
    echo "✅ Installed Cursor $VERSION to /Applications"
  else
    hdiutil detach "$MOUNT_POINT" -quiet
    echo "❌ Something went wrong — installation incomplete."
    exit 1
  fi
  
  hdiutil detach "$MOUNT_POINT" -quiet
  echo "✅ Installed Cursor $VERSION to /Applications"
elif [ "$OS" == "linux" ]; then
  mkdir -p "$HOME/Applications"
  FINAL_PATH="$HOME/Applications/Cursor-${VERSION}.AppImage"
  mv "$FILENAME" "$FINAL_PATH"
  chmod +x "$FINAL_PATH"
  echo "✅ Saved AppImage to $FINAL_PATH"
elif [ "$OS" == "windows" ]; then
  FINAL_PATH="$HOME/Downloads/$(basename "$DOWNLOAD_URL")"
  mv "$FILENAME" "$FINAL_PATH"
  echo "📥 Saved installer to $FINAL_PATH"
  echo "💡 Please run it manually."
else
  echo "❌ Unknown platform"
  exit 1
fi

# === Cleanup ===
rm -rf "$TMP_DIR"
echo "🎉 Done!"
