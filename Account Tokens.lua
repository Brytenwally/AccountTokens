-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    LevelsPerToken           = 10,  -- Earn tokens every X levels (e.g., 10, 20, 30...)
    AutogearTokensGranted    = 1,   -- Tokens awarded per milestone level up
    MaintenanceTokensGranted = 1,   -- Tokens awarded per milestone level up
    
    AutogearTokenCost        = 5,   -- Cost to execute the "autogear" command once
    MaintenanceTokenCost     = 5,   -- Cost to execute the "maintenance" command once
    
    NotificationSound        = 8424, -- Sound ID played on level up milestone
}

-- ============================================================================
-- CORE HELPER FUNCTIONS
-- ============================================================================

-- Safely fetches token counts for an account. Returns (autogear, maintenance)
local function GetAccountTokens(accountId)
    local query = CharDBQuery(string.format("SELECT autogear_tokens, maintenance_tokens FROM account_bot_tokens WHERE account_id = %d", accountId))
    if query then
        return query:GetUInt32(0), query:GetUInt32(1)
    end
    return 0, 0
end

-- Deducts a specific amount of tokens from the database
local function ConsumeTokens(accountId, tokenColumn, cost)
    CharDBExecute(string.format("UPDATE account_bot_tokens SET %s = %s - %d WHERE account_id = %d", tokenColumn, tokenColumn, cost, accountId))
end

-- Processes incoming chat strings to intercept playerbot commands
local function InterceptPlayerbotCommands(player, msg)
    local lowerMsg = string.lower(msg)
    local accountId = player:GetAccountId()
    
    -- 1. Check for Token Balance Request (Type 'tokens' or '!tokens')
    if string.find(lowerMsg, "tokens") or string.find(lowerMsg, "status") then
        local autogearTokens, maintenanceTokens = GetAccountTokens(accountId)
        
        player:SendBroadcastMessage(" ")
        player:SendBroadcastMessage("|cff00ffff=================== [ BOT TOKENS ] ===================|r")
        player:SendBroadcastMessage(string.format("  Account Autogear Balance:    |cffffffff%d|r tokens  (Cost: %d per use)", autogearTokens, CONFIG.AutogearTokenCost))
        player:SendBroadcastMessage(string.format("  Account Maintenance Balance: |cffffffff%d|r tokens  (Cost: %d per use)", maintenanceTokens, CONFIG.MaintenanceTokenCost))
        player:SendBroadcastMessage("|cff00ffff---------------------------------------------------|r")
        player:SendBroadcastMessage("|cffaaaaaa  Tokens are account-bound. Earn more every " .. CONFIG.LevelsPerToken .. " levels!|r")
        player:SendBroadcastMessage("|cff00ffff===================================================|r")
        return false -- Suppress message downstream
    end
    
    -- 2. Check for Autogear Command Interception
    if string.find(lowerMsg, "autogear") then
        local autogearTokens, _ = GetAccountTokens(accountId)
        
        if autogearTokens >= CONFIG.AutogearTokenCost then
            ConsumeTokens(accountId, "autogear_tokens", CONFIG.AutogearTokenCost)
            player:SendBroadcastMessage(string.format("|cff00ff00[Bot Tokens]:|r %d Autogear Tokens consumed. Remaining on Account: %d", CONFIG.AutogearTokenCost, autogearTokens - CONFIG.AutogearTokenCost))
            return true 
        else
            player:SendBroadcastMessage(string.format("|cffff0000[Bot Tokens Error]:|r 'autogear' requires %d tokens. You only have %d!", CONFIG.AutogearTokenCost, autogearTokens))
            return false 
        end
    end

    -- 3. Check for Maintenance Command Interception
    if string.find(lowerMsg, "maintenance") then
        local _, maintenanceTokens = GetAccountTokens(accountId)
        
        if maintenanceTokens >= CONFIG.MaintenanceTokenCost then
            ConsumeTokens(accountId, "maintenance_tokens", CONFIG.MaintenanceTokenCost)
            player:SendBroadcastMessage(string.format("|cff00ff00[Bot Tokens]:|r %d Maintenance Tokens consumed. Remaining on Account: %d", CONFIG.MaintenanceTokenCost, maintenanceTokens - CONFIG.MaintenanceTokenCost))
            return true 
        else
            player:SendBroadcastMessage(string.format("|cffff0000[Bot Tokens Error]:|r 'maintenance' requires %d tokens. You only have %d!", CONFIG.MaintenanceTokenCost, maintenanceTokens))
            return false 
        end
    end
    
    return true 
end

-- ============================================================================
-- AZEROTHCORE COMPATIBLE EVENT HANDLERS
-- ============================================================================

-- Hook 19: Intercepts whispers directly to a playerbot
local function OnPlayerWhisper(event, player, msg, Type, lang, receiver)
    return InterceptPlayerbotCommands(player, msg)
end

-- Hook 20: Intercepts messages sent inside a group (Party/Raid)
local function OnPlayerGroupChat(event, player, msg, Type, lang, group)
    -- Type 2 = Party, Type 51 = Party Leader
    if Type == 2 or Type == 51 then 
        return InterceptPlayerbotCommands(player, msg)
    end
    return true
end

-- Hook 13: Milestone level ups (Triggers token awards via boundary tracking)
local function OnPlayerLevelUp(event, player, oldLevel)
    local newLevel = player:GetLevel()
    
    local oldMilestones = math.floor(oldLevel / CONFIG.LevelsPerToken)
    local newMilestones = math.floor(newLevel / CONFIG.LevelsPerToken)
    local milestonesGained = newMilestones - oldMilestones
    
    if milestonesGained > 0 then
        local accountId = player:GetAccountId()
        local autogearGrant = CONFIG.AutogearTokensGranted * milestonesGained
        local maintenanceGrant = CONFIG.MaintenanceTokensGranted * milestonesGained
        
        CharDBExecute(string.format([[
            INSERT INTO account_bot_tokens (account_id, autogear_tokens, maintenance_tokens) 
            VALUES (%d, %d, %d) 
            ON DUPLICATE KEY UPDATE 
                autogear_tokens = autogear_tokens + %d, 
                maintenance_tokens = maintenance_tokens + %d
        ]], accountId, autogearGrant, maintenanceGrant, autogearGrant, maintenanceGrant))
        
        local autogear, maintenance = GetAccountTokens(accountId)
        
        if CONFIG.NotificationSound > 0 then
            player:PlayDistanceSound(CONFIG.NotificationSound)
        end
        
        player:SendBroadcastMessage(" ")
        player:SendBroadcastMessage("|cffffd700==================================================|r")
        player:SendBroadcastMessage(string.format("|cffffd700★ [BOT MILESTONE]: Passed %d Milestone Boundary! ★|r", milestonesGained))
        player:SendBroadcastMessage(string.format("|cff00ff00  +%d Autogear Tokens and +%d Maintenance Tokens Earned!|r", autogearGrant, maintenanceGrant))
        player:SendBroadcastMessage("|cffffd700--------------------------------------------------|r")
        player:SendBroadcastMessage(string.format("  Total Available Autogear:    |cffffffff%d|r (Uses: %d)", autogear, math.floor(autogear / CONFIG.AutogearTokenCost)))
        player:SendBroadcastMessage(string.format("  Total Available Maintenance: |cffffffff%d|r (Uses: %d)", maintenance, math.floor(maintenance / CONFIG.MaintenanceTokenCost)))
        player:SendBroadcastMessage("|cffffd700==================================================|r")
        player:SendBroadcastMessage(" ")
    end
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================
RegisterPlayerEvent(19, OnPlayerWhisper)     
RegisterPlayerEvent(20, OnPlayerGroupChat)   
RegisterPlayerEvent(13, OnPlayerLevelUp)     

print("[Eluna]: Account-Bound Playerbot Token Gating Engine Loaded.")