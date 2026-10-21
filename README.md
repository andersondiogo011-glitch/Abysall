# Abysall Hub is a free, open-sourced script hub I made because scripting is fun.
If you want to try it for yourself:
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/andersondiogo011-glitch/Abysall/refs/heads/main/Loader.luau"))()
```
Feel free to use any of the source code for your own projects, but credit would be appreciated.


## Fork: map tools

Open **Map Tools** during a run. There are sections for The Outdoors, The Backdoor,
The Archives, Stairwell, and The Mines. Only the detected map's shortcuts are
editable. They mirror the existing controls and retain their entity filters.

- **Outdoors:** Eyestalk path and anti-Snare shortcuts; nearby gate/vine-lever
  interaction; experimental local hitbox touch suppression for recognized
  Groundskeeper, Monument, and Bramble models.
- **Backdoor:** Lookman/Vacuum bypass and auto-hide shortcuts, time-lever
  interaction, and a low-time warning that rearms after gaining time.
- **Mines:** Giggle/Gloombat/Seek bypass shortcuts, anchor and minecart automation,
  nearby gate/pump interaction, and experimental Grumble hitbox touch suppression.
- **Archives and Stairwell:** shared ESP controls and the generic tools below.
  Their specific entities, internal floor names, and puzzles have not been
  verified in Roblox. No dedicated entity bypass or puzzle solver is claimed.

Shared tools add nearby interaction markers, detected-entity markers, distance
alerts with a cooldown, and opt-in objective interaction within the prompt's
normal range and line of sight. Custom entity/objective fields accept exact,
comma-separated model names, useful for inspecting support in newer maps.
Unknown models are not automatically treated as hostile. The `Entity = true`
attribute also enables entity markers and alerts, but not touch suppression.

Touch suppression affects only `Hitbox` / `DamageHitbox` parts of supported or
explicitly named entity models. It restores their original `CanTouch` values
when disabled, on death, or on unload. It does **not** guarantee protection from
server-side damage, remote-based attacks, or entities with different hitboxes.
New controls default to off. Existing bypasses still depend on game version and
executor support.

The fork's loaders and internal URLs now point to this fork. Original authorship
and license remain in place.

## Validation

Run `texlua tests/floor_tools_test.lua` (or `lua tests/floor_tools_test.lua` with
Lua 5.3+). The mocked runtime checks map detection, synchronized controls,
markers, alert cooldowns, touch restoration, timer rearming, and prompt limits.
Use `luau-compile` to check Luau syntax. These checks do not replace an in-game
Roblox test; no live game or executor was available during development.
