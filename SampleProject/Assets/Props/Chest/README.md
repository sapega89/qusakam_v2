# Chest (BACKLOG 33, art batch A1)

**AI-generated** by `Scripts/Tools/comfy_sprite.py chest`: the local ComfyUI with **Qwen-Image-Edit-2511**
(Alibaba Qwen, Apache 2.0, unsloth GGUF Q5_K_M) and the Qwen-Image-Edit-2511-Lightning LoRA (lightx2v, Apache 2.0),
made from the hero's artist frame `SampleProject/Sprites/Player/Walk/1.png` as the style reference, so it shares his
pixel, thick dark outline and flat shading. A Steam release has to disclose AI-generated content.

Every frame is a 64×64 cell in the hero's pixel scale (draw it at the hero's sprite scale), 16 colours, the chest's
bottom on row 56 (the hero's foot line) and its body at x 15–49 in every frame — only the lid moves.

| Folder | Frames | What |
|---|---|---|
| `Closed/1.png` | 1 | closed, lid down (top row 28) |
| `Opening/1–3.png` | 3 | the lid lifted a crack → half open → nearly upright, the inside dark |
| `Open/1.png` | 1 | the lid thrown fully back, the inside dark and empty (top row 14) |

The frames face the viewer three-quarters from the left; flip for a chest that should face the other way.
No glow is painted in: a light or particles over the opening are the scene's.
