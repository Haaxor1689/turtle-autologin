# Turtle AutoLogin

Patch for Turtle WoW client that adds auto login and account info saving features.

> This patch saves your login info into `\WTF\Config.wtf` so keep in mind that it will **contain your passwords** and thus you should think before sharing this file with someone else.

## Features

- Adds an Accounts select panel to the login screen
- Automatically adds accounts with saved login info to the list
- Select accounts to log in (double-click to login directly)
- Check "Auto-login this character" in character select screen to always automatically load into game with this character selected in future logins
- Remove saved character and accounts with controls at the bottom

## Installation

Download the repo and unpack it in such a way that the files end up in your WoW folder like this:
```
Data\Interface\GlueXML\AccountLogin.lua
Data\Interface\GlueXML\AccountLogin.xml
Data\Interface\GlueXML\Accounts.lua
Data\Interface\GlueXML\CharacterSelect.lua
Data\Interface\GlueXML\CharacterSelect.xml
```

## Advanced usage

To store as many logins as you like open the `\Data\Interface\GlueXML\Accounts.lua` file and add your own logins to the file, these will be used instead of the above `Config.lua` entry which has a limit to how much it can store.

---
* Edited for Weird Vibes
## Orignal author [Haaxor1689](https://github.com/Haaxor1689)