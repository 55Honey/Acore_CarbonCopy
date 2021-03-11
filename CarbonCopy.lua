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
local cc_maps = {};
local ticket_Cost = {};

-- Name of Eluna dB scheme
Config.customDbName = 'ac_eluna';
-- Min GM Level to use the .carboncopy command. Set to 0 for all players.
Config.minGMRankForCopy = 2;
-- Min GM Level to add tickets to an account.
Config.minGMRankForTickets = 3;
-- Max number of characters per account
Config.maxCharacters = 10;
-- This text is added to the mail which the new character receives alongside their copied items
Config.mailText = ",\n \n here you are your gear. Have fun with the new twink!\n \n- Sincerely,\n the team of ChromieCraft!";
-- Maximum level to allow copying a character.
Config.maxLevel = 79;
-- Whether the ticket amount withdrawn for a copy is always 1 (set it to "single") or depends on the level (set this to "level")
Config.ticketCost = "level";
-- Here you can adjust the cost in tickets if Config.ticketCost is set to "level"
ticket_Cost[19] = 1		--it costs 1 ticket to copy a character up to level 19
ticket_Cost[29] = 2
ticket_Cost[39] = 3
ticket_Cost[49] = 5
ticket_Cost[59] = 8
ticket_Cost[69] = 12
ticket_Cost[79] = 18
ticket_Cost[80] = 25	--it costs 25 tickets to copy a character at level 80

-- The maps below specify legal locations to use the .carboncopy command.
-- This is used to prevent dungeon specific gear to be copied e.g. the legendaries from the Kael'thas encounter.
-- Eastern kingdoms
table.insert(cc_maps, 0)
-- Kalimdor
table.insert(cc_maps, 1)
-- Outland
table.insert(cc_maps, 530)
-- Northrend
table.insert(cc_maps, 571)


------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

--Globals
cc_scriptIsBusy = 0
cc_oldItemGuids = {}
cc_newItemGuids = {}
cc_newCharacter = 0
cc_playerObject = 0

-- If module runs for the first time, create the db specified in Config.dbName and add the "carboncopy" table to it.
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`carboncopy` (`account_id` INT(11) NOT NULL, `tickets` INT(11) DEFAULT 0, `allow_copy_from_id` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');

local function CopyCharacter(event, player, command)
    
    local commandArray = cc_splitString(command)
    if commandArray[1] == "carboncopy" then
        -- make sure the player is properly ranked
        if player:GetGMRank() < Config.minGMRankForCopy then
            player:SendBroadcastMessage("You lack permisisions to execute this command.")
            cc_resetVariables()
            return false
        end

        -- provide syntax help 
        if commandArray[2] == "help" then
            player:SendBroadcastMessage("Syntax: .carboncopy $NewCharacterName")
            cc_resetVariables()
            return false
        end	

        -- check maxLevel
        if player:GetLevel() > Config.maxLevel then
            player:SendBroadcastMessage("The character you want to copy from is too high level. Max level is "..Config.maxLevel..". Aborting.")
            cc_resetVariables()
            return false
        end

        --check for target character to be on same account
        local accountId = player:GetAccountId()
        local playerGUID = tostring(player:GetGUID())
        playerGUID = tonumber(playerGUID)
        local targetGUID
        local targetName = commandArray[2]
        local Data_SQL = CharDBQuery('SELECT `account` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
        local targetAccountId = Data_SQL:GetUInt32(0)
        Data_SQL = nil
        if targetAccountId ~= accountId then
            player:SendBroadcastMessage("The requested character is not on the same account. Aborting.")
            cc_resetVariables()
            return false
        end

        local Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE `name` = "'..targetName..'" LIMIT 1;');
        if Data_SQL ~= nil then
            targetGUID = Data_SQL:GetUInt32(0)
       	else
            player:SendBroadcastMessage("Name not found. Check capitalization and spelling. Aborting.")
            cc_resetVariables()
            return false
        end
        Data_SQL = nil

        --check for available tickets
        local Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
        local availableTickets
        local requiredTickets
        if Data_SQL ~= nil then
            availableTickets = Data_SQL:GetUInt32(0)
            Data_SQL = nil
        else
            availableTickets = 0
        end

        if Config.ticketCost == "single" then
            if availableTickets ~= nil and availableTickets <= 0 then
                player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command. Aborting.")
                cc_resetVariables()
                return false
            end
            requiredTickets = 1
        elseif Config.ticketCost == "level" then
            local Data_SQL = CharDBQuery('SELECT `level` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
            local n = Data_SQL:GetUInt8(0) - 1
            repeat
                n = n + 1
            until ticket_Cost[n] ~= nil
            requiredTickets = ticket_Cost[n]
            if availableTickets ~= nil and availableTickets <= 0 then
                player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command. Aborting.")
                cc_resetVariables()
                return false
            end
            if availableTickets < requiredTickets then
                player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command. Aborting.")
                cc_resetVariables()
                return false
            end
            Data_SQL = nil
        else
            print("Unhandled exception in CarbonCopy. Config.ticketCost is neither set to \"single\" nor \"level\".")
        end

        --check for target character to be same class/race
        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `guid` = '..playerGUID..' LIMIT 1;');
        local sourceRace = Data_SQL:GetUInt8(0)
        local sourceClass = Data_SQL:GetUInt8(1)
        Data_SQL = nil

        local Data_SQL = CharDBQuery('SELECT `race`, `class` FROM `characters` WHERE `guid` = '..targetGUID..' LIMIT 1;');
        local targetRace = Data_SQL:GetUInt8(0)
        local targetClass = Data_SQL:GetUInt8(1)
        Data_SQL = nil

        if sourceRace ~= targetRace then
            player:SendBroadcastMessage("The requested character is not the same race as this character. Aborting.")
            cc_resetVariables()
            return false
        end
        if sourceClass ~= targetClass then
            player:SendBroadcastMessage("The requested character is not the same class as this character. Aborting.")
            cc_resetVariables()
            return false
        end

        -- check if target character wasn't logged in
        local cc_cinematic
        local Data_SQL = CharDBQuery('SELECT cinematic FROM characters WHERE guid = '..targetGUID..';');
        if Data_SQL ~= nil then
            cc_cinematic = Data_SQL:GetUInt16(0)
            if cc_cinematic == 1 then
                player:SendBroadcastMessage("The requested character has been logged in already. Aborting.")
                cc_cinematic = nil
                cc_resetVariables()
                return false
            end
        else
            print("Unhandled exception in CarbonCopy. Could not read characters.cinematic from playerGuid "..targetGUID..".")
        end

        -- check if target character is logged in currently in case cinematic wasnt already written to db
        local cc_online
        local Data_SQL = CharDBQuery('SELECT online FROM characters WHERE guid = '..targetGUID..';');
        if Data_SQL ~= nil then
            cc_online = Data_SQL:GetUInt16(0)
            if cc_online == 1 then
                player:SendBroadcastMessage("The requested character has been logged in already. Aborting.")
                cc_online = nil
                cc_resetVariables()
                return false
            end
        else
            print("Unhandled exception in CarbonCopy. Could not read characters.online from playerGuid "..targetGUID..".")
        end

        -- check source characters location
        local cc_mapId
        cc_mapId = player:GetMapId()
        if not cc_has_value(cc_maps, cc_mapId) then
            player:SendBroadcastMessage("You are not in an allowed map. Try again outside/not in a dungeon.")
            cc_resetVariables()
            return false
        end
        
        if cc_scriptIsBusy ~= 0 then
            player:SendBroadcastMessage("The server is currently busy. Please try again in a few seconds.")
            print("CarbonCopy user request failed because the script has a scheduled task.")
            return false
        end
        -- save the source character to db to prevent recent changes from being not applied
        player:SaveToDB()
        
        --set Global variable to prevent simultaneous action
        cc_scriptIsBusy = 1
        cc_newCharacter = targetGUID

        -- deduct tickets
        if Config.ticketCost == "single" then
            local Data_SQL = CharDBQuery('UPDATE `'..Config.customDbName..'`.`carboncopy` SET tickets = tickets -1 WHERE `account_id` = '..accountId..';');
            Data_SQL = nil
        elseif Config.ticketCost == "level" then
            local Data_SQL = CharDBQuery('UPDATE `'..Config.customDbName..'`.`carboncopy` SET tickets = tickets -'..requiredTickets..' WHERE `account_id` = '..accountId..';');
            Data_SQL = nil
        end

        -- delete TempTables
        cc_deleteTempTables(playerGUID)

        -- Copy characters table
        local QueryString
        QueryString = 'UPDATE `characters` AS t1 '
        QueryString = QueryString..'INNER JOIN `characters` AS t2 ON t2.guid = '..playerGUID..' '
        QueryString = QueryString..'SET t1.level = t2.level, t1.xp = t2.xp, t1.taximask = t2.taximask, t1.totaltime = t2.totaltime, '
        QueryString = QueryString..'t1.leveltime = t2.leveltime, t1.stable_slots = t2.stable_slots, t1.health = t2.health, '
        QueryString = QueryString..'t1.power1 = t2.power1, t1.power2 = t2.power2, t1.power3 = t2.power3, t1.power4 = t2.power4, '
        QueryString = QueryString..'t1.power5 = t2.power5, t1.power6 = t2.power6, t1.power7 = t2.power7, t1.talentGroupsCount = t2.talentGroupsCount, '
        QueryString = QueryString..'t1.exploredZones = t2.exploredZones WHERE t1.guid = '..targetGUID..';'
        local Data_SQL = CharDBQuery(QueryString);
        QueryString = nil
        Data_SQL = nil

        -- Copy character_homebind
        QueryString = 'UPDATE character_homebind AS t1 INNER JOIN character_homebind AS t2 ON t2.guid = '..playerGUID..' '
        QueryString = QueryString..'SET t1.mapId = t2.mapId, t1.zoneId = t2.zoneId, t1.posX = t2.posX, t1.posY = t2.posY, t1.posZ = t2.posZ '
        QueryString = QueryString..'WHERE t1.guid = '..targetGUID..';'
        local Data_SQL = CharDBQuery(QueryString);
        QueryString = nil
        Data_SQL = nil

        -- Copy character_pet
        local playerString = player:GetClassAsString(0)
        local cc_playerPetId
        if playerString == "Hunter" then
            local Data_SQL = CharDBQuery('SELECT id FROM character_pet WHERE owner = '..playerGUID..';');
            if Data_SQL ~= nil then
                cc_playerPetId = Data_SQL:GetUInt32(0) + 1
                Data_SQL = nil

                local Data_SQL = CharDBQuery('SELECT MAX(id) FROM character_pet;');
                local targetPetId = Data_SQL:GetUInt32(0) + 1
                Data_SQL = nil

                local Data_SQL = CharDBQuery('DELETE FROM character_pet WHERE owner = '..targetGUID..';')
                local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempPet'..playerGUID..' LIKE character_pet;')
                local Data_SQL = CharDBQuery('INSERT INTO tempPet'..playerGUID..' SELECT * FROM character_pet WHERE owner = '..playerGUID..';')
                local Data_SQL = CharDBQuery('UPDATE tempPet'..playerGUID..' SET id = '..targetPetId..' WHERE owner = '..playerGUID..';')
                local Data_SQL = CharDBQuery('UPDATE tempPet'..playerGUID..' SET owner = '..targetGUID..' WHERE owner = '..playerGUID..';')
                local Data_SQL = CharDBQuery('INSERT INTO character_pet SELECT * FROM tempPet'..playerGUID..';')
                local Data_SQL = CharDBQuery('DROP TABLE tempPet'..playerGUID..';')

                QueryString = nil
                Data_SQL = nil

                local Data_SQL = CharDBQuery('DELETE FROM pet_spell WHERE guid = '..targetPetId..';')
                local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempPet_spell'..playerGUID..' LIKE pet_spell;')
                local Data_SQL = CharDBQuery('INSERT INTO tempPet_spell'..playerGUID..' SELECT * FROM pet_spell WHERE guid = '..cc_playerPetId..';')
                local Data_SQL = CharDBQuery('UPDATE tempPet_spell'..playerGUID..' SET guid = '..targetPetId..' WHERE guid = '..cc_playerPetId..';')
                local Data_SQL = CharDBQuery('INSERT INTO pet_spell SELECT * FROM tempPet_spell'..playerGUID..';')
                local Data_SQL = CharDBQuery('DROP TABLE tempPet_spell'..playerGUID..';')
                QueryString = nil
                Data_SQL = nil
            end
        end

        --Copy quests
        local Data_SQL = CharDBQuery('DELETE FROM character_queststatus_rewarded WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempQuest'..playerGUID..' LIKE character_queststatus_rewarded;')
        local Data_SQL = CharDBQuery('INSERT INTO tempQuest'..playerGUID..' SELECT * FROM character_queststatus_rewarded WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempQuest'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_queststatus_rewarded SELECT * FROM tempQuest'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempQuest'..playerGUID..';')
        Data_SQL = nil

        --Copy reputation
        local Data_SQL = CharDBQuery('DELETE FROM character_reputation WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempReputation'..playerGUID..' LIKE character_reputation;')
        local Data_SQL = CharDBQuery('INSERT INTO tempReputation'..playerGUID..' SELECT * FROM character_reputation WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempReputation'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_reputation SELECT * FROM tempReputation'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempReputation'..playerGUID..';')
        Data_SQL = nil

        --Copy skills
        local Data_SQL = CharDBQuery('DELETE FROM character_skills WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempSkills'..playerGUID..' LIKE character_skills;')
        local Data_SQL = CharDBQuery('INSERT INTO tempSkills'..playerGUID..' SELECT * FROM character_skills WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempSkills'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_skills SELECT * FROM tempSkills'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempSkills'..playerGUID..';')
        Data_SQL = nil

        --Copy spells
        local Data_SQL = CharDBQuery('DELETE FROM character_spell WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempSpell'..playerGUID..' LIKE character_spell;')
        local Data_SQL = CharDBQuery('INSERT INTO tempSpell'..playerGUID..' SELECT * FROM character_spell WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempSpell'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_spell SELECT * FROM tempSpell'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempSpell'..playerGUID..';')
        Data_SQL = nil

        --Copy talents
        local Data_SQL = CharDBQuery('DELETE FROM character_talent WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempTalent'..playerGUID..' LIKE character_talent;')
        local Data_SQL = CharDBQuery('INSERT INTO tempTalent'..playerGUID..' SELECT * FROM character_talent WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempTalent'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_talent SELECT * FROM tempTalent'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempTalent'..playerGUID..';')
        Data_SQL = nil

        --Copy glyphs
        local Data_SQL = CharDBQuery('DELETE FROM character_glyphs WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempGlyphs'..playerGUID..' LIKE character_glyphs;')
        local Data_SQL = CharDBQuery('INSERT INTO tempGlyphs'..playerGUID..' SELECT * FROM character_glyphs WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempGlyphs'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_glyphs SELECT * FROM tempGlyphs'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempGlyphs'..playerGUID..';')
        Data_SQL = nil

        --Copy actions
        local Data_SQL = CharDBQuery('DELETE FROM character_action WHERE guid = '..targetGUID..';')
        local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempAction'..playerGUID..' LIKE character_action;')
        local Data_SQL = CharDBQuery('INSERT INTO tempAction'..playerGUID..' SELECT * FROM character_action WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('UPDATE tempAction'..playerGUID..' SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
        local Data_SQL = CharDBQuery('INSERT INTO character_action SELECT * FROM tempAction'..playerGUID..';')
        local Data_SQL = CharDBQuery('DROP TABLE tempAction'..playerGUID..';')
        Data_SQL = nil

        --Copy items
        local homeStone
        local Data_SQL = CharDBQuery('DELETE FROM item_instance WHERE owner_guid = '..targetGUID..' AND itemEntry != 6948;')
        local Data_SQL = CharDBQuery('SELECT guid FROM item_instance WHERE owner_guid = '..targetGUID..' AND itemEntry = 6948 LIMIT 1;')
        homeStone = Data_SQL:GetUInt32(0)
        local Data_SQL = CharDBQuery('DELETE FROM character_inventory WHERE guid = '..targetGUID..' AND item != '..homeStone..';')
        Data_SQL = nil

        local Data_SQL = CharDBQuery('SELECT item FROM character_inventory WHERE guid = '..playerGUID..' AND bag = 0 AND slot <= 18 LIMIT 18;')
        local ItemCounter = 1
        local item_guid
        local item_id
        local newItemGuid
        local returnedArray = {}
        local oldItemArray = {}
        local newItemArray = {}
        if Data_SQL ~= nil then
            repeat
                item_guid = Data_SQL:GetUInt32(0)
                local Data_SQL2 = CharDBQuery('SELECT itemEntry FROM item_instance WHERE guid = '..item_guid..' LIMIT 1;')
                item_id = Data_SQL2:GetUInt16(0)
                returnedArray = SendMail("Copied items", "Hello "..targetName..Config.mailText, targetGUID, 0, 61, 0, 0, 0, item_id, 1)
                newItemGuid = returnedArray[1]
                cc_oldItemGuids[ItemCounter] = item_guid
                cc_newItemGuids[ItemCounter] = newItemGuid
                ItemCounter = ItemCounter + 1
            until not Data_SQL:NextRow()
        end
        SaveAllPlayers()
        player:RegisterEvent(cc_fixItems, 3000) -- do it after 3 seconds

        cc_playerObject = player
        print("1) The player with GUID "..playerGUID.." has succesfully initiated the .carboncopy command. Target character: "..targetGUID);
        player:SendBroadcastMessage("Copy started. You have been charged "..requiredTickets.." ticket(s) for this action. There are "..availableTickets - requiredTickets.." ticket()s left.")
        player:SendBroadcastMessage("WAIT for a \"COMPLETED\" message.")

        cc_deleteTempTables(playerGUID)
        cc_resetVariables()
        return false

    elseif commandArray[1] == "addcctickets" then
        -- make sure the player is properly ranked
        local accountId
        local oldTickets
        local Data_SQL
        if player:GetGMRank() < Config.minGMRankForTickets then
            cc_resetVariables()
            return false
        end
        if commandArray[2] == "help" then
            player:SendBroadcastMessage("Syntax: .addcctickets $CharacterName $Amount")
            cc_resetVariables()
            return false
        end	
        if commandArray[2] == nil or commandArray[3] == nil then
            player:SendBroadcastMessage("Expected syntax: .addcctickets [CharacterName] [Amount]")
            cc_resetVariables()
            return false
        end

        Data_SQL = CharDBQuery("SELECT `account` FROM `characters` WHERE `name` = '"..tostring(commandArray[2]).."' LIMIT 1;");
        if Data_SQL ~= nil then
            accountId = Data_SQL:GetUInt32(0)
        else
            player:SendBroadcastMessage("Player name not found. Expected syntax: .addcctickets [CharacterName] [Amount]")
            cc_resetVariables()
            return false
        end
        Data_SQL = nil
        local Data_SQL
        Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..' LIMIT 1;');
        if Data_SQL  ~= nil then
            oldTickets = Data_SQL:GetUInt32(0)
        else
            oldTickets = 0
        end
        Data_SQL = nil

        -- the `allow_copy_from_id` column is hardcoded to 0 for now. Only copies to the same account are possible.
        local Data_SQL
        Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
        Data_SQL = CharDBQuery('INSERT INTO `'..Config.customDbName..'`.`carboncopy` VALUES ('..accountId..', '..commandArray[3] + oldTickets..', 0);');
        Data_SQL = nil
        print("GM "..player:GetName().. " has sucessfully used the .addcctickets command, adding "..commandArray[3].." tickets to the account "..accountId.." which belongs to player "..commandArray[2]..".")
        cc_resetVariables()
        return false
    end
end

function cc_fixItems()
    local n
    local Data_SQL
    for n,_ in ipairs(cc_oldItemGuids) do
        QueryString = 'UPDATE `item_instance` AS t1 '
        QueryString = QueryString..'INNER JOIN `item_instance` AS t2 ON t2.guid = '..cc_oldItemGuids[n]..' '
        QueryString = QueryString..'SET t1.owner_guid = '..cc_newCharacter..', t1.creatorGuid = t2.creatorGuid, '
        QueryString = QueryString..'t1.duration = t2.duration, t1.charges = t2.charges, t1.flags = 1, '
        QueryString = QueryString..'t1.enchantments = t2.enchantments, t1.randomPropertyId = t2.randomPropertyId '
        QueryString = QueryString..'WHERE t1.guid = '..cc_newItemGuids[n]..';'
        Data_SQL = CharDBQuery(QueryString);
    end

    player:SendBroadcastMessage("CarbonCopy has COMPLETED the duplication. You may log out now.")

    cc_newCharacter = 0
    cc_oldItemGuids = {}
    cc_newItemGuids = {}
    cc_scriptIsBusy = 0
    cc_playerObject = 0
    print("2) Item enchants/gems copied for player with GUID "..playerGUID..". Target character: "..targetGUID);
end

function cc_resetVariables()
    playerGUID = nil
    item_guid = nil
    Data_SQL = nil
    Data_SQL2 = nil
    ItemCounter = nil
    targetName = nil
    targetGUID = nil
    QueryString = nil
    cc_playerPetId = nil
    cc_targetPetId = nil
    item_id = nil
    homeStone = nil
    playerString = nil
    cc_cinematic = nil
    commandArray = nil
    availableTickets = nil
    newItemGuid = nil
end

function cc_deleteTempTables(cc_GUID)
    CharDBQuery('DROP TABLE IF EXISTS tempQuest'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempPet'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempPet_spell'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempReputation'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempSkills'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempSpell'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempTalent'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempGlyphs'..cc_GUID..';')
    CharDBQuery('DROP TABLE IF EXISTS tempAction'..cc_GUID..';')
end

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

function cc_has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local PLAYER_EVENT_ON_COMMAND = 42
-- function to be called when the command hook fires
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, CopyCharacter)
