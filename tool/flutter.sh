#!/bin/sh
# Runs the HarmonyOS (OpenHarmony) Flutter SDK: $OHOS_FLUTTER, or $HOME/ohos_flutter/bin/flutter when it is unset.
exec "${OHOS_FLUTTER:-$HOME/ohos_flutter/bin/flutter}" "$@"
