#!/usr/bin/env python3
# Шукає тексти з даних гри (SampleProject/Resources/Data/*.json), яких немає в uk.po
# (BACKLOG 31, design/localization_plan.md §4). Ключ (msgid) — англійський текст поля як є.
# Друкує кожен відсутній рядок; код виходу 1, якщо хоч один відсутній, інакше 0.
#   python3 Scripts/Tools/po_data_keys.py
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "SampleProject/Resources/Data"
UK_PO = ROOT / "SampleProject/Resources/Translations/uk.po"

# Які поля даних бачить гравець — SampleProject/Resources/Translations/data_fields.json (той самий список
# читає verify_locale.gd [4]). Шлях: "a.b" — ключ словника, "x[]" — кожен елемент масиву x, "*" — кожне значення словника.
FIELDS_FILE = ROOT / "SampleProject/Resources/Translations/data_fields.json"
FIELDS = [(r["file"], r["path"], r["shown"]) for r in json.loads(FIELDS_FILE.read_text(encoding="utf-8"))["fields"]]


def walk(node, parts: list):
    """Усі значення за шляхом (генератор)."""
    if not parts:
        yield node
        return
    head, rest = parts[0], parts[1:]
    if head.endswith("[]"):
        key = head[:-2]
        seq = node.get(key, []) if key else node
        for item in seq if isinstance(seq, list) else []:
            yield from walk(item, rest)
    elif head == "*":
        for value in node.values() if isinstance(node, dict) else []:
            yield from walk(value, rest)
    elif isinstance(node, dict) and head in node:
        yield from walk(node[head], rest)


def po_keys(path: Path) -> set:
    """Усі msgid з uk.po (розекрановані, щоб порівнювати з JSON як є)."""
    keys, key, field = set(), None, None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("msgid "):
            key, field = line[6:].strip()[1:-1], "id"
        elif line.startswith("msgstr "):
            keys.add(key)
            field = "str"
        elif line.startswith('"') and field == "id":
            key += line.strip()[1:-1]
    return {_unescape(k) for k in keys if k}


def _unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(s[i + 1], s[i + 1]))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def data_strings() -> list:
    """[(файл, шлях, текст)] без повторів, у порядку FIELDS."""
    cache, seen, out = {}, set(), []
    for file, path, _ in FIELDS:
        if file not in cache:
            cache[file] = json.loads((DATA / file).read_text(encoding="utf-8"))
        for value in walk(cache[file], path.split(".")):
            if isinstance(value, str) and value.strip() and value not in seen:
                seen.add(value)
                out.append((file, path, value))
    return out


def po_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main() -> int:
    keys = po_keys(UK_PO)
    strings = data_strings()
    missing = [(f, p, s) for f, p, s in strings if s not in keys]
    for file, path, text in missing:
        print(f"{file} {path}: \"{po_escape(text)}\"")
    print(f"data strings: {len(strings)}, missing in uk.po: {len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
