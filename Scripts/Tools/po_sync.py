#!/usr/bin/env python3
# Тримає en.po у кроці з uk.po (BACKLOG 31, design/localization_plan.md).
# Ключ (msgid) — англійський текст; uk.po — джерело правди: кожен msgid з його перекладом.
# en.po — ті самі msgid у тому ж порядку, значення = ключ. Скрипт переписує en.po і падає,
# якщо в uk.po є порожній переклад.
#   python3 Scripts/Tools/po_sync.py
import re
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parents[2] / "SampleProject/Resources/Translations"
HEADER = """# Kusakam — English (BACKLOG 31, design/localization_plan.md).
# Key (msgid) = the English text the scene or code shows (D121); Label/Button translate their text on their own.
# en.po carries the same keys, each value = its key (English is the key) — Scripts/Tools/po_sync.py keeps it in step.
msgid ""
msgstr ""
"Language: en\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"""


def parse(path: Path) -> list:
    """[(comment_lines, msgid, msgstr)] — рядки у вигляді, як у файлі (з екрануванням)."""
    entries, comments, key, value, field = [], [], None, None, None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            comments.append(line)
        elif line.startswith("msgid "):
            key, field = line[6:].strip()[1:-1], "id"
        elif line.startswith("msgstr "):
            value, field = line[7:].strip()[1:-1], "str"
        elif line.startswith('"') and field:
            if field == "id":
                key += line.strip()[1:-1]
            else:
                value += line.strip()[1:-1]
        elif not line.strip() and key is not None:
            entries.append((comments, key, value))
            comments, key, value, field = [], None, None, None
    if key is not None:
        entries.append((comments, key, value))
    return [e for e in entries if e[1] != ""]


def main() -> int:
    uk = parse(DIR / "uk.po")
    missing = [k for _, k, v in uk if not v]
    seen = set()
    dupes = [k for _, k, _ in uk if k in seen or seen.add(k)]
    out = [HEADER]
    for comments, key, _ in uk:
        out += [c for c in comments if c.startswith("# ──")]
        out += [f'msgid "{key}"', f'msgstr "{key}"', ""]
    (DIR / "en.po").write_text("\n".join(out), encoding="utf-8", newline="\n")
    print(f"en.po: {len(uk)} keys")
    for k in missing:
        print(f"uk.po: no translation for \"{k}\"")
    for k in dupes:
        print(f"uk.po: duplicate key \"{k}\"")
    return 1 if missing or dupes else 0


if __name__ == "__main__":
    sys.exit(main())
