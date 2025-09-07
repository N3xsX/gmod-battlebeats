# 🎵 BattleBeats for Garry's Mod

BattleBeats is a powerful music management system for Garry's Mod, allowing you to control ambient and combat music with precision. While it’s designed primarily for standalone use and may have limited compatibility with other addons, it gives you full control over most music-related features   

> ⚠️ **Note:** The `BATTLEBEATS` table is **client-sided**, so all operations are performed on the client

## Table of Contents
- [Core Variables](#core-variables)
- [Tables Structure](#tables)
    - [Music Packs](#music-packs)
    - [Current Tracks](#current-tracks)
    - [Excluded Tracks](#excluded-tracks)
- [Essential Functions](#essential-functions)
  - [PlayNextTrack](#battlebeatsplaynexttracktrack-time-nofade)
  - [FadeMusic](#battlebeatsfademusicstation-fadein-fadetime-ispreview)
  - [GetRandomTrack](#battlebeatsgetrandomtrackpacks-iscombat-excluded-lasttrack2-exclusiveplayonly)
- [Semi-Useful Functions](#semi-useful-functions)
    - [HideNotification](#battlebeatshidenotification)
    - [ShowTrackNotification](#battlebeatsshowtracknotificationtrackname-incombat-ispreviewedtrack)
- [Quick Start](#quick-start)

---

# Core Variables

Here are the key variables you’ll interact with:

| Variable | Type | Description |
|----------|------|-------------|
| `BATTLEBEATS.currentStation` | IGModAudioChannel | The main station playing 99% of the time, either ambient or combat |
| `BATTLEBEATS.currentPreviewStation` | IGModAudioChannel | Station used for track previews |
| `BATTLEBEATS.musicPacks` | table | Contains all music packs loaded by BattleBeats |
| `BATTLEBEATS.currentPacks` | table | Tracks which packs are currently enabled |
| `BATTLEBEATS.excludedTracks` | table | Tracks that have been disabled from playback |
| `BATTLEBEATS.isInCombat` | boolean | Indicates if the player is in combat. Updates every second |

# Tables

### Music Packs

Each music pack in `BATTLEBEATS.musicPacks` is stored like this:

```lua
BATTLEBEATS.musicPacks[title] = {
    ambient = ambientFiles,      -- table of ambient tracks
    combat = combatFiles,        -- table of combat tracks
    packType = packType,         -- type of pack, eg: "nombat", "sbm", "16thnote" or "battlebeats"
    packContent = packContent,   -- type of the content inside pack, this can either be "both", "combat" or "ambient"
    wsid = addon.wsid            -- Workshop ID
}
```

---

### Current Tracks

`BATTLEBEATS.currentPacks` is a **table of music packs currently enabled by the player**  
It is used to determine which packs are eligible for track selection

#### Key Points:

- Loaded from a cookie (`battlebeats_selected_packs`) on client start
- Only includes packs that exist in `BATTLEBEATS.musicPacks`; invalid pack names are removed automatically
- Example structure:
```lua
BATTLEBEATS.currentPacks = {
    ["dmc5ostt"] = true,
    ["zzzmusic"] = true
}
```

---

### Excluded Tracks

The `BATTLEBEATS.excludedTracks` table is used to **disable specific tracks** from being played automatically. 
All excluded tracks are stored as keys with the value `true`

This table is **saved to disk** in GMod under: `data/battlebeats_excluded_tracks.txt` as JSON. Example content:

```json
{
    "sound/battlebeats/dmc5ostt/combat/silver bullet.mp3": true,
    "sound/battlebeats/zzzmusic/combat/victoria style service.mp3": true
}
```

BattleBeats provides a function to save the current state of exclusions to disk:
`BATTLEBEATS.SaveExcludedTracks()`

After modifying `BATTLEBEATS.excludedTracks`, call `BATTLEBEATS.SaveExcludedTracks()` to persist your changes

> ⚠️ **WARNING**: This function is automatically called whenever a player excludes a track via the UI
You can call it manually in code, but doing so carelessly may overwrite or corrupt players exclusions

The function only saves tracks that are marked `true`, ignoring any `nil` or `false` values

# Essential Functions

### `BATTLEBEATS.PlayNextTrack(track, time, noFade)`

Starts playing the specified track and schedules the next track automatically

| Parameter | Type | Description |
|-----------|------|-------------|
| track | string | Path to the track file (starts from sound/ folder) |
| time | int/float | Time (in seconds) to start playback. Leave empty to start from the beginning |
| noFade | boolean | If true, skips the fade-in effect |

### Behavior

- Stops and fades out the current station before starting the new track
- Updates local variables `lastAmbienceTrack` / `lastCombatTrack` and stores track length/position for correct playback handling
- Shows a track notification if enabled
- Creates two timers:
  1. `"BattleBeats_NextTrack"` - plays the next track when the current one finishes
  2. `"BattleBeats_CheckSound"` - monitors the track and restarts playback if it stops unexpectedly
- Selects the next track using `GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)`
- Automatically handles combat vs ambient music and respects excluded tracks
- If `noFade` is false, `FadeMusic` is called internally to smoothly fade in the track

### `BATTLEBEATS.FadeMusic(station, fadeIn, fadeTime, isPreview)`

Fades a music station in or out  
This function is **used internally** by [PlayNextTrack](#battlebeatsplaynexttracktrack-time-nofade), but can be called manually if needed

| Parameter | Type | Description |
|-----------|------|-------------|
| station | IGModAudioChannel | The station to fade |
| fadeIn | boolean | true to fade in, false to fade out |
| fadeTime | int | Duration of the fade in seconds (default: 2) |
| isPreview | boolean | If true, uses master volume instead of ambient/combat volume |

### `BATTLEBEATS.GetRandomTrack(packs, isCombat, excluded, lastTrack2, exclusivePlayOnly)`

This function is the **core mechanism** BattleBeats uses for track selection and is called internally by [PlayNextTrack](#battlebeatsplaynexttracktrack-time-nofade)

| Parameter | Type | Description |
|-----------|------|-------------|
| packs | table | Table of packs to choose from |
| isCombat | boolean | Whether to pick from combat or ambient tracks |
| excluded | table | Table of excluded tracks |
| lastTrack2 | string | Internal use (ignore) |
| exclusivePlayOnly | boolean | Internal use (ignore) |

### Return Value

- Returns a **string** with the path to the selected track.
- Returns `nil` if:
  - `isCombat = true` but combat tracks are disabled (`enableCombat:GetBool() = false`), or  
  - `isCombat = false` but ambient tracks are disabled (`enableAmbient:GetBool() = false`)
  - If no packs are provided

### Behavior

**Exclusions**:  
   - Tracks listed in the `excluded` table are automatically skipped. If all available tracks are excluded, a random track from all tracks is returned as a fallback, and a notification warns the player

**Avoid repeats**:  
   - If more than one track is available after exclusions, the last played track (`lastCombatTrack` or `lastAmbienceTrack`) is skipped to avoid immediate repetition

# Semi-Useful Functions

### `BATTLEBEATS.HideNotification()`
Hides the current track notification if one exists

### `BATTLEBEATS.ShowTrackNotification(trackName, inCombat, isPreviewedTrack)`

This function is **used internally** by [PlayNextTrack](#battlebeatsplaynexttracktrack-time-nofade), but can be called manually if needed

| Parameter | Type | Description |
|-----------|------|-------------|
| trackName | string | Path to the track (automatically trimmed) |
| inCombat | boolean | Determines notification color: green (ambient) or orange (combat) |
| isPreviewedTrack | boolean | Overrides color to yellow if true |

# Quick Start

```lua
-- Play an ambient track immediately
BATTLEBEATS.PlayNextTrack("sound/mymusic/ambient/calm.ogg", nil, true)

-- Fade out the current station over 3 seconds
BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation, false, 3)

-- Show a track notification in orange color
BATTLEBEATS.ShowTrackNotification("sound/mymusic/combat/action.ogg", true, false)
-- This will show as: "Action"
```
