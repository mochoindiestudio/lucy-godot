# Devlog #1: The First Two Weeks of "Lucy à Luz do Amor"

Hey folks 👋

We're about 11 days into building **Lucy à Luz do Amor** and it felt like the right time for a first devlog. No trailer yet, no demo yet — just a big pile of systems getting bolted together in Godot 4.7. Here's the rundown of what actually exists right now.

## The cast is alive

Lucy (our protagonist) and six NPCs — Bella, Giorgio, Lucca, Mario, Mia, and Oscar — are all individually rigged and animated, each with their own FBX clips instead of a shared skeleton. That means every character can eventually have their own personality baked right into how they move, not just what they say. We built a proper animation showcase scene to preview all their states side-by-side before any of them set foot in the actual world.

## The world got a pulse

- **Sky3D day/night cycle** is running, and building lamps now auto-toggle based on it — no more "why is this street lamp on at noon" energy.
- **Terrain 3D** is in, with a rescaled cat statue (very important lore, trust us) and touched-up terrain around it.
- Buildings got migrated from FBX to GLB, ships got an idle bob and waving flags, and props got reorganized so the scene doesn't look like a junk drawer exploded.

## Lucy can actually *do* things now

- A generic **interaction system** is wired up — signposts, objects, an interact panel that tracks its target, sparkle particles when something's interactable. Basic, but it's the foundation for every quest/dialogue hook down the line.
- Lucy has a **firefly light** with flicker, timed shine, and an energy pool tied to a proper energy bar HUD.
- **Toast notifications** and collision on buildings/bridges/terrain trees mean the world finally has edges instead of being a beautiful ghost you clip through.
- A scrollable **minimap** now tracks Lucy's position in the bottom-right corner.

## The nerdy backstage stuff

We added an **F9 dev HUD** — FPS, frame/physics time, memory, render stats — because guessing performance is for cowards. That HUD paid off almost immediately: it caught a vegetation-driven draw call spike from the grass instancer, which we fixed by tuning the LOD. We also chased down a lamp-light performance issue. Basically: if it lags, we now *see* it lag, and that's half the battle.

And most recently — the **main menu** landed, complete with an animated windmill rotor. First thing players will see, and it already has more charm than most of our placeholder assets combined.

## Under the hood

Running on the `dialogue_manager`, `achievements_manager`, `inventory_manager`, and `quest_manager` addons, plus Sky3D and Terrain3D for the environment. Nothing user-facing yet from the RPG-systems side, but the plumbing is in and the debugger panels for each manager are hooked up so we can watch state change live while testing. Very "behind the curtain," very necessary.

## What's next

More world content, actual quest/dialogue hookups now that the interaction system exists, and (fingers crossed) something screenshot-worthy for the next devlog instead of just a windmill and a very smug cat statue.

Thanks for reading this far — more soon. 🌾
