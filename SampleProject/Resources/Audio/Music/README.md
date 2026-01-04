# Music Files

This folder is for game music files.

## Expected Files

The game looks for these music files:

### Menu Music
- `menu.ogg` - Main menu background music

### Gameplay Music
- `main_theme.ogg` - Default gameplay music
- `Sands of Serenity.mp3` - Alternative gameplay track

### Boss Music
- `boss.ogg` - Laboratory/boss fight music

## Notes

- **Current Status:** No music files present - game runs silently
- **Format:** OGG or MP3
- **Adding Music:**
  1. Place your music files in this folder
  2. Ensure filenames match the list above
  3. Restart Godot to reload resources

## Music Manager

Music is controlled by:
- `Scripts/Managers/Audio/GameMusicManager.gd`
- Global MusicManager autoload

The game will work fine without music files - it just won't play any background music.
