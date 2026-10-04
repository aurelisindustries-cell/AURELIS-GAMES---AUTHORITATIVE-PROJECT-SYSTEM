# Metroidvania world designer

Open the level editor with **F3**. **WORLD** opens a dedicated full-screen World Builder. **ROOM** opens the tools for placing transition areas and pickups while painting a room.

Room editing shortcuts: **Ctrl+Z** undoes, **Ctrl+Y** (or **Ctrl+Shift+Z**) redoes, with up to 50 edits retained for the open room. Paint/erase drags count as one edit. Opening or creating another room resets this history. Use **Select / Move** to box-select tiles and objects, **Ctrl+C** to copy, and **Ctrl+V** to paste at the mouse pointer. Tile rotations and enemy patrol settings are preserved. Pasted transitions/pickups get new IDs; pasting a player start replaces the existing start. **Delete** removes the selection. Hold the left button with **Erase** selected, or right-drag with a painting/placement tool, to erase continuously. Shortcuts leave focused text fields to handle their own editing.

Placing a touch transition, or clicking one with **Select / Move**, opens **Transition area** settings. Its stable **Door ID** identifies the arrival point other doors can target. Choose a **Destination room** and **Destination door ID**, adjust width/height and direction, optionally select a required ability, then **Apply** and save the room. Destination choices come from saved rooms added to the current World Builder; save the destination room after placing its doors. Each area's destination is one-way, so configure the other door separately for a return trip. Choosing **Use World Builder connection** restores the older map-link workflow. Explicit area destinations take precedence over map links and are used in world playtests/adventures. Invalid room/door references are rejected at runtime and reported by world validation.

## Try it first

In World Builder, click **Create starter world**, then **Test world** in the top bar. This creates two new room files and a world layout without replacing existing room files.

Walk right, collect Dash, activate the checkpoint, and walk through the right opening. Touching its transition area automatically changes rooms with a short fade; no interaction button is needed. The second room has a health upgrade and a return opening. **M** opens/closes the explored-room map. **Escape** returns to World Builder; **Room editor** or Escape again returns to room editing.

## Build your own world

1. Paint a room with the Tiles tools. Place a Player Start in your starting room.
2. In Room, choose the outward direction and area width/height, then **Place transition area** across a room opening. The cyan rectangle shows the exact trigger. Keep the arrival space inside the room clear of walls and hazards. To resize an existing area, select it with Select / Move, change the fields, and click **Apply to selected transition**.
3. Place checkpoints from Objects. Place ability pickups and health upgrades from Room.
4. **Save** the room in Level. Build and save another room.
5. Open World, name your world, choose a saved room on the left and click **+ Add to world** for each room.
6. Click a room on the map, then **Make starting room** on the right.
7. Click its blue transition handle, then a matching handle in another room. In Links, optionally choose an ability gate and click **Connect these transitions**. Connections work both ways. Pair left/right or up/down. The transition list in the Room inspector is an alternative to map handles.
8. In the World inspector tab, select any abilities the player starts with. Other movement upgrades are locked until collected.
9. Use the Check inspector tab to **Check world**, fix its reports, then **Save world** and **Test world** in the top bar.

Double-click a room on the map, or click **Edit this room**, to return to room editing. Save your current edits before accepting. After changing room geometry or transitions, save the room. Opening World Builder refreshes saved rooms automatically; **Refresh rooms** also does this. Wheel zooms the map, middle-drag pans, and **Fit map** restores its overview.

## Automatic sizing and positioning

Room bounds enclose tiles, placed objects, and authored patrol endpoints. Bounds align to 32-pixel tiles and grow in 1280 × 736-pixel screen units (40 × 23 tiles). Empty rooms start at one screen. **Show whole room** frames those bounds; their outline appears while World is open.

Auto layout begins at the starting room and follows connections. Exit directions place neighbors on the corresponding side. Exit positions align their screen rows or columns, allowing multiple neighboring rooms along a tall or wide room. Disconnected room groups are placed apart until connected.

These bounds drive the world map, room placement, and gameplay camera limits. Auto layout does **not** paint terrain or cut holes through walls. Transition rectangles must cover openings the player can reach. At runtime they become invisible touch triggers; locked ability gates remain visible and physically block passage. Crossing a trigger fades to the paired room and places the player just inside it. The arrival area stays suppressed until the player moves clear of its landing space, preventing immediate return loops, including from gravity in vertical passages.

For loops, the room sizes and exit alignments must agree around the whole loop. Validation reports map overlaps or inconsistent connections rather than silently moving rooms away from their doors.

## Progress and testing

- **Test world** starts fresh in memory and never writes player progression.
- **Continue saved adventure** in the World inspector tab uses a separate progress file for this world.
- **Restart saved adventure** resets that world's player progress after confirmation.
- Checkpoints heal and set the respawn room and location.
- Collected abilities, health upgrades, discovered rooms, and defeated enemies configured with `respawn_enabled = false` persist. Ordinary enemies are recreated when a room is revisited.
- Falling below room bounds triggers death and checkpoint respawn.
- Opening the map freezes the current room and player until it closes.
- Returning to editing preserves the authored room; gameplay runs separate instances.

Files:

- Rooms: `user://levels/*.tscn`
- World layouts: `user://worlds/*.tres`
- Player progress: `user://world_progress/*.json`

A world references its room files. Back up or share the room files together with the world layout. Moving to a packaged release requires bundling those room scenes and updating the paths; the editor's user files are not automatically included in exports.

## What Check world checks

Missing room files, missing starting-room Player Start, unconnected/deleted exits, opposite exit directions, overlapping rooms, inconsistent loops, and rooms unreachable with the starting abilities plus reachable pickups. It can catch an upgrade placed behind a connection requiring that same upgrade.

It does not simulate platforming inside a room. Playtest whether jumps are possible, pickups are accessible, and doorway arrival positions are clear of terrain and hazards.

This is the room/progression foundation. Fast travel, region art/music, quest flags, boss-specific gate authoring, multiple player save slots, and a shipping game's title/load menus remain separate features.

## Regression checks

Run with a Godot 4.7 executable from the project directory:

```text
godot --headless --path . --scene res://Tests/vania_world_test.tscn
godot --headless --path . --scene res://Tests/level_editor_test.tscn
```

The world test covers automatic bounds/layout, rejected duplicate exits, ability-gated reachability, serialized layouts, runtime transitions, actual controller unlocks, pickup persistence, full death/respawn, progression save/reload, isolated preview saves, and the starter world.

## Upgrade testing menu

Press **F2** during gameplay or a playtest to pause and open the categorized upgrade menu. Changes apply to the current player immediately and last for that play session, including room transitions and respawns. They do not rewrite earned upgrades in adventure saves. **Restore normal upgrades** removes all menu overrides. F2, Escape, or **Resume** closes the menu. **F3** opens the level editor from the test world.

The following weapon upgrades are available as optional F2 toggles, initially off:

- **Buster Module V1** (Dr. Trevor Lowe): hold the normal Arc Caster button (F / controller caster button) for 0.5 seconds and release for a 2x damage shot. The initial normal shot still fires on press. Module-slot attacks do not charge. The existing Charged caster toggle must also be enabled.
- **Extended Edge I / II** (Dr. Brian Conner): 125% / 150% dagger reach, including authored hitboxes and slash visuals.
- **Reinforced Edge I / II** (Dr. Kevin Evered): +2 / +4 dagger damage, including authored combo and directional attacks.

Enabling tier II enables tier I; disabling tier I disables tier II. Damage, reach, and charge timing can be adjusted on PlayerCombatController.

**Vine Whip** is available separately in **F2 > Evolved**, initially off. Press **R** (controller **Y / Triangle**) to use the selected ability. **Q/E** (tap controller bumpers) switches between enabled evolved abilities. Aim with **I/J/K/L** or the right stick; without aiming, it lashes in your facing direction. The green vine hits each enemy once, staggers targets, and stops at terrain. Prototype defaults are 220 pixels of reach, 4 damage, and a 0.65-second cooldown, editable on PlayerCombatController. Disabling its toggle cancels an active lash.

**Burrow** is also in **F2 > Evolved**, initially off. Stand on a **Burrowable Soil** strip, select Burrow, and press **R**. Left/right moves underground; **R or Jump** surfaces. It automatically tries to surface after five seconds. Solid obstacles still block movement and surfacing; move back to a clear opening if needed. Ordinary terrain cannot be burrowed through. Weapons are unavailable underground and the buried player is protected from contact hits. Disabling Burrow returns to the surface, falling back to the entry point if the current exit is obstructed; if both are blocked it waits for a clear exit.

Designers can place soil from **OBJECTS > Player & checkpoints > Burrowable Soil**. Each strip is 256 x 96 pixels, with its surface at the placement point. Leave the soil interior empty of painted tiles, keep space above it for surfacing, and leave its rotation/scale unchanged. Soil saves with the room and is included in automatic room bounds. Burrow speed (150 pixels/second) and duration are editable prototype settings on PlayerCombatController.
