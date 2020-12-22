# DVMMO

DVMMO aims to demonstrate the core risks which are detailed in the [OWASP Game Security Framework](https://owasp.org/www-project-game-security-framework/).

# Project Goals

The project aims to align with the OWASP Game Security Framework to serve as a practical demonstration of the concepts defined within. The project also aims to implement the following systems with various deliberate vulnerabilites:

- [ ] Point Capture game mode
- [ ] User accounts
- [ ] Embedded cosmetics store page

The project also aims to be an actually playable game in addition to serving as a deliberatly vulnerable hacking target.

## High level design
This relies on an aspect of Godot's export system called "Features." Each export template specifies which Features it supports, such as Windows, 64 bit, PC vs Mobile, etc.

These are the built-in features, but Godot also allows you to specify your own custom features. So you could, for instance, have two different Windows Export Presets, and they could each contain different custom Features that you specify.

Importantly, the presence of these features can be queried at runtime:

``` OS.has_feature("X") ```

You probably see where this is going now.

We can have two different export templates, and each has it's own custom feature: `client` for one, and `server` for the other.

Our `Main Scene` will be a simple `Entry` scene that detects which feature is present, and then launches into a different Scene accordingly.

The Client will launch into a Main Menu, and the Server will launch into a Lobby scene, where it will open a port and begin listening for clients.


# Project Structure
```
root/
|
- common
- client
- server
```

**common** contains the bulk of the game code. This is all of the code that runs on both client and server. This is where the real benefit of this architecture comes from.


## Client/Server specific code
Each scene in `common` will have a corresponding inherited scene in both client and server. This allows you to do client or server specific stuff quite easily.

The scenes are named to prevent confusion in an editor so:
```
common/Lobby.tscn
client/ClientLobby.tscn
server/ServerLobby.tscn
```

So the only trick here is that scene transitions must be in the inherited scenes, since the server will change to `ServerGame.tscn` and clients will change to `ClientGame.tscn`. This can be accomplished easily with overriden methods or signals.

## Running on a headless machine
If this was for some real game, the server likely would be on a headless machine. To accommodate this, we can use Godot's server export template. It is a graphicsless version of Godot, and will not attempt to open a window or use any graphics API.

This means you can easily run the dedicated server on a headless Linux box.

https://godotengine.org/download/server

## Exporting the Linux Server
In the **Export Project** dialog, click on the **Linux Server** preset. Then export the pack file, not the full Export Template.

You can then run the dedicated server as such:
```
./Godot_v3.2-stable_linux_server.64 --main-pack Server.pck
```

## Down sides
- This will still load all of the graphical assets, so it will not be as slim in memory as it could possibly be in the two project approach.