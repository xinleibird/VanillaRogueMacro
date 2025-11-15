-- 创建一个 Frame 并监听事件
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_DEAD")

frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- SuperWow专有事件
frame:RegisterEvent("UNIT_CASTEVENT")
frame:RegisterEvent("RAW_COMBATLOG")

ConsoleColor = "|cFF9264cdVRM: |r |cFFc3a7e2"
-- 进入战斗/战斗时间
VRMInCombat = false
VRMInCombatTime = 0

local castStartTime = {}
local castName = {}
local castDuration = {}

-- GCD计时器
local gcdTimer = 0
local isCasting = false

-- 自己的GUID
local playerGuid = 0

-- 周围的guid
local ObjectArray = {}

UnitXP_SP3 = pcall(UnitXP, "nop", "nop")
SuperWow = false

function VRMGetGCD()
	return GetTime() - gcdTimer
end

local function resetData()
	VRMInCombat = false
	isCasting = false
	castStartTime = {}
	castName = {}
	castDuration = {}
end

VRMAddonMessageTimer = 0

function VRMSendAddonMessage()
	if GetTime() - VRMAddonMessageTimer > 60 then
		-- reset time
		VRMAddonMessageTimer = GetTime()

		-- send message
		local name = UnitName("player")

		local inRaid = GetNumRaidMembers() > 0
		local inParty = GetNumPartyMembers() > 0

		SendAddonMessage("VRM", name, "GUILD")
		if inRaid then
			-- 当前在团队中（可能是团队或者团队中的小队）
			SendAddonMessage("VRM", name, "RAID")
		elseif inParty then
			-- 当前在小队中（但不是团队）
			SendAddonMessage("VRM", name, "PARTY")
		else
			-- 单独一人
		end
	end
end

function VRMINTCast(spellname)
	-- 检测是否有SuperWow模组
	if not SuperWow then
		DEFAULT_CHAT_FRAME:AddMessage(ConsoleColor .. "未加载SuperWow，自动打断读条功能无效。|r")
		return
	end

	-- 确认有目标
	if not UnitExists("target") then
		return
	end

	-- 确认目标正在读条
	local cast, name = VRMTargetCast()
	if not cast then
		return
	end

	-- 确认读条法术是指定法术
	if spellname then
		if not string.find(name, spellname) then
			return
		end
	end

	VRMIntCastSpell()
end

function VRMIntCastSpell()
	CastSpellByName("脚踢")
end

function VRMTargetCast()
	-- 检测是否有SuperWow模组
	if not SuperWow then
		return false, 0
	end

	-- 获取目标GUID，并确保其存在
	local _, guid = UnitExists("target")
	if not guid then
		return false, 0
	end

	if castStartTime[guid] ~= nil then
		if castName[guid] then
			--local spellName, _, _, _, _, _, _, _ = GetSpellInfo(castName[guid],"spell")
			local timer = GetTime() - castStartTime[guid]
			if timer < castDuration[guid] then
				return true, castName[guid]
			else
				return false, 0
			end
		end

		return true, 0
	end

	return false, 0
end

function VRMPushNpc(inGUID)
	if inGUID and not ObjectArray[inGUID] then
		if UnitCanAttack("player", inGUID) and not UnitIsDead(inGUID) then
			ObjectArray[inGUID] = GetTime()
		end
	end
end

function VRMMatchGuid(str, length)
	-- 生成 0x + N 位十六进制的模式
	local pattern = "0x" .. string.rep("%x", length or 16) -- 默认 16 位
	local start, finish = string.find(str, pattern)
	return start and string.sub(str, start, finish) or nil
end

function VRMMatch(str, pattern, index)
	if type(str) ~= "string" and type(str) ~= "number" then
		return nil --error(format("bad argument #1 to 'match' (string expected, got %s)", str and type(str) or "no value"), 2)
	elseif type(pattern) ~= "string" and type(pattern) ~= "number" then
		return nil --error(format("bad argument #2 to 'match' (string expected, got %s)", pattern and type(pattern) or "no value"), 2)
	elseif index and type(index) ~= "number" and (type(index) ~= "string" or index == "") then
		return nil --error(format("bad argument #3 to 'match' (number expected, got %s)", index and type(index) or "no value"), 2)
	end

	local i1, i2, match, match2 = string.find(str, pattern, index)

	if not match and i2 and i2 >= i1 then
		return sub(str, i1, i2)
	elseif match2 then
		local matches = { string.find(str, pattern, index) }
		tremove(matches, 2)
		tremove(matches, 1)
		return unpack(matches)
	end

	return match
end

function VRMCheckSpellLog(str)
	-- 通过日志收集周围目标
	local objectGUID = VRMMatchGuid(str)
	VRMPushNpc(objectGUID)

	if objectGUID and UnitCanAttack("player", objectGUID) then
		-- 打断部分收集信息
		local spellName = VRMMatch(str, "开始施放(.-)。")
		if spellName then
			castStartTime[objectGUID] = GetTime()
			castName[objectGUID] = spellName
			castDuration[objectGUID] = 20000 -- 用20秒作为长度
			return
		end
	end
end

local function OnEvent()
	-- 初始化
	if event == "PLAYER_LOGIN" then
		DEFAULT_CHAT_FRAME:AddMessage(ConsoleColor .. "VRM 加载完成！|r")

		if SUPERWOW_STRING then
			SuperWow = true
			-- 获取并保存自己的GUID
			_, playerGuid = UnitExists("player")
		end
	elseif event == "ADDON_LOADED" then
		_, VRMPlayerClass = UnitClass("player")

		-- 进入游戏世界刷新常量值
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- 刷新角色属性状态值
		resetData()

	-- 目标变化事件
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- 重置当前目标的战斗事件
		if VRMInCombat then
			VRMInCombatTime = GetTime()
		end

		VRMSendAddonMessage()

	-- 进入战斗事件
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- 战斗标记
		VRMInCombat = true
		VRMInCombatTime = GetTime()

	-- 离开战斗事件
	elseif event == "PLAYER_REGEN_ENABLED" then
		resetData()

	-- 玩家死亡，重置一些参数
	elseif event == "PLAYER_DEAD" then
		resetData()

	-- 施法事件处理，读条类，读条也要处理GCD
	elseif event == "SPELLCAST_START" then
		-- GCD时间处理
		isCasting = true
		gcdTimer = GetTime()
	elseif event == "SPELLCAST_STOP" then
		-- GCD时间处理
		if isCasting then
			isCasting = false
		else
			-- 未读条，应该是瞬发，GCD时间启动
			gcdTimer = GetTime()
		end
	elseif event == "SPELLCAST_FAILED" then
		-- GCD时间处理
		if isCasting then
			isCasting = false
		end
	elseif event == "SPELLCAST_INTERRUPTED" then
		-- GCD时间处理
		if isCasting then
			isCasting = false
		end

		-- 施法、攻击事件处理
	elseif event == "UNIT_CASTEVENT" then
		VRMPushNpc(arg1)
		VRMPushNpc(arg2)

		-- 施法事件监测
		if arg3 == "START" then
			if arg1 == playerGuid then
				isCasting = true
			end
		elseif arg3 == "CAST" then
			-- 监控所有人

			-- 用于打断
			if castStartTime[arg1] then
				castStartTime[arg1] = nil
				castName[arg1] = nil
				castDuration[arg1] = nil
			end

			-- 仅监控自己放出的技能
			if arg1 == playerGuid then
				isCasting = false
			end
		elseif arg3 == "FAIL" then
			if arg1 == playerGuid then
				isCasting = false
			end

			-- 监控所有人
			if castStartTime[arg1] then
				castStartTime[arg1] = nil
				castName[arg1] = nil
				castDuration[arg1] = nil
			end
		elseif arg3 == "CHANNEL" then
			if arg1 and UnitCanAttack("player", arg1) then
				castStartTime[arg1] = GetTime()
				castName[arg1] = arg4
				castDuration[arg1] = arg5 / 1000
			end
		end

	-- 战斗日志事件处理
	elseif event == "RAW_COMBATLOG" then
		VRMCheckSpellLog(arg2)
	end
end

-- 设置事件处理函数
frame:SetScript("OnEvent", OnEvent)
