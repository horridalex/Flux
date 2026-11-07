#!/usr/bin/env bash
# Builds WireGuard/ (Go) into WireGuard/build/FluxWG.xcframework, for the iPhone, the
# simulator, and the Mac, where `swift test` links it to test WireGuardServer.swift. xcodegen runs it before generating the project (preGenCommand in project.yml).
# It skips the build when the Go sources and the Go version haven't changed since the last one. Needs Go, see go.mod.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
src=$root/WireGuard
out=$src/build
stamp=$out/sources.sha

command -v go >/dev/null || { echo "Go is needed to build WireGuard/, see https://go.dev/dl" >&2; exit 1; }

# The Go version is in the hash too, so a Go upgrade (a fix in net, say) rebuilds.
hash=$({ cd "$src" && cat go.mod go.sum ./*.go "$root/scripts/build-wireguard.sh" && go version; } | shasum | cut -d' ' -f1)
if [[ -d $out/FluxWG.xcframework && -f $stamp && $(cat "$stamp") == "$hash" ]]; then
    exit 0
fi

rm -rf "$out"
mkdir -p "$out"

# One static library per platform and architecture. Go's own iOS support covers the simulator too,
# as long as the C compiler targets it.
build() {
    local sdk=$1 arch=$2 target=$3 dir=$out/$1-$2 goos=ios
    local sysroot
    [[ $sdk == macosx ]] && goos=darwin
    sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
    mkdir -p "$dir"
    CGO_ENABLED=1 GOOS=$goos GOARCH=$arch \
        CC="$(xcrun --sdk "$sdk" -f clang) -isysroot $sysroot -target $target" \
        CGO_CFLAGS="-isysroot $sysroot -target $target" \
        CGO_LDFLAGS="-isysroot $sysroot -target $target" \
        go -C "$src" build -buildmode=c-archive -trimpath -ldflags=-w -o "$dir/libfluxwg.a" .
}

build iphoneos arm64 arm64-apple-ios17.0
build iphonesimulator arm64 arm64-apple-ios17.0-simulator
build iphonesimulator amd64 x86_64-apple-ios17.0-simulator
build macosx arm64 arm64-apple-macos14.0
build macosx amd64 x86_64-apple-macos14.0

for platform in iphoneos iphonesimulator macosx; do
    mkdir -p "$out/$platform/Headers"
    cp "$out/$platform-arm64/libfluxwg.h" "$out/$platform/Headers/FluxWG.h"
    cat > "$out/$platform/Headers/module.modulemap" <<'EOF'
module FluxWG {
    header "FluxWG.h"
    link "resolv"
    export *
}
EOF
done
cp "$out/iphoneos-arm64/libfluxwg.a" "$out/iphoneos/"
lipo -create "$out/macosx-arm64/libfluxwg.a" "$out/macosx-amd64/libfluxwg.a" \
    -output "$out/macosx/libfluxwg.a"
lipo -create "$out/iphonesimulator-arm64/libfluxwg.a" "$out/iphonesimulator-amd64/libfluxwg.a" \
    -output "$out/iphonesimulator/libfluxwg.a"

xcodebuild -create-xcframework \
    -library "$out/iphoneos/libfluxwg.a" -headers "$out/iphoneos/Headers" \
    -library "$out/iphonesimulator/libfluxwg.a" -headers "$out/iphonesimulator/Headers" \
    -library "$out/macosx/libfluxwg.a" -headers "$out/macosx/Headers" \
    -output "$out/FluxWG.xcframework" >/dev/null
rm -rf "$out"/iphoneos* "$out"/iphonesimulator* "$out"/macosx*
echo "$hash" > "$stamp"
