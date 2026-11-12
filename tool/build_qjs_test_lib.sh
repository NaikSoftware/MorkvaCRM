#!/usr/bin/env bash
# Builds the flutter_qjs_next native library for host (VM) tests with gcc:
# this host has no clang/ninja for `flutter build linux`. Output:
# build/qjs/libflutter_qjs_next_plugin.so. Run the QuickJS suite with
#   FLUTTER_QJS_NEXT_LIBRARY=$PWD/build/qjs/libflutter_qjs_next_plugin.so \
#     flutter test --tags qjs test/automation/qjs
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .dart_tool/package_config.json ]] || flutter pub get
pkg=$(python3 -c '
import json, urllib.parse
cfg = json.load(open(".dart_tool/package_config.json"))
uri = next(p["rootUri"] for p in cfg["packages"] if p["name"] == "flutter_qjs_next")
print(urllib.parse.unquote(urllib.parse.urlparse(uri).path))
')
out=$PWD/build/qjs
src=$pkg/cxx/quickjs
mkdir -p "$out/obj"
cd "$out/obj"
# Objects land in build/, never in the pub cache.
gcc -O2 -fPIC -D_GNU_SOURCE -DCONFIG_VERSION="\"$(cat "$src/VERSION.txt")\"" \
  -c "$src"/{cutils,libregexp,libunicode,quickjs,dtoa}.c
g++ -O2 -fPIC -std=c++17 -c "$pkg/cxx/ffi.cpp"
g++ -shared -o "$out/libflutter_qjs_next_plugin.so" ./*.o -lm -lpthread -ldl
echo "$out/libflutter_qjs_next_plugin.so"
