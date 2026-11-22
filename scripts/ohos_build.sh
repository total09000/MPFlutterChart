#!/bin/bash
# Builds the example app as a HarmonyOS debug hap with the ohos Flutter SDK, and optionally installs and starts it.
# Compatible with the bash 3.2 that macOS ships. Tests:
# test/tool/ohos_build_script_test.dart (fake flutter/hdc toolchains).
#
# Exit codes: 0 ok; 2 bad arguments; 3 missing toolchain (flutter, hdc, DEVECO_SDK_HOME); 4 build failed;
# 5 install or start failed (including --install without a device).

set -u
unset CDPATH

usage() {
  cat <<'EOF'
usage: scripts/ohos_build.sh [--env | --no-build | --install] [--help]

  (default)   put the HarmonyOS toolchains on PATH, print the environment, run `flutter devices` and
              `hdc list targets`, then `flutter build hap --debug` inside example/
  --env       only print the resolved environment, then exit
  --no-build  environment + device detection, no build
  --install   build, then `hdc -t <device> install -r <hap>` and
              `hdc -t <device> shell aa start -a <mainElement> -b <bundleName>`
  --help      print this help

environment:
  OHOS_FLUTTER     ohos flutter executable (default $HOME/ohos_flutter/bin/flutter)
  OHOS_SDK_ROOT    OpenHarmony SDK root holding <api>/toolchains (default $HOME/Library/OpenHarmony/Sdk)
  DEVECO_HOME      DevEco Studio Contents directory (default /Applications/DevEco-Studio.app/Contents)
  DEVECO_SDK_HOME  SDK directory hvigor reads (default $DEVECO_HOME/sdk; exported for the build)
  OHOS_API         use only $OHOS_SDK_ROOT/$OHOS_API/toolchains
  OHOS_DEVICE      target for --install (default: the first entry of `hdc list targets`)

A device is needed only for --install; without one the other modes print a warning.
A build that exits non-zero but wrote a fresh hap (signed or unsigned) counts as built, with a warning;
without signing configured that hap is *-unsigned.hap: emulators accept it, real devices need a signature.
exit codes: 0 ok, 2 bad arguments, 3 missing toolchain, 4 build failed, 5 install or start failed
EOF
}

err() { printf '%s\n' "$*" >&2; }

MODE=build
set_mode() {
  if [ "$MODE" != build ] && [ "$MODE" != "$1" ]; then
    err "error: --$MODE and --$1 cannot be combined"
    usage >&2
    exit 2
  fi
  MODE="$1"
}
for arg in "$@"; do
  case "$arg" in
    --env) set_mode env ;;
    --no-build) set_mode no-build ;;
    --install) set_mode install ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      err "error: unknown argument: $arg"
      usage >&2
      exit 2
      ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE="$REPO/example"

OHOS_FLUTTER="${OHOS_FLUTTER:-$HOME/ohos_flutter/bin/flutter}"
OHOS_SDK_ROOT="${OHOS_SDK_ROOT:-${HOME:-}/Library/OpenHarmony/Sdk}"
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
OHOS_API="${OHOS_API:-}"
OHOS_DEVICE="${OHOS_DEVICE:-}"
if [ -n "${DEVECO_SDK_HOME:-}" ]; then
  SDK_HOME_GIVEN=1
else
  SDK_HOME_GIVEN=0
  DEVECO_SDK_HOME="$DEVECO_HOME/sdk"
fi
export DEVECO_SDK_HOME

case "$OHOS_API" in
  *[!0-9]*)
    err "error: OHOS_API must be an api number such as 20, not '$OHOS_API'"
    exit 2
    ;;
esac

# --- toolchains: "<api>\t<label>\t<dir>" lines, sorted by api, highest first ---------------------------------------
TAB="$(printf '\t')"
NL='
'
PROBLEMS=""
problem() { PROBLEMS="$PROBLEMS$*$NL"; }

CANDIDATES=""
add_candidate() { CANDIDATES="$CANDIDATES$1$TAB$2$TAB$3$NL"; }

DEVECO_TOOLCHAINS="$DEVECO_HOME/sdk/default/openharmony/toolchains"
if [ -n "$OHOS_API" ]; then
  if [ -x "$OHOS_SDK_ROOT/$OHOS_API/toolchains/hdc" ]; then
    add_candidate "$OHOS_API" "$OHOS_API" "$OHOS_SDK_ROOT/$OHOS_API/toolchains"
  else
    problem "error: OHOS_API=$OHOS_API but $OHOS_SDK_ROOT/$OHOS_API/toolchains/hdc does not exist; unset OHOS_API or install that api level of the OpenHarmony SDK (set OHOS_SDK_ROOT)."
  fi
else
  for dir in "$OHOS_SDK_ROOT"/*; do
    api="${dir##*/}"
    case "$api" in '' | *[!0-9]*) continue ;; esac
    if [ -f "$dir/toolchains/hdc" ] && [ -x "$dir/toolchains/hdc" ]; then
      add_candidate "$api" "$api" "$dir/toolchains"
    fi
  done
  if [ -f "$DEVECO_TOOLCHAINS/hdc" ] && [ -x "$DEVECO_TOOLCHAINS/hdc" ]; then
    api=""
    if [ -f "$DEVECO_HOME/sdk/default/sdk-pkg.json" ]; then
      api="$(sed -nE 's/^[[:space:]]*"apiVersion"[[:space:]]*:[[:space:]]*"?([0-9]+)"?.*/\1/p' \
        "$DEVECO_HOME/sdk/default/sdk-pkg.json" | head -n 1)"
    fi
    add_candidate "${api:-0}" "${api:-?}" "$DEVECO_TOOLCHAINS"
  fi
fi
SORTED="$(printf '%s' "$CANDIDATES" | sort -s -t "$TAB" -k1,1nr)"

PREPEND=""
prepend() { PREPEND="$PREPEND${PREPEND:+:}$1"; }
TOOLCHAIN_LINES=""
while IFS="$TAB" read -r api label dir; do
  [ -n "${dir:-}" ] || continue
  prepend "$dir"
  TOOLCHAIN_LINES="${TOOLCHAIN_LINES}toolchains: $dir (api $label)$NL"
done <<EOF
$SORTED
EOF

TOOL_LINES=""
for tool in node ohpm hvigor; do
  if [ -d "$DEVECO_HOME/tools/$tool/bin" ]; then
    prepend "$DEVECO_HOME/tools/$tool/bin"
    TOOL_LINES="${TOOL_LINES}tools:      $DEVECO_HOME/tools/$tool/bin$NL"
  fi
done
if [ -n "$PREPEND" ]; then
  PATH="$PREPEND${PATH:+:$PATH}"
fi
export PATH

HDC="$(command -v hdc 2>/dev/null)"
HVIGORW="$(command -v hvigorw 2>/dev/null)"
HVIGORW="${HVIGORW:-hvigorw}"

if [ ! -f "$OHOS_FLUTTER" ] || [ ! -x "$OHOS_FLUTTER" ]; then
  problem "error: no flutter executable at $OHOS_FLUTTER; set OHOS_FLUTTER to the ohos Flutter SDK's bin/flutter (not an upstream flutter)."
fi
if [ -z "$HDC" ]; then
  problem "error: no hdc found under $OHOS_SDK_ROOT/<api>/toolchains, $DEVECO_TOOLCHAINS or on PATH; install the OpenHarmony SDK (DevEco Studio > Settings > OpenHarmony SDK, or the command-line tools) and set OHOS_SDK_ROOT (or DEVECO_HOME) to it."
fi
SDK_HOME_NOTE=""
if [ ! -d "$DEVECO_SDK_HOME" ]; then
  SDK_HOME_NOTE=" (missing)"
  msg="DEVECO_SDK_HOME=$DEVECO_SDK_HOME is not a directory; hvigor needs it (error 00303217) - set DEVECO_SDK_HOME to DevEco Studio's sdk directory (DevEco Studio.app/Contents/sdk) or DEVECO_HOME to DevEco Studio's Contents directory."
  if [ "$SDK_HOME_GIVEN" = 1 ] || [ "$MODE" = build ] || [ "$MODE" = install ]; then
    problem "error: $msg"
  else
    err "warning: $msg"
  fi
fi

# --- environment block ----------------------------------------------------------------------------------------------
printf 'flutter:    %s\n' "$OHOS_FLUTTER"
printf 'sdk home:   %s%s\n' "$DEVECO_SDK_HOME" "$SDK_HOME_NOTE"
printf '%s' "$TOOLCHAIN_LINES"
printf '%s' "$TOOL_LINES"
printf 'hdc:        %s\n' "${HDC:-(not found)}"
printf 'example:    %s\n' "$EXAMPLE"

if [ -n "$PROBLEMS" ]; then
  printf '%s' "$PROBLEMS" >&2
  exit 3
fi
[ "$MODE" = env ] && exit 0

VERSION_OUT="$("$OHOS_FLUTTER" --version 2>&1)"
VERSION_RC=$?
VERSION_LINE="$(printf '%s\n' "$VERSION_OUT" | sed -n '/^Flutter /{p;q;}')"
[ -n "$VERSION_LINE" ] || VERSION_LINE="$(printf '%s\n' "$VERSION_OUT" | head -n 1)"
printf 'version:    %s\n' "$VERSION_LINE"
if [ "$VERSION_RC" -ne 0 ]; then
  printf '%s\n' "$VERSION_OUT" >&2
  err "error: '$OHOS_FLUTTER --version' exited $VERSION_RC; check that OHOS_FLUTTER is a working ohos Flutter SDK."
  exit 3
fi

# --- devices --------------------------------------------------------------------------------------------------------
NO_DEVICE_HINT="start an emulator in DevEco Studio > Device Manager, or connect a phone by USB with USB debugging on, then check 'hdc list targets' (or set OHOS_DEVICE)."

echo
echo '$ flutter devices'
"$OHOS_FLUTTER" devices || err "warning: 'flutter devices' exited $?"
echo
echo '$ hdc list targets'
TARGETS="$("$HDC" list targets 2>&1 | tr -d '\r')"
printf '%s\n' "$TARGETS"
FIRST_TARGET="$(printf '%s\n' "$TARGETS" | awk 'NF && $1 !~ /^\[/ { print $1; exit }')"
echo

DEVICE="$OHOS_DEVICE"
if [ -n "$DEVICE" ]; then
  if ! printf '%s\n' "$TARGETS" | awk -v d="$DEVICE" '$1 == d { found = 1 } END { exit !found }'; then
    echo "warning: OHOS_DEVICE=$DEVICE is not in 'hdc list targets'; trying it anyway."
  fi
else
  DEVICE="$FIRST_TARGET"
fi
if [ -n "$DEVICE" ]; then
  printf 'device:     %s\n' "$DEVICE"
elif [ "$MODE" = install ]; then
  err "error: no HarmonyOS device for --install; $NO_DEVICE_HINT"
  exit 5
else
  echo "warning: no HarmonyOS device ('hdc list targets' is empty); a build does not need one. To run the app: $NO_DEVICE_HINT"
fi
[ "$MODE" = no-build ] && exit 0

# --- build ----------------------------------------------------------------------------------------------------------
MARKER="$(mktemp "${TMPDIR:-/tmp}/ohos_build.XXXXXX")" || {
  err "error: mktemp failed"
  exit 4
}
trap 'rm -f "$MARKER"' EXIT

echo "\$ (cd $EXAMPLE && flutter build hap --debug)"
(cd "$EXAMPLE" && "$OHOS_FLUTTER" build hap --debug)
BUILD_RC=$?

# Lists the haps under example/build and example/ohos/entry/build; extra arguments are find predicates.
list_haps() {
  for d in "$EXAMPLE/build" "$EXAMPLE/ohos/entry/build"; do
    if [ -d "$d" ]; then
      find "$d" -type f -name '*.hap' "$@"
    fi
  done
}
# Prints the newest of the paths on stdin.
newest() {
  newest_path=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -z "$newest_path" ] || [ "$p" -nt "$newest_path" ]; then
      newest_path="$p"
    fi
  done
  printf '%s' "$newest_path"
}
# Prints the newest signed hap of the paths on stdin, or the newest unsigned one when there is no signed one.
pick_hap() {
  paths="$(cat)"
  picked="$(printf '%s\n' "$paths" | grep -v -- '-unsigned\.hap$' | newest)"
  [ -n "$picked" ] || picked="$(printf '%s\n' "$paths" | newest)"
  printf '%s' "$picked"
}

HAP="$(list_haps -newer "$MARKER" | pick_hap)"
if [ "$BUILD_RC" -ne 0 ]; then
  if [ -z "$HAP" ]; then
    err ""
    err "error: flutter build hap --debug exited $BUILD_RC and wrote no hap."
    err "hint (signing): open example/ohos in DevEco Studio > File > Project Structure > Signing Configs > Automatically generate signature (needs a Huawei account)."
    err "hint (ohpm): if a dependency download failed, check the network and the registry in 'ohpm config get registry'."
    err "hint (hvigor/node): check DEVECO_HOME=$DEVECO_HOME and DEVECO_SDK_HOME=$DEVECO_SDK_HOME, then run '$HVIGORW --stop-daemon' so a running hvigor daemon picks up the new environment."
    STALE="$(list_haps | pick_hap)"
    if [ -n "$STALE" ]; then
      err "note: $STALE is from an earlier build, not from this run."
    fi
    exit 4
  fi
  err ""
  err "warning: flutter build hap --debug exited $BUILD_RC, but this run wrote $HAP."
  case "$HAP" in
    *-unsigned.hap)
      err "warning: this is an unsigned debug hap: emulators accept it, real devices need a signature (DevEco Studio > File > Project Structure > Signing Configs > Automatically generate signature, needs a Huawei account)."
      ;;
  esac
fi
if [ -z "$HAP" ]; then
  HAP="$(list_haps | pick_hap)"
  if [ -n "$HAP" ]; then
    err "warning: no hap newer than this build; using $HAP from an earlier build."
  fi
fi
if [ -n "$HAP" ]; then
  printf 'hap:        %s\n' "$HAP"
fi
[ "$MODE" = install ] || exit 0

# --- install and start ----------------------------------------------------------------------------------------------
if [ -z "$HAP" ]; then
  err "error: flutter build hap succeeded but no .hap was found under $EXAMPLE/build or $EXAMPLE/ohos/entry/build."
  exit 4
fi

# Prints the first value of a top-level-looking `"key": "value"` line in a json5 file.
json5_value() {
  sed -nE "s/^[[:space:]]*[\"']?$1[\"']?[[:space:]]*:[[:space:]]*[\"']([^\"']+)[\"'].*/\\1/p" "$2" 2>/dev/null | head -n 1
}
APP_JSON5="$EXAMPLE/ohos/AppScope/app.json5"
MODULE_JSON5="$EXAMPLE/ohos/entry/src/main/module.json5"
BUNDLE="$(json5_value bundleName "$APP_JSON5")"
ABILITY="$(json5_value mainElement "$MODULE_JSON5")"
if [ -z "$BUNDLE" ]; then
  err "error: no bundleName in $APP_JSON5"
  exit 5
fi
if [ -z "$ABILITY" ]; then
  err "error: no mainElement in $MODULE_JSON5"
  exit 5
fi
printf 'bundle:     %s\n' "$BUNDLE"
printf 'ability:    %s\n' "$ABILITY"

echo "\$ hdc -t $DEVICE install -r $HAP"
OUT="$("$HDC" -t "$DEVICE" install -r "$HAP" 2>&1)"
RC=$?
printf '%s\n' "$OUT"
# hdc can print [Fail] and still exit 0, so the output is checked too.
if [ "$RC" -ne 0 ] || printf '%s\n' "$OUT" | grep -q '\[Fail\]'; then
  err "error: installing $HAP on $DEVICE failed."
  err "hint: a real device rejects an unsigned hap (configure Signing Configs in DevEco Studio); a copy signed differently must be removed first with 'hdc -t $DEVICE uninstall $BUNDLE'."
  exit 5
fi

echo "\$ hdc -t $DEVICE shell aa start -a $ABILITY -b $BUNDLE"
OUT="$("$HDC" -t "$DEVICE" shell aa start -a "$ABILITY" -b "$BUNDLE" 2>&1)"
RC=$?
printf '%s\n' "$OUT"
if [ "$RC" -ne 0 ] || printf '%s\n' "$OUT" | grep -Eqi 'error|\[fail\]'; then
  err "error: starting $ABILITY of $BUNDLE on $DEVICE failed; check 'hdc -t $DEVICE shell hilog' for the reason."
  exit 5
fi
exit 0
