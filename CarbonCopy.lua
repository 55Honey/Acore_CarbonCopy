--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 18/02/2021
-- Time: 23:28
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module

------------------------------------------------------------------------------------------------
-- USAGE:   - create a new character with same class/race as the one to copy in the same account
--          - log in with the source character
--          - .carboncopy newToonsName
------------------------------------------------------------------------------------------------


local Config = {};

-- Name of Eluna dB
Config.customDbName = 'ac_eluna';
-- Min GM Level to use the .carboncopy command. Set to 0 for all players.
Config.minGMRankForCopy = 2;
-- Min GM Level to add tickets to an account.
Config.minGMRankForTickets = 3;
-- Max number of characters per account
Config.maxCharacters = 10;


------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- If module runs for the first time, create the db specified in Config.dbName and add the "carboncopy" table to it.
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`carboncopy` (`account_id` INT(11) NOT NULL, `tickets` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');



local function CopyCharacter(event, player, command)
    local commandArray = cc_splitString(command)
    --for n,_ in pairs(commandArray) do
    --    print(n.."a: "..commandArray[n])
    --end
    if commandArray[1] == "carboncopy" then
        -- make sure the player is properly ranked
        if player:GetGMRank() < Config.minGMRankForCopy then
            return false
        end

        --check for available tickets
        local accountId = player:GetAccountId()
        --print("1: "..accountId)
        local Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
        local availableTickets = Data_SQL:GetUInt32(0)
        --print("2: "..availableTickets)
        Data_SQL = nil
        if availableTickets ~= nil and availableTickets <= 0 then
            player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command.")
            return false
        end

        --check for target character to be on same account
        local playerGUID = tostring(player:GetGUID())
        playerGUID = tonumber(playerGUID)
        --print("3: "..playerGUID)
        local targetName = commandArray[2]
        local Data_SQL = CharDBQuery('SELECT `account` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
        local targetAccountId = Data_SQL:GetUInt32(0)
        Data_SQL = nil
        if targetAccountId ~= accountId then
            player:SendBroadcastMessage("The requested character is not on the same account.")
            return false
        end

        --check for target character to be same class/race
        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
        local sourceRace = Data_SQL:GetUInt32(0)
        local sourceClass = Data_SQL:GetUInt32(1)
        Data_SQL = nil

        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `name` = '..targetName..' LIMIT 1;');
        local targetRace = Data_SQL:GetUInt32(0)
        local targetClass = Data_SQL:GetUInt32(1)
        Data_SQL = nil

        if sourceRace ~= targetRace then
            player:SendBroadcastMessage("The requested character is not the same race as this character.")
            return false
        end
        if sourceClass ~= targetClass then
            player:SendBroadcastMessage("The requested character is not the same class as this character.")
            return false
        end


        local QueryString = 'UPDATE `characters` AS t1'
        QueryString = QueryString..'INNER JOIN `character` AS t2 ON t2.guid = '..playerGUID..' '
        QueryString = QueryString..'SET t1.level = t2.level, t1.xp = t2.xp, t1.taximask = t2.taximask, t1.totaltime = t2.totaltime,'
        QueryString = QueryString..'t1.leveltime = t2.leveltime, t1.stable_slots = t2.stable_slots, t1.health = t2.health, '
        QueryString = QueryString..'t1.power1 = t2.power1, t1.power2 = t2.power2, t1.power3 = t2.power3, t1.power4 = t2.power4, '
        QueryString = QueryString..'t1.power5 = t2.power5, t1.power6 = t2.power6, t1.power7 = t2.power7, t1.talentGroupsCount = t2.talentGroupsCount, '
        QueryString = QueryString..'t1.exploredZones = t2.exploredZones` WHERE t1.name = `'..targetName..'`;'

        local Data_SQL = CharDBQuery(QueryString);
        QueryString = nil
        Data_SQL = nil




        print("The player with GUID "..playerGUID.." has succesfully used the .carboncopy command. ");
        player:SendBroadcastMessage("Character copied.")
    end
    return false
end


--Todo: Register a command to let staff add CarbonCopy tickets (And/or offer it as a shop service, increasing tickets by 1 for X amount of points)

-- Todo: Read the players equipped items and duplicate them. Make the new toon owner.
   -- Todo: also read: talents, glyphs, achievements and queststates. Do not copy gold in the saved data. Also ignore bags and items in bags including bagpack.



function cc_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end


local PLAYER_EVENT_ON_COMMAND = 42
-- function to be called when the command hook fires
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, CopyCharacter)