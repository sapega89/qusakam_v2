"""Спрайти персонажів через ComfyUI (D239): Qwen-Image-Edit-2511 (Apache 2.0, GGUF Q5) малює персонажа з
референсу — кадру героя від художника — у його піксельному стилі, а кожен кадр анімації — з першого кадру цього
персонажа, щоб він лишався тим самим. Кадр 64 px збільшується ×16 (піксель — блок 16×16, модель тримає сітку),
скрипт вирізає фон (виміряний колір рамки), зменшує ×16 назад до 64×64, зводить усі кадри до однієї палітри
(з першого кадру — кольори не мерехтять) і ставить ступні всіх кадрів на один рядок. Лист — рядок на анімацію.
Кеш — %TEMP%/comfy_sprite (референс + підказка + зерно). Потрібен запущений ComfyUI з моделями з edit_graph().
Запуск: python -I -B Scripts/Tools/comfy_sprite.py <персонаж> [анімація ...]   (лист — коли всі кадри є в кеші)
"""

import hashlib
import json
import os
import sys
import tempfile
import urllib.request

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import API, run, upload  # noqa: E402

CACHE = os.path.join(tempfile.gettempdir(), "comfy_sprite")
UP, CELL = 16, 64
MAGENTA = (255, 0, 255)
KEEP = (
    "Keep this exact character — {who}, the same pixel art style, thick dark outline, flat shading, colours, size "
    "and position. Change only the pose: {pose}. Keep the plain flat magenta background."
)
URIZEN_FRONT = (
    "turned to face the viewer: a front view of him standing idle, the thin dark iron circlet across his forehead above "
    "the small tattoo, both eyes visible, the coin amulet in the middle of his chest, arms at his sides"
)
URIZEN_STEP = "walking quickly to the right in the same side view facing right, %s leg stepping forward, %s leg back, the robe swinging"
URIZEN_RAISE = "in the same side view facing right: raising his right hand to shoulder height in front of him, a small golden coin in his palm"
URIZEN_SMITE = "in the same side view facing right: his right arm stretched high above his head, a shining golden coin held up in his hand"
ASTRIT_FRONT = (
    "turned to face the viewer: a front view of her standing idle, both amber eyes visible, the red bow on her ponytail, "
    "the huge spiked shield with the flame emblem at her side, the burning spell book in her other hand"
)
ASTRIT_STEP = (
    "running to the right in the same side view facing right, %s leg stepping forward, %s leg back, the ponytail flying "
    "behind her, the shield held in front of her"
)
ASTRIT_CROUCH = (
    "in the same side view facing right: crouching very low on bent knees, her head down behind the top of her huge "
    "spiked shield, ready to pounce"
)
ASTRIT_LEAP = "in the same side view facing right: leaping forward through the air, her huge spiked shield thrust out in front of her"
ASTRIT_SLAM = (
    "in the same side view facing right: slamming her huge spiked shield forward with all her weight, leaning into the "
    "blow, the flame emblem on the shield blazing"  # «полум'я рветься зі щита» різала межа кадру
)
ALISIA_LOOK = (
    "a cheerful young huntress with long silver-grey hair in a high ponytail, a soft smile, brown leather armour with gold "
    "trim and a fur collar, a dark tattered cape and a wooden longbow in her hand"
)
ALISIA_FRONT = (
    "turned to face the viewer: a front view of her standing idle, heterochromia — one bright green eye and one bright "
    "sky-blue eye, clearly different colours, her long silver high ponytail falling forward over her right shoulder "
    "down to her chest, clearly visible beside her face, her forehead uncovered, the longbow in her hand"
)  # хвіст за головою у фас читався як шолом чи гулька
ALISIA_STEP = (
    "running to the right in the same side view facing right, %s leg stepping forward, %s leg back, the ponytail flying "
    "behind her, the longbow in her hand"
)
STEP_B = (
    "in the same side view facing right, mid-stride with the opposite leg: the far leg, half hidden behind the body, "
    "reaching forward, the near leg pushed far back behind, the near arm swinging forward"
)
ALISIA_AIM = "in the same side view facing right: raising her longbow in front of her, an arrow nocked"
ALISIA_DRAW = "in the same side view facing right: drawing the bowstring back to her cheek, the longbow aimed forward"
ALISIA_RELEASE = (
    "in the same side view facing right: the arrow is gone, already flown away — no arrow on the bow; her bow arm "
    "stretched straight forward holding the empty longbow, the bowstring straight, her string hand open and pulled back "
    "past her ear"
)
CAT_LOOK = (
    "a tiny white tiger cub with soft off-white fur, brown stripes, blue eyes and glowing cyan spiral markings on its "
    "fur, standing on all four paws. It is very small, kitten-sized: the whole cub fits in the bottom third of the picture, "
    "its ears no higher than the belt of the character in picture 1, a large empty magenta space above it"
)  # кошеня було ростом з героя — тепер 29 px, ~60 % його 48; референс Sapega тягнув розмір угору — без нього
CAT_FRONT = (
    "turned to face the viewer: sitting on its haunches, a front view with both blue eyes, its tail curled by its paws; "
    "just as tiny as before — the sitting cub fits in the bottom half of the picture, a large empty magenta space above it"
)
CAT_RUN = (
    "in the same side view facing right, the same small size, running fast: %s; strict profile, its head in profile "
    "looking ahead to the right, not at the viewer"
)
CAT_SWIPE = (
    "in the same side view facing right, the same small size, its head in profile: %s"
)
BASE_ALISIA = (
    "Replace the character in picture 1 with the woman from picture 2 — "
    + ALISIA_LOOK
    + " — drawn in exactly the pixel art "
    "style of the character in picture 1: the same big square pixels, chibi proportions, thick dark outline and flat "
    "shading. Strict side view: her head and body in profile facing right, her eye and nose on the right side of her face, looking ahead to the right. Standing idle. Keep the plain flat magenta background."
)
BASE_CAT = (
    "Replace the character in picture 1 with "
    + CAT_LOOK
    + " — drawn in exactly the pixel art style of the character in picture 1: the same big square pixels, chibi "
    "proportions, thick dark outline and flat shading. Strict side view: its head and body in profile facing right, "
    "its eye and nose on the right side of its face, looking ahead to the right. Keep the plain flat magenta background."
)
# rows — рядки листа: (анімація, підказки кадрів); None — сам перший кадр (base).
# Хода дорослого NPC у профіль праворуч (BACKLOG 14): чотири кадри, четвертий — той самий кадр, що другий.
WALK = [
    "walking to the right in strict side view, his whole body in profile facing right, his left leg stepping forward "
    "and his right leg back, arms swinging",
    "walking to the right in strict side view, his whole body in profile facing right, mid-stride with both legs "
    "passing together under his body",
    "walking to the right in strict side view, his whole body in profile facing right, his right leg stepping forward "
    "and his left leg back, arms swinging",
    "walking to the right in strict side view, his whole body in profile facing right, mid-stride with both legs "
    "passing together under his body",
]

SAME = ", everything else exactly the same"
# BACKLOG 42 (арт A3): меч героя — той самий у кожному кадрі; ON: — кадр художника, до якого модель лише додає меч
SWORD = "a short straight steel sword with a simple steel cross-guard and a brown grip"
# у клітинці 96x96 модель збільшувала героя на ~30 % (заповнювала порожнє місце) — розмір словами, як у кошеняти
SWORD_SIZE = (
    "He stays exactly as small as in the picture, not enlarged: his feet on the same spot near the bottom, the top of "
    "his head just below the middle of the picture, a large empty magenta space above him"
)
SWORD_COLOURS = ", his armour the same light steel grey and his cape the same dark red as in the picture, not darker"
SWORD_ON = (
    "ON:SampleProject/Sprites/Player/%s.png:keeping exactly the same pose, legs, arms, cape, size and position as in "
    "the picture, only now holding "
    + SWORD
    + " in his near hand, the blade pointing %s"
)
# BACKLOG 42, A3: кинджал — з кадрів меча (той самий герой, поза й метал), меч замінено; удари — уколи, не дуги
DAGGER = (
    "a short steel dagger with a small steel cross-guard and a brown grip, its blade only as long as his forearm, "
    "the same light grey and white steel as the sword in the picture"
)
# з кадрів меча модель лишала довгий клинок — біг і стрибок, як у меча, з кадрів художника
DAGGER_ON = (
    "ON:SampleProject/Sprites/Player/%s.png:keeping exactly the same pose, legs, arms, cape, size and position as in "
    "the picture, only now holding "
    + DAGGER
    + " in his near hand, the blade pointing %s; the blade shorter than his forearm, a short knife, not a sword"
    + SWORD_COLOURS
)
# кинджал у високих позах модель видовжувала до меча — довжину названо
DAGGER_SHORT = (
    "; the dagger exactly as small as in the picture, its blade shorter than his forearm, a short knife, not a sword"
)
# FROM: з кадру, де кинджал уже короткий, — інакше в нових позах він росте до меча
DAGGER_KEEP = (
    "; the same short dagger as in the picture, exactly the same size and colours, its blade shorter than his "
    "forearm, not longer, only one dagger, facing right"
)
# BACKLOG 42, A3: булава — як кинджал, з кадру меча (той самий герой, поза й метал), меч замінено; удари — зверху вниз
MACE = (
    "a short one-handed steel mace: a brown wooden handle as long as his forearm and a small round flanged steel head "
    "on its end, the head the same light grey and white steel as the sword in the picture"
)
MACE_ON = (
    "ON:SampleProject/Sprites/Player/%s.png:keeping exactly the same pose, legs, arms, cape, size and position as in "
    "the picture, only now holding "
    + MACE
    + " in his near hand, the handle pointing %s; a small mace, not a sword, no blade"
    + SWORD_COLOURS
)
# арт-директор (булава, друга хвиля): «flanged» малював шипи й молот — гладка куля й коротке руків'я, тримане за низ
MACE_BALL = (
    "a one-handed mace with a smooth round spherical steel head, a plain ball with no spikes or flanges, on a short "
    "brown wooden handle as long as his forearm held at its bottom end, the ball the same light grey and white steel "
    "as the sword in the picture"
)
MACE_BALL_ON = (
    "ON:SampleProject/Sprites/Player/%s.png:keeping exactly the same pose, legs, arms, size and position as in the "
    "picture, only now holding "
    + MACE_BALL
    + " in his near hand, the handle pointing %s; the cape flowing behind him, the same dark maroon cape with the "
    "dark outline and two-tone shading as in the picture; a small mace, not a sword, no blade"
    + SWORD_COLOURS
)
# у високих позах модель збільшувала булаву до кувалди — довжину названо
MACE_SHORT = "; the mace small, its handle only as long as his forearm, not a long staff or a sledgehammer"
# FROM: з кадру, де булава вже вдала, — тримає її розмір і кольори
MACE_KEEP = (
    "; the same small mace as in the picture, exactly the same size and colours, a short handle and a small round "
    "steel head, only one mace, no blade, facing right"
)
# BACKLOG 42, A3: алебарда (D267: дворучна — уколи й низький мах, обидві руки на древку); з кадру меча, як булава
HALBERD = (
    "a two-handed steel halberd: a long thin straight brown wooden pole as long as he is tall, at its top end a "
    "single small steel axe blade on one side only, a small steel spike on the other side and a short pointed steel "
    "spear tip at the very end of the pole, not a double axe, the blade and tip the same light grey and white steel as "
    "the sword in the picture"
)
HALBERD_ON = (
    "ON:SampleProject/Sprites/Player/%s.png:keeping exactly the same pose, legs, cape, size and position as in the "
    "picture, only now carrying "
    + HALBERD
    + " in his near hand, the pole slanted with the axe blade and spear point %s; one long polearm, not a sword"
    + SWORD_COLOURS
)
# стрибок: «вперед і вгору» алебарда лягала головою назад, через плече — сторони названо
HALBERD_AIR = (
    HALBERD_ON
    % ("%s", "up on the right in front of his face, the bottom end of the pole down on the left behind his feet")
    + "; the steel head small, his bare round lizard head exactly as in the picture, no helmet, the same cape as in "
    "the picture"
)
# FROM: з кадру, де алебарда вже вдала, — тримає її довжину й кольори
HALBERD_KEEP = (
    "; the same halberd as in the picture, exactly the same size and colours, a long brown wooden pole with the steel "
    "axe blade and spear point at its top end, only one halberd, no sword, facing right"
)
# голова алебарди «вперед» виходила позаду голови героя або подвійною сокирою — сторони названо
HALBERD_LEVEL = (
    "; the same halberd as in the picture, exactly the same size and colours, its single axe blade, spike and spear "
    "tip at the front end on the right, the hero does not grow, only one halberd, no arrow, no double axe, facing right"
)
# низько тримана алебарда: лезо звисає під древком, шип угору — не дволезова сокира
HALBERD_LOW = (
    "; the same small halberd head as in the picture, not bigger: one single axe blade hanging down under the pole, "
    "a small spike pointing up and the spear tip at the front end, not a double axe, only one halberd, the hero the "
    "same size, facing right"
)
# BACKLOG 5 (D295): перші кадри дій NPC — з першого кадру персонажа (профіль), решта циклу — FROM: з цього кадру
SMITH_RAISE = (
    "in the same side view facing right, standing at a small dark iron anvil on the ground right in front of him, a "
    "glowing orange blade lying on the anvil, holding the blade with long tongs in his left hand, the smithing hammer "
    "raised high above his shoulder in his right hand"
)
MERCHANT_COUNT = (
    "in the same side view facing right, counting money: holding a small open leather coin purse in his left hand and a "
    "gold coin between the fingers of his right hand, looking down at the coins"
)
PRIEST_PRAY = (
    "in the same side view facing right, praying: her head bowed, eyes closed, both hands pressed together in front of "
    "her chest, the slender white staff leaning against her shoulder"
)
WITCH_READ = (
    "in the same side view facing right, reading an open old spell book held in her left hand, her head bent over the "
    "pages, the gnarled black wand in her right hand"
)
DERVISH_WHIRL = (
    "turned to face the viewer: a front view of him whirling in a sacred dance, his right arm raised high with the palm "
    "up, his left arm stretched out low to the side with the palm down, his head tilted to his right shoulder, eyes "
    "closed, his wide flared ochre skirt spinning out in a bell shape, the very tall brimless cylindrical camel felt hat"
)
OLDMAN_PIPE = (
    "in the same side view facing right, leaning on his walking staff with one hand and holding a long thin wooden pipe "
    "to his mouth with the other, his eyes half closed, content"
)

CHARACTERS = {
    "bandit": dict(
        out="SampleProject/Assets/Characters/Enemies/bandit/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=2,
        colors=16,
        who="the same chibi desert bandit with the red face scarf, sand-coloured cloak and curved scimitar",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, "
        "thick dark outline and flat shading: a desert bandit with a curved scimitar, a red head scarf wrapped over his "
        "face and a ragged sand-coloured cloak, standing in an idle fighting stance facing right. Keep the plain flat "
        "magenta background.",
        rows=[
            (
                "idle",
                [
                    None,
                    "breathing in the same fighting stance, head and shoulders slightly lower, the red scarf still covering his nose and mouth",
                ],
            ),
            (
                "walk",
                [
                    "walking to the right, left leg stepping forward, right leg back",
                    "walking to the right, legs passing each other, feet together",
                    "walking to the right, right leg stepping forward, left leg back",
                    "walking to the right, legs passing each other, body slightly raised",
                ],
            ),
            (
                "attack",
                [
                    "winding up, the scimitar raised high behind his head",
                    "slashing down and forward with the scimitar, lunging on his front leg",
                    "follow-through after the slash, the scimitar pointing down in front of him, leaning forward",
                    "recovering back into his fighting stance",
                ],
            ),
            (
                "death",
                [
                    "recoiling backwards from a heavy hit, head thrown back",
                    "falling to his knees, the scimitar dropping from his hand",
                    "collapsing forward onto the ground",
                    "lying on his back on the ground, arms spread, the scimitar on the ground beside him",
                ],
            ),
        ],
    ),
    # NPC: дорослі, на 1,5 вищі за героя (D172) — клітинка 64×96 при його ж пікселі; дихання з двох кадрів.
    "blacksmith": dict(
        out="SampleProject/Assets/Characters/NPCs/blacksmith/sheet.png",
        prop=(
            "work",
            (34, 62, 64, 92),
            "SampleProject/Assets/Characters/NPCs/blacksmith/anvil.png",
        ),
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=5,
        colors=16,
        who="the same burly bearded blacksmith with the leather apron and the smithing hammer",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a burly bearded blacksmith, a tall adult man filling the whole height of the picture, with a leather apron "
        "over a dark shirt, rolled-up sleeves, thick forearms and a smithing hammer in his right hand, standing idle facing "
        "right. Keep the plain flat magenta background.",
        rows=[
            (
                "idle",
                [
                    None,
                    "breathing, chest and shoulders slightly lower, the hammer resting at his side",
                ],
            ),
            # BACKLOG 14 (D292): виходить із кузні — профіль у ході; на місці стоїть фасом (D243)
            ("walk", WALK),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing idle, both eyes visible, the full dark beard, "
                    "the leather apron over the dark shirt, rolled-up sleeves, the smithing hammer hanging in his right hand",
                    "BOB:56:front:0",
                ],
            ),
            # BACKLOG 5 (D295): кує біля ковадла — замах, удар, відскок; іскри — частинки в сцені
            (
                "work",
                [
                    SMITH_RAISE,
                    "FROM:work:0:his hammer arm lowered: the hammer head now level with his shoulder, halfway down to the "
                    "anvil, about to strike; the blade on the anvil still only glowing orange, no flames"
                    + SAME,
                    "FROM:work:0:the smithing hammer striking the glowing blade on the anvil, his arm swung straight "
                    "down" + SAME,
                ],
            ),
        ],
    ),
    "merchant": dict(
        out="SampleProject/Assets/Characters/NPCs/merchant/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=6,
        colors=16,
        who="the same cheerful desert merchant in the red turban and the yellow robe with the leather satchel",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a cheerful desert merchant, a tall adult man filling the whole height of the picture, in a red turban and a "
        "long yellow robe with a big leather satchel over his shoulder, holding a small scroll, standing idle facing right. "
        "Keep the plain flat magenta background.",
        rows=[
            (
                "idle",
                [None, "breathing, chest and shoulders slightly lower, the same smile"],
            ),
            ("walk", WALK),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing idle, both eyes visible, the red turban, "
                    "the long yellow robe, the big leather satchel on his hip, the small scroll in his hand",
                    "BOB:56:front:0",
                ],
            ),
            # BACKLOG 5 (D295): лічить монети — кидає в гаманець, підносить одну до очей
            (
                "work",
                [
                    MERCHANT_COUNT,
                    "FROM:work:0:dropping the gold coin from his right hand into the open purse, the coin in the air "
                    "between his hands" + SAME,
                    "FROM:work:0:his right hand raised, holding the gold coin up in front of his eyes to inspect it, a "
                    "satisfied smile" + SAME,
                ],
            ),
        ],
    ),
    # Хранителі клятв у місті (BACKLOG 22, D281): профіль — коли герой говорить із ними, фас — коли стоять (D243).
    "priest": dict(
        out="SampleProject/Assets/Characters/NPCs/priest/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=21,
        colors=16,
        who="the same serene priestess of the sky in the long white and pale-blue robes with gold trim, the white hood, "
        "the gold ring pendant and the slender white staff",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a serene priestess of the sky, a tall adult woman filling the whole height of the picture, in long white "
        "and pale-blue robes with gold trim, a white hood over her head, a gold ring pendant on her chest and a slender white "
        "staff topped with a small open gold ring held upright in her right hand. Strict side view: her head and body in "
        "profile facing right, her eye and nose on the right side of her face, looking ahead to the right. Keep the plain "
        "flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            (
                "front",
                [
                    "turned to face the viewer: a front view of her standing idle, both eyes visible, the white hood, the "
                    "gold ring pendant in the middle of her chest, the slender white staff upright in her hand",
                    "BOB:56:front:0",
                ],
            ),
            # BACKLOG 5 (D295): молиться Небу — схилена голова, потім долоні до неба
            (
                "work",
                [
                    PRIEST_PRAY,
                    "BOB:56:work:0",
                    "FROM:work:0:her face lifted up to the sky, eyes closed, both hands raised open in front of her face, "
                    "palms up, the staff still leaning against her shoulder" + SAME,
                    "BOB:56:work:2",
                ],
            ),
        ],
    ),
    "witch": dict(
        out="SampleProject/Assets/Characters/NPCs/witch/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=22,
        colors=16,
        who="the same witch with the wide-brimmed pointed dark purple hat, the long black hair, the dark violet dress, the "
        "tattered black shawl and the gnarled black wand with the violet crystal",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a mysterious witch, a tall adult woman filling the whole height of the picture, with a wide-brimmed pointed "
        "dark purple hat, long straight black hair, pale skin, a long dark violet dress with a tattered black shawl over her "
        "shoulders and a gnarled black wand with a small glowing violet crystal in her right hand. Strict side view: her head "
        "and body in profile facing right, her eye and nose on the right side of her face, looking ahead to the right. Keep "
        "the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            (
                "front",
                [
                    "turned to face the viewer: a front view of her standing idle, both eyes visible, the wide-brimmed "
                    "pointed dark purple hat, the long black hair on both sides of her face, the tattered black shawl, the "
                    "gnarled black wand with the violet crystal in her hand",
                    "BOB:56:front:0",
                ],
            ),
            # BACKLOG 5 (D295): читає гримуар — перегортає сторінку, торкається її паличкою
            (
                "work",
                [
                    WITCH_READ,
                    "FROM:work:0:turning a page of the open spell book with her right hand, the wand tucked under her "
                    "arm" + SAME,
                    "FROM:work:0:tapping the open spell book with the tip of her wand, the violet crystal glowing "
                    "brightly" + SAME,
                ],
            ),
        ],
    ),
    "dervish": dict(
        out="SampleProject/Assets/Characters/NPCs/dervish/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=23,
        colors=16,
        who="the same sand dervish with the very tall brimless cylindrical camel felt hat, the short dark beard, the long ochre robe with the "
        "wide flared skirt and the red sash",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a sand dervish, a tall lean adult man filling the whole height of the picture, with a very tall brimless "
        "cylindrical camel-coloured felt hat with no brim at all (like a tall fez without a tassel), a short dark beard, a long sand-and-ochre robe with a wide flared skirt, a red sash around his waist and "
        "bare feet, his hands folded calmly in front of him. Strict side view: his head and body in profile facing right, his "
        "eye and nose on the right side of his face, looking ahead to the right. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing idle, both eyes visible, the very tall "
                    "brimless cylindrical camel felt hat, the short dark beard, the red sash around his waist, the wide flared ochre "
                    "skirt, his hands folded in front of him",
                    "BOB:56:front:0",
                ],
            ),
            # BACKLOG 5 (D295): повільне кружляння дервіша (сема) — фас, профіль, спина, дзеркальний профіль
            (
                "work",
                [
                    DERVISH_WHIRL,
                    "FROM:work:0:the same whirling dance turned a quarter: now in strict side view facing right, his "
                    "right arm raised high, his left arm stretched out low, the flared skirt spinning out, the very tall "
                    "brimless felt hat",
                    "FROM:work:0:the same whirling dance seen from behind: his back to the viewer, his arms raised and "
                    "stretched the same way, the flared skirt spinning out, the very tall brimless felt hat",
                    "FLIP:work:1",
                ],
            ),
        ],
    ),
    # Дід — дід Кусакама, тож теж ящур (lore, Sapega 2026-10-19): той самий вид, що й герой, тільки старий.
    # Варта біля воріт міста (BACKLOG feedback 18): двоє стоять обабіч брами й дихають.
    "gate_guard": dict(
        out="SampleProject/Assets/Characters/NPCs/gate_guard/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=12,
        colors=16,
        who="the same desert city guard with the pointed steel helmet, the red tabard and the long spear",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a desert city gate guard, a tall adult man filling the whole height of the picture, with a pointed steel "
        "helmet wrapped in a white cloth, a short dark beard, a red tabard with a plain golden disc over a chain shirt, baggy "
        "sand-coloured trousers, a curved sword at his belt and a long spear held upright in his right hand, standing at "
        "attention facing right. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            # BACKLOG 5 (D295): варта переминається — озирається через плече, поправляє пов'язку шолома
            (
                "work",
                [
                    "only his head turned to look back to the left over his shoulder; his body, legs, sword and the "
                    "long upright spear exactly where they are now, the spear still on the left side of the picture"
                    + SAME,
                    "in the same side view facing right, shifting his weight onto one leg, his free left hand adjusting "
                    "the white cloth on his helmet, the long spear still upright in his right hand",
                ],
            ),
        ],
    ),
    "old_man": dict(
        out="SampleProject/Assets/Characters/NPCs/old_man/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=8,
        colors=16,
        who="the same old lizardfolk grandfather with the faded scales, the hooded brown robe and the walking staff",
        base="Change this character into his old grandfather: the same lizardfolk species with the same round head shape, big "
        "eyes and snout, but elderly — paler faded scales, droopy wrinkled eyelids, a slight hunch, a hooded brown robe and a "
        "gnarled wooden walking staff; taller than the reference character and filling the whole height of the picture; the same "
        "pixel art style, thick dark outline and flat shading; standing idle facing right. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:50"]),
            # BACKLOG 5 (D295): дід курить довгу люльку біля дверей і дрімає
            (
                "work",
                [
                    OLDMAN_PIPE,
                    "FROM:work:0:lowering the long pipe from his mouth to his chest, a small puff of grey smoke in front "
                    "of his snout" + SAME,
                    "FROM:work:0:the long pipe held at his chest, his head nodding down, eyes closed, dozing"
                    + SAME,
                ],
            ),
        ],
    ),
    # Уризен — жрець бога контрактів (lore). Два ракурси (Sapega): фас — стоїть у лабораторії й портрет, профіль —
    # біг (enter, ним же й тікає) і смайт монетою (strike, монети падають на кадрі 6). Листи — як у старих кадрів
    # (6/12/12 по 64 px, ступні на рядку 58): сцени й build_laboratory.gd ріжуть їх без змін. Повтор підказки —
    # той самий кадр з кешу (тримає позу довше). Референс Sapega (обличчя анфас) тягнув профіль у пів-оберта —
    # опис словами дав чистий профіль.
    "urizen": dict(
        rows_out="SampleProject/Assets/Characters/Companions/urizen",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=31,
        colors=16,
        floor=58,
        who="the same chubby bald priest with the thin dark iron circlet, the small forehead tattoo, the golden coin amulet, "
        "the dark tunic with a belt and the long brown hooded robe",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, thick "
        "dark outline and flat shading: a chubby bald human priest with a sly smile, a small dark tattoo on his forehead, a "
        "long brown robe over a dark tunic with a belt, a big round golden coin amulet on his chest and a thin dark iron "
        "circlet around his bald head. Strict side view: his head and body in profile facing right, his eye, nose and smile "
        "on the right side of his face, looking ahead to the right. Standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [URIZEN_FRONT] * 3 + ["BOB:45:idle:0"] * 3),
            (
                "enter",
                (
                    [URIZEN_STEP % ("left", "right")]
                    * 2  # A,A,N,B,B,N ×2: стоп-кадр між кроками
                    + [None]
                    + [STEP_B] * 2
                    + [None]
                )
                * 2,
            ),
            (
                "strike",
                [None]
                + [URIZEN_RAISE] * 2
                + [URIZEN_SMITE] * 6
                + [URIZEN_RAISE] * 2
                + [None],
            ),
        ],
    ),
    # Астрит — драконороджена варварка-тауматургиня з величезним шипастим щитом і книгою (lore): символи вогню. Як
    # Уризен — фас стоїть і портрет, профіль у русі. Листи старих розмірів: забіг (enter) і відхід (run) — той самий
    # біг, наскок щитом (strike) влучає на кадрі 5 (strike_frame).
    "astrit": dict(
        rows_out="SampleProject/Assets/Characters/Companions/astrit",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=43,
        colors=16,
        floor=58,
        who="the same fierce red-haired barbarian woman with the high ponytail and the red bow, the dark steel armour with red "
        "flame emblems, the huge round spiked shield with the flame emblem and the burning spell book",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, thick "
        "dark outline and flat shading: a fierce adult barbarian woman with fiery red hair in a high ponytail tied with a big "
        "red bow, amber eyes, dark steel plate armour with red flame emblems, a huge round spiked shield with a big "
        "red-and-gold flame emblem held in front of her, and her other hand wreathed in red fire holding a small spell book "
        "with a golden flame on its cover. Strict side view: her head and body in profile facing right, her eye and nose on "
        "the right side of her face, looking ahead to the right. Standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [ASTRIT_FRONT] * 3 + ["BOB:44:idle:0"] * 3),
            (
                "enter",
                (
                    [ASTRIT_STEP % ("left", "right")]
                    * 2  # A,A,N,B,B,N ×2: стоп-кадр між кроками
                    + [None]
                    + [STEP_B] * 2
                    + [None]
                )
                * 2,
            ),
            (
                "run",
                (
                    [ASTRIT_STEP % ("left", "right")]
                    * 2  # A,A,N,B,B,N ×2: стоп-кадр між кроками
                    + [None]
                    + [STEP_B] * 2
                    + [None]
                )
                * 2,
            ),
            (
                "strike",
                [ASTRIT_CROUCH] * 2
                + [ASTRIT_LEAP] * 3
                + [ASTRIT_SLAM] * 3
                + [ASTRIT_CROUCH] * 2
                + [None] * 2,
            ),
        ],
    ),
    # Алісия — мисливиця з кошеням-тигром (lore): очі різні, праве зелене, ліве синє (Sapega) — видно у фас. Обидві з
    # референсів Sapega (кандидати 2 і 2). Кадри — у пікселі героя (64 px ×1.5) замість кадрів з паку 128/48 px.
    "alisia": dict(
        rows_out="SampleProject/Assets/Characters/Companions/alisia",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        design="assets/references/companions/alisia_1_hunter.webp",
        seed=51,
        colors=24,  # 16 губили синє око (рідкісний колір)
        floor=58,
        who="the same silver-haired huntress with the high ponytail, the brown leather armour with gold trim, the fur collar, "
        "the dark cape and the wooden longbow",
        base=BASE_ALISIA,
        rows=[
            ("idle", [ALISIA_FRONT] * 3 + ["BOB:44:idle:0"] * 3),
            (
                "enter",
                ([ALISIA_STEP % ("left", "right")] * 2 + [None] + [STEP_B] * 2 + [None])
                * 2,
            ),
            # кішку посилає на кадрі 4 (strike_frame) — тятива щойно відпущена
            (
                "strike",
                [None, ALISIA_AIM, ALISIA_DRAW, ALISIA_DRAW]
                + [ALISIA_RELEASE] * 3
                + [ALISIA_AIM, None, None],
            ),
        ],
    ),
    "cat": dict(
        rows_out="SampleProject/Assets/Characters/Companions/cat",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=62,
        colors=16,
        floor=58,
        who="the same small creamy off-white tiger cub with brown stripes, blue eyes and glowing cyan spiral markings",
        base=BASE_CAT,
        rows=[
            ("idle", [CAT_FRONT] * 2 + ["BOB:48:idle:0"] * 2),
            (
                "run",
                [
                    CAT_RUN
                    % "stretched out mid-leap, front paws reaching forward, hind legs extended behind"
                ]
                * 3
                + [CAT_RUN % "body bunched together, all four paws gathered under it"]
                * 3,
            ),
            (
                "strike",
                # замах / удар витягнутою лапою (кадри 1–2, по ньому б'є pet_swipe_frame) / повернення
                [
                    CAT_SWIPE
                    % "winding up, crouched on its hind legs, one front paw drawn back with claws out",
                    CAT_SWIPE
                    % "swiping forward, one front paw fully extended straight ahead with claws out",
                    CAT_SWIPE
                    % "swiping forward, one front paw fully extended straight ahead with claws out",
                    CAT_SWIPE
                    % "recovering, the paw coming back down, standing on all four paws",
                ],
            ),
        ],
    ),
    # Нові кадри героя з його ж кадру художника (D239): Idle дихає, Jump/Fall, Roll, Climb — досі позичали біг і ходьбу.
    "hero_idle": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=11,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Idle",
                [None, "BOB:44", "BOB:30"],
            )  # BOB:30 — лише голова, проміжний кадр вдиху (feedback 20)
        ],  # модель розвертала героя й домальовувала хмарку подиху
    ),
    "hero_air": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=12,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Jump",
                [
                    "crouching with bent knees, about to jump",
                    "in the same side view facing right: jumping up, knees tucked, one arm raised, cape flowing down behind him",
                ],
            ),
            (
                "Fall",
                [
                    "falling down, legs dangling, arms raised above his head, cape flowing up"
                ],
            ),
        ],
    ),
    "hero_roll": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=13,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        # Клубок крутиться поворотами того самого кадру (модель ламала героя догори ногами й домальовувала колоду),
        # вихід — присід зі стрибка. Спершу hero_air.
        rows=[
            (
                "Roll",
                [
                    "ducking forward into a roll, head tucked, body low",
                    "curled into a tight ball rolling forward, cape wrapped around him",
                    "ROT:Roll:1:90",
                    "ROT:Roll:1:180",
                    "ROT:Roll:1:270",
                    "FILE:SampleProject/Sprites/Player/Jump/1.png",
                ],
            )
        ],
    ),
    "hero_climb": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=1,
        palette="hero",
        floor=56,  # як у кадрів художника: на драбині герой не просідає на 3 px
        who="the same small lizard knight seen from behind, with the steel armour, dark red cape and tail",
        base="Keep this exact character: the same small lizard knight with the same steel armour, red cape, tail and colours, the "
        "same pixel art style with a thick dark outline and flat shading. Change only his pose and view: climbing pose seen from "
        "behind, both arms raised high as if gripping a ladder rung above his head, one leg lifted; no ladder is drawn. Keep the "
        "plain flat magenta background.",
        rows=[
            (
                "Climb",
                [
                    None,
                    "the same climbing pose seen from behind, but the other leg lifted and the arms one rung lower",
                ],
            )
        ],
    ),
    # Плавніший стрибок (BACKLOG feedback 20): вершина стрибка, другий кадр падіння (плащ тріпоче), приземлення.
    # Старі кадри — FILE, щоб їх не перегенерувати.
    "hero_smooth": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=12,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Jump",
                [
                    "FILE:SampleProject/Sprites/Player/Jump/1.png",
                    "FILE:SampleProject/Sprites/Player/Jump/2.png",
                    "in the same side view facing right: at the very top of his jump, floating, both knees tucked up, "
                    "arms slightly spread, the cape floating out level behind him",
                ],
            ),
            (
                "Fall",
                [
                    "FILE:SampleProject/Sprites/Player/Fall/1.png",
                    "in the same side view facing right: falling down, legs dangling, arms raised above his head, "
                    "the cape fluttering up above him",
                ],
            ),
            (
                "Land",
                [
                    # з трьох кандидатів (низький присід / рука в землю / присід з нахилом) узято останній
                    "in the same side view facing right: absorbing the impact of a landing, squatting low with knees "
                    "bent wide and torso leaning forward, both arms hanging down in front, the cape falling down behind him",
                ],
            ),
        ],
    ),
    # Souls-lite бій (BACKLOG 4 + 15, D264): збій, важкий удар (замах і удар), блок. Кулаки порожні — зброю малює WeaponView.
    "hero_combat": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=21,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Hurt",
                [
                    "in the same side view facing right: recoiling from a hard hit to the chest, his body bent backwards, "
                    "head thrown back, eyes squeezed shut, both arms flung out, staggering back on one foot",
                ],
            ),
            (
                "Heavy",
                [
                    "in the same side view facing right: winding up a heavy overhead blow, both empty fists raised high "
                    "above his head, leaning back, knees bent, the cape hanging behind him",
                    "in the same side view facing right: finishing a heavy downward blow, crouched low and leaning far "
                    "forward, both empty fists swung down low in front of him at knee height, the cape flying up behind him",
                ],
            ),
            (
                "Block",
                [
                    "in the same side view facing right: guarding, both empty fists raised together in front of his face, "
                    "forearms up, crouched slightly and braced on bent knees, the cape hanging behind him",
                ],
            ),
        ],
    ),
    # Пози кастів навичок (BACKLOG 21, D271): замах і вивільнення для кожної активної навички; зброю малює WeaponView.
    "hero_cast": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=21,
        floor=56,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "CastPalm",
                [
                    "in the same side view facing right: standing still with his eyes closed, both open palms pressed "
                    "together in front of his chest as if praying, elbows out, calm, the cape hanging behind him",
                    "in the same side view facing right: one open palm pushed straight forward at chest height, fingers "
                    "up, the other hand resting at his hip, feet planted apart, eyes open, the cape hanging behind him",
                ],
            ),
            (
                "CastFire",
                [
                    "in the same side view facing right: crouched very low on bent knees, leaning forward, his front fist "
                    "drawn far back down behind his hip as if holding a sword low behind him, the other hand forward, "
                    "the cape hanging behind him",
                    "in the same side view facing right: a deep lunge forward, the front knee bent and the back leg "
                    "straight, his empty front fist swept forward and up to shoulder height at the end of a rising "
                    "slash, no weapon in his hands, the cape flying behind him",
                ],
            ),
            (
                "CastStorm",
                [
                    "in the same side view facing right, the same height and proportions: standing with his feet apart, "
                    "his empty front fist raised straight up above his head, the other fist clenched at his side, "
                    "looking ahead to the right, the cape hanging behind him",
                    "in the same side view facing right: stepping forward, one arm thrust straight forward at shoulder "
                    "height with the fist clenched, the other arm back, leaning into the thrust, the cape flying behind him",
                ],
            ),
        ],
    ),
    # Медитація на вершині скелі в каньйоні (Sapega 2026-10-20, BACKLOG feedback 8): сидить, дихає (BOB).
    "hero_meditate": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=14,
        floor=56,  # як у кадрів художника
        palette="hero",
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        base="Keep this exact character: the same small lizard knight with the same steel armour, red cape, tail and colours, "
        "the same pixel art style with a thick dark outline and flat shading, the same size. Change only his pose: in the "
        "same side view facing right, sitting cross-legged on the ground in a calm meditation pose, back straight, both "
        "hands resting on his knees, eyes closed, the cape and tail lying on the ground behind him. Keep the plain flat "
        "magenta background.",
        rows=[("Meditate", [None, "BOB:40"])],
    ),
    # Скриня (BACKLOG 33, арт A1): закрита, відкривається, відкрита; кадри — з закритої (FROM: тримає ту саму скриню).
    "chest": dict(
        frames_out="SampleProject/Assets/Props/Chest",  # кадри по теках, як у героя
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=41,
        colors=16,
        who="the same small wooden treasure chest with the dark iron bands, the iron corner plates and the small iron lock",
        base="Replace this character with a small wooden treasure chest drawn in exactly the same pixel art style, thick "
        "dark outline and flat shading: a sturdy chest of warm brown wooden planks with dark iron bands, iron corner plates "
        "and a small iron lock plate in the front, a rounded lid, about half as tall as the character was, standing on the "
        "ground at the bottom of the picture, closed, in a side view slightly from the front. Keep the plain flat magenta "
        "background.",
        rows=[
            ("Closed", [None]),
            (
                "Opening",
                [
                    # без «золотого сяйва»: модель фарбувала ним усю кришку, кути відкриття не відрізнялись
                    "FROM:Closed:0:the lid lifted open just a little at the front, a thin dark gap between the lid and "
                    "the chest body, the lid still the same brown wood with the iron bands, the chest body unchanged",
                    "FROM:Closed:0:the lid swung half open, tilted back on its hinges at the back of the chest, the dark "
                    "empty inside of the chest visible in the gap, the lid still brown wood with iron bands, the chest "
                    "body unchanged",
                    "FROM:Closed:0:the lid swung almost fully open, nearly upright on its hinges at the back of the "
                    "chest, the dark empty inside of the chest visible, the lid still brown wood with iron bands, the "
                    "chest body unchanged",
                ],
            ),
            (
                "Open",
                [
                    "FROM:Closed:0:the lid swung fully open and resting back on its hinges at the back, the inside of "
                    "the chest dark and empty, the chest body unchanged",
                ],
            ),
        ],
    ),
    # Герой піднімає знайдений предмет над головою (BACKLOG 33, арт A1); руки порожні — предмет малює код.
    "hero_raise": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=22,
        floor=56,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Raise",
                [
                    "in the same side view facing right: bending forward on slightly bent knees, both empty hands "
                    "reaching down and forward in front of him as if picking something up, the cape hanging behind him",
                    # кадр 2 (долоні чашею низько перед животом) не вдався за три спроби (арт-директор, artA1A2):
                    # руки під самою мордою, предмету нема місця, раз — фас. None з base=None — файл не пишеться
                    None,
                    # над головою — свій кадр, не Heavy/1 (замах атаки з плащем на вітрі); руки позаду голови, щоб
                    # обличчя не ховалось
                    "in the same side view facing right, the same size: standing straight with his feet planted apart, "
                    "both arms raised straight up behind his big head, his elbows behind the back of his head, his two "
                    "open empty hands meeting together just above the top of his head, his whole face, eye and snout "
                    "fully visible and uncovered, looking ahead to the right, the cape hanging straight down behind him",
                ],
            )
        ],
    ),
    # Герой з одноручним мечем у кадрі (BACKLOG 42, арт A3): клітинка 96x96 (меч виходить за 64x64), піксель — блок
    # 12, щоб картинка лишилась ~1,3 Мп; кадр художника 64x64 стоїть у ній з (16, 32), ступні на рядку 88 (= 56).
    # Бойові пози — з першого кадру (той самий меч), біг і стрибок — ON: з кадрів художника (модель лише додає меч).
    "hero_weapon_sword": dict(
        frames_out="SampleProject/Sprites/Player/Weapons/sword",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(96, 96),
        up=12,
        seed=52,
        floor=88,
        palette="hero",
        who="the same small lizard knight with the steel armour, dark red cape and tail, holding "
        + SWORD
        + ", exactly as small as in the picture, the top of his head below the middle of the picture",
        base=KEEP.format(
            who="the same small lizard knight with the steel armour, dark red cape and tail",
            pose="in the same side view facing right, the same size: standing in a combat stance with his feet apart "
            "and knees slightly bent, holding "
            + SWORD
            + " in his near hand at waist height, the blade pointing "
            "forward and up at an angle in front of him, his other fist raised near his chest, the cape hanging "
            "behind him. " + SWORD_SIZE,
        ),
        rows=[
            ("CombatIdle", [None, "BOB:76", "BOB:76", None]),
            (
                "Run",
                # кадри 1–2 модель темнила (броня й плащ майже чорні) — кольори названо; кадр 2 темний і після трьох спроб — без нього
                [
                    SWORD_ON % ("Run/%d" % n, "forward and up")
                    + (SWORD_COLOURS if n == 1 else "")
                    for n in (1, 3, 4, 5, 6, 7, 8)
                ],
            ),
            (
                "Air",
                [
                    SWORD_ON % ("Jump/2", "forward and up"),
                    SWORD_ON % ("Jump/3", "forward and up"),
                    SWORD_ON % ("Fall/2", "forward and up"),
                ],
            ),
            (
                "Attack1",
                [
                    "in the same side view facing right: winding up a downward slash, the sword raised high above and "
                    "behind his head in his near hand, the blade pointing back, leaning back slightly, knees bent, the "
                    "cape hanging behind him, no motion lines or sparkles",
                    "in the same side view facing right: slashing down, his sword arm swung forward at shoulder height, "
                    "the sword held straight out in front of him pointing forward, stepping forward on his front leg, "
                    "the cape flying behind him",
                    "in the same side view facing right: the end of a downward slash, leaning forward on his bent front "
                    "leg, the sword swung down low in front of him, the blade pointing down and forward, its tip just "
                    "above the ground, the cape flying behind him",
                ],
            ),
            (
                "Attack2",
                [
                    "in the same side view facing right: winding up a rising slash, crouched on bent knees, the sword "
                    "drawn back low behind his hip, the blade pointing back and down, the cape hanging behind him",
                    "in the same side view facing right: a rising slash, stepping forward, the sword swung forward and "
                    "up at chest height, the blade pointing forward and up, the cape flying behind him",
                    "in the same side view facing right: the end of a rising slash, standing tall, his sword arm "
                    "stretched high above his head, the blade pointing straight up, the cape flying behind him",
                ],
            ),
            (
                "Attack3",
                [
                    "in the same side view facing right: winding up a big finishing slash, his body twisted back, the "
                    "sword drawn far back behind his head, the blade pointing back horizontally behind him, his weight "
                    "on the back leg, the cape hanging behind him",
                    "in the same side view facing right: a wide horizontal slash, lunging deep on his bent front leg, "
                    "the back leg straight, his sword arm fully extended straight forward at shoulder height, the blade "
                    "pointing straight ahead, the cape flying behind him",
                    "in the same side view facing right: the follow-through of a big slash, crouched low and leaning "
                    "forward, the sword swept down in front of him, the blade pointing down near his front foot, the "
                    "cape flying up behind him",
                ],
            ),
            (
                "Heavy",
                [
                    # з самого кадру Attack1/1: замах «з нуля» малював удвічі товстіший і довший меч (арт-директор)
                    "FROM:Attack1:0:the same pose, now his second hand also gripping the hilt just below the first, "
                    "both hands together on the hilt raised above his head; the sword itself exactly the same short "
                    "narrow sword as in the picture, the same thin blade, the same length, the same small cross-guard, "
                    "not bigger, not wider; leaning back, knees bent, the cape hanging behind him",
                    "in the same side view facing right: swinging a heavy blow down, both hands gripping the sword hilt "
                    "in front of his face, the blade pointing forward and up, stepping forward, the cape flying behind "
                    "him",
                    "in the same side view facing right: finishing a heavy downward blow, crouched low and leaning far "
                    "forward, both hands gripping the sword hilt low in front of him, the blade pointing down, its tip "
                    "on the ground in front of his feet, the cape flying up behind him",
                ],
            ),
            (
                "Block",
                [
                    "in the same side view facing right: guarding, crouched and braced on bent knees, the sword held "
                    "upright in front of his face, the blade pointing straight up, his other hand pressed against the "
                    "flat of the blade, the cape hanging behind him",
                ],
            ),
            (
                "Hurt",
                [
                    "in the same side view facing right: recoiling from a hard hit to the chest, his body bent "
                    "backwards, head thrown back, eyes squeezed shut, his sword arm flung back behind him still holding "
                    "the sword, staggering back on one foot",
                ],
            ),
        ],
    ),
    "hero_weapon_dagger": dict(
        frames_out="SampleProject/Sprites/Player/Weapons/dagger",
        ref="SampleProject/Sprites/Player/Weapons/sword/CombatIdle/1.png",
        cell=(96, 96),
        up=12,
        seed=52,
        floor=88,
        palette="hero",
        who="the same small lizard knight with the steel armour, dark red cape and tail, holding "
        + DAGGER
        + ", exactly as small as in the picture",
        base="Keep this exact character — the same small lizard knight with the steel armour, dark red cape and tail, "
        "the same pixel art style, thick dark outline, flat shading, colours, size, pose and position. Change only "
        "the weapon: the long sword in his hand replaced by "
        + DAGGER
        + ", held low in front of his waist in the same hand, the short blade pointing forward and up; no sword. "
        "Keep the plain flat magenta background.",
        rows=[
            ("CombatIdle", [None, "BOB:76", "BOB:76", None]),
            # Run/2 художника пропущено, як у меча (7 кадрів)
            ("Run", [DAGGER_ON % ("Run/%d" % n, "forward and up") for n in (1, 3, 4, 5, 6, 7, 8)]),
            (
                "Air",
                [DAGGER_ON % (f, "forward and up") for f in ("Jump/2", "Jump/3")]
                # Fall/2 «вперед і вгору» — кривий клинок і зім'ятий плащ
                + [DAGGER_ON % ("Fall/2", "straight forward, a straight blade") + ", his head in profile facing right"],
            ),
            (
                "Attack1",
                [
                    "in the same side view facing right: drawing back for a quick stab, the dagger pulled back beside "
                    "his hip in his near hand, the short blade pointing forward, elbow bent back, knees bent, the cape "
                    "hanging behind him",
                    "in the same side view facing right: a quick straight stab, his dagger arm thrust straight forward "
                    "at chest height, the short blade pointing straight ahead, stepping forward on his front leg, the "
                    "cape flying behind him",
                    "in the same side view facing right: pulling back after a stab, the dagger drawn back in front of "
                    "his chest, the short blade pointing forward, standing on bent knees, the cape hanging behind him",
                ],
            ),
            (
                "Attack2",
                [
                    "in the same side view facing right: crouched low on bent knees, the dagger held low beside his "
                    "knee in his near hand, the short blade pointing forward and up, the cape hanging behind him",
                    # Attack2/2-3 пропущено (арт-директор, D-батч dagger): за три спроби кожного (FROM:Attack2:0 — кинджал
                    # над головою прямим і зворотним хватом) модель малювала меч ~20 px з широкою гардою
                ],
            ),
            (
                "Attack3",
                [
                    "FROM:Attack1:0:coiled for a lunging stab, leaning back with his weight on the bent back leg, the "
                    "dagger pulled further back behind his hip, the blade pointing forward, his other hand stretched "
                    "forward, the cape hanging behind him"
                    + DAGGER_KEEP,
                    "in the same side view facing right: a deep lunging stab, lunging far on his bent front leg, the "
                    "back leg straight, his dagger arm fully extended straight forward at chest height, the short blade "
                    "pointing straight ahead, the cape flying behind him",
                    "FROM:Attack3:1:recovering after the lunge, knees bent, the same short dagger pulled back close "
                    "in front of his hip, the short blade pointing forward and a little down, its tip at the height of "
                    "his knees, far above his feet, the blade the same length as in the picture, the cape flying "
                    "behind him"
                    + DAGGER_KEEP,
                ],
            ),
            # Heavy пропущено: за три спроби (з першого кадру, FROM:Attack1:0, FROM:Attack2:2) модель малювала
            # другий кинджал або меч-завдовжки лезо (список пропущених — у README кинджала)
            (
                "Block",
                [
                    "in the same side view facing right: guarding, crouched and braced on bent knees, the dagger held "
                    "crosswise in front of his face, the short blade pointing forward and up, his other forearm raised "
                    "beside it, the cape hanging behind him"
                    + DAGGER_SHORT,
                ],
            ),
            (
                "Hurt",
                [
                    "in the same side view facing right: recoiling from a hard hit to the chest, his body bent "
                    "backwards, head thrown back, eyes squeezed shut, his dagger arm flung back behind him still "
                    "holding the dagger, staggering back on one foot"
                    + DAGGER_SHORT,
                ],
            ),
        ],
    ),
    "hero_weapon_mace": dict(
        frames_out="SampleProject/Sprites/Player/Weapons/mace",
        ref="SampleProject/Sprites/Player/Weapons/sword/CombatIdle/1.png",
        cell=(96, 96),
        up=12,
        seed=52,
        floor=88,
        palette="hero",
        who="the same small lizard knight with the steel armour, dark red cape and tail, holding "
        + MACE
        + ", exactly as small as in the picture",
        base="Keep this exact character — the same small lizard knight with the steel armour, dark red cape and tail, "
        "the same pixel art style, thick dark outline, flat shading, colours, size, pose and position. Change only "
        "the weapon: the long sword in his hand replaced by "
        + MACE
        # ще дві спроби («коротке руків'я», «удвічі коротша за меч») малювали молот — лишено першу, з круглою головою
        + ", held at his waist in the same hand, the handle pointing forward and up with the round head at its top "
        "end; no sword, no blade. Keep the plain flat magenta background.",
        rows=[
            ("CombatIdle", [None, "BOB:76", "BOB:76", None]),
            # Run/2 художника пропущено, як у меча (7 кадрів)
            ("Run", [MACE_ON % ("Run/%d" % n, "forward and up") for n in (1, 3, 4, 5, 6, 7, 8)]),
            # Air/2 і Air/3 — гладка куля й плащ художника (арт-директор: Air/2 мав червону пляму замість плаща)
            ("Air", [MACE_ON % ("Jump/2", "forward and up")] + [MACE_BALL_ON % (f, "forward and up") for f in ("Jump/3", "Fall/2")]),
            (
                "Attack1",
                [
                    # з самого базового кадру двічі вийшло не те (кувалда й велетень; герой обернувся ліворуч)
                    "FROM:CombatIdle:0:in the same side view facing right, his face and snout still pointing right: "
                    "winding up an overhead smash, his mace arm raised up beside his head, the mace held up behind "
                    "his head, the round head above and behind his head, standing on bent knees, the cape hanging "
                    "behind him" + MACE_KEEP,
                    "in the same side view facing right: smashing down, his mace arm swung forward at shoulder "
                    "height, the mace held out in front of him, the round head forward, stepping forward on his "
                    "front leg, the cape flying behind him" + MACE_KEEP,
                    "in the same side view facing right: the end of an overhead smash, leaning forward on his bent "
                    "front leg, the mace swung down low in front of him, its round head just above the ground in "
                    "front of his front foot, the cape flying behind him" + MACE_KEEP,
                ],
            ),
            (
                "Attack2",
                [
                    "in the same side view facing right: winding up a rising swing, crouched on bent knees, the mace "
                    "drawn back low behind his hip, the round head pointing back and down, the cape hanging behind "
                    "him" + MACE_KEEP,
                    "in the same side view facing right: a rising swing, stepping forward, the mace swung forward and "
                    "up at chest height, the round head forward and up, the cape flying behind him" + MACE_KEEP,
                    "in the same side view facing right: the end of a rising swing, standing tall, his mace arm "
                    "stretched high above his head, the round head pointing straight up, the cape flying behind him"
                    + MACE_KEEP,
                ],
            ),
            (
                "Attack3",
                [
                    "in the same side view facing right: winding up a big finishing smash, his body twisted back, the "
                    "mace drawn far back behind his head, his weight on the back leg, the cape hanging behind him"
                    + MACE_KEEP,
                    "in the same side view facing right: a big smash, lunging deep on his bent front leg, the back "
                    "leg straight, his mace arm fully extended straight forward at shoulder height, the round head "
                    "straight ahead, the cape flying behind him" + MACE_KEEP,
                    "in the same side view facing right: the follow-through of a big smash, crouched low and leaning "
                    "forward, the mace slammed down in front of him, its round head on the ground near his front "
                    "foot, the cape flying up behind him" + MACE_KEEP,
                ],
            ),
            (
                "Heavy",
                [
                    # з першого кадру герой обертався ліворуч — з Attack1/1, як у меча
                    # арт-директор: перший варіант був копією Attack1/1 — тепер обидві руки й замах за голову
                    "FROM:Attack1:0:the same side view facing right, his face and snout still pointing right: a "
                    "two-handed overhead wind-up, leaning back, both hands gripping the mace handle above and behind "
                    "his head, both elbows raised high, the round head hanging far behind his back, the steel armour "
                    "plates on his chest drawn as in the picture, knees bent, the cape hanging behind him" + MACE_KEEP,
                    "in the same side view facing right: swinging a heavy blow down, both hands gripping the mace "
                    "handle in front of his face, the round head forward and up, stepping forward, the cape flying "
                    "behind him" + MACE_KEEP,
                    # арт-директор: руків'я виходило за руки до хвоста — з Heavy/2, де руків'я коротке
                    "FROM:Heavy:1:in the same side view facing right: the end of a heavy downward blow, crouched low "
                    "and leaning forward, both hands together at the bottom end of the short handle, the mace swung "
                    "down in front of him, its round head on the ground in front of his front foot, nothing sticking "
                    "out behind his hands, his tail curled on the ground behind him, the cape flying up behind him, no "
                    "motion lines, no dust" + MACE_KEEP,
                ],
            ),
            (
                "Block",
                [
                    "in the same side view facing right: guarding, crouched and braced on bent knees, the mace held "
                    "upright in front of his face, the round head at the top, his other forearm raised beside it, "
                    "the cape hanging behind him" + MACE_KEEP,
                ],
            ),
            (
                "Hurt",
                [
                    "in the same side view facing right: recoiling from a hard hit to the chest, his body bent "
                    "backwards, head thrown back, eyes squeezed shut, his mace arm flung back behind him still "
                    "holding the mace, staggering back on one foot" + MACE_KEEP,
                ],
            ),
        ],
    ),
    # Алебарда (BACKLOG 42, A3, D267): дворучна — уколи вперед і низький мах, обидві руки на древку; клітинка й
    # лінія ніг як у меча (96x96, ступні на рядку 88); біг і стрибок — з кадрів художника (несе в одній руці)
    "hero_weapon_halberd": dict(
        frames_out="SampleProject/Sprites/Player/Weapons/halberd",
        ref="SampleProject/Sprites/Player/Weapons/sword/CombatIdle/1.png",
        cell=(96, 96),
        up=12,
        seed=52,
        floor=88,
        palette="hero",
        who="the same small lizard knight with the steel armour, dark red cape and tail, holding "
        + HALBERD
        + ", exactly as small as in the picture",
        base="Keep this exact character — the same small lizard knight with the steel armour, dark red cape and tail, "
        "the same pixel art style, thick dark outline, flat shading, colours, size, pose and position. Change only "
        "the weapon: the sword in his hand replaced by "
        + HALBERD
        + ", held with both hands on the pole at waist height like a pike, the pole pointing forward and a little up, "
        "the axe blade and spear point far in front of him, the bottom end of the pole behind his hip; no sword. "
        "Keep the plain flat magenta background.",
        rows=[
            ("CombatIdle", [None, "BOB:76", "BOB:76", None]),
            # Run/2 художника пропущено, як у меча (7 кадрів)
            # Run/5 з першої спроби — друга зброя (спис) у задній руці; названо «одна алебарда»
            (
                "Run",
                [
                    HALBERD_ON % ("Run/%d" % n, "forward and up")
                    + ("; exactly one halberd held in one hand, no spear, his other hand empty" if n == 5 else "")
                    for n in (1, 3, 4, 5, 6, 7, 8)
                ],
            ),
            # Air/1-2: алебарда лягає через плече головою назад (у стилі); з HALBERD_AIR модель двічі надягала шолом
            ("Air", [HALBERD_ON % (f, "forward and up") for f in ("Jump/2", "Jump/3")] + [HALBERD_AIR % "Fall/2"]),
            (
                "Attack1",
                [
                    "FROM:CombatIdle:0:in the same side view facing right: drawing back for a thrust, leaning back "
                    "with his weight on the back leg, knees bent, both hands pulled back to his hip holding the "
                    "halberd pointing forward and a little up, its steel head on the right in front of his face, the "
                    "bottom end of the pole on the left behind his back, the cape hanging behind him" + HALBERD_LEVEL,
                    "FROM:CombatIdle:0:in the same side view facing right, the same size: a straight thrust, leaning forward, "
                    "both arms pushed forward holding the halberd pointing forward and a little up, its steel head far "
                    "out on the right in front of him, the bottom end of the pole at his hip, stepping forward on his "
                    "front leg, the cape flying behind him" + HALBERD_LEVEL,
                    "FROM:CombatIdle:0:in the same side view facing right: pulling back after the thrust, the halberd "
                    "held in both hands in front of his chest pointing forward and a little up, its steel head on the "
                    "right in front of him, the bottom end of the pole on the left behind him, standing on bent knees, "
                    "the cape hanging behind him" + HALBERD_LEVEL,
                ],
            ),
            (
                "Attack2",
                [
                    # з першого кадру низька алебарда ставала великою подвійною сокирою — з Attack1/3 (та сама голова)
                    "FROM:Attack1:2:winding up a low sweep, crouched on bent knees, both hands on the pole at his hip, "
                    "the halberd lowered to point forward and down, its steel head on the right low in front of his "
                    "feet" + HALBERD_LOW,
                    "FROM:Attack2:0:a low sweep, crouched low and stepping forward, both hands on the pole at his hip, "
                    "the halberd lowered to point straight forward just above the ground, its steel head far out on "
                    "the right, the cape flying behind him" + HALBERD_LOW,
                    "FROM:Attack2:0:the end of a low sweep, leaning forward on his bent front leg, both hands on the "
                    "pole, the halberd pointing forward and down, its steel head on the right just above the ground "
                    "in front of his front foot, the cape flying behind him" + HALBERD_LOW,
                ],
            ),
            (
                "Attack3",
                [
                    # з першого кадру голова виходила більшою подвійною сокирою — з кадрів, де вона вже вдала
                    "FROM:Attack1:0:coiled for a big lunging thrust, crouched lower on bent knees, leaning further "
                    "back, both hands pulled back to his hip, the halberd pointing forward and up, the cape hanging "
                    "behind him" + HALBERD_LEVEL + "; the same small halberd head as in the picture, not bigger",
                    "FROM:Attack2:0:a deep lunging thrust, lunging far on his bent front leg, the back leg straight, "
                    "both arms stretched forward on the pole, the halberd raised to point straight forward at chest "
                    "height, its steel head far out on the right, the cape flying behind him" + HALBERD_LOW,
                    "FROM:Attack2:0:recovering after the lunge, standing up on bent knees, both hands on the pole at "
                    "his waist, the halberd pointing forward and a little down, its steel head on the right at the "
                    "height of his knees, the cape hanging behind him" + HALBERD_LOW,
                ],
            ),
            (
                "Heavy",
                [
                    # з першого кадру — друга голова героя під лезом; з Attack1/1 (нахил назад, та сама алебарда)
                    "FROM:Attack1:0:his face and snout still pointing right, only one head: a two-handed overhead "
                    "wind-up, leaning further back, both hands raised up beside his head gripping the pole, the "
                    "halberd tilted back over his shoulder, its steel head high above and behind the back of his "
                    "head, knees bent, the cape hanging behind him" + HALBERD_KEEP,
                    "FROM:CombatIdle:0:in the same side view facing right: chopping a heavy blow down, both hands "
                    "gripping the pole in front of his face, the halberd pointing forward and up, its steel head on "
                    "the right high in front of him, stepping forward, the cape flying behind him" + HALBERD_LEVEL,
                    "FROM:CombatIdle:0:in the same side view facing right: the end of a heavy downward chop, crouched "
                    "low and leaning forward, both hands on the pole, the halberd pointing forward and down, its steel "
                    "head on the right resting on the ground far in front of his front foot, the cape flying up "
                    "behind him" + HALBERD_LEVEL,
                ],
            ),
            (
                "Block",
                [
                    # «тримає древко вертикально» малювало дві алебарди — та сама поза, лише нижче й ближче
                    "FROM:CombatIdle:0:in the same side view facing right: the same pose, now guarding: crouched "
                    "lower and braced on bent knees, the same single halberd pulled close so its pole stands almost "
                    "upright right in front of his chest, both hands on it, its steel head above his head, his face "
                    "in profile with the same big round eye, the cape hanging behind him; exactly one halberd and "
                    "nothing else in his hands" + HALBERD_KEEP,
                ],
            ),
            (
                "Hurt",
                [
                    # перша спроба — дві алебарди й обличчя анфас
                    "FROM:CombatIdle:0:in the same side view facing right: recoiling from a hard hit to the chest, "
                    "his body leaning backwards, his head tipped back with the eye squeezed shut, his face still in "
                    "profile pointing right, the same single halberd still in both hands tilted back over his "
                    "shoulder, staggering back on one foot, the cape hanging behind him; exactly one halberd"
                    + HALBERD_KEEP,
                ],
            ),
        ],
    ),
    # Зала мера й лабораторія (BACKLOG 16 + 17, D301-D305, D309): боси вищі за героя (клітинка 96x112), профіль
    # (вони б'ються); Малік - профіль у ході й фас у розмові (D243); в'язень і алхімік - лише профіль.
    "brass_collector": dict(
        out="SampleProject/Assets/Characters/Bosses/brass_collector/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(96, 112),
        seed=31,
        colors=16,
        who="the same huge brass and sandstone golem with the glowing amber eye slits, the long heavy brass arms and "
        "the barred iron cage on its back",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a huge hulking golem built of riveted brass plates and cracked sandstone blocks, much taller than the "
        "reference character and filling the whole height of the picture, broad shoulders, long heavy arms with big brass "
        "fists hanging to its knees, a small head with two glowing amber eye slits, a barred iron cage strapped to its back. "
        "Strict side view: its head and body in profile facing right, standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:62"]),
            (
                "walk",
                [
                    "stomping heavily to the right in the same side view facing right, its left leg stepping forward and "
                    "its right leg back, the long arms swinging",
                    "stomping heavily to the right in the same side view facing right, both legs together under its body",
                    "stomping heavily to the right in the same side view facing right, its right leg stepping forward and "
                    "its left leg back, the long arms swinging",
                    "stomping heavily to the right in the same side view facing right, both legs together under its body",
                ],
            ),
            (
                "attack",
                [
                    "in the same side view facing right: winding up, its right brass fist raised high behind its shoulder, "
                    "leaning back",
                    "in the same side view facing right: its huge right arm swung forward and down, the brass fist thrust "
                    "out in front of its chest; no motion trail, no swoosh line",
                    "in the same side view facing right: follow-through, its brass fist low in front of it near the ground, "
                    "leaning forward",
                    "in the same side view facing right: straightening up again, the fist coming back to its side",
                ],
            ),
            (
                "charge",
                [
                    "in the same side view facing right: lowering its head and shoulders, leaning far forward, ready to "
                    "charge, the arms pulled back",
                    "in the same side view facing right: charging forward at full speed, leaning forward shoulder first, "
                    "one leg stretched far behind",
                ],
            ),
            (
                "slam",
                [
                    "in the same side view facing right: both huge brass fists raised high above its head, about to "
                    "smash the ground, both feet planted, nothing else on the ground",
                    "in the same side view facing right: crouching low, both brass fists smashed down onto the ground in "
                    "front of it",
                ],
            ),
            (
                "death",
                [
                    "in the same side view facing right: staggering backwards, bright cracks across its brass chest",
                    "in the same side view facing right: fallen to its knees, its arms hanging limp, the eye slits dim",
                    "lying on its back on the ground, broken, the iron cage crushed beside it, the eye slits dark",
                ],
            ),
        ],
    ),
    "fire_djinn": dict(
        out="SampleProject/Assets/Characters/Bosses/fire_djinn/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(96, 112),
        seed=33,
        colors=16,
        who="the same fire djinn with red-orange skin, burning flame hair rising like horns, glowing yellow eyes, golden "
        "arm bands and the swirling smoke-and-flame tail instead of legs",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a fearsome fire djinn, a tall muscular spirit with red-orange skin, burning flame hair rising like two "
        "horns, glowing yellow eyes, golden bands on his wrists and upper arms, a bare chest, his body tapering below the "
        "waist into a long tail of dark smoke and flame instead of legs that trails straight down to the bottom edge, "
        "floating; he is big and fills the whole height of the picture from the top edge to the bottom edge. Strict side view: his head and body in profile facing right, his eye on the right side of his face, "
        "arms crossed. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:50"]),
            (
                "attack",
                [
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: drawing his right clawed hand back behind his shoulder, fingers "
                    "spread like claws",
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: slashing forward with his right claws in a wide swipe",
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: slashing forward with his left claws, leaning into the blow",
                ],
            ),
            (
                "cast",
                [
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: both hands raised above his head, a ball of fire glowing between "
                    "his palms",
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: both palms thrust forward in front of his chest, his hands "
                    "blazing with fire",
                ],
            ),
            (
                "fly",
                [
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: flying upward, both arms raised above his head, the flame tail "
                    "streaming straight down below him"
                ],
            ),
            (
                "death",
                [
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: recoiling, clutching his chest, his flames dim and flickering",
                    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging straight down; the whole body in the picture, the same size, in the same side view facing right: his body crumbling into glowing embers and grey smoke, fading",
                ],
            ),
        ],
    ),
    "malik": dict(
        out="SampleProject/Assets/Characters/NPCs/malik/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=35,
        colors=16,
        who="the same portly desert merchant in the torn purple silk robe with gold embroidery, the small white turban, "
        "the trimmed black beard, the gold rings and the iron shackle on his wrist",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a portly middle-aged desert merchant, a tall adult man filling the whole height of the picture, a stained "
        "and torn deep purple silk robe with gold embroidery, a small white turban, a neatly trimmed black beard, gold rings "
        "on his fingers, an iron shackle with a broken chain on his left wrist, a sly ingratiating smile, his hands clasped "
        "together. Strict side view: his head and body in profile facing right. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            ("walk", WALK),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing, both eyes visible, a wide sly smile, the small "
                    "white turban, the torn purple robe with gold embroidery, his hands spread welcomingly, the iron shackle "
                    "on his wrist",
                    "BOB:56:front:0",
                ],
            ),
        ],
    ),
    "prisoner": dict(
        out="SampleProject/Assets/Characters/NPCs/prisoner/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=37,
        colors=16,
        who="the same gaunt bandit prisoner in ragged sand-coloured clothes with the dirty red neck scarf, the unkempt "
        "black hair and the chained iron shackles on both wrists",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a gaunt desert bandit prisoner, a tall adult man filling the whole height of the picture, ragged torn "
        "sand-coloured clothes, a dirty red scarf around his neck, unkempt black hair and stubble, wild eyes, iron shackles "
        "on both wrists joined by a short chain, barefoot, standing hunched. Strict side view: his head and body in "
        "profile facing right. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            ("walk", WALK),
            (
                "shout",
                [
                    "in the same side view facing right: throwing his head back and shouting up at the ceiling, his "
                    "chained arms raised high, his mouth wide open"
                ],
            ),
            (
                "collapse",
                [
                    "lying on his back on the ground, motionless, the chains across his chest"
                ],
            ),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing hunched, both wild eyes visible, the unkempt "
                    "black hair and stubble, the dirty red scarf around his neck, the ragged sand-coloured clothes, the iron "
                    "shackles on both wrists joined by a short chain, barefoot",
                    "BOB:56:front:0",
                ],
            ),
        ],
    ),
    "alchemist": dict(
        out="SampleProject/Assets/Characters/NPCs/alchemist/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=39,
        colors=16,
        who="the same thin laboratory alchemist in the long stained grey-green coat, the leather apron, the round brass "
        "goggles, the black cloth mask over his mouth and the big glass syringe",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a cold laboratory alchemist, a tall thin adult man filling the whole height of the picture, a long stained "
        "grey-green coat over dark clothes, a leather apron, round brass goggles over his eyes, a black cloth mask over his "
        "mouth and nose, dark gloves, a big glass syringe with green liquid in his right hand. Strict side view: his head and "
        "body in profile facing right, standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [None, "BOB:56"]),
            ("walk", WALK),
            (
                "inject",
                [
                    "in the same side view facing right: thrusting the big glass syringe forward and down in front of "
                    "him with his right hand, injecting, the black mask still over his mouth"
                ],
            ),
            (
                "front",
                [
                    "turned to face the viewer: a front view of him standing idle, the round brass goggles over both eyes, the "
                    "black cloth mask over his mouth and nose, the long stained grey-green coat, the leather apron, dark "
                    "gloves, the big glass syringe with green liquid in his right hand",
                    "BOB:56:front:0",
                ],
            ),
        ],
    ),
}


def edit_graph(text, seed, ref_name, megapixels, design_name=None):
    def node(c, **i):
        return {"class_type": c, "inputs": i}

    g = {
        "unet": node("UnetLoaderGGUF", unet_name="qwen-image-edit-2511-Q5_K_M.gguf"),
        "clip": node(
            "CLIPLoader",
            clip_name="qwen_2.5_vl_7b_fp8_scaled.safetensors",
            type="qwen_image",
            device="default",
        ),
        "vae": node("VAELoader", vae_name="qwen_image_vae.safetensors"),
        "lora": node(
            "LoraLoaderModelOnly",
            model=["unet", 0],
            lora_name="Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
            strength_model=1.0,
        ),
        "shift": node("ModelSamplingAuraFlow", model=["lora", 0], shift=3.1),
        "model": node("CFGNorm", model=["shift", 0], strength=1.0),
        "ref": node("LoadImage", image=ref_name),
        "scaled": node(
            "ImageScaleToTotalPixels",
            image=["ref", 0],
            upscale_method="nearest-exact",
            megapixels=megapixels,  # = розмір референсу: блоки 16×16 не перемасштабовуються
            resolution_steps=16,
        ),
        "pos": node(
            "TextEncodeQwenImageEditPlus",
            clip=["clip", 0],
            prompt=text,
            vae=["vae", 0],
            image1=["scaled", 0],
        ),
        "neg": node(
            "TextEncodeQwenImageEditPlus",
            clip=["clip", 0],
            prompt="",
            vae=["vae", 0],
            image1=["scaled", 0],
        ),
        "latent": node("VAEEncode", pixels=["scaled", 0], vae=["vae", 0]),
        "sample": node(
            "KSampler",
            model=["model", 0],
            positive=["pos", 0],
            negative=["neg", 0],
            latent_image=["latent", 0],
            seed=seed,
            steps=4,
            cfg=1.0,
            sampler_name="euler",
            scheduler="simple",
            denoise=1.0,
        ),
        "decode": node("VAEDecode", samples=["sample", 0], vae=["vae", 0]),
        "save": node(
            "SaveImage", images=["decode", 0], filename_prefix="kusakam/sprite"
        ),
    }
    if design_name:
        g["design"] = node("LoadImage", image=design_name)
        g["design_scaled"] = node(
            "ImageScaleToTotalPixels",
            image=["design", 0],
            upscale_method="lanczos",
            megapixels=1.0,
            resolution_steps=16,
        )
        for k in ("pos", "neg"):
            g[k]["inputs"]["image2"] = ["design_scaled", 0]
    return g


def enlarge(path, cell):
    """Кадр героя знизу посередині клітинки cell на пурпурі, ×16 найближчим сусідом — для моделі. Вища клітинка —
    для дорослих NPC (D172: на 1,5 вищі за героя) при тому ж пікселі."""
    ref = Image.open(path).convert("RGBA")
    canvas = Image.new("RGBA", cell, MAGENTA + (255,))
    canvas.alpha_composite(ref, ((cell[0] - ref.width) // 2, cell[1] - ref.height))
    return np.asarray(canvas.resize((cell[0] * UP, cell[1] * UP), Image.NEAREST))


GENERATED, MAX_NEW = 0, int(os.environ.get("COMFY_MAX", "1000"))


def free():
    urllib.request.urlopen(
        urllib.request.Request(
            API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def edit(ref_rgba, text, seed, design=None):
    """Редагування з кешем: той самий референс, підказка й зерно — та сама картинка без моделі. design — шлях до
    картинки з дизайном персонажа (референс Sapega): друга картинка моделі, перша — стиль героя й полотно."""
    extra = open(design, "rb").read() if design else b""
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode() + extra
    ).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".png")
    if not os.path.exists(path):
        global GENERATED
        if GENERATED >= MAX_NEW:  # COMFY_MAX=4: не більше 4 картинок за запуск (ОЗП), решта — наступним запуском
            free()
            sys.exit(f"{MAX_NEW} new images generated — run again for the rest")
        GENERATED += 1
        name = upload(ref_rgba, "sprite_ref.png")
        design_name = (
            upload(np.asarray(Image.open(design).convert("RGBA")), "sprite_design.png")
            if design
            else None
        )
        os.makedirs(CACHE, exist_ok=True)
        mp = ref_rgba.shape[0] * ref_rgba.shape[1] / 1048576
        Image.fromarray(
            run(edit_graph(text, seed, name, mp, design_name)).astype(np.uint8)
        ).save(path)
        print("generated", text[:60], flush=True)
    return np.asarray(Image.open(path).convert("RGBA"))


def cached(ref_rgba, text, seed):
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode()
    ).hexdigest()[:16]
    return os.path.exists(os.path.join(CACHE, key + ".png"))


def shrink(img, cell, k=32):
    """Фон — виміряний колір рамки (модель малює «#FF00FF» як (244..252, 6..7, 245..247)); ×16 → клітинка
    кольором, якого в блоці найбільше (з k кольорів кадру). Середнє розмивало дрібні деталі моделі й краї, де її
    сітка не збігається з нашою, — татуювання Уризена ставало сірою плямою (Sapega: «дуже розмитий»)."""
    w, h = cell
    rgb = img[: h * UP, : w * UP, :3]
    f = rgb.astype(np.float32)
    border = np.concatenate(
        [
            f[:12].reshape(-1, 3),
            f[-12:].reshape(-1, 3),
            f[:, :12].reshape(-1, 3),
            f[:, -12:].reshape(-1, 3),
        ]
    )
    a = np.linalg.norm(f - np.median(border, axis=0), axis=2) > 75
    # тінь, яку модель кладе під ступні на пурпурі, — теж геть: пурпурових кольорів на персонажах немає
    a &= ~((f[..., 0] > f[..., 1] + 60) & (f[..., 2] > f[..., 1] + 60))
    pim = Image.fromarray(rgb[a][None].astype(np.uint8)).quantize(
        k, Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE
    )
    pal = np.array(pim.getpalette()[: 3 * k], dtype=np.float32).reshape(-1, 3)
    block = (np.arange(h * UP)[:, None] // UP) * w + np.arange(w * UP)[None] // UP
    counts = np.bincount(
        block[a] * k + np.asarray(pim)[0], minlength=h * w * k
    ).reshape(h, w, k)
    return pal[counts.argmax(axis=2)], counts.sum(axis=2) >= UP * UP / 2


def feet_row(opaque):
    rows = np.nonzero(opaque.any(axis=1))[0]
    return int(rows[-1]) if len(rows) else len(opaque) - 1


def bob(small, waist):
    """Дихання: усе вище рядка waist — на піксель нижче (кадр художника лишається його кадром)."""
    rgb, op = small[0].copy(), small[1].copy()
    rgb[1:waist], op[1:waist] = rgb[: waist - 1].copy(), op[: waist - 1].copy()
    op[0] = False
    return rgb, op


def rotate(small, deg):
    """Поворот на кратний 90° кут за годинниковою стрілкою навколо середини силуету — піксель-арт без втрат."""
    rgb, op = small
    ys, xs = np.nonzero(op)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    k = (-deg // 90) % 4
    crop_rgb, crop_op = np.rot90(rgb[y0:y1, x0:x1], k), np.rot90(op[y0:y1, x0:x1], k)
    h, w = crop_op.shape
    ny0, nx0 = int(round((y0 + y1) / 2 - h / 2)), int(round((x0 + x1) / 2 - w / 2))
    out_rgb, out_op = np.zeros_like(rgb), np.zeros_like(op)
    ys0, xs0 = max(0, ny0), max(0, nx0)
    ys1, xs1 = min(op.shape[0], ny0 + h), min(op.shape[1], nx0 + w)
    out_rgb[ys0:ys1, xs0:xs1] = crop_rgb[ys0 - ny0 : ys1 - ny0, xs0 - nx0 : xs1 - nx0]
    out_op[ys0:ys1, xs0:xs1] = crop_op[ys0 - ny0 : ys1 - ny0, xs0 - nx0 : xs1 - nx0]
    return out_rgb, out_op


def from_file(path):
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    return im[..., :3], im[..., 3] > 128


def regrid(img, cell):
    """Згенерований кадр, зведений до сітки клітинки й знову ×16 на пурпурі — чистий референс для FROM:."""
    rgb, op = shrink(img, cell)
    out = np.where(op[..., None], rgb, np.array(MAGENTA, np.float32)).astype(np.uint8)
    out = np.dstack([out, np.full(op.shape, 255, np.uint8)])
    return np.asarray(
        Image.fromarray(out).resize((cell[0] * UP, cell[1] * UP), Image.NEAREST)
    )


SPECIAL = ("BOB", "ROT", "FILE", "FLIP")
OUTLINE = np.array([0x28, 0x17, 0x2A], np.float32)  # контур героя
MAX_CHROMA = 0.7 * 255  # найяскравіший колір героя — 171: акценти не перекрикують його


def clamp_chroma(pal):
    """Насиченість (max−min каналів) не вище MAX_CHROMA: тягне мін. канали до макс., яскравість лишається."""
    hi = pal.max(axis=1, keepdims=True)
    chroma = hi - pal.min(axis=1, keepdims=True)
    k = np.minimum(1.0, MAX_CHROMA / np.maximum(chroma, 1.0))
    return hi - (hi - pal) * k


def polish(rgb, op):
    """Після палітри (не для героя): прибрати поодинокі пікселі (≤1 непрозорий сусід з 8), майже чорний край
    силуету — у контур героя, і замкнути контур — 1 px OUTLINE зовні там, де край не темний."""
    rgb, op = rgb.copy(), op.copy()

    def neighbours(m, diag):
        p = np.pad(m, 1)
        shifts = [(-1, 0), (1, 0), (0, -1), (0, 1)] + (
            [(-1, -1), (-1, 1), (1, -1), (1, 1)] if diag else []
        )
        return sum(
            p[1 + dy : 1 + dy + m.shape[0], 1 + dx : 1 + dx + m.shape[1]].astype(int)
            for dy, dx in shifts
        )

    op &= neighbours(op, True) > 1
    dark = rgb.max(axis=2) < 64
    edge = op & (neighbours(~op, False) > 0)
    rgb[edge & dark] = OUTLINE
    outer = ~op & (neighbours(op & ~dark, False) > 0)
    rgb[outer] = OUTLINE
    op |= outer
    return rgb, op


def hero_palette():
    """Усі кольори кадрів художника — нові кадри героя мають лише їх (28 кольорів)."""
    cols = set()
    for path in sorted(os.listdir("SampleProject/Sprites/Player")):
        folder = os.path.join("SampleProject/Sprites/Player", path)
        for f in sorted(os.listdir(folder)) if path in ("Run", "Walk") else []:
            if f.endswith(".png"):
                px = np.asarray(
                    Image.open(os.path.join(folder, f)).convert("RGBA")
                ).reshape(-1, 4)
                cols |= {tuple(c[:3]) for c in px if c[3] > 128}
    return np.array(sorted(cols), dtype=np.float32)


if __name__ == "__main__":
    char = CHARACTERS[sys.argv[1]]
    only = sys.argv[2:]
    seed = char["seed"]
    cell = char.get("cell", (CELL, CELL))
    UP = char.get(
        "up", UP
    )  # менший блок для більшої клітинки: картинка моделі лишається ~1 Мп (меч, 96x96)
    ref = enlarge(char["ref"], cell)
    # base=None — перший кадр сам кадр художника (новий кадр героя, D239), інакше модель робить його з референсу
    base = (
        ref
        if char["base"] is None
        else edit(ref, char["base"], seed, char.get("design"))
    )
    base_ref = base.copy()
    base_ref[..., 3] = 255
    frames = {}
    floors = {}  # ON: — ступні на рядку кадру-джерела (біг художника підскакує на 1–2 px)
    for anim, poses in char["rows"]:
        for i, pose in enumerate(poses):
            text = KEEP.format(who=char["who"], pose=pose) if pose else None
            if pose is None:
                frames[(anim, i)] = base
            elif pose.startswith("FROM:"):
                # FROM:<анімація>:<кадр>:<поза> — з іншого згенерованого кадру (цикл дії тримає реквізит і позу)
                _, src_anim, src_i, rest = pose.split(":", 3)
                src = frames.get((src_anim, int(src_i)))
                if src is not None:
                    src_ref = regrid(src, cell)
                    text = KEEP.format(who=char["who"], pose=rest)
                    if not only or anim in only or cached(src_ref, text, seed):
                        frames[(anim, i)] = edit(src_ref, text, seed)
            elif pose.startswith("ON:"):
                # ON:<png>:<поза> — з кадру-файлу (кадр художника): модель лише додає зброю, рух лишається його
                _, path, rest = pose.split(":", 2)
                src_ref = enlarge(path, cell)
                text = KEEP.format(who=char["who"], pose=rest)
                src_op = from_file(path)[1]
                floors[(anim, i)] = cell[1] - len(src_op) + feet_row(src_op)
                if not only or anim in only or cached(src_ref, text, seed):
                    frames[(anim, i)] = edit(src_ref, text, seed)
            elif pose.split(":")[0] in SPECIAL:
                frames[(anim, i)] = (
                    pose  # BOB:<рядок пояса> | ROT:<анімація>:<кадр>:<градуси> | FILE:<png>
                )
            elif not only or anim in only:
                frames[(anim, i)] = edit(base_ref, text, seed)
            elif cached(base_ref, text, seed):
                frames[(anim, i)] = edit(base_ref, text, seed)
    total = sum(len(p) for _, p in char["rows"])
    free()
    if len(frames) < total:
        sys.exit(
            f"{len(frames)}/{total} frames cached — run the remaining animations, then the sheet is built"
        )
    small = {k: shrink(v, cell) for k, v in frames.items() if not isinstance(v, str)}
    for k, pose in frames.items():
        if isinstance(pose, str):
            kind, *arg = pose.split(":")
            if (
                kind == "BOB"
            ):  # BOB:<рядок пояса>[:<анімація>:<кадр>] — дихає перший кадр або вказаний
                small[k] = bob(
                    small[(arg[1], int(arg[2]))]
                    if len(arg) > 1
                    else shrink(base, cell),
                    int(arg[0]),
                )
            elif kind == "FLIP":  # FLIP:<анімація>:<кадр> — дзеркало (дервіш крутиться)
                rgb, op = small[(arg[0], int(arg[1]))]
                small[k] = (rgb[:, ::-1].copy(), op[:, ::-1].copy())
            elif kind == "ROT":
                small[k] = rotate(small[(arg[0], int(arg[1]))], int(arg[2]))
            else:
                small[k] = from_file(":".join(arg))
    rgb0, op0 = shrink(base, cell)
    if char.get("palette") == "hero":
        pal_rgb = hero_palette()
    else:
        # палітра з усіх кадрів: фас Алісиї має синє око, якого в профілі (першому кадрі) немає — ставало сірим
        every = np.concatenate([rgb[op] for rgb, op in small.values()])
        pim = Image.fromarray(every.astype(np.uint8)[None]).quantize(
            char["colors"], Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE
        )
        pal_rgb = np.array(
            pim.getpalette()[: 3 * char["colors"]], dtype=np.float32
        ).reshape(-1, 3)
        pal_rgb = clamp_chroma(pal_rgb)
    floor = char.get(
        "floor", feet_row(op0)
    )  # ступні — на рядок першого кадру; floor — явно (лінія ніг героя 56)
    cols = max(len(p) for _, p in char["rows"])
    cw, ch = cell
    sheet = np.zeros((ch * len(char["rows"]), cw * cols, 4), np.uint8)
    for r, (anim, poses) in enumerate(char["rows"]):
        for i, pose in enumerate(poses):
            rgb, op = small[(anim, i)]
            q = pal_rgb[
                np.linalg.norm(rgb[:, :, None, :] - pal_rgb[None, None], axis=3).argmin(
                    axis=2
                )
            ]
            if (
                char.get("palette") != "hero"
            ):  # кадри героя — тільки кольори художника, без змін
                q, op = polish(q, op)
            else:  # лише поодинокі пікселі (жодного з 8 сусідів) — сміття ключування (арт-директор, Hurt кинджала)
                p = np.pad(op, 1)
                op = op & (
                    sum(
                        p[1 + dy : 1 + dy + op.shape[0], 1 + dx : 1 + dx + op.shape[1]].astype(int)
                        for dy in (-1, 0, 1)
                        for dx in (-1, 0, 1)
                        if dy or dx
                    )
                    > 0
                )
            frame = np.dstack([q, op * 255.0]).astype(np.uint8)
            shift = floors.get((anim, i), floor) - feet_row(op)
            frame = np.roll(frame, shift, axis=0)
            if shift > 0:
                frame[:shift] = 0
            elif shift < 0:
                frame[shift:] = 0
            sheet[r * ch : (r + 1) * ch, i * cw : (i + 1) * cw] = frame
            if char.get("rows_out") and i == len(poses) - 1:
                # компаньйони — лист на анімацію (idle/enter/strike), як їх ріжуть сцени й build_laboratory.gd
                Image.fromarray(sheet[r * ch : (r + 1) * ch, : len(poses) * cw]).save(
                    os.path.join(char["rows_out"], anim + ".png")
                )
            if char.get("frames_out") and not (pose is None and char["base"] is None):
                # кадри героя — окремими текстурами, як його кадри художника (Player.tscn міняє Sprite2D:texture)
                folder = os.path.join(char["frames_out"], anim)
                os.makedirs(folder, exist_ok=True)
                Image.fromarray(frame).save(os.path.join(folder, f"{i + 1}.png"))
            print(f"{anim}[{i}] feet row {feet_row(op)} -> {floor}")
    if "prop" in char:
        # реквізит у кадрах дії (ковадло коваля) — з першого кадру окремою текстурою тієї ж клітинки: стоїть і поза
        # дією, за персонажем (підставки ковадла в кадрах дії збігаються до пікселя — перевірено)
        anim, (x0, y0, x1, y1), prop_out = char["prop"]
        r = [a for a, _ in char["rows"]].index(anim)
        first = sheet[r * ch : (r + 1) * ch, 0:cw]
        prop = np.zeros((ch, cw, 4), np.uint8)
        prop[y0:y1, x0:x1] = first[y0:y1, x0:x1]
        Image.fromarray(prop).save(prop_out)
    if (
        "out" in char
    ):  # кадри героя — лише окремими текстурами (frames_out), листа гра не бере
        os.makedirs(os.path.dirname(char["out"]), exist_ok=True)
        Image.fromarray(sheet).save(char["out"])
    print(
        "sheet",
        char.get("out") or char.get("frames_out") or char.get("rows_out"),
        sheet.shape[1],
        "x",
        sheet.shape[0],
        "| feet row",
        floor,
    )
