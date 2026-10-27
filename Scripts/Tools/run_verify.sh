#!/usr/bin/env bash
# Проганяє SampleProject/UI/verify_*.gd. Тест провалений, якщо немає зеленого RESULT
# АБО в його лозі є SCRIPT ERROR: помилка в корутині не зупиняє тест і не псує RESULT.
#   Scripts/Tools/run_verify.sh              — усі
#   Scripts/Tools/run_verify.sh combat_flow  — verify_combat_flow.gd (glob: 'skills*')
G=${G:-/d/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe}
cd "$(dirname "$0")/../.." || exit 1
mkdir -p logs
failed=0
for f in SampleProject/UI/verify_${1:-*}.gd; do
	name=$(basename "$f" .gd)
	log=logs/$name.log
	# Кожен запуск падає з 139 на виході (design/test_baseline.md, issue 1) — ховаємо це повідомлення bash.
	# Кожен тест — під спільним замком (godot_locked.sh), щоб паралельні worktree не заважали одне одному.
	# SCRIPT ERROR у _initialize() обриває корутину до quit() — Godot висить вічно. Найдовший тест ~30 с.
	# Довгий тест (обходить усі кімнати) пише у своїй шапці «## TIMEOUT: <с>»; решта — 180 с.
	t=$(grep -m1 -o "## TIMEOUT: [0-9]*" "$f" | grep -o "[0-9]*$"); t=${t:-180}
	{ G="$G" timeout "$t" Scripts/Tools/godot_locked.sh --headless --path . --script "res://$f" > "$log" 2>&1; } 2>/dev/null
	# Убитий за таймаутом godot_locked.sh не встигає зняти замок — інакше наступні тести чекали б його 10 хв.
	[[ $? -eq 124 ]] && { echo "RESULT: HUNG — killed after $t s" >> "$log"; rmdir "${TEST_LOCK:-/d/Projects/.godot_test_lock}" 2>/dev/null; }
	result=$(grep -m1 -E '^RESULT:|^=== ALL CHECKS PASSED' "$log")
	errors=$(grep -c 'SCRIPT ERROR' "$log")
	if [[ "$result" =~ ALL\ (PASS|CHECKS\ PASSED) && $errors -eq 0 ]]; then
		echo "PASS  $name"
	else
		failed=$((failed + 1))
		echo "FAIL  $name — ${result:-no RESULT line}, $errors SCRIPT ERROR"
		grep -m3 -A1 'SCRIPT ERROR' "$log" | sed 's/^/      /'
	fi
done
echo "SUITE: $([[ $failed -eq 0 ]] && echo "ALL PASS" || echo "$failed FAIL")"
exit $((failed > 0))
