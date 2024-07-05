-- Create the main frame
local frame = CreateFrame("Frame")

-- Initialize the saved variables table if it doesn't exist.
if not GoldTrackerDB then
    GoldTrackerDB = {}
end

-- Helper function to calculate the date difference in days
local function dateDiff(date1, date2)
    local year1, month1, day1 = date1:match("(%d+)-(%d+)-(%d+)")
    local year2, month2, day2 = date2:match("(%d+)-(%d+)-(%d+)")
    local time1 = time({year = year1, month = month1, day = day1})
    local time2 = time({year = year2, month = month2, day = day2})
    local diff = difftime(time1, time2) / (24 * 3600)
    return diff
end

-- Function to clean up old data
local function cleanOldData()
    local currentDate = date("%Y-%m-%d")
    for char, dates in pairs(GoldTrackerDB) do
        for recordDate, _ in pairs(dates) do
            if dateDiff(currentDate, recordDate) > 90 then  -- 90 days ~ 3 months
                dates[recordDate] = nil
            end
        end
    end
end

-- Function to get the most recent and previous gold entries for each character
local function getRecentAndPreviousGold(dates)
    local sortedDates = {}
    for date in pairs(dates) do
        table.insert(sortedDates, date)
    end
    table.sort(sortedDates, function(a, b) return a > b end) -- Sort in descending order
    
    if #sortedDates == 0 then
        return nil, nil
    end
    
    local mostRecentDate = sortedDates[1]
    local previousDate = sortedDates[2]
    
    return dates[mostRecentDate], dates[previousDate]
end

-- Function to calculate gold summary for all characters
local function calculateGoldSummary()
    local totalGold = 0
    local totalChange = 0
    local summary = {}
    
    for char, dates in pairs(GoldTrackerDB) do
        local mostRecentGold, previousGold = getRecentAndPreviousGold(dates)
        
        if mostRecentGold then
            local change = previousGold and mostRecentGold - previousGold or 0
            
            summary[char] = {
                currentGold = mostRecentGold,
                change = change
            }
            
            totalGold = totalGold + mostRecentGold
            totalChange = totalChange + change
        end
    end
    
    return summary, totalGold, totalChange
end

-- Function to format numbers with thousand separators
local function formatNumber(num)
    local formatted = tostring(num)
    formatted = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end

-- Event handler function
local function eventHandler(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Get character name and realm
        local name = UnitName("player")
        local realm = GetRealmName()
        local fullName = name .. "-" .. realm
        
        -- Get current date
        local currentDate = date("%Y-%m-%d")
        
        -- Initialize character table if it doesn't exist
        if not GoldTrackerDB[fullName] then
            GoldTrackerDB[fullName] = {}
        end
        
        -- Get today's gold amount
        local goldAmount = GetMoney()
        
        -- Store today's gold amount
        GoldTrackerDB[fullName][currentDate] = goldAmount
        
        -- Print a message displaying the stored gold amount
        print("GoldTracker: Stored " .. formatNumber(math.floor(goldAmount / 10000)) .. " g for " .. fullName .. " on " .. currentDate)
        
        -- Clean up old data
        cleanOldData()
    end
end

-- Register the PLAYER_LOGIN event
frame:RegisterEvent("PLAYER_LOGIN")

-- Set the event handler
frame:SetScript("OnEvent", eventHandler)

-- Create the UI frame for displaying gold summary for the current month
local goldFrame = CreateFrame("Frame", "GoldTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
goldFrame:SetSize(450, 300)
goldFrame:SetPoint("CENTER", UIParent, "CENTER")
goldFrame:EnableMouse(true)  -- Enable mouse interaction for frame
goldFrame:SetMovable(true)   -- Make the frame movable
goldFrame:RegisterForDrag("LeftButton")  -- Register for dragging with left mouse button
goldFrame:SetScript("OnDragStart", goldFrame.StartMoving)  -- Start moving when drag starts
goldFrame:SetScript("OnDragStop", goldFrame.StopMovingOrSizing)  -- Stop moving when drag stops
goldFrame:Hide()

-- Title
goldFrame.title = goldFrame:CreateFontString(nil, "OVERLAY")
goldFrame.title:SetFontObject("GameFontHighlight")
goldFrame.title:SetPoint("LEFT", goldFrame.TitleBg, "LEFT", 5, 0)
goldFrame.title:SetText("Gold Tracker")

-- ScrollFrame
goldFrame.scrollFrame = CreateFrame("ScrollFrame", nil, goldFrame, "UIPanelScrollFrameTemplate")
goldFrame.scrollFrame:SetPoint("TOPLEFT", 10, -30)
goldFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Content Frame
goldFrame.content = CreateFrame("Frame", nil, goldFrame.scrollFrame)
goldFrame.scrollFrame:SetScrollChild(goldFrame.content)
goldFrame.content:SetSize(360, 1)  -- Will adjust height dynamically
goldFrame.content.lines = {}  -- Initialize lines as an empty table

-- Function to populate the scroll frame with gold summary
local function populateGoldSummary()
    local summary, totalGold, totalChange = calculateGoldSummary()
    local content = goldFrame.content
    
    -- Clear existing content
    for i = 1, #content.lines do
        content.lines[i]:Hide()
    end
    
    local lineHeight = 20
    local currentHeight = 0

    -- Create table header
    local headerChar = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerChar:SetPoint("TOPLEFT", 0, -currentHeight)
    headerChar:SetText("Character Name")
    headerChar:Show()
    table.insert(content.lines, headerChar)
    
    local headerGold = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerGold:SetPoint("TOPLEFT", 180, -currentHeight)  -- Adjusted x-coordinate
    headerGold:SetText("Gold")
    headerGold:SetJustifyH("RIGHT") -- Right justify
    headerGold:Show()
    table.insert(content.lines, headerGold)
    
    local headerChange = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerChange:SetPoint("TOPLEFT", 280, -currentHeight)
    headerChange:SetText("Since Yesterday")
    headerChange:SetJustifyH("RIGHT") -- Right justify
    headerChange:Show()
    table.insert(content.lines, headerChange)
    
    currentHeight = currentHeight + lineHeight
    
    for char, data in pairs(summary) do
        local currentGold = data.currentGold
        local change = data.change
        
        local charLine = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        charLine:SetPoint("TOPLEFT", 0, -currentHeight)
        charLine:SetText(char)
        charLine:Show()
        table.insert(content.lines, charLine)
        
        local goldLine = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        goldLine:SetPoint("TOPLEFT", 180, -currentHeight)  -- Adjusted x-coordinate
        goldLine:SetText(formatNumber(math.floor(currentGold / 10000)) .. "g")
        goldLine:SetJustifyH("RIGHT") -- Right justify
        goldLine:Show()
        table.insert(content.lines, goldLine)
        
        local changeLine = content.lines[#content.lines + 1] or content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        changeLine:SetPoint("TOPLEFT", 280, -currentHeight)
        
        -- Set color based on change
        if change < 0 then
            changeLine:SetText("|cFFFF0000" .. formatNumber(math.floor(change / 10000)) .. "g|r")
        elseif change > 0 then
            changeLine:SetText("|cFF00FF00" .. formatNumber(math.floor(change / 10000)) .. "g|r")
        else
            changeLine:SetText(formatNumber(math.floor(change / 10000)) .. "g")
        end
        
        changeLine:SetJustifyH("RIGHT") -- Right justify
        changeLine:Show()
        table.insert(content.lines, changeLine)
        
        currentHeight = currentHeight + lineHeight
    end
    
    -- Display total gold and total change summary in the header
    goldFrame.title:SetText("Gold Tracker - Total: " .. formatNumber(math.floor(totalGold / 10000)) .. "g - Since Yesterday: " .. formatNumber(math.floor(totalChange / 10000)) .. "g")
    
    content:SetHeight(currentHeight)
end

-- Slash command to show gold summary for the current month
SLASH_GOLDTRACKER1 = "/gt"
SlashCmdList["GOLDTRACKER"] = function()
    goldFrame:Show()
    populateGoldSummary()
end