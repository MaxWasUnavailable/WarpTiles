# WarpTiles
A simple tile teleportation mod for Project Zomboid.

There are 2 types of tiles:
- Source tile: the tile you want to teleport from
- Destination tile: the tile you want to teleport to

There are two possible configurations:
- One source tile and one destination tile
- Two source tiles

## One source tile and one destination tile
This is the simplest configuration. You can teleport from the source tile to the destination tile.

This is a one-way teleportation system.

## Two source tiles
This configuration is a bit more complex. You can teleport from the first source tile to the second source tile. You can also teleport from the second source tile to the first source tile.

This is a two-way teleportation system.

## How to use
1. Right-click on a tile to open the context menu and set it as a source tile 
2. Right-click on another tile to either set it as a destination tile (1-way) or as a second source tile (2-way)

To remove, right-click on a tile and select "Remove warp tile". This will remove both linked tiles.