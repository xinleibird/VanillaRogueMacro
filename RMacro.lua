-- RMacro.lua
-- 这是基于 InterruptCast.lua 和 CatEvent.lua 内容实现的 MPTargetCast 完整版本。
-- 包含事件注册和必要的全局/局部变量，以提供一个自包含的示例。

-- =========================================================================
-- 全局/文件局部变量
-- =========================================================================

-- 用于聊天消息的颜色前缀，保持与原始文件一致。
RMacroConsoleColor = "|cFFFF8000" -- 示例颜色

-- 用于指示 SuperWow 插件是否加载。
-- 假设 SuperWoW 插件会设置一个全局变量来表明其存在，例如 _G["SUPERWOW_STRING"]。
local SuperWow = false

-- 用于存储各个单位（GUID）的施法开始时间。
-- 键为单位的 GUID，值为施法开始时的 GetTime()。
local castStartTime = {}

-- 用于存储各个单位（GUID）当前施放的法术名称。
-- 键为单位的 GUID，值为法术名称字符串。
local castName = {}

-- 用于存储各个单位（GUID）当前施放法术的持续时间（秒）。
-- 键为单位的 GUID，值为持续时间。
local castDuration = {}

-- 玩家自身的 GUID，用于区分玩家自身的施法事件。
local PLAYER_GUID = 0

-- 用于跟踪所有被观察到的单位 GUID 的表。
-- 在实际插件中，这可能用于维护一个更复杂的单位信息数据库。
local ObjectArray = {}

-- -------------------------------------------------------------------------
-- 辅助函数 (简化实现，实际插件中会更复杂)
-- -------------------------------------------------------------------------

-- 简化版的战斗日志 GUID 匹配函数。
-- 实际的 WoW 战斗日志 GUID 匹配非常复杂，这里仅为示例。
function RMacroMatchGUID(logString)
	-- 尝试从日志字符串中匹配一个简单的 GUID 模式。
	-- 例如，"Creature-0-0-0-0-12345-UnitName" 或 "Player-0-0-0-0-12345-UnitName"
	local guidPattern = "(%a+%-GUID%-[%d%-]+)" -- 匹配常见的 GUID 格式
	local _, _, guid = string.find(logString, guidPattern)
	if guid then
		return guid
	end

	-- 如果是更简单的日志，尝试匹配目标名称并返回一个假 GUID
	local targetName = UnitName("target")
	if targetName and string.find(logString, targetName) then
		-- 这是一个非常简化的处理，不推荐用于生产环境
		return "FakeGUID-" .. string.gsub(targetName, " ", "") -- 基于目标名称生成假 GUID
	end
	return nil -- 未能匹配到 GUID
end

-- 简化版的文本模式匹配函数。
-- 从文本中提取符合给定模式的捕获组。
function RMacroMatch(text, pattern)
	local _, _, capture = string.find(text, pattern)
	return capture
end

-- 简化版的单位对象追踪函数。
-- 仅将 GUID 记录到 ObjectArray 中，不做额外检查。
function RMacroPushObject(inGUID)
	if inGUID and not ObjectArray[inGUID] then
		ObjectArray[inGUID] = GetTime() -- 记录首次观察到的时间
	end
end

-- =========================================================================
-- WoW 事件处理框架和函数
-- =========================================================================

-- 创建一个独立的 Frame 来监听 WoW 事件。
local frame = CreateFrame("Frame", "RMacro")

-- 事件处理主函数
function OnEvent()
	if event == "PLAYER_LOGIN" then
		DEFAULT_CHAT_FRAME:AddMessage(RMacroConsoleColor .. "RMacro 插件加载成功！|r")

		-- 检查 SuperWoW 插件是否已加载。
		-- 假设 SuperWoW 会设置一个名为 "SUPERWOW_STRING" 的全局变量。
		if _G["SUPERWOW_STRING"] then
			SuperWow = true
			local _, guid = UnitGUID("player") -- 获取玩家的 GUID
			PLAYER_GUID = guid
			DEFAULT_CHAT_FRAME:AddMessage(
				RMacroConsoleColor .. "SuperWoW 模块已检测到。玩家 GUID: " .. PLAYER_GUID .. "|r"
			)
		else
			DEFAULT_CHAT_FRAME:AddMessage(
				RMacroConsoleColor .. "|cFFFF3030未检测到 SuperWoW 模块，部分功能将受限！|r"
			)
		end
	elseif event == "UNIT_CASTEVENT" then
		local casterGUID = arg1 -- 施法者的 GUID
		local castEventType = arg3 -- 施法事件类型 ("START", "CAST", "FAIL", "CHANNEL", "INTERRUPT")
		local spellName = arg4 -- 法术名称 (主要用于 "CHANNEL")
		local durationMilliseconds = arg5 -- 持续时间 (毫秒，主要用于 "CHANNEL")

		-- 将施法者 GUID 添加到观察列表
		RMacroPushObject(casterGUID)

		if castEventType == "CHANNEL" then
			-- 对于引导法术，UNIT_CASTEVENT 提供完整的施法信息
			if casterGUID and UnitExists(casterGUID) and UnitCanAttack("player", casterGUID) then
				castStartTime[casterGUID] = GetTime()
				castName[casterGUID] = spellName
				castDuration[casterGUID] = durationMilliseconds / 1000 -- 转换为秒
			end
		elseif castEventType == "CAST" or castEventType == "FAIL" or castEventType == "INTERRUPT" then
			-- 施法成功、失败或被打断，清除该单位的施法信息
			if castStartTime[casterGUID] then
				castStartTime[casterGUID] = nil
				castName[casterGUID] = nil
				castDuration[casterGUID] = nil
			end
		-- 注意: "START" 事件通常不直接提供法术名称和持续时间，
		-- 而是由 "CHANNEL" 或后续的战斗日志事件补充。
		-- 为了 RMacroTargetCast 的目的，我们主要依赖 "CHANNEL" 和 "RAW_COMBATLOG"。
		elseif event == "RAW_COMBATLOG" then
			local logString = arg2 -- 战斗日志的原始字符串

			local objectGUID = RMacroMatchGUID(logString) -- 尝试从日志中提取 GUID
			if objectGUID then
				RMacroPushObject(objectGUID) -- 追踪该单位

				if UnitExists(objectGUID) and UnitCanAttack("player", objectGUID) then
					-- 尝试从日志中匹配 "开始施放..." 的模式来捕获法术名称
					local spellNameFromLog = RMacroMatch(logString, "开始施放(.-)。")
					if spellNameFromLog then
						-- 记录施法信息。对于从日志中捕获的施法，
						-- 如果没有明确的持续时间，我们给一个默认的较长持续时间。
						-- 实际情况中，可能需要更智能的法术持续时间数据库。
						castStartTime[objectGUID] = GetTime()
						castName[objectGUID] = spellNameFromLog
						castDuration[objectGUID] = 20 -- 默认 20 秒持续时间
					end
				end
			end
		end
	end
end

-- 注册 Frame 需要监听的事件
frame:RegisterEvent("PLAYER_LOGIN") -- 插件加载和初始化时触发
frame:RegisterEvent("UNIT_CASTEVENT") -- SuperWoW 提供的单位施法事件
frame:RegisterEvent("RAW_COMBATLOG") -- 原始战斗日志事件，用于捕获更多施法信息

-- 将 OnEvent 函数设置为 Frame 的 OnEvent 脚本
frame:SetScript("OnEvent", OnEvent)

-- =========================================================================
-- RMacroTargetCast 函数
-- =========================================================================

-- 获取目标是否正在施法
-- 返回值：
--   - 第一个返回值 (boolean): 如果目标正在施法，返回 true；否则返回 false。
--   - 第二个返回值 (string 或 nil): 如果目标正在施法，返回法术名称字符串；否则返回 nil。
function RMacroTargetCast()
	-- 1. 检查 SuperWoW 模块是否加载
	if not SuperWow then
		DEFAULT_CHAT_FRAME:AddMessage(RMacroConsoleColor .. "未加载 SuperWoW，MPTargetCast() 功能无效。|r")
		return false, nil
	end

	-- 2. 获取当前目标的 GUID 并检查目标是否存在
	local _, targetGUID = UnitGUID("target") -- 获取目标 GUID
	if not targetGUID then
		return false, nil -- 没有目标，不施法
	end

	print(targetGUID)

	-- 3. 查询内部存储的施法信息
	if castStartTime[targetGUID] then
		-- 如果有施法开始时间记录
		if castName[targetGUID] then
			-- 如果有法术名称记录，计算已施法时间
			local elapsedTime = GetTime() - castStartTime[targetGUID]
			if elapsedTime < castDuration[targetGUID] then
				-- 仍在施法持续时间内，返回 true 和法术名称
				return true, castName[targetGUID]
			else
				-- 施法已超时，清除记录并返回 false
				castStartTime[targetGUID] = nil
				castName[targetGUID] = nil
				castDuration[targetGUID] = nil
				return false, nil
			end
		else
			-- 有施法开始时间记录，但没有法术名称。
			-- 这可能是一个不完整的日志条目，或我们不关心的施法。
			-- 为避免误判，这里将其视为不正在施放可打断的已知法术。
			-- 也可以根据具体需求，例如，如果 elapsedTime 极短，可能是一个即将有名称的施法。
			-- 但为了明确性，当前版本如果无名称则不打断。
			return false, nil
		end
	end

	-- 默认情况：没有施法信息记录，认为目标没有施法
	return false, nil
end

-- 注册 /rm 命令
SlashCmdList["RM1"] = function(arg1)
	if not arg1 or string.len(arg1) < 1 then
		DEFAULT_CHAT_FRAME:AddMessage(RMacroConsoleColor .. "请输入参数，例如 /rm xxx|r")
	elseif arg1 == "cast" then
		local _, spellName = RMacroTargetCast()
		DEFAULT_CHAT_FRAME:AddMessage(RMacroConsoleColor .. spellName .. "|r")
	end
end
SLASH_CAT11 = "/rm"
