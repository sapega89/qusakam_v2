#!/usr/bin/env bash
# Проходження очима гравця (SampleProject/UI/playthrough.gd). Друкує лише рядки FAIL і підсумок
# PLAYTHROUGH: PASS / FAIL — увесь лог у logs/playthrough.log, знімки й різниці в logs/playthrough/.
#   Scripts/Tools/playthrough.sh            — порівняти з еталоном design/playthrough/
#   Scripts/Tools/playthrough.sh --approve  — зробити поточний прогін еталоном (лише з дозволу Sapega)
G=${G:-/d/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe}
cd "$(dirname "$0")/../.." || exit 1
mkdir -p logs
args=()
[[ "$1" == "--approve" ]] && args=(-- --approve)
# Вікно, не --headless: headless рендерить чорні кадри. Кожен запуск виходить з 139 (test_baseline.md).
{ timeout 300 "$G" --path . --script res://SampleProject/UI/playthrough.gd "${args[@]}" > logs/playthrough.log 2>&1; } 2>/dev/null
[[ $? -eq 124 ]] && echo "PLAYTHROUGH: HUNG — killed after 300 s" >> logs/playthrough.log
grep -E '^PLAYTHROUGH:|^  FAIL |SCRIPT ERROR|Parse Error' logs/playthrough.log | head -20
grep -q '^PLAYTHROUGH:' logs/playthrough.log || echo "PLAYTHROUGH: FAIL — no result line, see logs/playthrough.log"
grep -qE '^PLAYTHROUGH: (PASS|APPROVED)' logs/playthrough.log
