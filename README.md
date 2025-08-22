## Warptorio (Space Age)

Hi, I liked the original concept of this mod but no-one made it work in 2.0 so I just did it myself.
Enjoy.

## New Features

* Balanced and added a bunch of vanilla researches but less that warptorio 2 (they are no longer needed with quality research).
* Fixed a bunch of essential bugs: Original warptorio did not play well with new QOL so it was redesigned to account for that
* Added support for all planets + their research. If you want more planets feel free to add them in a same way like you would to normal space exploration.
* Overhaul: Floors were completely changed to account for gameplay centered around various planets. Now your main floor will be ground (so you can research planet specific things)
* Overhaul: Science has been completely reworked now with special end game research that will fully test your platform
* Overhaul: Re-worked how power delivery works to make it easier in early game
* Overhaul: Re-worked enemies to make them possible on all planets. Feel free to add other enemy mods, if it is too easy
* New Feature: Warptorio does not start untill you research green science or warp platform, to let you stockup on resources


## Special thanks

*  Nonoce for originally creating this fantastic mod - https://mods.factorio.com/mod/warptorio
*  PyroFire for expanding on the original mod - https://mods.factorio.com/mod/warptorio2
* Jimmyster for  the text translation
* PreLeyZero For creating assets for Exotic industries that I could use to make things look better 

## Discord

Since people wanted discord to talk about this (and some even found my personal server) I am putting it here as well (It now has channel for warptorio)
[Discord Link Here](https://discord.gg/rUcDrB84y8)

## Interfaces

Starting with 0.2.8 there is now interface to add better support for more planet variants

Here is short tutorial how to do it.

1. Install mods that you want this variant to be based on
2. Select new single player game and using the sliders for generating new planet create the variant that you want (make sure to check all planets if you are making variant for more that one)
3. Start a new game and go to edit mode (/editor)
4. Generate all surfaces (Surfaces -> Generate planets)
5. Run this command  ```/c for k,v in pairs(game.surfaces) do helpers.write_file(k.."_{your_variant_name}.json",helpers.table_to_json(game.surfaces[k].map_gen_settings)) end ```
6. locate new variants in .factorio/script-output and transform them from json back to lua
7. Make a mod that depends on warptorio
8. In your mod add your variants using this remote interface  ```remote.call("warptorio", "edit_planet_variants", variant,planet,map_gen_settings)```
