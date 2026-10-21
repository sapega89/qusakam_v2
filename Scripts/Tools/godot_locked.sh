#!/usr/bin/env bash
# Запускає Godot під спільним замком: паралельні агенти (різні worktree) не ганяють тести й знімки
# одночасно — вони ділять user:// (сейви, налаштування) і процесор (тести на час).
#   Scripts/Tools/godot_locked.sh --headless --path . --script res://SampleProject/UI/verify_x.gd
# Замок старший за 10 хв вважається покинутим (агента зупинили) і знімається.
G=${G:-/d/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe}
LOCK=${TEST_LOCK:-/d/Projects/.godot_test_lock}
until mkdir "$LOCK" 2>/dev/null; do
	if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null) ]]; then rmdir "$LOCK" 2>/dev/null; continue; fi
	sleep 2
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
"$G" "$@"
