## What's new in 1.0.3

### Overload
- **Burden meter**: a new OVERLOAD section in the config window shows each element's overload chance as a bar and percentage. It reads the game's "overload chance" chat line each time a maneuver goes on and counts it down between readings, 1% every 3 seconds. It counts down faster when a Heatsink is among your automaton's attachments (and with Water Maneuvers on).
- **Overload set**: optionally switch to a chosen maneuver set when your puppet overloads, and back once the Overload effect has worn off and burden is below a value you pick. Choosing a set yourself while it is active cancels the automatic switch.
- **Minimized bar**: the maneuver dots pulse from about 10% overload chance, then wiggle and flash harder as it rises. While overloaded the whole bar and its outline pulse red.
- **Overdrive**: a rainbow surges around the bar's outline while Overdrive is active.

### Auto Repair
- Repair now equips the best ticked oil into the Ammo slot first, including from Mog Wardrobes 1 to 8, then uses Repair.
- The oil list and total count your inventory and all eight wardrobes.
- `/puphq debug` shows what Auto Repair sees and prints each attempt.

### Other
- The oil count moved under the Auto Repair slider as a list with one tick box per oil kind.
- New "Stay on in zones" option (not into towns or cities).
- The minimized bar's status light is now a button that enables or disables the addon.
- Attachment list has a "Filter by element" row.
- Name field and "Clear set" for attachment sets, and a resizable attachment tab.
- Pet HP, MP and TP shown at the top of the config window.

Install: copy the `puphq` folder to `Ashita\addons\` and run `/addon reload puphq`.

Commands: `/puphq config`, `/puphq ad toggle`, `/puphq toggle`, `/puphq manset next|prev|1|2|3`, `/puphq debug`.
