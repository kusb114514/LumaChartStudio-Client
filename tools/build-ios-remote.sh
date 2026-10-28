#!/bin/bash
# Remote half of tools\Build-iOSApp.ps1. Runs inside the macOS build VM.
#
# Produces an UNSIGNED .ipa. The VM deliberately holds no Apple account,
# certificate or provisioning profile, so signing is the user's step on their
# own machine.
set -euo pipefail

CONFIGURATION="${1:-Release}"
BUNDLE_ID="${2:-}"
OFFLINE="${3:-}"

. "$HOME/lumachart-env.sh"
cd "$LUMACHART_SRC"

# The VM reaches NuGet through the Windows host's default route, which a proxy
# or VPN on the host can take over; restore then burns minutes on timeouts even
# though every package is already in the pinned cache. With no sources declared,
# restore resolves purely from that cache and finishes in milliseconds. It fails
# loudly if a package is genuinely missing, which is the wanted behaviour.
if [ "$OFFLINE" = "offline" ]; then
    cat > NuGet.config <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
  </packageSources>
</configuration>
EOF
fi

# macOS ships bash 3.2, where expanding an empty array under `set -u` is an
# error, so the optional argument is passed positionally instead.
# HybridGlobalization has to be a *global* property, which is why it is here and
# not in the csproj. Xamarin.Shared.Sdk.targets sets it with
#
#   <HybridGlobalization Condition="'$(InvariantGlobalization)' != 'true'">true</...>
#
# — no "only if nobody set it" guard — so it overwrites anything the project
# states, and a build with it in the csproj still shipped
# System.Globalization.Hybrid=true. Only a command-line property outranks that.
#
# Why it must be off: hybrid globalization answers from Apple's own APIs instead
# of shipping ICU, and cannot honour every CompareOptions combination. Japanese
# kanji romanization compares with IgnoreCase together with IgnoreSymbols, inside
# Kawazu/WanaKana where there is no call site to rewrite, and threw
# PlatformNotSupported_HybridGlobalizationWithCompareOptions on device. Costs app
# size; the alternative is the feature not working at all on iOS.
publish() {
    dotnet publish LumaChart.iOS/LumaChart.iOS.csproj \
        -c "$CONFIGURATION" \
        -f net10.0-ios26.2 \
        -r ios-arm64 \
        -p:HybridGlobalization=false \
        --nologo \
        "$@"
}

if [ -n "$BUNDLE_ID" ]; then
    publish "-p:LumaChartBundleId=$BUNDLE_ID"
else
    publish
fi

APP="$(find "$LUMACHART_SRC/LumaChart.iOS/bin/$CONFIGURATION" -maxdepth 4 -name '*.app' -type d | head -1)"
if [ -z "$APP" ]; then
    echo 'IOS_BUILD_ERROR: no .app was produced'
    exit 1
fi

# Refuse to ship something that is accidentally signed: the whole delivery
# contract is that the user signs it themselves.
if codesign -dv "$APP" >/dev/null 2>&1; then
    echo 'IOS_BUILD_ERROR: the .app carries a signature; this build must be unsigned'
    exit 1
fi

STAGE="$TMPDIR/lumachart-ipa-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

OUT="$LUMACHART_SRC/artifacts-ios"
mkdir -p "$OUT"
IPA="$OUT/LumaChartStudio-unsigned.ipa"
rm -f "$IPA"

# -X omits macOS extended attributes, which some signing tools reject.
( cd "$STAGE" && zip -qry -X "$IPA" Payload )

echo "IOS_APP=$APP"
echo "IOS_IPA=$IPA"
echo "IOS_IPA_BYTES=$(stat -f%z "$IPA")"
echo "IOS_IPA_SHA256=$(shasum -a 256 "$IPA" | awk '{print $1}')"
echo "IOS_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "IOS_MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
echo 'IOS_BUILD=OK'
