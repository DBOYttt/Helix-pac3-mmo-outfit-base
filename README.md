# PAC MMO Outfit Plugin - Documentation

## Overview

The **PAC MMO Outfit** plugin provides a *base item* that supports:
- **Stats or “Look Only” equip modes**  
- **PAC3 integration** for customizing player appearance  
- **Random attribute generation** using a discrete geometric distribution so that higher values become exponentially rarer  
- **Persistent item data** across server restarts  

This plugin is especially useful if you want to create MMO-style equipment where a small set of item templates yield a large variety of randomized stats.

---

## Installation

1. **Place the Plugin Folder**  
   Copy the plugin folder (e.g. `pacmmooutfit/`) into your server’s `plugins/` directory.  
2. **Ensure It Loads**  
   In your main `sh_plugin.lua` (within the plugin folder), you should have something like:
   ```lua
   PLUGIN.name = "PAC MMO Outfit Plugin"
   PLUGIN.author = "DBOY"
   PLUGIN.description = "Provides a PAC outfit base with MMO-style random attributes."

   ix.item.LoadFromDir("plugins/pacmmooutfit/items")
   ```
3. **Restart Your Server**  
   Helix will automatically discover the base item file in `items/base/` and register it as `"base_pacmmooutfit"`.

---

## The Base Item

The base item file is typically located at:

```
plugins/pacmmooutfit/items/base/sh_pacmmooutfit.lua
```

Within it, you’ll find a Helix item definition (named `"PAC Outfit Base"`) that implements:

1. **Equip / Unequip** logic for Stats or “Look Only” mode.  
2. **PAC3 functions** (`ShowPAC`, `HidePAC`, etc.) so the player’s appearance updates accordingly.  
3. **Random attribute generation** (`GenerateRandomAttributes`) using a **discrete geometric distribution**.  
4. **Hook overrides** to preserve item data across restarts and prevent transferring equipped items.

### Random Attribute Generation

The base item allows child items to define an `attribRanges` table, specifying minimum and maximum values for each attribute. For example:

```lua
ITEM.attribRanges = {
    ["str"] = {min = 1, max = 50},
    ["arm"] = {min = 1, max = 50},
    ["end"] = {min = 1, max = 50},
    ["stm"] = {min = 1, max = 50}
}
```

When an item instance is created, the code **randomly chooses a value** for each attribute between `min` and `max`, with **higher values becoming exponentially less likely**. The resulting random attributes get saved in the item’s data (`SetData("attributes", ...)`) so that they persist across server restarts.

> **Note:**if you not sure what your attribs names are type that command in console `lua_run PrintTable(ix.attributes.list)` it will print your all attributes tables

---

## Creating Child Items

To create a new item that uses this base:

1. **Folder & File Name**  
   In your plugin’s `items/` subfolder (or a new subfolder therein), create a file named `sh_<some_name>.lua`.   
2. **Example item look:**  
   If you want random attributes, define a table specifying the minimum and maximum values:
   ```lua
    ITEM.name = "Inquisitor's cheast"
    ITEM.description = ""
    ITEM.uniqueID = "inq_chest"
    ITEM.outfitCategory = "chest"
    ITEM.model = "models/player/xozz/hydra/inquisitor/inquisitormale_01.mdl"
    ITEM.Base = "base_pacmmooutfit"

    ITEM.width = 1
    ITEM.height = 1
    ITEM.iconCam = {
	   pos = Vector(210.69, -0.31, 8.74),
	   ang = Angle(-11.45, -180.07, 0),
	   fov = 5.88
    }

    ITEM.width = 1
    ITEM.height = 1
    ITEM.attribRanges = {
	  ["str"] = {min = 1, max = 50},
	  ["stm"]  = {min = 1,  max = 50},
	  ["arm"]  = {min = 1,  max = 50},
	  ["end"] = {min = 1,  max = 50}
    }

   ITEM.pacData = {}
   }
   ```

### Equip Modes

When a player right-clicks the item in their inventory, they’ll see:
- **Equip (Stats)** – Applies the item’s random attributes (or fixed boosts) to the player’s stats and shows the PAC3 appearance.  
- **Equip (Look Only)** – Changes only appearance (PAC3), no stat boosts.  
- **Unequip** – Removes the item from either Stats or Look Only mode.

---

## The Probability Equation

Our discrete geometric distribution picks each attribute value in `[min, max]` such that **each successive integer is half as likely as the previous**. For an integer range `1` to `N`, you can define:

![image](https://github.com/user-attachments/assets/741d2068-f907-4760-8ab4-648bc252281f)
where `x` ranges from 1 to `N`.  

#### Explanation

1. We treat the lowest value (1) as having the highest probability.  
2. For each increment above 1, the chance is halved relative to the previous number.  
3. **Summation:**  
![image](https://github.com/user-attachments/assets/079b6068-cae6-4ddd-afd3-a80248ea7ecb)
4. **Normalization:**  
![image](https://github.com/user-attachments/assets/63e5f9fc-ec78-4ee8-afcb-170afecbb70d)
5. **Implementation:**  
   In code, we do something like:
   ```lua
   local total = 0
   for i=0, (N-1) do
       total = total + (0.5)^i
   end
   local r = math.random() * total
   local cum = 0
   for i=0, (N-1) do
       cum = cum + (0.5)^i
       if r <= cum then
           return 1 + i
       end
   end
   return N
   ```
   Which ensures each value in `[1..N]` is chosen with its geometric probability.

---

## Example

Imagine we define:

```lua
ITEM.attribRanges = {
    str = {min = 1, max = 50}
}
```

- The chance to get **`str=1`** is the highest.  
- The chance to get **`str=2`** is about half of that.  
- The chance to get **`str=3`** is about half of `str=2`, and so on… making **`str=50`** extremely rare.

When the player **equips** the item in “stats” mode, it applies that chosen value to their Strength attribute. Then, if you view the item’s description, you’ll see something like:

```
Example Random Armor

(Equipped in 'stats' mode, grants:)
Strength: +3
```

---

## Troubleshooting

- **Non-existent Base Error**:  
  Make sure the file is named `sh_pacmmooutfit.lua` and placed in `items/base/`. Helix will auto-register it as `base_pacmmooutfit`.  
- **Create items in plugin area**
  make sure you placed your items files in `plugins/pacmmooutfit/items/pacmmooutfit` directory
- **Stats Not Applying**:  
  Check that you used “Equip (Stats),” not “Equip (Look Only).”  
- **No Attributes Display in Description**:  
  Confirm your child item defines `attribRanges` and that the base generated them on instance creation (`OnInstanced`).  
- **PAC3 Conflicts**:  
  If multiple items share the same PAC3 `UniqueID`, they may conflict. Update the `ITEM.pacData` to ensure unique `"UniqueID"` values.  

 
