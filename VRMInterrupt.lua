-- VRMInterrupt.lua

local function getCastInfo()
  if not (C_Spell and C_Spell.UnitCastingInfo) then
    return nil, nil
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
  return castName, notInterruptible
end

function VRMINTCast()
  if not UnitExists("target") then
    return
  end

  local castName, notInterruptible = getCastInfo()
  if not castName then
    return
  end

  if notInterruptible then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9264cdVRM: |r |cFFc3a7e2目标法术不可打断。|r")
    return
  end

  CastSpellByName("脚踢")
end

function VRMINTCastSpell(enemy_name, spell_name)
  if not enemy_name or not spell_name then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9264cdVRM: |r |cFFc3a7e2VRMINTCastSpell 缺少参数：对手名 + 法术名。|r")
    return
  end

  if not UnitExists("target") then
    return
  end

  if UnitName("target") ~= enemy_name then
    return
  end

  local castName, notInterruptible = getCastInfo()
  if not castName then
    return
  end

  if notInterruptible then
    return
  end

  if not string.find(castName, spell_name, 1, true) then
    return
  end

  CastSpellByName("脚踢")
end