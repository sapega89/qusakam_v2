# Arrows (BACKLOG 40, art A4)

**AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps` LoRA, licence
**Apache 2.0**) by `Scripts/Tools/comfy_fx.py arrow`: one picture on a magenta key, keyed out, fitted
into the texture at the game's pixel scale (1 texture px = 1.5 world px, like the hero) and quantised. Steam needs the
AI-content disclosure. Not wired yet.

| File | Size | Notes |
|---|---|---|
| `arrow.png` | 28×9 | plain arrow flying right; tip at (27, 4), shaft on rows 4–5; fletching at the left |
| `arrow_charged.png` | 36×13 | `arrow.png` (placed at (4, 2)) + a cream glow behind the head and a short trail hugging the shaft, in the glow colours of the hero's `Charged` frames (`Scripts/Tools/bow_fixups.py`); tip at (31, 6) |

Both face right (flip for the left); the arrowhead tip is the hit point; the vertical centre is row 4 in `arrow.png`, row 6 in `arrow_charged.png`.
