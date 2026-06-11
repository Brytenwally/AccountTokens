# Account Tokens

An Eluna Lua script for AzerothCore that gates specific Playerbot commands (`autogear` and `maintenance`) behind account-wide tokens earned via leveling milestones.

## Requirements

* **AzerothCore** (WOTLK 3.3.5a)
* **mod-playerbots**
* **mod-ale** 

## Setup

### 1. Database Table
Run the SQL Query on your **`acore_characters`** database:


### 2. Script Installation
Place the .lua file inside your server's ../lua_scripts/ directory.
Restart the server or type .reload ale.



### Configuration
Modify the CONFIG block at the top of the script to change values:

LevelsPerToken: Level intervals required to earn tokens (e.g., every 10 levels).

AutogearTokensGranted / MaintenanceTokensGranted: Tokens given at milestones.

AutogearTokenCost / MaintenanceTokenCost: Tokens deducted per command use.

In-Game Usage:

Type "tokens"  in party chat to check your account balance.

Commands are automatically intercepted and will block if you do not have enough tokens.
