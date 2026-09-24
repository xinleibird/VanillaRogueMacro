-- VRMInterrupt.lua

function VRMINTCast()
  if not UnitExists("target") then
    return
  end

  if not (C_Spell and C_Spell.UnitCastingInfo) then
    return
  end

  local castName, notInterruptible

  local name, _, _, _, _, _, _, castNotInterruptible = C_Spell.UnitCastingInfo("target")
  if name then
    castName, notInterruptible = name, castNotInterruptible
  else
    local cname, _, _, _, _, _, channelNotInterruptible = C_Spell.UnitChannelInfo("target")
    if cname then
      castName, notInterruptible = cname, channelNotInterruptible
    end
  end

  if not castName then
    return
  end

  if notInterruptible then
    DEFAULT_CHAT_FRAME:AddMessage(ConsoleColor .. "目标法术不可打断。|r")
    return
  end

  CastSpellByName("脚踢")
end
