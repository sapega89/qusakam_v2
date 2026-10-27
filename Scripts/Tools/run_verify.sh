#!/usr/bin/env bash
# Проганяє SampleProject/UI/verify_*.gd. Тест провалений, якщо немає зеленого RESULT
# АБО в його лозі є SCRIPT ERROR: помилка в корутині не зупиняє тест і не псує RESULT.
#   Scripts/Tools/run_verify.sh              — усі
#   Scripts/Tools/run_verify.sh combat_flow  — verify_combat_flow.gd (glob: 'skills*')
#   J=1 Scripts/Tools/run_verify.sh          — по одному (за замовчуванням J=4 паралельно)
# Кожен тест має свою порожню user:// (APPDATA на Windows, XDG_DATA_HOME на Linux), тож паралельні тести
# не ділять сейви й налаштування, і спільний замок godot_locked.sh не потрібен.
export G=${G:-/d/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe}
J=${J:-4}
cd "$(dirname "$0")/../.." || exit 1
mkdir -p logs

run_one() {
	local f=$1 name log t home data start rc result errors line
	name=$(basename "$f" .gd)
	log=logs/$name.log
	# SCRIPT ERROR у _initialize() обриває корутину до quit() — Godot висить вічно.
	# Довгий тест (обходить усі кімнати) пише у своїй шапці «## TIMEOUT: <с>»; решта — 180 с.
	t=$(grep -m1 -o "## TIMEOUT: [0-9]*" "$f" | grep -o "[0-9]*$"); t=${t:-180}
	home=$(mktemp -d)
	data=$home
	command -v cygpath > /dev/null && data=$(cygpath -w "$home") # Godot на Windows не розуміє /tmp/...
	start=$SECONDS
	# Кожен запуск падає з 139 на виході (design/test_baseline.md, issue 1) — ховаємо це повідомлення bash.
	{ APPDATA=$data XDG_DATA_HOME=$data timeout "$t" "$G" --headless --path . --script "res://$f" > "$log" 2>&1; } 2>/dev/null
	rc=$?
	rm -rf "$home"
	[[ $rc -eq 124 ]] && echo "RESULT: HUNG — killed after $t s" >> "$log"
	result=$(grep -m1 -E '^RESULT:|^=== ALL CHECKS PASSED' "$log")
	errors=$(grep -c 'SCRIPT ERROR' "$log")
	if [[ "$result" =~ ALL\ (PASS|CHECKS\ PASSED) && $errors -eq 0 ]]; then
		line="PASS  $name  $((SECONDS - start)) s"
	else
		line="FAIL  $name  $((SECONDS - start)) s — ${result:-no RESULT line}, $errors SCRIPT ERROR"
		line+=$'\n'$(grep -m3 -A1 'SCRIPT ERROR' "$log" | sed 's/^/      /')
	fi
	echo "$line" # одним рядком-записом, щоб паралельні тести не перемішали вивід
}
export -f run_one

out=$(mktemp)
begin=$SECONDS
# Тест, що міряє реальний час (хітстоп у мс, падіння за таймером), пише в шапці «## SERIAL»:
# під навантаженням сусідніх тестів його виміри пливуть, тож він іде після решти, сам.
files=(SampleProject/UI/verify_${1:-*}.gd)
serial=$(grep -l "^## SERIAL" "${files[@]}")
{
	printf '%s\n' "${files[@]}" | grep -v -x -F "${serial:-//}" | xargs -P "$J" -I{} bash -c 'run_one {}'
	[[ -n $serial ]] && echo "$serial" | xargs -P 1 -I{} bash -c 'run_one {}'
} | tee "$out"
failed=$(grep -c '^FAIL' "$out")
echo "Slowest:"; awk '/^(PASS|FAIL)/{print "  " $3 " s  " $2}' "$out" | sort -rn | head -10
echo "SUITE: $([[ $failed -eq 0 ]] && echo "ALL PASS" || echo "$failed FAIL") in $(((SECONDS - begin) / 60)) min $(((SECONDS - begin) % 60)) s, J=$J"
rm -f "$out"
exit $((failed > 0))
