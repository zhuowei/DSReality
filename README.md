DS emulation in Augmented Reality

Turns a DS game into a holographic 3D image that floats above your controller.

![screenshot of Mario Kart DS](https://github.com/zhuowei/DSReality/assets/704768/1514c7c8-76b1-4e41-9894-a027b6d35cb0)

- DS emulation with [melonDS](https://github.com/melonDS-emu/melonDS) and [@rileytestut/Delta](https://github.com/rileytestut/Delta)'s MelonDS core
- live 3D model extraction with [@scurest/MelonRipper](https://github.com/scurest/MelonRipper)
- 3D model rendered in augmented reality using iOS [RealityKit](https://developer.apple.com/documentation/realitykit/) (with some help from [@noah@mastodon.art](https://mastodon.art/@noah/110574749502309331))

This is only a concept/prototype: in particular,

- the MelonRipper->RealityKit converter doesn't work very well (e.g. doesn't handle transparency)
- there's a terrible memory leak (might be [this](https://developer.apple.com/forums/thread/710657)?) that crashes the app after a few minutes
- only tested with the camera position used by Mario Kart DS. (for example, Pokemon Black and HeartGold use a different camera angle, and I had to remove the shader that crops for their models to show up)
- no way to select rom/touchscreen input/etc. The ROM name is hardcoded to "rom.nds" in the app's folder in Files/iTunes.
