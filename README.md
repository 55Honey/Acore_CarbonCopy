## CarbonCopy
LUA script for Azerothcore with ElunaLUA to allow players to keep copies of their characters at a stage, e.g. for twink pvp.

WIP - not fully tested

## Requirements:

Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
The ElunaLua module itself usually doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed, add the .lua script to your `../bin/release/lua_scripts/` directory.
Adjust the top part of the .lua file with the config flags.
On first startup of the core, a scheme specified in the config part of the .lua file will be created.

You need to grant account related tickets in its `carboncopy` table:
- `account_id` refers to the unique guid of the account.
- `tickets is the # of times a player can copy a character`
- `allow_copy_from_id` is reserved for future use. 

## PLAYER USAGE:
- create a new character with same class/race as the one to copy in the same account. Do NOT log it in
- log in with the source character
- while logged in on the character to copy, do `.carboncopy newToonsName`

What it does:
- Delete the new characters starter gear, except the Homestone.
- Send copies of all items worn to the new character by mail.
- Grant the new character the sources level, xp, discovered flightmasters, /played, stats, explored zones, homebind
- Grant a copy of the pet and previously bought stable slots
- Complete all quests on the new character, which the source has completed already
- Grant the new character all gained reputation, talents, glyphs, spells and skills
- **Place all actions on the new characters bars. If you copy your macro data from one characters /wtf/ directory to the other, you do not need to setup macros either.**

What it **NOT** does:
- No items from bags/bank are copied. All starter gear is deleted except the homestone.
- No gold is copied. The new character will be at zero copper.
- No achievements are copied. Achievements were made with the source characters and are reserved to them.