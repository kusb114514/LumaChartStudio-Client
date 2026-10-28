#!/bin/bash
# Builds the patched LibNMeCab assembly used by the iOS client.
#
# Why: LibNMeCab resolves a dictionary's charset by comparing encoding names with
# CompareOptions.IgnoreCase | CompareOptions.IgnoreSymbols. .NET on Apple mobile
# answers globalization through the platform rather than ICU and refuses that
# combination outright, so the very first comparison threw
# PlatformNotSupportedException, MeCabIpaDicTagger.Create failed, and Kawazu's
# converter — and every kanji reading with it — never came up. Upstream master
# still has the same line, and the iOS runtime pack ships no ICU to switch to, so
# neither upgrading nor HybridGlobalization=false helps. See
# docs/ios-platform-notes.md.
#
# LumaChart.iOS.csproj picks the result up through an Exists() guard, so a machine
# that has never run this builds against the stock package and simply has no kanji
# romanization on iOS. Windows and Android have real ICU and are untouched either
# way — they never use this assembly.
#
# Unlike the Avalonia patch this needs no special environment: LibNMeCab is a
# plain netstandard2.0 library with no strong name, so a rebuilt DLL drops in.
set -euo pipefail

TAG="${NMECAB_TAG:-v0.10.1}"
SRC="${NMECAB_SRC:-$HOME/Developer/nmecab-src}"
OUT="${NMECAB_PATCHED_OUT:-$HOME/Developer/nmecab-patched-out}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET="${LUMACHART_DOTNET:-$HOME/Library/Caches/LumaChartStudio/DotNet/root/dotnet}"

# Outside the synced tree: Sync-MacSource.ps1 -Delete does rm -rf on the
# repository mirror and would take the clone and the staged DLL with it.
case "$SRC" in
    "$HOME/Developer/"*) ;;
    *) echo "refusing to clone into $SRC; keep it outside the synced repository" >&2; exit 1 ;;
esac

if [ ! -d "$SRC/.git" ]; then
    echo "== Cloning NMeCab $TAG =="
    git clone --depth 1 --branch "$TAG" https://github.com/komutan/NMeCab.git "$SRC"
fi

echo "== Resetting to $TAG =="
git -C "$SRC" checkout -- .

echo "== Applying the encoding-lookup fix =="
git -C "$SRC" apply "$PATCH_DIR/0001-encoding-lookup-without-ignoresymbols.patch"

# Build-environment adjustment, not part of the fix and not part of any upstream
# submission. NMeCab stamps its version with CenterCLR.RelaxVersioner, a build
# task that runs on netcoreapp2.0 — a runtime this machine does not have and will
# not be getting:
#
#   error MSB3073: ... rv.dll ... exited with code 150
#   To install missing framework ... framework_version=2.0.0
#
# Dropping the reference removes the generated assembly attributes with it, so
# the version is stated explicitly below instead; the identity has to stay
# 0.10.1.0 because that is what the rest of the graph resolved against.
echo "== Removing the RelaxVersioner build task =="
python3 - "$SRC/src/LibNMeCab/LibNMeCab.csproj" <<'PYTHON'
import io, re, sys
path = sys.argv[1]
text = io.open(path, encoding='utf-8-sig').read()
patched = re.sub(
    r'\s*<PackageReference Include="CenterCLR\.RelaxVersioner".*?</PackageReference>',
    '',
    text,
    flags=re.S)
if patched == text:
    raise SystemExit('RelaxVersioner reference not found; check the tag')
io.open(path, 'w', encoding='utf-8-sig', newline='').write(patched)
PYTHON

echo "== Building LibNMeCab =="
"$DOTNET" build "$SRC/src/LibNMeCab/LibNMeCab.csproj" -c Release \
    -p:Version=0.10.1 -p:AssemblyVersion=0.10.1.0 -p:FileVersion=0.10.1.0

mkdir -p "$OUT"
cp "$SRC/src/LibNMeCab/bin/Release/netstandard2.0/LibNMeCab.dll" "$OUT/"

echo
echo "NMECAB_PATCHED=$OUT/LibNMeCab.dll"
ls -la "$OUT"
