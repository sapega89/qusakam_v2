#!/bin/bash
# B145: прогін експортованої гри. export_drive.sh <binary> <scenario: cutscene|fall|walk> [xvfb]
# Кладе override.cfg поруч із бінарником (автолоад Scripts/Tools/export_drive.gd, flush stdout) і запускає.
set -u
BIN=$1; SCEN=$2; MODE=${3:-headless}
DIR=$(dirname "$BIN")
printf '[application]\n\nrun/flush_stdout_on_print=true\n\n[autoload]\n\nExportDrive="*res://Scripts/Tools/export_drive.gd"\n' > "$DIR/override.cfg"
if [ "$MODE" = xvfb ]; then
	xvfb-run -a -s "-screen 0 1920x1080x24" timeout 300 "$BIN" --resolution 1920x1080 --rendering-driver opengl3 ++ "$SCEN"
else
	timeout 300 "$BIN" --headless ++ "$SCEN"
fi
echo "exit $?"
rm "$DIR/override.cfg"
