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

-- Name of Eluna dB scheme
Config.customDbName = 'ac_eluna';
-- Min GM Level to use the .carboncopy command. Set to 0 for all players.
Config.minGMRankForCopy = 2;
-- Min GM Level to add tickets to an account. (currently unused)
Config.minGMRankForTickets = 3;
-- Max number of characters per account
Config.maxCharacters = 10;
-- This text is added to the mail which the new character receives alongside their copied items
Config.mailText = ", here you are your gear. Have fun with the new twink! - Sincerely, the team of ChromieCraft!"

-- The maps below specify legal locations to sue the .copycharacter command.
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

-- If module runs for the first time, create the db specified in Config.dbName and add the "carboncopy" table to it.
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`carboncopy` (`account_id` INT(11) NOT NULL, `tickets` INT(11) DEFAULT 0, `allow_copy_from_id` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');



local function CopyCharacter(event, player, command)
    local commandArray = cc_splitString(command)
    if commandArray[1] == "carboncopy" then
		-- make sure the player is properly ranked
        if player:GetGMRank() < Config.minGMRankForCopy then
            cc_resetVariables()
			return false
        end

        --check for available tickets
        local accountId = player:GetAccountId()
        local Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
        local availableTickets = Data_SQL:GetUInt32(0)
        Data_SQL = nil
        if availableTickets ~= nil and availableTickets <= 0 then
            player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command. Aborting.")
			cc_resetVariables()
            return false
        end

        --check for target character to be on same account
        local playerGUID = tostring(player:GetGUID())
        playerGUID = tonumber(playerGUID)
        --print("3: "..playerGUID)
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
				return false
			end
		else
			print("Unhandled exception in CarbonCopy. Could not read characters.online from playerGuid "..targetGUID..".")
		end
		
		-- check source characters location
		local cc_mapId
		cc_mapId = player:GetMapId()
		if not has_value(cc_maps, cc_mapId) then
			player:SendBroadcastMessage("You are not in an allowed map. Try again outside/not in a dungeon.")
			cc_resetVariables()
			return false
		end

        --deduct one ticket
        local Data_SQL = CharDBQuery('UPDATE `'..Config.customDbName..'`.`carboncopy` SET tickets = tickets -1 WHERE `account_id` = '..accountId..';');
        Data_SQL = nil
		
		--delete TempTables
		CharDBQuery('DROP TABLE IF EXISTS tempQuest;')
		CharDBQuery('DROP TABLE IF EXISTS tempPet;')
		CharDBQuery('DROP TABLE IF EXISTS tempPet_spell;')
		CharDBQuery('DROP TABLE IF EXISTS tempReputation;')
		CharDBQuery('DROP TABLE IF EXISTS tempSkills;')
		CharDBQuery('DROP TABLE IF EXISTS tempSpell;')
		CharDBQuery('DROP TABLE IF EXISTS tempTalent;')
		CharDBQuery('DROP TABLE IF EXISTS tempGlyphs;')
		CharDBQuery('DROP TABLE IF EXISTS tempAction;')
		CharDBQuery('DROP TABLE IF EXISTS tempItems;')
		
        local QueryString
        -- Copy characters table
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
		if playerString == "Hunter" then
			local Data_SQL = CharDBQuery('SELECT id FROM character_pet WHERE owner = '..playerGUID..';');
			if Data_SQL ~= nil then
				cc_playerPetId = Data_SQL:GetUInt32(0) + 1
				Data_SQL = nil

				local Data_SQL = CharDBQuery('SELECT MAX(id) FROM character_pet;');
				local targetPetId = Data_SQL:GetUInt32(0) + 1
				Data_SQL = nil
	
				local Data_SQL = CharDBQuery('DELETE FROM character_pet WHERE owner = '..targetGUID..';')
				local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempPet LIKE character_pet;')
				local Data_SQL = CharDBQuery('INSERT INTO tempPet SELECT * FROM character_pet WHERE owner = '..playerGUID..';')
				local Data_SQL = CharDBQuery('UPDATE tempPet SET id = '..targetPetId..' WHERE owner = '..playerGUID..';')
				local Data_SQL = CharDBQuery('UPDATE tempPet SET owner = '..targetGUID..' WHERE owner = '..playerGUID..';')
				local Data_SQL = CharDBQuery('INSERT INTO character_pet SELECT * FROM tempPet;')
				local Data_SQL = CharDBQuery('DROP TABLE tempPet;')
				
				QueryString = nil
				Data_SQL = nil

				local Data_SQL = CharDBQuery('DELETE FROM pet_spell WHERE guid = '..targetPetId..';')
				local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempPet_spell LIKE pet_spell;')
				local Data_SQL = CharDBQuery('INSERT INTO tempPet_spell SELECT * FROM pet_spell WHERE guid = '..cc_playerPetId..';')
				local Data_SQL = CharDBQuery('UPDATE tempPet_spell SET guid = '..targetPetId..' WHERE guid = '..cc_playerPetId..';')
				local Data_SQL = CharDBQuery('INSERT INTO pet_spell SELECT * FROM tempPet_spell;')
				local Data_SQL = CharDBQuery('DROP TABLE tempPet_spell;')
				QueryString = nil
				Data_SQL = nil
			end
			
			local Data_SQL = CharDBQuery('DELETE FROM character_queststatus WHERE guid = '..targetGUID..';')
			local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempQuest LIKE character_queststatus;')
			local Data_SQL = CharDBQuery('INSERT INTO tempQuest SELECT * FROM character_queststatus WHERE guid = '..playerGUID..';')
			local Data_SQL = CharDBQuery('UPDATE tempQuest SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
			local Data_SQL = CharDBQuery('INSERT INTO character_queststatus SELECT * FROM tempQuest;')
			local Data_SQL = CharDBQuery('DROP TABLE tempQuest;')
			Data_SQL = nil
		end
		
        --Copy reputation
		local Data_SQL = CharDBQuery('DELETE FROM character_reputation WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempReputation LIKE character_reputation;')
		local Data_SQL = CharDBQuery('INSERT INTO tempReputation SELECT * FROM character_reputation WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempReputation SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_reputation SELECT * FROM tempReputation;')
		local Data_SQL = CharDBQuery('DROP TABLE tempReputation;')
        Data_SQL = nil

        --Copy skills
        local Data_SQL = CharDBQuery('DELETE FROM character_skills WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempSkills LIKE character_skills;')
		local Data_SQL = CharDBQuery('INSERT INTO tempSkills SELECT * FROM character_skills WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempSkills SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_skills SELECT * FROM tempSkills;')
		local Data_SQL = CharDBQuery('DROP TABLE tempSkills;')
		Data_SQL = nil

        --Copy spells
        local Data_SQL = CharDBQuery('DELETE FROM character_spell WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempSpell LIKE character_spell;')
		local Data_SQL = CharDBQuery('INSERT INTO tempSpell SELECT * FROM character_spell WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempSpell SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_spell SELECT * FROM tempSpell;')
		local Data_SQL = CharDBQuery('DROP TABLE tempSpell;')
		Data_SQL = nil

        --Copy talents
        local Data_SQL = CharDBQuery('DELETE FROM character_talent WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempTalent LIKE character_talent;')
		local Data_SQL = CharDBQuery('INSERT INTO tempTalent SELECT * FROM character_talent WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempTalent SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_talent SELECT * FROM tempTalent;')
		local Data_SQL = CharDBQuery('DROP TABLE tempTalent;')
		Data_SQL = nil

        --Copy glyphs
        local Data_SQL = CharDBQuery('DELETE FROM character_glyphs WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempGlyphs LIKE character_glyphs;')
		local Data_SQL = CharDBQuery('INSERT INTO tempGlyphs SELECT * FROM character_glyphs WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempGlyphs SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_glyphs SELECT * FROM tempGlyphs;')
		local Data_SQL = CharDBQuery('DROP TABLE tempGlyphs;')
		Data_SQL = nil

        --Copy actions
        local Data_SQL = CharDBQuery('DELETE FROM character_action WHERE guid = '..targetGUID..';')
		local Data_SQL = CharDBQuery('CREATE TEMPORARY TABLE tempAction LIKE character_action;')
		local Data_SQL = CharDBQuery('INSERT INTO tempAction SELECT * FROM character_action WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('UPDATE tempAction SET guid = '..targetGUID..' WHERE guid = '..playerGUID..';')
		local Data_SQL = CharDBQuery('INSERT INTO character_action SELECT * FROM tempAction;')
		local Data_SQL = CharDBQuery('DROP TABLE tempAction;')
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
		repeat
			item_guid = Data_SQL:GetUInt32(0)
			--print("item_guid: "..item_guid)
            local Data_SQL2 = CharDBQuery('SELECT itemEntry FROM item_instance WHERE guid = '..item_guid..' LIMIT 1;')
			item_id = Data_SQL2:GetUInt16(0)
			--print("item_id: "..item_id)
			SendMail("Copied items", "Hello "..targetName..Config.mailText, targetGUID, 0, 61, 0, 0, 0, item_id, 1)
            ItemCounter = ItemCounter + 1
        until not Data_SQL:NextRow()
		
        print("The player with GUID "..playerGUID.." has succesfully used the .carboncopy command. Target character: "..targetGUID);
        player:SendBroadcastMessage("Character copied. You have "..availableTickets.." tickets left.")
		
	elseif commandArray[1] == "addcctickets" then
		-- make sure the player is properly ranked
    --    if player:GetGMRank() < Config.minGMRankForTickets then
    --        cc_resetVariables()
	--		return false
    --    end
	--	print(commandArray[2])
	--	print(tostring(commandArray[2]))
	--	print(commandArray[3])
	--	print(tonumber(commandArray[3]))
	--	if commandArray[2] == nil or commandArray[3] == nil then
	--		player:SendBroadcastMessage("Expected syntax: .addcctickets [CharacterName] [Amount]")
	--		cc_resetVariables()
	--		return false
	--	end	
	--	
	--	local Data_SQL = CharDBQuery('SELECT `account` FROM `characters` WHERE `name` = "'..commandArray[2]..'" LIMIT 1;');
    --   if DataSQL ~= nil then
	--		local accountId = Data_SQL:GetUInt32(0)
	--	else	
	--		player:SendBroadcastMessage("Player name not found. Expected syntax: .cctickets [CharacterName] [Amount]")
	--		return false
	--	end	
	--	Data_SQL = nil
	--	local Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id`` = '..account_id..' LIMIT 1;');
	--	if Data_SQL  ~= nil then
	--		local oldTickets = Data_SQL:GetUInt32(0)
	--	else
	--		local oldTickets = 0
	--	end
	--	Data_SQL = nil
	--	
	--	local Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
	--	local Data_SQL = CharDBQuery('INSERT INTO `'..Config.customDbName..'`.`carboncopy` VALUES ('..accountId..', '..commandArray[3] + oldTickets..', 0;');
    --   Data_SQL = nil
	--	print("GM "..player.. "has sucessfully used the .addcctickets command on the account "..accountId.." which belongs to player "..commandArray[2]..".")
	end
	
	cc_resetVariables()
    return false
end

--Todo: Register a command to let staff add CarbonCopy tickets (And/or offer it as a shop service, increasing tickets by 1 for X amount of points)

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

local function has_value (tab, val)
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
