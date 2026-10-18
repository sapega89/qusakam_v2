"""Листи ворогів зі спрайтів Crusenho (D229, CC BY 4.0 — «Crusenho Agus Hennihuno», crusenho.itch.io):
tank = скорпіон (`3 Scorpio`), fast = гієна-шакал (`2 Hyena`) з assets/Complete_UI_Essential_Pack_Free/.

Сітка та сама, що в сценах enemy_tank / enemy_fast: рядки idle / walk / attack / death, клітинка 96x72,
ступні на нижньому рядку клітинки, морда праворуч (у паку — ліворуч, віддзеркалюємо), тіло idle по центру.
Кадри 48x48 без масштабу — у сцені ×1.5, як герой.
Запуск: python Scripts/Tools/build_desert_enemy_sheets.py
"""
from PIL import Image

PACK = "assets/Complete_UI_Essential_Pack_Free/"
OUT = "SampleProject/Assets/Characters/Enemies/"
CW, CH, F = 96, 72, 48

ENEMIES = [  # (тека паку, префікс, тека в проєкті)
    ("3 Scorpio", "Scorpio", "scorpion"),
    ("2 Hyena", "Hyena", "jackal"),
]

for folder, prefix, name in ENEMIES:
    rows = []
    for anim in ("idle", "walk", "attack", "death"):
        im = Image.open(f"{PACK}{folder}/{prefix}_{anim}.png").convert("RGBA")
        rows.append([im.crop((i * F, 0, i * F + F, F)).transpose(Image.FLIP_LEFT_RIGHT) for i in range(im.width // F)])
    left, _, right, _ = rows[0][0].getbbox()
    dx = CW // 2 - (left + right) // 2
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * CW, len(rows) * CH))
    for y, row in enumerate(rows):
        for x, frame in enumerate(row):
            sheet.alpha_composite(frame, (x * CW + dx, y * CH + CH - F))
    import os
    os.makedirs(OUT + name, exist_ok=True)
    sheet.save(OUT + name + "/sheet.png")
    print(name, "cols", cols, "frames", [len(r) for r in rows])
