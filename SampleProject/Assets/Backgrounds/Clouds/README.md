# Standalone clouds (BACKLOG 19, A5b)

`gen_cloud_1.png` (179×97, big cumulus), `gen_cloud_2.png` (258×50, long flat streak), `gen_cloud_3.png`
(102×77, small puff): single cloud sprites for drifting clouds, made by `Scripts/Tools/comfy_backdrop.py`
(`Clouds/gen_cloud_*` layers: `seam="drop"`, `small=2`, `trim`, largest blob only) in the palette of
`Canyon/gen_clouds.png`. Trimmed to the cloud; no anchor (they float). Not wired into scenes yet.

AI-generated: drawn by the local ComfyUI with **Qwen-Image** (Alibaba Qwen, Apache 2.0) + the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then keyed, downscaled to the game pixel and quantised by a script. A Steam release has to disclose AI-generated content.
