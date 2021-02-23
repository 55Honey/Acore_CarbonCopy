--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 18/02/2021
-- Time: 23:28
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module

------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
--               -  grant account related tickets in the `carboncopy` table
-- PLAYER USAGE: 1) create a new character with same class/race as the one to copy in the same account. Do NOT log it in
--               2) log in with the source character
--               3) .carboncopy newToonsName
------------------------------------------------------------------------------------------------

local Config = {};

-- Name of Eluna dB scheme
Config.customDbName = 'ac_eluna';
-- Min GM Level to use the .carboncopy command. Set to 0 for all players.
Config.minGMRankForCopy = 2;
-- Min GM Level to add tickets to an account.
--Config.minGMRankForTickets = 3;
-- Max number of characters per account
Config.maxCharacters = 10;


------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- If module runs for the first time, create the db specified in Config.dbName and add the "carboncopy" table to it.
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`carboncopy` (`account_id` INT(11) NOT NULL, `tickets` INT(11) DEFAULT 0, `allow_copy_from_id` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');



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

        local Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE `name` = '..targetName..' LIMIT 1;');
        local targetGUID = Data_SQL:GetUInt32(0)
        Data_SQL = nil


        --check for target character to be same class/race
        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
        local sourceRace = Data_SQL:GetUInt32(0)
        local sourceClass = Data_SQL:GetUInt32(1)
        Data_SQL = nil

        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `guid` = '..targetGUID..' LIMIT 1;');
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

        -- TODO: Check for character not be logged in for once

        -- Copy characters table
        local QueryString = 'UPDATE `characters` AS t1'
        QueryString = QueryString..'INNER JOIN `character` AS t2 ON t2.guid = '..playerGUID..' '
        QueryString = QueryString..'SET t1.level = t2.level, t1.xp = t2.xp, t1.taximask = t2.taximask, t1.totaltime = t2.totaltime,'
        QueryString = QueryString..'t1.leveltime = t2.leveltime, t1.stable_slots = t2.stable_slots, t1.health = t2.health, '
        QueryString = QueryString..'t1.power1 = t2.power1, t1.power2 = t2.power2, t1.power3 = t2.power3, t1.power4 = t2.power4, '
        QueryString = QueryString..'t1.power5 = t2.power5, t1.power6 = t2.power6, t1.power7 = t2.power7, t1.talentGroupsCount = t2.talentGroupsCount, '
        QueryString = QueryString..'t1.exploredZones = t2.exploredZones` WHERE t1.guid = `'..targetGUID..'`;'
        local Data_SQL = CharDBQuery(QueryString);
        QueryString = nil
        Data_SQL = nil

        -- Copy character_homebind
        QueryString = 'UPDATE character_homebind AS t1 INNER JOIN characters_homebind AS t2 ON t2.guid = '..playerGUID..' '
        QueryString = QueryString..'SET t1.mapId = t2.mapId, t1.zoneId = t2.zoneId, t1.posX = t2.posX, t1.posY = t2.posY, t1.posZ = t2.posZ'
        QueryString = QueryString..'WHERE t1.guid = `'..targetGUID..'`;'
        local Data_SQL = CharDBQuery(QueryString);
        QueryString = nil
        Data_SQL = nil

        -- Copy character_pet
        local Data_SQL = CharDBQuery('SELECT MAX(id) FROM character_pet;');
        local targetPetId = Data_SQL:GetUInt32(0) + 1
        Data_SQL = nil

        local Data_SQL = CharDBQuery('SELECT id FROM character_pet WHERE owner = '..playerGUID..';');
        local playerPetId = Data_SQL:GetUInt32(0) + 1
        Data_SQL = nil

        QueryString = 'CREATE TEMPORARY TABLE tempPet LIKE character_pet; INSERT INTO tempPet '
        QueryString = QueryString..'SELECT * FROM character_pet WHERE owner = '..playerGUID..'; UPDATE tempPet SET id = '..targetPetId..' '
        QueryString = QueryString..'WHERE owner = '..playerGUID..'; UPDATE tempPet SET owner = '..targetGUID..' WHERE owner = '..playerGUID..';'
        QueryString = QueryString..'INSERT INTO character_pet SELECT * FROM tempPet; DROP TABLE tempPet;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        QueryString = 'CREATE TEMPORARY TABLE tempPet_spell LIKE pet_spell; INSERT INTO tempPet_spell '
        QueryString = QueryString..'SELECT * FROM pet_spell WHERE guid = '..playerPetId..'; UPDATE tempPet_spell SET guid = '..targetPetId..' '
        QueryString = QueryString..'WHERE guid = '..playerPetId..'; INSERT INTO pet_spell SELECT * FROM tempPet_spell; DROP TABLE tempPet_spell;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy finished quests
        QueryString = 'CREATE TEMPORARY TABLE tempQuest LIKE character_queststatus; INSERT INTO tempQuest '
        QueryString = QueryString..'SELECT * FROM character_queststatus WHERE guid = '..playerGUID..'; UPDATE tempQuest SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_queststatus SELECT * FROM tempQuest; DROP TABLE tempQuest;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy reputation
        QueryString = 'CREATE TEMPORARY TABLE tempReputation LIKE character_reputation; INSERT INTO tempReputation '
        QueryString = QueryString..'SELECT * FROM character_reputation WHERE guid = '..playerGUID..'; UPDATE tempReputation SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_reputation SELECT * FROM tempReputation; DROP TABLE tempReputation;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy skills
        QueryString = 'CREATE TEMPORARY TABLE tempSkills LIKE character_skills; INSERT INTO tempSkills '
        QueryString = QueryString..'SELECT * FROM character_skills WHERE guid = '..playerGUID..'; UPDATE tempSkills SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_skills SELECT * FROM tempSkills; DROP TABLE tempSkills;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy spells
        QueryString = 'CREATE TEMPORARY TABLE tempSpell LIKE character_spell; INSERT INTO tempSpell '
        QueryString = QueryString..'SELECT * FROM character_spell WHERE guid = '..playerGUID..'; UPDATE tempSpell SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_spell SELECT * FROM tempSpell; DROP TABLE tempSpell;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy talents
        QueryString = 'CREATE TEMPORARY TABLE tempTalent LIKE character_talent; INSERT INTO tempTalent '
        QueryString = QueryString..'SELECT * FROM character_talent WHERE guid = '..playerGUID..'; UPDATE tempTalent SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_talent SELECT * FROM tempTalent; DROP TABLE tempTalent;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        --Copy glyphs
        QueryString = 'CREATE TEMPORARY TABLE tempGlyphs LIKE character_glyphs; INSERT INTO tempGlyphs '
        QueryString = QueryString..'SELECT * FROM character_glyphs WHERE guid = '..playerGUID..'; UPDATE tempGlyphs SET guid = '..targetGUID..' '
        QueryString = QueryString..'WHERE guid = '..playerGUID..'; INSERT INTO character_glyphs SELECT * FROM tempGlyphs; DROP TABLE tempGlyphs;'
        local Data_SQL = CharDBQuery(QueryString)
        QueryString = nil
        Data_SQL = nil

        -- Todo: Copy character_action
        -- Todo: Read the players equipped items and send them by mail
        -- Todo: Do not copy gold, also ignore bags and items in bags including bagpack.


        print("The player with GUID "..playerGUID.." has succesfully used the .carboncopy command. ");
        player:SendBroadcastMessage("Character copied.")
    end
    return false
end


--Todo: Register a command to let staff add CarbonCopy tickets (And/or offer it as a shop service, increasing tickets by 1 for X amount of points)





local function cc_splitString(inputstr, seperator)
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


