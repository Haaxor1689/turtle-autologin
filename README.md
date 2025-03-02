# Turtle AutoLogin

* Requires a recent enough version of [SuperWow](https://github.com/balakethelock/SuperWoW/), currently `>=1.4`  

Patch for Turtle WoW client that adds auto login and account info saving features.

> This patch saves your login info into `\Imports\logins.txt` so keep in mind that it will **contain your passwords** and thus you should think before sharing this file with someone else.  

> This patch is a replacement for patches like [vanilla-autologin](https://github.com/Haaxor1689/vanilla-autologin), remove them before using it.  

## Features

- Adds an Accounts select panel to the login screen
- Automatically adds accounts with saved login info to the list
- Select accounts to log in (double-click to login directly)
- Right click to toggle autologin for an account, auto-login will log directly into the last chosen character on login.
- - Alternatively check "Auto-login this character" in character select screen.
- Remove saved character and accounts with controls at the bottom

## Installation

Download the repo and unpack it in such a way that the files end up in your WoW folder like this:
```
Data\Interface\GlueXML\AccountLogin.lua
Data\Interface\GlueXML\AccountLogin.xml
Data\Interface\GlueXML\CharacterSelect.lua
Data\Interface\GlueXML\CharacterSelect.xml
```

---
* Created for Weird Vibes
* Orignal idea by [Haaxor1689](https://github.com/Haaxor1689)