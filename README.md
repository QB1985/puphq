# PUPHQ

An [Ashita v4](https://www.ashitaxi.com/) addon for Puppetmaster in Final Fantasy XI: a control panel for
maneuvers, repair, deploy and attachment sets, with a dark violet look.

Based on **Puphelper** by GetAwayCoxn, restyled after YunaUI. The attachment-set code is adapted from
**pupsets** (GPLv3).

## Features

- Auto Deploy, Auto Repair (by pet HP%) and Auto Maneuvers, paused while resting, asleep, stunned and so on
- Maneuver sets that belong to each attachment set (add as many as you like with +, right click to remove), switchable from the panel, the bar or by command
- Minimized bar: status light, Auto Deploy switch, maneuver circles you can click to change, set arrows,
  size and opacity options
- Pet HP / MP / TP and an oil count (by kind) under the Auto Repair slider
- Attachment sets: six sets with names, head and frame pickers with icons, a scrollable list of every
  attachment you have learned, affinity totals that stop you going over capacity, a one-click
  *Equip now* (deactivate, apply the set, reactivate), *Use current* and *Clear set*
- Overload: a burden meter read from the game's overload-chance messages, an optional overload maneuver set, and red / rainbow effects on the minimized bar for Overload and Overdrive
- Fully hidden when your main job is not PUP

## Install

Copy the `puphq` folder to `Ashita\addons\`, then in game:

    /addon load puphq

## Commands

| Command | What it does |
| --- | --- |
| `/puphq config` | open or close the config panel (works on any job) |
| `/puphq ad toggle` | toggle Auto Deploy |
| `/puphq toggle` | enable or disable |
| `/puphq manset next` / `prev` / `1` / `2` / `3` | change the maneuver set |
| `/puphq debug` | show what Auto Repair sees and print each attempt (toggle) |

## Notes

- Changing attachments needs the automaton put away; *Equip now* does that for you.
- Equipping uses the game's own function, one slot at a time with a short delay between slots.
- Not affiliated with Square Enix.

## Licence

GPL-3.0-or-later, the same licence as pupsets, from which part of this code is derived. See `LICENSE`.
