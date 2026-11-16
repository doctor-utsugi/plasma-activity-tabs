#!/usr/bin/env bash
# Install or upgrade the widget for the current user.
set -euo pipefail
cd "$(dirname "$0")"
kpackagetool6 -t Plasma/Applet -u package 2>/dev/null || kpackagetool6 -t Plasma/Applet -i package
