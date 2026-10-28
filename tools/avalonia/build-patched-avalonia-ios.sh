#!/bin/bash
# Builds the patched Avalonia.iOS assembly on the macOS build VM.
#
# Why this exists at all: Avalonia 12.1.1 renders on DisplayLinkTimer's own
# thread and touches the render layer from there, which iPadOS 26 refuses. The
# result is a black screen with no exception and no log — see
# docs/ios-platform-notes.md. The fix is one file, and it cannot be applied from
# the app: Avalonia's platform interfaces carry a NotClientImplementable guard,
# so Avalonia.iOS only compiles inside the Avalonia repository.
#
# LumaChart.iOS.csproj picks the result up through an Exists() guard, so a
# machine that has never run this builds against the stock package instead. That
# is safe for Windows and Android and is a BLACK SCREEN on an iOS device: if the
# app renders nothing on iPadOS 26, check this ran.
#
# Delete this whole directory once a released Avalonia carries the fix.
set -euo pipefail

TAG="${AVALONIA_TAG:-12.1.1}"
TFM="${AVALONIA_IOS_TFM:-net10.0-ios26.2}"
SRC="${AVALONIA_SRC:-$HOME/Developer/avalonia-src}"
OUT="${AVALONIA_PATCHED_OUT:-$HOME/Developer/avalonia-patched-out}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET="${LUMACHART_DOTNET:-$HOME/Library/Caches/LumaChartStudio/DotNet/root/dotnet}"

# Outside the synced tree on purpose: Sync-MacSource.ps1 -Delete does rm -rf on
# the repository mirror, which would take the clone and the staged DLL with it.
case "$SRC" in
    "$HOME/Developer/"*) ;;
    *) echo "refusing to clone into $SRC; keep it outside the synced repository" >&2; exit 1 ;;
esac

if [ ! -d "$SRC/.git" ]; then
    echo "== Cloning Avalonia $TAG =="
    git clone --depth 1 --branch "$TAG" https://github.com/AvaloniaUI/Avalonia.git "$SRC"
    # XamlX is a submodule; without it Avalonia.Build.Tasks fails with ~1533 errors.
    git -C "$SRC" submodule update --init --recursive --depth 1
fi

echo "== Resetting to $TAG =="
git -C "$SRC" checkout -- .
git -C "$SRC" clean -fd -- src build >/dev/null

echo "== Applying the iOS 26 display-link fix =="
git -C "$SRC" apply "$PATCH_DIR/0001-ios26-display-link-on-main-thread.patch"

# Build-environment narrowing, not part of the fix and not part of the PR: this
# VM has only the one iOS SDK band, and Avalonia's defaults ask for iOS 26.0
# plus maccatalyst and tvOS workloads that are not installed.
echo "== Narrowing target frameworks for this machine =="
sed -i "" "s/-ios26\.0/-${TFM#net10.0-}/" "$SRC/build/TargetFrameworks.props"
sed -i "" "s|<TargetFrameworks>.*</TargetFrameworks>|<TargetFrameworks>$TFM</TargetFrameworks>|" \
    "$SRC/src/iOS/Avalonia.iOS/Avalonia.iOS.csproj"

echo "== Building Avalonia.iOS =="
# NU1510 is warning-as-error in Avalonia's own build and fires on this trimmed
# target set; it says nothing about the fix.
"$DOTNET" build "$SRC/src/iOS/Avalonia.iOS/Avalonia.iOS.csproj" \
    -c Release -p:WarningsNotAsErrors=NU1510

mkdir -p "$OUT"
cp "$SRC/src/iOS/Avalonia.iOS/bin/Release/$TFM/Avalonia.iOS.dll" "$OUT/"

echo
echo "AVALONIA_PATCHED=$OUT/Avalonia.iOS.dll"
ls -la "$OUT"
