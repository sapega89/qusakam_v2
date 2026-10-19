# Settlement backdrops (D219)

Drawn by `Scripts/Tools/draw_town_layers.py` (original work, no third-party licence). Pixel scale of the
Desert Oasis backdrop: 576 px wide, ×1.5 in the game = one 864 px MetSys cell; building bases on texture row 260
(floor y 384 sits on row 256, so the bases hide behind the tiles). Even top light, no sun ([[lore]]).

| File | Room | Use |
|---|---|---|
| `city_far.png` | City | Parallax2D ×0.4 — hazy wall with crenellations, towers, domes, minarets |
| `city_near.png` | City | Parallax2D ×0.85 — dense two-storey houses with market awnings |
| `mayor_hall_wall.png` | MayorHall | Sprite2D wall — sandstone masonry, arched niches, columns, red banners with a coin |

The painted `assets/The Desert/` set has village / city / palace scenes, but it is not pixel art and draws a sun.

The Village's houses moved to `../Village/` (generated, D236).
