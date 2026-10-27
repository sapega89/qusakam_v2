#!/usr/bin/env bash
# Фільми кімнат для критиків глибини (design/depth_critics_plan.md, слайс 1): один запуск Godot на кімнату
# (Movie Maker пише один файл на запуск), потім пакунок у design/shots/depth/<кімната>/. Відео лишається в <тека>.
#   Scripts/Tools/film_rooms.sh <тека для відео> [Кімната ...]      (без кімнат — усі SampleProject/Maps/*.tscn)
# Потрібні: $G (Godot 4.6), xvfb-run, python3 з cv2 і numpy.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="$(realpath -m "$1")"
shift
mkdir -p "$out"
rooms=("$@")
if [ ${#rooms[@]} -eq 0 ]; then
	for f in SampleProject/Maps/*.tscn; do rooms+=("$(basename "$f" .tscn)"); done
fi
for room in "${rooms[@]}"; do
	start=$(date +%s)
	xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --path . --resolution 1920x1080 --rendering-driver opengl3 \
		--write-movie "$out/$room.avi" --fixed-fps 30 --script res://SampleProject/UI/film_rooms.gd \
		-- "room=$room" "out=$out" > "$out/$room.log" 2>&1 || true
	grep -E "^FILM|SCRIPT ERROR" "$out/$room.log" || echo "FILM $room: no result, see $out/$room.log"
	echo "TIME $room $(( $(date +%s) - start )) s"
done
python3 -I Scripts/Tools/film_pack.py pack "$out" design/shots/depth "${rooms[@]}"
