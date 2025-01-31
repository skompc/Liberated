This is my WIP private server for Shin Megami Tensei:Dx2

Follow along on my dev journey at https://www.youtube.com/watch?v=yyznmOjwHMI&list=PLV4ay6xrx8nRm06QnXDBUYqTn3Xk_-wdr

The completed server will aim to have the game fully operational, excluding multiplayer components

It should be noted that this is a rewrite of my second attempt into php

The uploaded code will NOT have game assets from Sega's servers. There is an asset scraper however.

# First Steps
Make sure you have nodejs installed (https://nodejs.org/en/download/).

Run <code>git clone https://github.com/skompc/Liberated.git</code> to copy this repo to your pc.

Run <code>npm install</code> to install dependencies for the scraper.

Install the DNS Changer apk that is in the root directory.

# Scrape The Assets

Run <code>node ./scraper.js</code> to fetch assets.

copy everything from <code>./contents/Android/(asset_bundle_version)</code> to a new folder called <code>./contents/Android/custom</code>

edit the first line of <code>./contents/Android/custom/en/ab_list.txt</code> from whatever it is to <code>custom</code>

copy/move the <code>./contents</code> folder over into <code>./nginx/html</code>

# Run The Server

Run <code>start.bat</code>

Note the IP address that is listed in the DNS Server window

# Connect To The Server
Use the included DNS changer app to change your phones DNS to the IP address that you visited earlier

If this is your first time connecting to the server, then go to <code>liberated.local</code> in your web browser and follow the directions for android devices. If it warns you about privacy or something like that click "advanced" then continue.

# What works
. Tutorial

. Story Battles On Normal Difficulty

. Story Battles On Hard Difficulty (Season 2 not available for now...)

. Story Review

. Basic Party Management

# What Doesn't
. (Some) Story Battles On Harder Difficulties

. Fusion

. Gacha/Summoning

. Everything Else

# Known bugs

1. Any unimplemented endpoints will softlock the game. Simply restart the app.
2. Story choices don't matter... just choose the path you want... I won't fix this!
3. Results screen is inaccurate. Just ignore until I implement everything...

# FAQ

Q: The modded version of the app isn't fetching the assets I downloaded

A: Make sure to do all the steps in [Scrape The Assets](#scrape-the-assets)

----------------------------------------------

Q: How do I patch the game!

A: There is a video on my YouTube channel on how to do this [here](https://youtu.be/U4BZSEMW9XM)

----------------------------------------------

Q: I don't have a computer that I can do this with! Can I still patch the app myself?

A: No... you need a computer for both patching and running the server.

----------------------------------------------

Q: Will iOS devices be supported?

A: Unfortunately no.

# Relevent links:

Youtube - https://www.youtube.com/@SquirrelDevDiaries
Github - https://github.com/skompc

# Extra Thanks!
Extra credit to @lukefz on Discord for helping me finally crack the decryption function! Their github is https://github.com/LukeFZ
