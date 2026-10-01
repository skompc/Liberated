This is my WIP private server for Shin Megami Tensei:Dx2

Follow along on my dev journey at https://www.youtube.com/watch?v=yyznmOjwHMI&list=PLV4ay6xrx8nRm06QnXDBUYqTn3Xk_-wdr

The completed server will aim to have the game fully operational, excluding multiplayer components

It should be noted that this is a rewrite of my second attempt into php

The uploaded code will NOT have game assets from Sega's servers. There is an asset scraper however.

# First Steps
Install the DNS Changer apk that is in the root directory on your phone.

# Get The Server
Download a build for your OS from the [Actions](https://github.com/skompc/Liberated/actions) tab (open the latest "Build Liberated" run and grab the artifact), or build it yourself:

| OS | Build command | Output |
| --- | --- | --- |
| Windows | <code>powershell -ExecutionPolicy Bypass -File .\build-windows.ps1</code> | <code>dist\Liberated-windows\Liberated.exe</code> |
| macOS | <code>./build-mac.sh</code> (needs Xcode Command Line Tools) | <code>dist/Liberated.app</code> |
| Linux | <code>./build-linux.sh</code> (needs build-essential + curl) | <code>dist/Liberated-linux/Liberated</code> |

Everything (nginx, PHP, Python, configs and the site) lives inside that app/folder. Delete it and it's gone.

# Run The Server
Launch Liberated. The first time, it will offer to download the game assets (this takes a while). You can re-run the download later with the "Update Assets" button.

Asset download settings (check code, language, platform) come from <code>scraper/scraper-config.json</code> at build time (see <code>scraper/scraper-config-values.txt</code> for possible values). To change them after building, edit the copy inside the build at <code>resources/scraper/scraper-config.json</code> (on macOS: <code>Liberated.app/Contents/Resources/scraper/</code>).

Note the IP address that Liberated shows you.

On Linux, Liberated will ask for your password because ports 53/80/443 need root there.

The files that get served are in ./web/html/

# Connect To The Server
Use the included DNS changer app to change your phones DNS to the IP address that you found earlier

If this is your first time connecting to the server, then go to <code>liberated.dx2</code> in your web browser and follow the directions for android devices. If it warns you about privacy or something like that click "advanced" then continue.

# What works
. Tutorial

. Story Battles On Normal Difficulty (not chapter 2.5)

. Story Battles On Hard Difficulty (not chapter 2.5)

. Story Review

. Basic Party Management

. Alterworld

. Demon Maker

. Fusion

# What Doesn't
. Story Battles On Hell Difficulties

. Aura Gate

. Pandemonium

. Gacha/Summoning

. Everything Else

# Known bugs

1. Any unimplemented endpoints will softlock the game. Simply restart the app.
2. Story choices don't matter... just choose the path you want... I won't fix this!
3. Results screen is inaccurate sometimes. Just ignore until I implement everything...
4. Fusion doesn't consume the demons you put in... LIKELY WON'T FIX!

# FAQ

Q: The app isn't fetching the assets I downloaded

A: Click "Update Assets" in Liberated (see [Run The Server](#run-the-server)) and let the download finish

----------------------------------------------

Q: I don't have a computer that I can do this with! Can I still run the server?

A: No... you need a computer for running the server... I will make an android version at some point...

----------------------------------------------

Q: Will iOS devices be supported?

A: ~~Unfortunately no.~~ Actually I just got a Mac and an iPhone to test with so now it's a maybe!

# Relevent links:

Youtube - https://www.youtube.com/@SquirrelDevDiaries
Github - https://github.com/skompc

# Extra Thanks!
Extra credit to @lukefz on Discord for helping me finally crack the decryption function! Their github is https://github.com/LukeFZ
