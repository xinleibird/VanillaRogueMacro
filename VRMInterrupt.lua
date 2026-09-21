-- VRMInterrupt.lua

function VRMIntCastSpell()
    CastSpellByName("脚踢")
end

function VRMTargetCast()
    if not UnitExists("target") then
        return false, 0
    end

    if C_Spell and C_Spell.UnitCastingInfo then
        local name = C_Spell.UnitCastingInfo("target")
        if name then
            return true, name
        end

        local cname = C_Spell.UnitChannelInfo("target")
        if cname then
            return true, cname
        end
    end

    return false, 0
end

function VRMINTCast(enemy_name, spell_name)
    if not UnitExists("target") then
        return
    end

    if enemy_name and UnitName("target") ~= enemy_name then
        return
    end

    local cast, name = VRMTargetCast()
    if not cast then
        return
    end

    if spell_name and not string.find(name, spell_name) then
        return
    end

    VRMIntCastSpell()
end