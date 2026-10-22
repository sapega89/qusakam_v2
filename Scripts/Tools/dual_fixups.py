"""Перший кадр парної зброї (BACKLOG 42, A3) — запускати з кореня проєкту ПЕРЕД `comfy_sprite.py hero_weapon_dual`.

Арт-директор: у CombatIdle другий клинок виходив завдовжки з меч (два мечі), а дві спроби моделі (з кадру меча)
вкорочували й сам меч. Тому dual/CombatIdle/1 = кадр меча художника sword/CombatIdle/1 (меч у ближній руці біля
стегна) + короткий кинджал моделі з dual/Attack1/1 (лезо ~9 px з гардою, ті самі кольори металу), вставлений у
підняту порожню дальню руку біля грудей. Інструмент бере цей файл як перший кадр (base="FILE:...") — з нього
дихання (BOB) і всі кадри FROM:CombatIdle:0.

`--after` — запускати ПІСЛЯ інструмента: Attack4/2 (випад) за три спроби мав кинджал завдовжки з меч (17 px леза
горизонтально) — лезо вкорочено до 10 px, вістря моделі зсунуто на 7 px до гарди.
"""

import sys


import numpy as np
from PIL import Image

D = "SampleProject/Sprites/Player/Weapons/"
DAGGER_BOX = (64, 57, 72, 66)  # x0, y0, x1, y1 (без кулака) у dual/Attack1/1
SHIFT = (-3, -2)  # куди зсунути кинджал: гарда над кулаком sword/CombatIdle/1 (59–62, 61–66)

if sys.argv[1:] == ["--after"]:
    path = D + "dual/Attack4/2.png"
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    rows = slice(63, 67)  # лезо кинджала; гарда — стовпець 70, лезо 71–87, вістря 88
    assert a[64, 87, 3] > 128, "Attack4/2: no long dagger blade — already trimmed or the frame changed"
    a[rows, 73:82] = a[rows, 80:89]
    a[rows, 82:89] = 0
    Image.fromarray(a).save(path)
    sys.exit()

idle = np.asarray(Image.open(D + "sword/CombatIdle/1.png").convert("RGBA")).copy()
src = np.asarray(Image.open(D + "dual/Attack1/1.png").convert("RGBA"))
x0, y0, x1, y1 = DAGGER_BOX
part = src[y0:y1, x0:x1]
dx, dy = SHIFT
dst = idle[y0 + dy : y1 + dy, x0 + dx : x1 + dx]
dst[part[..., 3] > 128] = part[part[..., 3] > 128]
Image.fromarray(idle).save(D + "dual/CombatIdle/1.png")
