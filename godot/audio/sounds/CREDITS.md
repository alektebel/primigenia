# Valley audio

All files are CC0 1.0, verified on the linked authors' publication pages on
2026-11-15. Licence: https://creativecommons.org/publicdomain/zero/1.0/
Only individual audio files were downloaded; no packs, archives, SDKs or other
assets were downloaded. The shipped Ogg files total 2,137,173 bytes (under 6 MB).
Runtime gain, position and playback-rate changes do not alter the source files.

| Shipped file | Author | Source / original file | Licence | Edits |
|---|---|---|---|---|
| `step-0.ogg` | Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds), `footstep_grass_000.ogg`; [individual-file mirror](https://raw.githubusercontent.com/liamgh/FlopperFlinger/main/footstep_grass_000.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `step-1.ogg` | Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds), [footstep_grass_001.ogg mirror](https://forge.apps.education.fr/blender-edutech/ropy/ropy/-/raw/v2.6/asset/sounds/kenney_impactsounds/footstep_grass_001.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `step-2.ogg` | Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds), [footstep_grass_002.ogg mirror](https://forge.apps.education.fr/blender-edutech/ropy/ropy/-/raw/v2.6/asset/sounds/kenney_impactsounds/footstep_grass_002.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `grass-rustle.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [grass_1.ogg](https://opengameart.org/sites/default/files/grass_1.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `hurt.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [hurt_1.ogg](https://opengameart.org/sites/default/files/hurt_1.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `hit.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [punch_1.ogg](https://opengameart.org/sites/default/files/punch_1.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `block.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [baseballbat_1.ogg](https://opengameart.org/sites/default/files/baseballbat_1.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `dodge.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [bat.ogg](https://opengameart.org/sites/default/files/bat.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `spit.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [bee_2.ogg](https://opengameart.org/sites/default/files/bee_2.ogg) | CC0 1.0 | Renamed; audio unchanged; used as a short creature projectile buzz. |
| `click.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack), [item_1.ogg](https://opengameart.org/sites/default/files/item_1.ogg) | CC0 1.0 | Renamed; audio unchanged. |
| `meadow.ogg` | Spring Spring; public-domain bird recordings by isaiah658, syncopika, pauliuw | [Birds and Wind](https://opengameart.org/content/birds-and-wind-ambient-birds-wind-and-synth), [Birds and Wind - Ambient_1.ogg](https://opengameart.org/sites/default/files/Birds%20and%20Wind%20-%20Ambient_1.ogg) | CC0 1.0 | Renamed; audio unchanged; ambient version without the synth arrangement. |
| `wind.ogg` | Spring Spring; isaiah658, syncopika, pauliuw | Same [Birds and Wind ambient recording](https://opengameart.org/sites/default/files/Birds%20and%20Wind%20-%20Ambient_1.ogg) | CC0 1.0 | First 20 s; 350 Hz low-pass, gain ×2, 0.8 s endpoint fades; mono, 24 kHz Vorbis quality 2. |
| `idle.ogg` | mikeask | [Monster](https://opengameart.org/content/monster-5), [Monster.wav](https://opengameart.org/sites/default/files/Monster.wav) | CC0 1.0 | First 0.65 s; 25 ms fade-in / 80 ms fade-out; mono, 24 kHz Vorbis quality 2. |
| `aggro.ogg` | mikeask | [Monster](https://opengameart.org/content/monster-5), [Monster.wav](https://opengameart.org/sites/default/files/Monster.wav) | CC0 1.0 | First 2.4 s; same fades / encoding. |
| `death.ogg` | mikeask | [Monster](https://opengameart.org/content/monster-5), [Monster.wav](https://opengameart.org/sites/default/files/Monster.wav) | CC0 1.0 | From 0.5 s for 2.8 s; same fades / encoding. |

Reproduction of the edited files uses installed FFmpeg, `-ac 1 -ar 24000
-c:a libvorbis -q:a 2`. Cry filter: `afade=t=in:d=0.025,areverse,
afade=t=in:d=0.08,areverse`; wind filter: `lowpass=f=350,volume=2,
afade=t=in:d=0.8,afade=t=out:st=19.2:d=0.8`.

These are basic sampled effects. Their suitability, loudness and loop seams
still need the owner's listening review; no procedural voice system is claimed.
