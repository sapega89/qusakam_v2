"""Каталог арту Кусакама: що є, де вжито, чого бракує — одна HTML-сторінка для Sapega.

    python Scripts/Tools/asset_catalog.py <out_dir>

Сканує SampleProject/Assets (крім Audio, Fonts) і SampleProject/Sprites, робить мініатюри
(кадри анімації — одна стрічка), шукає шлях і uid:// кожного файлу в *.tscn/*.tres/*.gd/*.json,
пише <out_dir>/catalog.json і <out_dir>/index.html (мініатюри вбудовані як data: URI).
Вердикти Sapega («ок» / «поправити» / «прибрати») сторінка зберігає в db артефакту,
колекція `verdicts`, документ на кожну картку (див. VERDICT_DOC нижче).
"""

import base64
import hashlib
import io
import json
import re
import sys
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SP = ROOT / "SampleProject"
SCAN = [SP / "Assets", SP / "Sprites"]
SKIP_DIRS = {"Audio", "Fonts"}
EXTS = {".png", ".jpg"}
CORPUS_EXTS = {".tscn", ".tres", ".gd", ".json"}
CORPUS_SKIP = {"Extensions",
    ".godot",
    ".git",
    "graphify-out",
    "design",
    "docs",
    "build",
    "raw_assets",
    "logs",
    "addons",
}
# посилання лише з тестів / інструментів — гра цей файл не показує
TEST_REF = re.compile(r"/UI/(verify|capture|probe)_|^Scripts/Tools/|playthrough\.gd$")
FRAME = re.compile(r"^(.*?)(\d+)$")
VERDICT_DOC = "verdicts/<doc_id(key)>: {key, status: ok|fix|remove, note, at}"


def doc_id(key: str) -> str:
    # дозволені символи сегмента db: літери, цифри, _ - . ~ : @ +
    return re.sub(r"[^A-Za-z0-9_.~:@+-]", "_", key.replace("/", "~").replace(" ", "+"))


def corpus_index():
    """токен (шлях SampleProject/... або uid://...) -> множина файлів, де він трапляється."""
    tok = re.compile(
        r"SampleProject/(?:Assets|Sprites)/[^\"'\n\]\)]+?\.(?:png|jpg)|uid://[a-z0-9]+"
    )
    idx = defaultdict(set)
    stack = [ROOT]
    while stack:
        d = stack.pop()
        for p in d.iterdir():
            if p.is_dir():
                if p.name not in CORPUS_SKIP:
                    stack.append(p)
            elif p.suffix in CORPUS_EXTS:
                rel = p.relative_to(ROOT).as_posix()
                for t in set(
                    tok.findall(p.read_text(encoding="utf-8", errors="ignore"))
                ):
                    idx[t].add(rel)
    return idx


@lru_cache(None)
def template_re(t: str):
    return re.compile("".join("[^/]+" if re.fullmatch(r"%0?\d*[sd]", x) else re.escape(x)
                              for x in re.split(r"(%0?\d*[sd])", t)))


def uid_of(p: Path):
    imp = p.with_name(p.name + ".import")
    if imp.exists():
        m = re.search(
            r'uid="(uid://[a-z0-9]+)"', imp.read_text(encoding="utf-8", errors="ignore")
        )
        return m and m.group(1)


def thumb(images, max_w=360, max_h=132):
    """кадри поруч (проміжок 2 px), зменшення лише якщо не влазить; повертає data URI."""
    gap = 2
    w = sum(i.width for i in images) + gap * (len(images) - 1)
    h = max(i.height for i in images)
    strip = Image.new("RGBA", (w, h))
    x = 0
    for i in images:
        strip.paste(i.convert("RGBA"), (x, h - i.height))
        x += i.width + gap
    s = min(1.0, max_w / w, max_h / h)
    if s < 1:
        strip = strip.resize((max(1, round(w * s)), max(1, round(h * s))), Image.BOX)
    buf = io.BytesIO()
    if strip.width * strip.height > 120 * 120 and not any(
        i.mode in ("RGBA", "LA", "P") for i in images
    ):
        strip.convert("RGB").save(buf, "JPEG", quality=82)
        mime = "jpeg"
    else:
        strip.save(buf, "PNG", optimize=True)
        mime = "png"
    return f"data:image/{mime};base64," + base64.b64encode(buf.getvalue()).decode()


def section_of(rel: str):
    parts = rel.split("/")  # Assets|Sprites, ...
    if parts[0] == "Sprites" and len(parts) > 2 and parts[1] == "Player":
        sub = parts[2] if parts[2] != "Weapons" else "Weapons/" + parts[3]
        return "Герой", sub if len(parts) > 3 else "—"
    if parts[0] == "Sprites":
        return "Sprites (старе)", parts[1] if len(parts) > 2 else "—"
    sec = parts[1]
    if sec == "Characters" and len(parts) > 3:
        return "Characters/" + parts[2], parts[3] if len(parts) > 4 else "—"
    return sec, parts[2] if len(parts) > 3 else "—"


def scan():
    files = []
    for base in SCAN:
        for p in sorted(base.rglob("*")):
            if p.suffix.lower() in EXTS and not SKIP_DIRS & set(
                p.relative_to(SP).parts
            ):
                files.append(p)
    # групи кадрів: (тека, префікс) з ≥2 нумерованими файлами
    groups = defaultdict(list)
    for p in files:
        m = FRAME.match(p.stem)
        groups[(p.parent, m.group(1) if m else p.stem + "\0")].append(p)
    idx = corpus_index()
    hashes = defaultdict(list)
    cards = []
    for (folder, prefix), ps in groups.items():
        if len(ps) > 1 and not prefix.endswith("\0"):
            ps.sort(key=lambda p: int(FRAME.match(p.stem).group(2)))
            rel_dir = folder.relative_to(SP).as_posix()
            key, name = f"{rel_dir}/{prefix}#", f"{folder.name}/{prefix}1…{len(ps)}"
        else:
            cards.extend(make_card(p, [p], idx, hashes) for p in ps)
            continue
        cards.append(make_card(ps[0], ps, idx, hashes, key, name))
    dups = [v for v in hashes.values() if len(v) > 1]
    for c in cards:
        c["dup"] = sorted(
            {r for v in dups if set(c["files"]) & set(v) for r in v} - set(c["files"])
        )
    cards.sort(key=lambda c: (c["section"], c["sub"], c["key"].lower()))
    return cards, dups


def make_card(first, ps, idx, hashes, key=None, name=None):
    rels = [p.relative_to(SP).as_posix() for p in ps]
    images = [Image.open(p) for p in ps]
    for p, r in zip(ps, rels):
        hashes[hashlib.md5(p.read_bytes()).hexdigest()].append(r)
    refs = set()
    for p, r in zip(ps, rels):
        refs |= idx.get("SampleProject/" + r, set())
        # шаблони з коду: "…/Assets/FX/Skills/%s/%s_%d.png" вантажать файли динамічно
        refs |= {f for t, fs in idx.items() if "%" in t and template_re(t).fullmatch("SampleProject/" + r) for f in fs}
        u = uid_of(p)
        if u:
            refs |= idx.get(u, set())
    game = sorted(r for r in refs if not TEST_REF.search(r))
    tests = sorted(r for r in refs if TEST_REF.search(r))
    sizes = sorted({f"{i.width}×{i.height}" for i in images})
    section, sub = section_of(rels[0])
    return {
        "key": key or rels[0],
        "id": doc_id(key or rels[0]),
        "name": name or first.name,
        "section": section,
        "sub": sub,
        "files": rels,
        "frames": len(ps),
        "size": ", ".join(sizes),
        "uneven": len(sizes) > 1,
        "used": game,
        "tests": tests,
        "use": "game" if game else ("tests" if tests else "unused"),
        "thumb": thumb(images),
    }


# Чого бракує — зібрано вручну з планів (2026-10-27); кожен рядок цитує джерело.
# ponytail: список статичний; оновлювати тут, коли плани зміняться.
MISSING = [
    (
        "Фони · Каньйон (M6a)",
        [
            (
                "Уступи (Rock ledges): 1×2 екрани, уступи вгору без летючих платформ (A15); джерело диму біля проходу в село",
                "MASTER_PLAN M6a-2b; m6_backdrops Batch 1 ⬜",
            ),
            (
                "Спалене село + дим над селом і впалий бар'єр (історія на тлі)",
                "MASTER_PLAN M6a-3; m6_backdrops Batch 1 «M1a» ⬜",
            ),
        ],
    ),
    (
        "Фони · решта Каньйону (M6b)",
        [
            (
                "Печера під мостом — 1×3, вхід у печеру, шлях униз",
                "MASTER_PLAN M6b; m6_backdrops ⬜",
            ),
            ("Горище діда — 1 екран, люк з драбиною", "m6_backdrops ⬜"),
            ("Схованка контрабандистів — 1 екран, тріснута стіна", "m6_backdrops ⬜"),
            ("Вершина мези — 4 екрани", "m6_backdrops ⬜"),
            (
                "Оаза «Привал Захри» — 2 екрани (у плані: тека DesertOasis порожня; насправді в ній є bg1–bg4 — перевірити, чи це воно)",
                "m6_backdrops ⬜",
            ),
            ("Дюни — 4 екрани, стежка до табору", "m6_backdrops ⬜"),
            ("Старі руїни — 4 екрани, брама з ключем ватажка", "m6_backdrops ⬜"),
            ("Прірва — 1 екран, міст, скинутий з дальнього боку", "m6_backdrops ⬜"),
            ("Сухе русло — 1×2, вихід нагору", "m6_backdrops ⬜"),
            ("Акведук — 4 екрани, шлях нагору до підходу до брами", "m6_backdrops ⬜"),
            ("Підхід до брами — 2 екрани, міська брама", "m6_backdrops ⬜"),
        ],
    ),
    (
        "Фони · Місто (M6c)",
        [
            (
                "Ремісничий квартал — 3 екрани (фасади кузні й каплиці вже є)",
                "MASTER_PLAN M6c; m6_backdrops Batch 2 ⬜",
            ),
            (
                "Палацова площа — 2 екрани, двері палацу, провулок униз",
                "m6_backdrops ⬜",
            ),
            (
                "Дахи — 3 екрани, драбина на стіні будинку, стрибок до брами",
                "m6_backdrops ⬜",
            ),
            ("Голубник — 1 екран, хиткі дошки", "m6_backdrops ⬜"),
            (
                "Горище таверни — 2 екрани, люк з драбиною за прилавком",
                "m6_backdrops ⬜",
            ),
            ("Архів мера — 1 екран, двері-книжкова шафа", "m6_backdrops ⬜"),
            (
                "Цистерна під ринком — 3 екрани, колодязь, ґрати в підвал брами",
                "m6_backdrops ⬜",
            ),
            ("Схованка в цистерні — 2 екрани, тріснута стіна", "m6_backdrops ⬜"),
        ],
    ),
    (
        "Фони · Лабораторія (M6d)",
        [
            (
                "Поверхи 1–3 зигзагом — по 5 екранів, отвір у підлозі на змінних кінцях (сьогоднішні шари Lab/, довші)",
                "MASTER_PLAN M6d; m6_backdrops Batch 3 ⬜",
            ),
            ("Коридор алхіміка — 3 екрани, сходи з 1-го поверху", "m6_backdrops ⬜"),
            ("Комора алхіміка — 2 екрани, замкнені двері", "m6_backdrops ⬜"),
            ("Схованка Маліка — 2 екрани, хитка плита в камері", "m6_backdrops ⬜"),
            (
                "Обвалений стік — 7 екранів, ґрати в підлозі 3-го поверху, люк у камери",
                "m6_backdrops ⬜",
            ),
            ("Двір (фінал) — 1 екран", "m6_backdrops ⬜"),
        ],
    ),
    (
        "Плани наявних кімнат",
        [
            (
                "Фреска дракона і підйом на мезу: підлога запечена в один фон — потрібен передній план з підлогою на лінії ходу",
                "BUGS B173",
            ),
            (
                "Підвал брами: два шари швидкості, без підлоги — нарізати плани; бочки, ящики, стелаж, ліхтар, кажан окремими пропами",
                "BUGS B174",
            ),
            (
                "Підвал брами: колона Pillar2 закриває героя біля x 1450–1560; намальовані бочки ~70 px замість 32",
                "MASTER_PLAN R1 (хвости) → R4",
            ),
            (
                "Найбільші предмети — перемалювати за таблицею розмірів після твого «ок»",
                "MASTER_PLAN R4; world_scale_plan",
            ),
        ],
    ),
    (
        "Герой",
        [
            (
                "Пози навичок руху: випад-різ (Dash Strike / Blood Rush / Wind Step), ривок за щитом (Shield Charge), стрибок зі зброєю вгору + удар об землю (Heaven's Anvil / Dune Quake) — кожна з замахом, рухом і ударом",
                "cloud_reports/skills-v2-move.md «For the art lane» (гілка cloud/skills-v2-move); MASTER_PLAN H3",
            ),
            (
                "Лук: кадри Air 1–3, Block, Hurt (зараз у стрибку, блоці, удару й перекаті лук зникає)",
                "BUGS B110",
            ),
            (
                "Меч у різних руках між бігом і атакою — перегенерувати кадри не тієї руки; перевірити інші зброї",
                "BUGS B124",
            ),
            (
                "Смерть: кадри 1 і 3 перемальовані — чекають твого погляду в грі (кадри ще не підключені, H1)",
                "BUGS B184; MASTER_PLAN H1",
            ),
            (
                "Голі руки (необов'язковий слайс 7) та інші пари для двох рук",
                "BACKLOG п. 42; hero_weapon_animation_plan",
            ),
        ],
    ),
    (
        "Ефекти",
        [
            (
                "Небесний щит для Shield Charge (заклинання блоку S19; поки нічого не показується)",
                "cloud_reports/skills-v2-move.md",
            ),
            (
                "Слід ривка; кривава дуга й цівка до героя (Blood Rush); вітряна смуга (Wind Step)",
                "cloud_reports/skills-v2-move.md",
            ),
            (
                "Стовпи світла з землі (Heaven's Anvil), піщана хвиля в обидва боки (Dune Quake), кільце удару при приземленні",
                "cloud_reports/skills-v2-move.md",
            ),
            (
                "В'язень спалахує в камерах перед появою джина — анімація жертви (кадри або FX)",
                "BUGS B168 (D459)",
            ),
            (
                "Шліфування всіх ефектів за твоїми нотатками (GIF-и в design/shots/fx/)",
                "BACKLOG «Moved out of MASTER_PLAN» A9",
            ),
        ],
    ),
    (
        "Персонажі",
        [
            (
                "Старійшина села — арт у двох ракурсах, потім замінити аркуш village_elder.tscn",
                "BACKLOG п. 38",
            ),
            ("Вороги без кадрів оглушення (зараз лише відтінок)", "BACKLOG п. 4"),
            ("Броньований скорпіон: генератор змішує напрямки рядків", "BUGS B148"),
            (
                "Чібі / три чверті для старих персонажів: бандит і шакал, лучник і скорпіон, потім дорослі NPC (відкладено)",
                "BACKLOG A10 (D597, D598)",
            ),
            (
                "Повнорост замість портретів у сюжетних сценах",
                "BACKLOG «Agreed but never built» D112",
            ),
        ],
    ),
    (
        "Живність і UI",
        [
            (
                "Миша: доріжка по підлозі й нора (намальована) — аркуш mouse.png є, але миша не розміщена",
                "ambient_critters_plan; MASTER_PLAN R2",
            ),
            ("Менший голуб, міль своєї форми", "BACKLOG «Critter tweaks»"),
            ("Піксельний скін UI і шрифт (відкладено)", "BACKLOG A11 (D239)"),
        ],
    ),
]


# Сторінка; /*CATALOG*/null замінюється на дані.
PAGE = r'''<title>Ассети Кусакама</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@500;700&family=Golos+Text:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
/* Layout: sticky filter bar over a dense card grid, one tab per job (є / бракує / дублікати). Ochre of the canyon as the accent. */
:root {
  --bg: #eceef1; --surface: #ffffff; --line: #d4d8de; --fg: #1d2127; --muted: #5d6570;
  --accent: #a8620f; --accent-ink: #ffffff; --check-a: #e3e6ea; --check-b: #f4f5f7;
  --ok: #2f7d4a; --fix: #b26b00; --remove: #b3392f; --unused: #6b5b9a;
  --f-display: "Pixelify Sans", "Golos Text", system-ui, sans-serif;
  --f-body: "Golos Text", system-ui, -apple-system, "Segoe UI", sans-serif;
  --f-mono: "JetBrains Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #15171b; --surface: #1f2228; --line: #343943; --fg: #e7e9ec; --muted: #9aa2ad;
  --accent: #e3a04a; --accent-ink: #1a1408; --check-a: #2a2e35; --check-b: #23262c;
  --ok: #5fbf7f; --fix: #e8a53a; --remove: #ef7a6f; --unused: #a99ae0; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #15171b; --surface: #1f2228; --line: #343943; --fg: #e7e9ec; --muted: #9aa2ad;
  --accent: #e3a04a; --accent-ink: #1a1408; --check-a: #2a2e35; --check-b: #23262c;
  --ok: #5fbf7f; --fix: #e8a53a; --remove: #ef7a6f; --unused: #a99ae0; color-scheme: dark }
body { background: var(--bg); color: var(--fg); font: 15px/1.5 var(--f-body); }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--bg); }
.wrap { max-width: 1400px; margin: 0 auto; padding-block: 20px 48px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
h1 { font: 700 34px/1.1 var(--f-display); margin: 0; letter-spacing: .01em; text-wrap: balance; }
h2 { font: 700 20px/1.2 var(--f-display); margin: 28px 0 10px; display: flex; gap: 10px; align-items: baseline; text-wrap: balance; }
h2 small, .count { font: 500 12px var(--f-mono); color: var(--muted); }
h3 { font: 600 14px/1.3 var(--f-body); margin: 0; overflow-wrap: anywhere; }
.lede { color: var(--muted); max-width: 70ch; margin: 6px 0 0; }
.stats { display: flex; flex-wrap: wrap; gap: 6px 18px; margin: 14px 0 0; font: 500 13px var(--f-mono); font-variant-numeric: tabular-nums; }
.stats b { color: var(--fg); } .stats span { color: var(--muted); }
.tabs { display: flex; gap: 4px; margin: 18px 0 0; flex-wrap: wrap; }
.tabs button { font: 600 14px var(--f-body); padding: 8px 14px; border: 1px solid var(--line); background: var(--surface);
  color: var(--fg); border-radius: 6px; cursor: pointer; }
.tabs button[aria-selected="true"] { background: var(--accent); color: var(--accent-ink); border-color: var(--accent); }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg); padding-block: 10px;
  display: flex; flex-wrap: wrap; gap: 8px; border-bottom: 1px solid var(--line); margin-top: 12px; }
.bar input, .bar select { font: 14px var(--f-body); padding: 7px 10px; border: 1px solid var(--line); border-radius: 6px;
  background: var(--surface); color: var(--fg); min-width: 0; }
.bar input { flex: 1 1 220px; }
.bar select { flex: 0 1 auto; max-width: 100%; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.dbnote { font-size: 13px; color: var(--muted); margin: 8px 0 0; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 250px), 1fr)); gap: 10px; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; display: flex; flex-direction: column; min-width: 0; overflow: hidden; }
.card[data-v="ok"] { border-color: var(--ok); } .card[data-v="fix"] { border-color: var(--fix); } .card[data-v="remove"] { border-color: var(--remove); }
.thumb { height: 140px; display: flex; align-items: center; justify-content: center; overflow-x: auto; padding: 6px;
  background: repeating-conic-gradient(var(--check-a) 0 25%, var(--check-b) 0 50%) 0 0 / 12px 12px; }
.thumb img { image-rendering: pixelated; max-width: none; flex: none; }
.body { padding: 10px 12px 12px; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
.meta { font: 12px var(--f-mono); color: var(--muted); overflow-wrap: anywhere; font-variant-numeric: tabular-nums; }
.warn { color: var(--fix); }
.use { font-size: 12.5px; }
.use summary { cursor: pointer; color: var(--muted); }
.use ul { margin: 4px 0 0; padding-left: 16px; font: 11.5px/1.45 var(--f-mono); overflow-wrap: anywhere; }
.pill { display: inline-block; font: 600 11.5px var(--f-body); padding: 1px 8px; border-radius: 99px; border: 1px solid currentColor; }
.pill.unused { color: var(--unused); } .pill.tests { color: var(--fix); }
.verdict { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; margin-top: 2px; }
.verdict button { font: 600 12.5px var(--f-body); padding: 6px 4px; border-radius: 6px; border: 1px solid var(--line);
  background: transparent; color: var(--fg); cursor: pointer; }
.verdict button:disabled { opacity: .45; cursor: not-allowed; }
.verdict button[aria-pressed="true"][data-s="ok"] { background: var(--ok); border-color: var(--ok); color: var(--surface); }
.verdict button[aria-pressed="true"][data-s="fix"] { background: var(--fix); border-color: var(--fix); color: var(--surface); }
.verdict button[aria-pressed="true"][data-s="remove"] { background: var(--remove); border-color: var(--remove); color: var(--surface); }
textarea { font: 13px var(--f-body); width: 100%; box-sizing: border-box; min-height: 52px; resize: vertical; padding: 6px 8px;
  border: 1px solid var(--line); border-radius: 6px; background: var(--bg); color: var(--fg); }
.saved { font-size: 11.5px; color: var(--muted); min-height: 1em; }
.empty { color: var(--muted); padding: 24px 0; }
.miss { display: grid; gap: 4px; margin: 0; padding: 0; list-style: none; }
.miss li { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 9px 12px;
  display: flex; flex-wrap: wrap; gap: 4px 14px; justify-content: space-between; align-items: baseline; }
.miss .what { flex: 1 1 380px; min-width: 0; }
.miss .src { font: 11.5px var(--f-mono); color: var(--muted); flex: 0 1 auto; min-width: 0; overflow-wrap: anywhere; }
.dups li { display: block; font: 12px/1.5 var(--f-mono); overflow-wrap: anywhere; }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>

<div class="wrap">
  <h1>Ассети Кусакама</h1>
  <p class="lede">Увесь арт із SampleProject/Assets і SampleProject/Sprites: що є, де воно в грі, чого бракує за планами.
    Постав кожній картці вердикт — «ок», «поправити» з приміткою або «прибрати»; він зберігається, і я його прочитаю.
    «Використано» означає, що на файл є пряме посилання в .tscn / .tres / .gd / .json (шлях, uid або шаблон шляху в коді);
    чи сама та сцена потрапляє в гру, сторінка не перевіряє.</p>
  <div class="stats" id="stats"></div>
  <div class="tabs" role="tablist">
    <button role="tab" id="tab-have" aria-selected="true" data-tab="have">Що є</button>
    <button role="tab" id="tab-miss" aria-selected="false" data-tab="miss">Чого немає</button>
    <button role="tab" id="tab-dups" aria-selected="false" data-tab="dups">Дублікати</button>
  </div>

  <section id="have">
    <div class="bar">
      <input id="q" type="search" placeholder="Пошук за назвою або шляхом" aria-label="Пошук">
      <select id="sec" aria-label="Група"><option value="">Усі групи</option></select>
      <select id="use" aria-label="Використання">
        <option value="">Будь-яке використання</option>
        <option value="game">У грі</option>
        <option value="tests">Лише в тестах / інструментах</option>
        <option value="unused">Не використовується</option>
      </select>
      <select id="ver" aria-label="Вердикт">
        <option value="">Будь-який вердикт</option>
        <option value="none">Без вердикту</option>
        <option value="ok">Ок</option>
        <option value="fix">Поправити</option>
        <option value="remove">Прибрати</option>
      </select>
    </div>
    <p class="dbnote" id="dbnote">Під'єднуюсь до сховища вердиктів…</p>
    <div id="list"></div>
    <p class="empty" id="none" hidden>Нічого не знайдено — зміни фільтри.</p>
  </section>
  <section id="miss" hidden></section>
  <section id="dups" hidden></section>
</div>

<script>
const DATA = /*CATALOG*/null;
const LABEL = { ok: "Ок", fix: "Поправити", remove: "Прибрати" };
const verdicts = {};      // doc id -> {status, note}
let db = null;
const $ = (s, r = document) => r.querySelector(s);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

// ---- що є
const cards = [];
const sections = [...new Set(DATA.cards.map(c => c.section))];
for (const s of sections) $("#sec").append(new Option(s, s));
for (const s of sections) {
  const items = DATA.cards.filter(c => c.section === s);
  const sec = el("div"); sec.dataset.section = s;
  const h = el("h2", null, s); h.append(el("small", null, items.length + " карт."));
  const grid = el("div", "grid");
  sec.append(h, grid);
  for (const c of items) grid.append(card(c));
  $("#list").append(sec);
}

function card(c) {
  const a = el("article", "card");
  a.dataset.id = c.id;
  const th = el("div", "thumb");
  const img = new Image(); img.alt = c.name; img.loading = "lazy"; img.decoding = "async";
  img.onload = () => { const k = Math.max(1, Math.floor(Math.min(128 / img.naturalHeight, 600 / img.naturalWidth)));
    img.style.width = img.naturalWidth * k + "px"; img.style.height = img.naturalHeight * k + "px"; };
  img.src = c.thumb; th.append(img);
  const b = el("div", "body");
  b.append(el("h3", null, c.name));
  const meta = el("div", "meta", c.size + " px" + (c.frames > 1 ? " · " + c.frames + " кадр." : ""));
  if (c.uneven) meta.append(el("span", "warn", " · різні розміри кадрів"));
  b.append(meta, el("div", "meta", c.sub !== "—" ? c.key : c.key));
  const use = el("div", "use");
  if (c.use === "unused") use.append(el("span", "pill unused", "не використовується"));
  else {
    const refs = c.used.concat(c.tests.map(t => t + "  (тест)"));
    const d = el("details"); const sm = el("summary", null, (c.use === "tests" ? "лише тести / інструменти · " : "використано: ") + refs.length + " файл.");
    if (c.use === "tests") sm.prepend(el("span", "pill tests", "не в грі"), " ");
    const ul = el("ul"); for (const r of refs) ul.append(el("li", null, r));
    d.append(sm, ul); use.append(d);
  }
  if (c.dup.length) use.append(el("div", "meta warn", "Той самий файл: " + c.dup.join(", ")));
  b.append(use);
  const v = el("div", "verdict"); v.setAttribute("role", "group"); v.setAttribute("aria-label", "Вердикт");
  for (const s of ["ok", "fix", "remove"]) {
    const btn = el("button", null, LABEL[s]); btn.type = "button"; btn.dataset.s = s; btn.disabled = true;
    btn.setAttribute("aria-pressed", "false"); btn.onclick = () => choose(c, s); v.append(btn);
  }
  const ta = el("textarea"); ta.id = "note-" + c.id; ta.placeholder = "Що поправити?"; ta.hidden = true;
  ta.onchange = () => save(c, "fix", ta.value.trim());
  const saved = el("div", "saved");
  b.append(v, ta, saved);
  a.append(th, b);
  cards.push({ c, a, ta, saved, hay: (c.name + " " + c.key + " " + c.sub).toLowerCase() });
  return a;
}

function paint() {
  for (const k of cards) {
    const v = verdicts[k.c.id]; const s = v ? v.status : "";
    k.a.dataset.v = s;
    for (const b of k.a.querySelectorAll(".verdict button")) { b.setAttribute("aria-pressed", String(b.dataset.s === s)); b.disabled = !db; }
    k.ta.hidden = s !== "fix";
    if (s === "fix" && document.activeElement !== k.ta) k.ta.value = v.note || "";
  }
  filter(); stats();
}

function choose(c, s) {
  const cur = verdicts[c.id];
  if (cur && cur.status === s) return clear(c);
  save(c, s, s === "fix" ? (cur && cur.note) || "" : "");
  if (s === "fix") setTimeout(() => $("#note-" + CSS.escape(c.id)).focus(), 0);
}
async function save(c, status, note) {
  const k = cards.find(k => k.c.id === c.id);
  verdicts[c.id] = { status, note }; paint();
  try { await db.collection("verdicts").doc(c.id).set({ key: c.key, status, note, at: new Date().toISOString() }); k.saved.textContent = "Збережено"; }
  catch (e) { k.saved.textContent = "Не збереглося: " + (e.message || e.code) + ". Спробуй ще раз."; }
}
async function clear(c) {
  const k = cards.find(k => k.c.id === c.id);
  delete verdicts[c.id]; paint();
  try { await db.collection("verdicts").doc(c.id).delete(); k.saved.textContent = "Вердикт знято"; }
  catch (e) { k.saved.textContent = "Не вдалося зняти: " + (e.message || e.code); }
}

function filter() {
  const q = $("#q").value.trim().toLowerCase(), sec = $("#sec").value, use = $("#use").value, ver = $("#ver").value;
  let shown = 0;
  for (const k of cards) {
    const s = (verdicts[k.c.id] || {}).status || "none";
    const ok = (!q || k.hay.includes(q)) && (!sec || k.c.section === sec) && (!use || k.c.use === use) && (!ver || s === ver);
    k.a.hidden = !ok; if (ok) shown++;
  }
  for (const s of $("#list").children) s.hidden = !s.querySelector(".card:not([hidden])");
  $("#none").hidden = shown > 0;
}
for (const id of ["q", "sec", "use", "ver"]) $("#" + id).addEventListener("input", filter);

function stats() {
  const files = DATA.cards.reduce((n, c) => n + c.frames, 0);
  const n = s => Object.values(verdicts).filter(v => v.status === s).length;
  const missing = DATA.missing.reduce((n, g) => n + g.items.length, 0);
  const row = [["карток", DATA.cards.length], ["файлів", files],
    ["не використовуються", DATA.cards.filter(c => c.use === "unused").length],
    ["лише в тестах", DATA.cards.filter(c => c.use === "tests").length],
    ["бракує", missing], ["ок", n("ok")], ["поправити", n("fix")], ["прибрати", n("remove")]];
  $("#stats").replaceChildren(...row.map(([l, v]) => { const s = el("span"); s.append(el("b", null, v), " " + l); return s; }));
  $("#tab-have").textContent = "Що є (" + DATA.cards.length + ")";
  $("#tab-miss").textContent = "Чого немає (" + missing + ")";
  $("#tab-dups").textContent = "Дублікати (" + DATA.dups.length + ")";
}

// ---- чого немає
for (const g of DATA.missing) {
  const h = el("h2", null, g.group); h.append(el("small", null, g.items.length + ""));
  const ul = el("ul", "miss");
  for (const it of g.items) { const li = el("li"); li.append(el("span", "what", it.what), el("span", "src", it.src)); ul.append(li); }
  $("#miss").append(h, ul);
}
// ---- дублікати
if (!DATA.dups.length) $("#dups").append(el("p", "empty", "Однакових файлів немає."));
else {
  $("#dups").append(el("p", "lede", "Файли з однаковим вмістом (байт у байт). Один із пари, мабуть, зайвий."));
  const ul = el("ul", "miss dups");
  for (const d of DATA.dups) ul.append(el("li", null, d.join("  =  ")));
  $("#dups").append(ul);
}

for (const t of document.querySelectorAll("[data-tab]")) t.onclick = () => {
  for (const u of document.querySelectorAll("[data-tab]")) { u.setAttribute("aria-selected", String(u === t)); $("#" + u.dataset.tab).hidden = u !== t; }
};

stats(); filter();

// ---- вердикти зі спільного сховища
(async () => {
  db = await window.claude?.use?.("db") ?? null;
  if (!db) { $("#dbnote").textContent = "Сховище вердиктів недоступне в цьому перегляді — відкрий сторінку на claude.ai, увійшовши в акаунт."; return; }
  $("#dbnote").textContent = "Вердикти зберігаються для всіх, хто відкриває цю сторінку. Повторне натискання знімає вердикт.";
  db.collection("verdicts").limit(1000).onSnapshot(snap => {
    for (const k in verdicts) delete verdicts[k];
    for (const d of snap.docs) { const v = d.data(); verdicts[d.id] = { status: v.status, note: v.note || "" }; }
    paint();
  }, e => { $("#dbnote").textContent = "Не вдалося прочитати вердикти: " + (e.message || e.code) + ". Онови сторінку."; });
  paint();
})();
</script>
'''


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "asset_catalog"
    out.mkdir(parents=True, exist_ok=True)
    cards, dups = scan()
    data = {
        "cards": cards,
        "dups": dups,
        "missing": [
            {"group": g, "items": [{"what": w, "src": s} for w, s in it]}
            for g, it in MISSING
        ],
    }
    (out / "catalog.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    (out / "index.html").write_text(
        PAGE.replace(
            "/*CATALOG*/null",
            json.dumps(data, ensure_ascii=False).replace("</", r"<\/"),
        ),
        encoding="utf-8",
    )
    n_files = sum(c["frames"] for c in cards)
    print(
        f"cards {len(cards)} files {n_files} unused {sum(c['use'] == 'unused' for c in cards)} "
        f"tests-only {sum(c['use'] == 'tests' for c in cards)} dup-groups {len(dups)} "
        f"missing {sum(len(i) for _, i in MISSING)} html {(out / 'index.html').stat().st_size // 1024} KB"
    )


if __name__ == "__main__":
    main()
