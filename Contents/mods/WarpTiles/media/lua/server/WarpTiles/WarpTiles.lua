---
--- Created by Max
--- Created on: 24/09/2023
---

-- Mod class
---@class WarpTiles
WarpTiles = {}

-- Mod info
WarpTiles.modName = "WarpTiles"
WarpTiles.modVersion = "1.0.1"
WarpTiles.modAuthor = "Max"
WarpTiles.modDescription = "Adds one-way and two-way warp tile systems to the game."

-- Mod data keys
WarpTiles.modDataKey = "WarpTiles"

-- Mod data access
--- Get the mod data table.
---@return KahluaTable
WarpTiles.getModData = function()
    ModData.request(WarpTiles.modDataKey)
    return ModData.getOrCreate(WarpTiles.modDataKey)
end

--- Sync the mod data table to the server & clients.
WarpTiles.syncModData = function()
    ModData.transmit(WarpTiles.modDataKey)
end

-- Mod Types

--- Enum for the different types of warp tiles.
WarpTiles.tileType = {
    source = "WarpTiles.WarpTileSource",
    destination = "WarpTiles.WarpTileDestination"
}

--- Table to store in-progress links. Format is playerID: {tile, tileType}
WarpTiles.inProgressLink = {}

-- Permission helpers

---@class AccessLevelEnum
---Enums representing different access levels.
---admin, moderator, overseer, gm, observer, none
AccessLevelEnum = {
    none = 1,
    observer = 2,
    gm = 3,
    overseer = 4,
    moderator = 5,
    admin = 6
}

---@return number
---@param access_level string
local function stringToEnumVal(access_level)
    for i, v in pairs(AccessLevelEnum) do
        if i == access_level:lower() then
            return v
        end
    end
    -- Default to none
    return 1
end

---@return boolean
---@param sandbox_value number
local function hasAccess(sandbox_value)
    local access_level = getAccessLevel()
    if access_level == "admin" then
        return true
    end
    local required_access = sandbox_value
    if required_access == nil then
        print("WarpTiles: hasAccess() - Sandbox value is nil.")
        return false
    end
    -- Convert the access level to a number using the enum
    access_level_val = stringToEnumVal(access_level)
    -- Check if the player has the required access level or higher
    if access_level_val >= required_access then
        return true
    end
    return false
end

-- Mod core functions

--- Check if a player has a link in progress.
---@param _player Integer
--- To be used as the key for the inProgressLink table.
---@return Boolean
WarpTiles.hasLinkInProgress = function(_player)
    return WarpTiles.inProgressLink[tostring(_player)] ~= nil
end

--- Convert a tile to an x,y,z table.
---@param _tile IsoObject
--- The tile to be converted.
---@return table
--- An x,y,z table representing the tile.
WarpTiles.toXYZTable = function(_tile)
    return {
        x = _tile:getX(),
        y = _tile:getY(),
        z = _tile:getZ()
    }
end

--- Check if two x,y,z tables are equal.
---@param _table1 table
--- An x,y,z table to be compared.
---@param _table2 table
--- An x,y,z table to be compared.
---@return Boolean
--- True if the tables are equal, false otherwise.
WarpTiles.XYZTableEquals = function(_table1, _table2)
    return _table1.x == _table2.x and _table1.y == _table2.y and _table1.z == _table2.z
end

--- Save mod data for a tile.
---@param _tile table
--- An x,y,z table representing a tile for which to save mod data.
---@param _thisLink table
--- The link information for the tile representation being saved.
---@param _otherLink table
--- The link information for the tile representation being linked to.
WarpTiles.saveTileData = function(_tile, _thisLink, _otherLink)
    -- TODO: should probably take an IsoObject instead of a table
    if _thisLink.tileType == WarpTiles.tileType.source then
        print("Saving source tile data for tile " .. _tile.x .. ", " .. _tile.y .. ", " .. _tile.z)

        local tile = getCell():getGridSquare(_tile.x, _tile.y, _tile.z)
        tile:getModData().WarpTiles = _otherLink.tile

        tile:transmitModdata()
    end
end

--- Remove mod data for a tile.
---@param _tile table
--- An x,y,z table representing a tile for which to remove mod data.
WarpTiles.removeTileData = function(_tile)
    -- TODO: should probably take an IsoObject instead of a table
    print("Removing tile data for tile " .. _tile.x .. ", " .. _tile.y .. ", " .. _tile.z)

    local tile = getCell():getGridSquare(_tile.x, _tile.y, _tile.z)
    local tileData = tile:getModData().WarpTiles

    if not tileData then
        print("ERROR: No tile data found to remove for tile " .. _tile.x .. ", " .. _tile.y .. ", " .. _tile.z)
        return
    end

    tile:getModData().WarpTiles = nil

    tile:transmitModdata()
end

--- Check if a tile has a link.
---@param _tile IsoObject
--- The tile to be checked for a link.
---@return Boolean
WarpTiles.tileHasLink = function(_tile)
    local tileData = _tile:getModData().WarpTiles

    if not tileData then
        return false
    end

    return true
end

--- Get the destination of a tile.
---@param _tile IsoObject
--- The tile for which to get the destination.
---@return table
--- An x,y,z table representing the destination of the tile.
--- Returns nil if no destination is found.
WarpTiles.getTileDestination = function(_tile)
    local tileData = _tile:getModData().WarpTiles

    if not tileData then
        print("ERROR: No tile data found for tile " .. _tile:getX() .. ", " .. _tile:getY() .. ", " .. _tile:getZ())
        return nil
    end

    return tileData
end

--- Save a link between two tiles. Requires an in-progress link to exist.
---@param _player Integer
--- To be used as the key for the inProgressLink table.
---@param _tile IsoObject
--- The tile to be linked to the in-progress link.
---@param _tileType String
--- The type of tile to be linked to the in-progress link.
WarpTiles.saveLink = function(_player, _tile, _tileType)
    local inProgressLink = WarpTiles.inProgressLink[tostring(_player)]
    local playerObj = getSpecificPlayer(_player)
    if not inProgressLink then
        print("ERROR: No link in progress for player " .. playerObj:getUsername() .. " while trying to save link.")
        WarpTiles.cancelLink(_player)
        return
    end

    local firstLink = {
        tile = WarpTiles.toXYZTable(inProgressLink[1]),
        tileType = inProgressLink[2]
    }

    local secondLink = {
        tile = WarpTiles.toXYZTable(_tile),
        tileType = _tileType
    }

    print("Saving link (performed by " .. playerObj:getUsername() .. ")")

    local link = {
        source = firstLink,
        destination = secondLink
    }

    WarpTiles.saveTileData(firstLink.tile, firstLink, secondLink)
    WarpTiles.saveTileData(secondLink.tile, secondLink, firstLink)

    local linkTable = WarpTiles.getModData()

    table.insert(linkTable, link)

    WarpTiles.syncModData()

    print("Link saved")
    HaloTextHelper.addText(playerObj, "Warp link saved!", HaloTextHelper.getColorGreen())

    print("DEBUG: There are now " .. #linkTable .. " links in the link table.")

    WarpTiles.cancelLink(_player)
end

--- Remove a link between two tiles from the link table.
---@param _tile IsoObject
--- The tile to be removed from the link table.
WarpTiles.removeLink = function(_tile)
    local linkTable = WarpTiles.getModData()

    for i, link in pairs(linkTable) do
        if WarpTiles.XYZTableEquals(link.source.tile, WarpTiles.toXYZTable(_tile)) or WarpTiles.XYZTableEquals(link.destination.tile, WarpTiles.toXYZTable(_tile)) then
            WarpTiles.removeTileData(link.source.tile)
            WarpTiles.removeTileData(link.destination.tile)

            table.remove(linkTable, i)
            WarpTiles.syncModData()

            print("Link removed at coordinate " .. _tile:getX() .. ", " .. _tile:getY() .. ", " .. _tile:getZ())
        end
    end

    print("ERROR: No link found to remove")
end

--- Create a link entry in the in-progress link table. If the player already has a link in progress, then the two tiles will be linked together through the saveLink function.
---@param _player Integer
--- To be used as the key for the inProgressLink table.
---@param _tile IsoObject
--- The tile to be linked to the in-progress link.
---@param _tileType String
--- The type of tile to be linked to the in-progress link.
WarpTiles.createLink = function(_player, _tile, _tileType)
    local playerObj = getSpecificPlayer(_player)
    if WarpTiles.tileHasLink(_tile) then
        -- If the tile already has a link, then we need to do nothing.
        -- TODO: might be redundant due to context menu options. Kept around for now just in case.
        HaloTextHelper.addText(playerObj, "Tile already has a link!", HaloTextHelper.getColorRed())
        return
    end
    if WarpTiles.hasLinkInProgress(_player) then
        -- If the player already has a link in progress, then we need to link the two tiles together.
        WarpTiles.saveLink(_player, _tile, _tileType)
    else
        -- If the player doesn't have a link in progress, then we need to create one.
        WarpTiles.inProgressLink[tostring(_player)] = {_tile, _tileType}
        HaloTextHelper.addText(playerObj, "Link started!", HaloTextHelper.getColorGreen())
    end
end

--- Cancel a link in progress. Simply removes the in-progress link.
---@param _player Integer
--- To be used as the key for the inProgressLink table.
WarpTiles.cancelLink = function(_player)
    if WarpTiles.hasLinkInProgress(_player) then
        -- If the player has a link in progress, then we need to cancel it.
        WarpTiles.inProgressLink[tostring(_player)] = nil
        print("In-progress link canceled for player " .. getSpecificPlayer(_player):getUsername())
    end
    -- If the player doesn't have a link in progress, then we don't need to do anything.
end

--- Warp a player to the destination of a tile.
---@param _player IsoPlayer
--- The player to be warped.
---@param _tile IsoObject
--- The tile to be warped to.
WarpTiles.warpPlayer = function(_player, _tile)
    local destination = WarpTiles.getTileDestination(_tile)

    if not destination then
        print("ERROR: No destination found for tile " .. _tile:getX() .. ", " .. _tile:getY() .. ", " .. _tile:getZ())
        return
    end

    _player:setPosition(destination.x, destination.y, destination.z)
    print("Player " .. _player:getUsername() .. " warped to " .. destination.x .. ", " .. destination.y .. ", " .. destination.z)
end

-- Context menu

--- Add the context menu options to the right click menu.
---@param _player Integer
---@param _context KahluaTable
---@param _square IsoGridSquare
local function addOptions(_player, _context, _square)
    if not hasAccess(SandboxVars.WarpTiles.MinimumRole) then
        return
    end

    if WarpTiles.tileHasLink(_square) then
        -- If the tile already has a link, then we can offer the option to remove it.
        _context:addOption("Remove Warp Link", _square, WarpTiles.removeLink)
        return
    end

    local linkText = "Start Warp Link"
    if WarpTiles.hasLinkInProgress(_player) then
        -- If the player already has a link in progress, then we can offer the option to cancel it.
        linkText = "Finish Warp Link"
        _context:addOption("Cancel Link", _player, WarpTiles.cancelLink)
        _context:addOption(linkText .. " (Destination)", _player, WarpTiles.createLink, _square, WarpTiles.tileType.destination)
    else
        -- TODO: Remove else once reliable system to prevent teleportation spam looping is implemented. (Time-based cooldown? Check to prevent teleportation from destination tile after teleportation --> Walk away from tile first?)
        _context:addOption(linkText .. " (Source)", _player, WarpTiles.createLink, _square, WarpTiles.tileType.source)
    end
end

-- Event hooks

--- Get the tile at the right click position, and add the context menu options to it by calling the addOptions function.
---@param _player Integer
---@param _context KahluaTable
---@param _worldObjects KahluaTable
local function contextMenuHook(_player, _context, _worldObjects)
    for i, v in ipairs(_worldObjects) do
        square = v:getSquare();
        if square then
            addOptions(_player, _context, square)
            return
        end
    end
end

--- Check if a player has moved onto a warp tile.
---@param _player IsoPlayer
local function checkForWarp(_player)
    local playerTile = _player:getCurrentSquare()

    if not playerTile then
        return
    end

    if WarpTiles.tileHasLink(playerTile) then
        WarpTiles.warpPlayer(_player, playerTile)
    end
end

-- Init

--- Initialize the mod and add event hooks.
local function init()
    Events.OnTick.Remove(init)

    Events.OnFillWorldObjectContextMenu.Add(contextMenuHook)
    Events.OnPlayerMove.Add(checkForWarp)

    WarpTiles.getModData()

    print(WarpTiles.modName .. " " .. WarpTiles.modVersion .. " initialized.")
end

-- Init hook

Events.OnTick.Add(init)