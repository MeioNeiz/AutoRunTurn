-- While autorunning, the strafe keys and Left/Right arrows turn instead of strafing. The
-- game has no autorun state API, so it is tracked from the movement functions the key
-- bindings call. Bindings can't change in combat: keys strafe for the whole fight.
local TURN = { STRAFELEFT = "TURNLEFT", STRAFERIGHT = "TURNRIGHT" }

local function Keys()
  local keys = { LEFT = "TURNLEFT", RIGHT = "TURNRIGHT" }
  for strafe, turn in pairs(TURN) do
    for _, key in ipairs({ GetBindingKey(strafe) }) do keys[key] = turn end
  end
  return keys
end

local owner = CreateFrame("Frame")
local autorun = false
local applied = false

-- Rebinding a held key strands its movement: the key-up goes to the new action, so the old
-- turn or strafe never stops. Wait until the keys are up.
local function AnyHeld()
  for key in pairs(Keys()) do
    if IsKeyDown(key) then return true end
  end
  return false
end

local function Swap()
  if autorun then
    for key, action in pairs(Keys()) do SetOverrideBinding(owner, false, key, action) end
  else
    ClearOverrideBindings(owner)
  end
  applied = autorun
end

local function Apply()
  if InCombatLockdown() or autorun == applied then
    owner:SetScript("OnUpdate", nil)
  elseif AnyHeld() then
    owner:SetScript("OnUpdate", Apply)
  else
    owner:SetScript("OnUpdate", nil)
    Swap()
  end
end

local function Set(on)
  autorun = on
  Apply()
end

-- Autorun asked for while rooted, or a state we missed (both mouse buttons): not moving.
-- Speed is secret in combat: can't tell then, so trust the key press.
local function Verify()
  if not autorun then return end
  local speed = GetUnitSpeed("player")
  if not issecretvalue(speed) and speed == 0 then Set(false) end
end

local function Started()
  Set(true)
  C_Timer.After(0.5, Verify)
end

hooksecurefunc("StartAutoRun", Started)
hooksecurefunc("StopAutoRun", function() Set(false) end)
hooksecurefunc("ToggleAutoRun", function()
  if autorun then Set(false) else Started() end
end)
hooksecurefunc("MoveForwardStart", function() Set(false) end)
hooksecurefunc("MoveBackwardStart", function() Set(false) end)

owner:RegisterEvent("PLAYER_STOPPED_MOVING")
owner:RegisterEvent("PLAYER_ENTERING_WORLD")
owner:RegisterEvent("PLAYER_REGEN_DISABLED")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- last moment protected calls are still allowed; a held key keeps turning for the fight
    if applied and not AnyHeld() then
      ClearOverrideBindings(owner)
      applied = false
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Apply()
  else
    Set(false)
  end
end)

MeioAutoRunTurn = { IsAutoRunning = function() return autorun end }
