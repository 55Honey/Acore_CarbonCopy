--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 18/02/2021
-- Time: 23:28
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


local Config = {};

-- Name of Eluna dB
Config.customDbName = 'ac_eluna';
Config.minGMRank = 2;
-- Max number of characters per account
Config.maxCharacters = 10;



------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- If module runs for the first time, create the db specified in Config.dbName and add the "carboncopy" table to it.
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`carboncopy` (`account_id` INT(11) NOT NULL, `tickets` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');

local PLAYER_EVENT_ON_COMMAND = 42
-- function to be called when the command hook fires
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, CopyCharacter)


local function CopyCharacter(event, player, command)
    if command == "carboncopy" then
        -- make sure the player is properly ranked
        if player:GetGMRank() < Config.minGMRank then return end
        local accountId = Player:GetAccountId()

        --check for available tickets
        local Data_SQL = CharDBQuery('SELECT `tickets` FROM `'..Config.customDbName..'`.`carboncopy` WHERE `account_id` = '..accountId..';');
        local availableTickets = Data_SQL:GetUInt32(0)
        Data_SQL = nil
        if not availableTickets > 0 then
            player:SendBroadcastMessage("You do not have enough Carbon Copy tickets to execute this command.")
            return false
        end

        --check if the account has a free character slot
        local Data_SQL = CharDBQuery('SELECT `numchars` FROM `realmcharacters` WHERE `acctid` = '..accountId..';')
        local numCharacters = Data_SQL:GetUInt32(0)
        if numCharacters >= Config.maxCharacters then
            player:SendBroadcastMessage("You do not have enough a free character slot.")
            return false
        end

        -- Todo: Read the players equipped items including enchants, level, xp, talents, glyphs, achievements and queststates. Do not copy gold in the saved data. Also ignore bags and items in bags including bagpack.



        print("The player "..player.." has used the .carboncopy command. ")
    end
    return false
end


--Todo: Register a command to let staff add CarbonCopy tickets (Or offer it as a shop service, increasing tickets by 1 for X amount of points)
--Todo: Register a command to let a player CarbonCopy his/her character

--On use of the Copy command:
--Create a new character of the same class and race with a random name. Mark it for rename. add the above data to the new character.
--to find a free character guid: 'SELECT MAX(guid) FROM characters'
