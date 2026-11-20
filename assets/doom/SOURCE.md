# DOOM arcade runtime

- Engine: Crispy Doom 7.2.0, official Windows x64 release:
  https://github.com/fabiangreffrath/crispy-doom/releases/tag/crispy-doom-7.2
- Campaign: Freedoom: Phase 1, version 0.13.0:
  https://github.com/freedoom/freedoom/releases/tag/v0.13.0
- Engine source archive is included as `crispy-doom-7.2-source.zip`.
- Engine license is included as `CRISPY-COPYING.txt`.
- Freedoom license is included as `FREEDOOM-COPYING.txt`.

Reproduce with `./scripts/fetch_doom.ps1`. The script downloads from the
official projects, scans both archives and unpacked runtime with Microsoft
Defender, and fails on any nonzero scan result. It never executes the engine.
SHA-256 inventory and scanner output are written to `build/doom-downloads/`.

The shipped game is Freedoom, not id Software's commercial game data.
Users can select their own DOOM / DOOM II IWAD; no proprietary IWAD is bundled.
Runtime files are copied next to the Windows executable under `assets/doom/`.
Saves, configuration, imported IWADs and session logs are under the app's
separate `flux_tracker/doom` user-data directory.
