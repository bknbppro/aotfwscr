--[[
    AOTFR Tools: Nape Hitbox Expander + Gear (client-side)
    Observed on: placeId 11567929685 ("Practice"), placeVersion 594, 2026-11-25

    Hitbox facts (read live from this build):
      - Titans live in Workspace.OnGameTitans as Models with BoolValue "Titan".
      - "Nape" is an invisible Part (CanQuery/CanTouch on, Massless, CanCollide off),
        Weld p0=Nape p1=UpperTorso, so resizing keeps it centered behind UpperTorso.
      - Hits are detected on the client: Character.Gear uses ReplicatedStorage.RaycastHitbox
        in PartMode and sends the hit part via Events.HitEvent:FireServer(part, dmg, key).
        A locally larger Nape is therefore hit by those rays more easily.
      - Unknown: whether the server re-validates distance/position of the Nape hit.
      - Shifters (e.g. Workspace.ArmoredTitan / Workspace.FemaleTitan) are player characters with an
        invisible "SNape" Part (welded to UpperTorso); Gear's hit check accepts "Nape" or "SNape".
      - Shifter weak-point parts (seen on Workspace.ColossalTitan and Workspace.ArmoredTitan): invisible,
        massless Parts welded to the body: SNape (UpperTorso), SEyes (Head), LLegTendons/RLegTendons
        (lower legs). Armored's leg parts carry BoolValue "CalfArmor" (true = calf armor intact).
        Armored calf armor, recorded live (own ArmoredTitan): LLegTendons/RLegTendons.CalfArmor stayed TRUE
        through the whole cycle; the real state is the model's NumberValue CalfArmorHealth (child
        CalfArmorMaxHealth = 20):
          20 intact     - <Left|Right>LowerLeg.CalfArmor1 visible, CalfArmor2 hidden
          10 cracked    - after "Break Plates" (ARLocal: CalfArmorBreak:FireServer(true)): CalfArmor1 deleted,
                          CalfArmor2 (cracked pieces) shown
           0 broken     - after running / dashing: CalfArmor2 deleted
          20 again      - after the player regenerates the plates (costs 20 s of shift time)
        Armored legs open at CalfArmorHealth <= 0, or below max when ArmoredLegsOnCracked is on.
        Workspace.FemaleTitan has the same parts; each carries BoolValue "Armored" (hardening).
      - Workspace.BeastTitan and Workspace.CartTitan (seen live): same SNape / SEyes / L-RLegTendons parts,
        no hardening rule used.
      - Workspace.AttackTitan (seen live): same SNape / SEyes / L-RLegTendons parts, no hardening rule used.
      - Workspace.WarhammerTitan (seen live): same parts, every one with BoolValue "Armored" (like Female),
        plus HumanHardening. Parts close while their own "Armored" is true (assumed to mirror Female, not
        seen flip). Its SNape read 11.13 x 6.21 x 7.37 only because the "Other shifters" fallback had already
        expanded it (3.5x of ~3.19 x 1.78 x 2.11), so it uses the normal 3x default.
      - Workspace.JawTitan (seen live, Shifter=Jaw, Variant=Porco): same SNape / SEyes / L-RLegTendons, each
        with BoolValue "Armored"; gated the same way as War Hammer (flip not seen). Its SNape size was also
        read while already expanded by the fallback.
      - Workspace.WeakArmoredTitan (seen live, Shifter=Armored, ARLocal script): weakened Armored. Only
        Upper/LowerTorso carry "Armor" meshes; head, arms and legs are "NonArmor", there is no HeadArmor and
        no CalfArmor1/2 plates, and L/RLegTendons have no "CalfArmor" BoolValue ("Armored"=false).
        CalfArmorHealth=20 still exists but has no plates behind it, so it is not used. Rule: eyes always,
        legs while their own "Armored" is false, nape left out (torso stays armored, SNape.Armored=true).
      - Kneel arms (seen in WarhammerTitan.WALocal + live models): a shifter whose legs are cut has
        LLegTendons.LLDebounce and RLegTendons.RLDebounce both true; WALocal stuns (kneels) exactly while both
        are true. Arm hit parts are LArmTendons / RArmTendons (each with its own "Armored" BoolValue).
        Mindless titans (OnGameTitans) carry LLDebounce / RLDebounce BoolValues on the model root; they are
        assumed to mean the same (not seen flipping). Mindless titans have no separate arm hitbox: the arm is
        the visible LeftUpperArm / RightUpperArm MeshPart (BoolValue "Cutted"), so expanding it also scales
        the arm mesh visually; it is made non-collidable locally while expanded. The Gear hit code sends any
        touched part to HitEvent; whether the server cuts on an upper-arm hit is not verified.
      - Hooks (Q/E) aim with mouse.Target / mouse.Hit (TargetFilter = own Character). An __index hook
        on the PlayerMouse re-casts the ray ignoring expanded napes, so hooks land on what is behind them.

    Gear facts (Character.Humanoid.Gear, same build):
      - Gas (NumberValue, max 2000 per refill code / GasGui bar) is decremented ONLY by the
        client Gear script; the server asks for it via GasUpdateLocal -> GasUpdateServer:FireServer(Gas.Value).
        Holding it at max locally = infinite gas.
      - Blades (IntValue, /8) and BladeDurability (IntValue, max = Upgrades.BladesEfficiency) are never
        written by client scripts except Blades=8 on refill; the server owns them (BrokenBlades event,
        BladeReload:FireServer). Client-side locking cannot change the server's count.
      - Skills: Gear gates every skill on the LOCAL Humanoid.Gear.Skills.<Skill> BoolValue
        (Impulse, Dodge, Counter, BladeThrow, SuperJump, HandCut, HandCutMk2) and shows the hotbar via
        PlayerGui.SkillsGui.<Skill>.Enabled. Real unlocks go through MenuGui.UnlockSkill:InvokeServer
        and cost PlayersDataFolder.<name>.SkillPoints. "Unlock skills (local)" only flips the local
        values; no remote is called and no data changes. Unknown: whether the server re-checks its own
        Skills values when a skill's effect is sent.
      - Hood: Humanoid.Hood (BoolValue). The menu's HoodButton calls
        PlayerGui.MenuGui.ClothesChange:InvokeServer("Hood", nil, true) only if not Stunned/Grabbed/Burning,
        team is not Warriors / Interior Police / Rogue, GameStateValues.HoodsEnabled is true and the
        character has Cloak/BrownCloak/GreyCloak. "Auto Hood" makes the same call under the same checks.
      - Shifter time limit (seen on FemaleTitan / FELocal): the SERVER decrements <ShifterLocal>.Stats.Time
        (~1/s); the CLIENT script's only Time.Changed handler calls Unshift(true) -> ShiftEvent:FireServer(
        false, nil, true) when Time <= 0. "Infinite Shift" disables that one connection (getconnections),
      - (note) Shifter stamina: the shift form's <XXLocal> script drives Humanoid.Stamina (current, IntValue) up to
        Stats.TotalStamina (max) and the StaminaGui bar reads Stamina/TotalStamina -- client-side, like gas.
        "Infinite Stamina" holds Humanoid.Stamina at TotalStamina each frame while shifted. The separate
        Stats.Energy (abilities) is left alone. Server authority over stamina is not verified.
      - (note) Dodge: Gear pushes the dodge with HumanoidRootPart:ApplyImpulse(LookVector * v406), v406
        negative (backward), from the Dodge animation (rbxassetid seen 9371217951, read live per character).
        "Dodge boost" listens for that animation on our own character and applies an extra
        ApplyImpulse(LookVector * -DodgeBoostImpulse) in the same direction. Flat, client-side; server
        validation of the extra travel is not verified.
        so the timer no longer unshifts you. Manual unshift and Defeated-unshift are untouched.
        Cart (CALocal) has no timer at all. Unknown: whether the server forces an unshift by itself at 0.
      - Staff: MenuLocalSript / LocalChat label players from PlayersDataFolder.<name>.GroupRank (rank in
        group 11141380): 97 Moderator, 98 Administrator, 99 Head Department, 100 Head of Staff, >=101 Dev;
        "DankAlert8686" is Founder. StaffTag only hides the chat/list tag, GroupRank stays. "Staff Alert"
        checks both GroupRank and Player:GetRankInGroup(11141380) for every player in the server.
        Group roles (GroupService): 93 Tester, 94 Contributor, 95 Balance Committee, 96 Junior Moderator,
        97 Moderator, 98 Administrator, 99 Head Department, 100 Head of Staff, 101 Developer, 255 Owner.
      - Counter: Gear handles V / MouseButton3 when blades are out, not grabbed, counter cooldown (3 s,
        HvHCooldowns.CounterCooldown) is over; it calls MoreEvents.Counter:InvokeServer(...) and the SERVER
        decides success. Attacks are Gear.Animations BladeHolding (charge) -> BladeRelease*/LeviBladeRelease*
        (swing), plus KickRelease / HandCut / HandCutMk2. Other players' animations replicate, so
        "Auto Counter" presses V when a nearby player starts one of those. Humanoid.BladeAttacking is never
        written by client scripts (server-owned); it is used as a second trigger, UNVERIFIED as to timing.
        Counter window length and the range at which a swing can hit are UNKNOWN: CounterRange is uncalibrated.
        Live recording (player vs player): BladeHoldingAnim, then BladeAttacking -> true together with
        BladeReleaseAnim ~0.05 s later, BladeAttacking back to false ~0.5 s after that.
        Titans: mindless titans' attacks are their Animations folder entries (B/F/L/R/TGrab*, *Eat*). Shifter
        attack animations are played by the server and exist nowhere on the client (searched all Animation
        objects and the shifter scripts); the shifter scripts (ATLocal/ARLocal/...) only name non-combat
        animations (+ ArmoredCharge*, *TitanThrow, ExplosivesThrow). Live track properties separate the rest:
        idle/walk/run/HitboxMovement are Looped; a combat anim seen on AttackTitan (16497333502) is not looped,
        Priority Action, 1.07 s; a Colossal ability (130668367288943) is not looped, Action, 12 s. So an
        unnamed shifter animation counts as an attack only if not Looped, Priority Action..Action4 and
        Length <= TitanAttackMaxLength. Titan distance is measured to the surface of its nearest body part
        (a bounding-box radius made a far-away Colossal read "0 studs" and wasted the 3 s cooldown).
        Flying attackers: the attacker's own client decides the hit, and on our screen they lag behind by
        their ping + interpolation, so a swing that starts far away already lands before an
        animation-start check can react (and a charge started out of range was never re-checked). Predictive
        mode keeps every charging / swinging player "armed" and, each frame, presses V when
        distance <= CounterHitReach + closingSpeed * (CounterLeadTime + own network ping).
        CounterHitReach and CounterLeadTime are UNCALIBRATED starting values.
        Live recording (flying kill): the attacker pressed their own counter mid-flight (LeviCounter at 25 studs,
        closing 63 studs/s); its spin (LeviDefenseSpin) killed us 0.23 s later, at ~11 studs on our screen.
        No blade charge/swing was played, so that attack never armed the counter. Counter / LeviCounter /
        DefenseSpin / LeviDefenseSpin now arm prediction too, but only for an attacker closing faster than
        CounterSpinMinClosing (a standing opponent's counter near us did no damage in the same recording).
        Kick response: a player's KickRelease animation (Gear's X kick, 20 damage, seen landing 0.14-0.25 s
        after the animation at 15-23 studs while flying) no longer triggers a counter; "Attack on kick" taps
        MouseButton1 through VirtualInputManager (Gear: press starts BladeHolding, release swings and runs
        LocalHitbox) after turning toward the kicker. Gear ignores the click when gameProcessed (cursor over a
        GUI) or when blades are not out. Whether a swing beats a kick on the server is not verified.
        Latency: named animations (swing/charge/spin/kick) no longer wait for track.Length (that wait, up to
        0.12 s, is only needed for unnamed shifter animations). A kick swings at once when
        dist <= KickSwingReach + closing * (CounterLeadTime + ping), otherwise the kicker stays armed and is
        re-checked every frame, so a far kick is answered when it arrives instead of whiffing early. The tap
        is one frame long.
        Landing (Gear FFE, on touch) clears PlatformStand only while Gear's "busy" upvalue is false. Counter
        sets it true and only the server's MoreEvents.PFST(false, true, ...) reply, a finished dodge/impulse
        or the gas jump clear it; if that reply never comes the character keeps PlatformStand on the ground
        (looks like a ragdoll it cannot leave). "Anti stuck" does what FFE would: PlatformStand false and
        JumpPower 11, only when grounded (ray <= StuckGroundDist), no vertical motion (sliding allowed), not stunned/grabbed/ragdolled
        and in human form, for StuckDelay seconds. The busy upvalue itself cannot be reset from here.
        Gear's InputBegan connections are foreign (not callable from the executor), so V is sent through
        VirtualInputManager; the remaining delay is network latency, reduced only by counter-on-charge.

    Settings: saved to the executor workspace as aotfr_tools_settings.json whenever they change (checked
    every 0.5 s) and on close; loaded on start before the menu is built. Delete the file to reset.

    Keys: RightShift = show/hide menu.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Single instance: unload a previous copy before starting.
local ENV = (getgenv and getgenv()) or _G
if ENV.__NapeExpander and ENV.__NapeExpander.Unload then
    pcall(ENV.__NapeExpander.Unload)
end

local Config = {
    Enabled = false,
    Visualize = true,
    -- Hitbox size multipliers per titan type (X = width, Y = height, Z = depth).
    Scales = {
        Titan = { X = 3, Y = 3, Z = 3 },
        Colossal = { X = 3, Y = 3, Z = 3 },
        Armored = { X = 3, Y = 3, Z = 3 },
        Female = { X = 3, Y = 3, Z = 3 },
        Attack = { X = 3, Y = 3, Z = 3 },
        Beast = { X = 3, Y = 3, Z = 3 },
        Cart = { X = 3, Y = 3, Z = 3 },
        Warhammer = { X = 3, Y = 3, Z = 3 },
        WeakArmored = { X = 3, Y = 3, Z = 3 },
        Jaw = { X = 3, Y = 3, Z = 3 },
        Shifter = { X = 3, Y = 3, Z = 3 },
        KneelArms = { X = 3, Y = 3, Z = 3 },
    },
    MinScale = 1,
    MaxScale = 20,
    -- Per-target switches (all also require "Expander" ON):
    --   Colossal = ColossalTitan SNape + SEyes
    --   Armored  = ArmoredTitan SEyes + Left/Right LegTendons (each leg only while its CalfArmor is false)
    --   Female   = FemaleTitan SNape + SEyes + legs (each part only while its "Armored" hardening is false)
    --   Attack   = Attack Titan SNape + SEyes + legs (no hardening)
    --   Beast    = BeastTitan SNape + SEyes + legs (no hardening)
    --   Cart     = CartTitan SNape + SEyes + legs (no hardening)
    --   Shifter  = any other shifter's SNape
    Kinds = { Titan = true, Colossal = true, Armored = true, Female = true, Attack = true, Beast = true,
        Cart = true, Warhammer = true, Jaw = true, WeakArmored = true, Shifter = true, KneelArms = true },
    KneelArmsMindless = true,   -- also expand mindless titans' upper arms (visible mesh) while kneeling
    KneelNeedsBothLegs = true,  -- true: both legs cut (the game's own kneel condition); false: any leg
    AttackTitanModelNames = { "AttackTitan" },  -- verified live
    ArmoredLegsOnCracked = false, -- false: Armored legs open only when fully broken (CalfArmorHealth 0)
    HookPassThrough = true,    -- Q/E hooks ignore expanded napes
    VisibilityInterval = 0.1,  -- seconds between line-of-sight checks for "Show hitbox"
    HookRayLength = 5000,
    ToggleMenuKey = Enum.KeyCode.RightShift,

    InfiniteGas = false,
    GasMax = 2000,           -- from Gear refill code (Gas.Value = 2000) and GasGui bar (Gas/2000)
    AutoReload = false,      -- presses R when the server breaks the blades and spares remain
    AutoReloadCooldown = 1.5,
    LockBlades = false,      -- experimental: local Blades count lock, server count unaffected
    BladesMax = 8,           -- from Gear UI text ("/8") and refill code (Blades.Value = 8)
    UnlockSkills = false,    -- local-only: Gear.Skills.* = true and SkillsGui entries enabled
    AutoHood = false,        -- puts the hood back on whenever the menu button would be allowed to
    AutoHoodCooldown = 2,
    HoodKey = Enum.KeyCode.H, -- toggles hood + cloak together (equip on, remove off); H unused by Gear
    InfiniteShift = false,   -- disable the shifter script's Time.Changed -> Unshift handler
    InfiniteStamina = false, -- while shifted: hold Humanoid.Stamina at TotalStamina (client-driven bar)
    DodgeBoost = false,      -- add extra backward impulse on the dodge skill (further dash)
    DodgeBoostImpulse = 30,  -- studs-impulse added backward on each dodge (game's own base is ~45), UNCALIBRATED
    StaffAlert = true,       -- notify when a staff member is in / joins / leaves the server
    StaffGroupId = 11141380, -- from OwnerPanelLocal / MenuLocalSript (GroupRank)
    StaffMinRank = 96,       -- group roles: 96 Junior Moderator .. 101 Developer, 255 Owner
    StaffNames = { DankAlert8686 = "Founder" },

    AutoCounter = false,
    CounterRange = 30,           -- studs, UNCALIBRATED
    CounterOnCharge = true,      -- also trigger on a close attacker's charge animation (earlier, more misses)
    CounterChargeRange = 15,     -- studs; charge trigger only this close, UNCALIBRATED
    CounterTitans = true,        -- also counter mindless titans and shifters
    TitanCounterRange = 20,      -- studs from the surface of the titan's nearest body part, UNCALIBRATED
    TitanAttackMaxLength = 3,    -- seconds; longer unnamed shifter animations are abilities, not punches
    CounterIgnoreModels = { ColossalTitan = true },  -- never auto-counter these models
    TitanAttackWords = { "Grab", "Eat", "Charge", "Throw", "Punch", "Kick", "Smash", "Slam", "Stomp", "Swipe",
        "Bite", "Attack" },
    CounterSkipTeammates = true,
    CounterCooldown = 3.05,      -- Gear's counter cooldown is 3 s
    CounterSwingAnims = { "BladeReleaseAnim", "BladeRelease2Anim", "BladeRelease3Anim", "BladeReleaseSpamAnim",
        "LeviBladeReleaseAnim", "LeviBladeReleaseSpamAnim", "HandCut", "HandCutMk2" },
    CounterKickAnims = { "KickRelease" },
    CounterChargeAnims = { "BladeHoldingAnim", "LeviBladeHoldingAnim" },
    AntiStuck = true,            -- free the character when it is left PlatformStand on the ground
    StuckDelay = 0.35,           -- seconds grounded (no vertical motion) before freeing
    StuckMaxSlide = 60,          -- studs/s; sliding along the floor faster than this is left alone
    StuckGroundDist = 3,         -- studs from root to floor that count as grounded (rig HipHeight ~0.7)
    KickResponse = true,         -- a player's kick makes us swing (MouseButton1 tap) instead of countering
    KickResponseRange = 80,      -- studs; kickers farther than this are ignored
    KickSwingReach = 10,         -- studs at which our swing is assumed to connect, UNCALIBRATED
    KickArmTime = 1.2,           -- seconds a kicker stays armed after the kick animation starts
    KickResponseCooldown = 1,    -- seconds between automatic swings
    KickResponseFace = true,     -- turn toward the kicker before the swing
    AttackTapHold = 0,           -- seconds MouseButton1 is held (Gear swings on release); 0 = one frame
    CounterPredict = true,       -- keep charging/swinging players armed and counter by time-to-contact
    CounterLeadTime = 0.25,      -- seconds added to own ping when predicting, UNCALIBRATED
    CounterHitReach = 12,        -- studs (on our screen) at which a hit connects; ~11 seen live, UNCALIBRATED
    CounterSpinAnims = { "Counter", "LeviCounter", "DefenseSpin", "LeviDefenseSpin" },
    CounterSpinMinClosing = 15,  -- studs/s; a counter-spin only arms when the attacker flies at us
    CounterPredictMaxRange = 150, -- studs; farther armed players are ignored
    CounterArmMax = 4,           -- seconds an attacker stays armed at most
    CounterSwingGrace = 0.6,     -- seconds an attacker stays armed after the charge/swing animation ends

    -- Player ESP (Drawing API). Same universe has teams: Soldiers / Warriors / Interior Police /
    -- Rogue / Training Corps / Founder. "Enemies" = any team other than yours (Warriors included here).
    EspEnabled = false,
    EspBox = true,
    EspName = true,
    EspDistance = true,
    EspHealth = true,
    EspTracer = false,           -- line from bottom-centre of the screen to each target
    EspTeamColor = true,         -- colour boxes/names by the target's TeamColor (false = EspFallbackColor)
    EspAllTeams = false,         -- false: only players not on your team; true: every other player
    EspWarriorsOnly = true,      -- ESP shows only Warriors (PlayersDataFolder.<name>.Warrior or team Warriors)
    WarriorListKey = Enum.KeyCode.K,  -- shows/hides the Warriors name list (bottom-right); K is unused by Gear
    WarriorListInterval = 0.5,   -- seconds between list refreshes while it is open
    EspMaxDistance = 2000,       -- studs; 0 = no limit
    EspTextSize = 13,
    EspFallbackColor = Color3.fromRGB(255, 60, 60),
}

local VirtualInputManager = game:GetService("VirtualInputManager")

------------------------------------------------------------------------
-- Settings persistence (executor workspace file, JSON)
------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local SettingsFile = "aotfr_tools_settings.json"
local PersistKeys = {
    "Enabled", "Visualize", "Scales", "Kinds", "HookPassThrough",
    "InfiniteGas", "AutoReload", "LockBlades", "UnlockSkills",
    "AutoHood", "InfiniteShift", "InfiniteStamina", "DodgeBoost", "DodgeBoostImpulse", "StaffAlert",
    "AutoCounter", "CounterTitans", "CounterOnCharge", "KickResponse", "AntiStuck", "CounterPredict", "CounterRange", "CounterChargeRange", "TitanCounterRange",
    "ArmoredLegsOnCracked", "KneelArmsMindless", "KneelNeedsBothLegs",
    "EspEnabled", "EspBox", "EspName", "EspDistance", "EspHealth", "EspTracer",
    "EspTeamColor", "EspAllTeams", "EspMaxDistance", "EspWarriorsOnly",
}

local function settingsJson()
    local t = {}
    for _, k in ipairs(PersistKeys) do t[k] = Config[k] end
    t.Keybinds = {
        ToggleMenuKey = Config.ToggleMenuKey.Name,
        HoodKey = Config.HoodKey.Name,
        WarriorListKey = Config.WarriorListKey.Name,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(t) end)
    return ok and json or nil
end

-- Copies saved values over the defaults; every value is type/range checked, anything else keeps its default.
local function loadSettings()
    if not readfile then return false end
    if isfile then
        local okExists, exists = pcall(isfile, SettingsFile)
        if not okExists or not exists then return false end
    end
    local ok, raw = pcall(readfile, SettingsFile)
    if not ok or type(raw) ~= "string" or raw == "" then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDecode or type(data) ~= "table" then return false end
    for _, k in ipairs(PersistKeys) do
        local v, def = data[k], Config[k]
        if k == "Scales" then
            if type(v) == "table" then
                for kind, axes in pairs(def) do
                    local src = v[kind]
                    if type(src) == "table" then
                        for _, a in ipairs({ "X", "Y", "Z" }) do
                            local n = tonumber(src[a])
                            if n and n == n then axes[a] = math.clamp(n, Config.MinScale, Config.MaxScale) end
                        end
                    end
                end
            end
        elseif k == "Kinds" then
            if type(v) == "table" then
                for kind in pairs(def) do
                    if type(v[kind]) == "boolean" then def[kind] = v[kind] end
                end
            end
        elseif type(def) == "boolean" then
            if type(v) == "boolean" then Config[k] = v end
        elseif type(def) == "number" then
            local n = tonumber(v)
            if n and n == n and n > 0 and n < 1000 then Config[k] = n end
        end
    end
    if type(data.Keybinds) == "table" then
        for _, name in ipairs({ "ToggleMenuKey", "HoodKey", "WarriorListKey" }) do
            local kn = data.Keybinds[name]
            if type(kn) == "string" then
                local okK, code = pcall(function() return Enum.KeyCode[kn] end)
                if okK and typeof(code) == "EnumItem" then Config[name] = code end
            end
        end
    end
    return true
end

local SettingsLoaded = loadSettings()
local LastSavedJson = settingsJson()

local function saveSettings(force)
    if not writefile then return end
    local json = settingsJson()
    if not json or (not force and json == LastSavedJson) then return end
    if pcall(writefile, SettingsFile, json) then LastSavedJson = json end
end

local Tracked = {}       -- [napePart] = { OriginalSize = Vector3, Adornment = BoxHandleAdornment?, Conns = {} }
local Connections = {}
local Applying = false   -- guards our own Size writes from the Size-changed listener
local Rebinding = false  -- true while a keybind row is waiting to capture a key (other key handlers pause)

------------------------------------------------------------------------
-- Titan / Nape identification
------------------------------------------------------------------------
local function isTitanModel(model)
    if not model or not model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local flag = model:FindFirstChild("Titan")
    return flag ~= nil and flag:IsA("BoolValue") and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isShifterModel(model)
    if not model or not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local WatchedNames = { Nape = true, SNape = true, SEyes = true, LLegTendons = true, RLegTendons = true,
    LArmTendons = true, RArmTendons = true, LeftUpperArm = true, RightUpperArm = true }
local ShifterArmNames = { LArmTendons = true, RArmTendons = true }
local MindlessArmNames = { LeftUpperArm = true, RightUpperArm = true }

-- Per shifter model name: which parts expand, and which are gated by a BoolValue inside the part
-- (expanded only while that value is false).
local ShifterRules = {
    ColossalTitan = { Kind = "Colossal", Parts = { SNape = true, SEyes = true } },
    ArmoredTitan = {
        Kind = "Armored",
        Parts = { SEyes = true },
        Gated = { LLegTendons = "CalfArmor", RLegTendons = "CalfArmor" },
    },
    FemaleTitan = {
        Kind = "Female",
        Gated = { SNape = "Armored", SEyes = "Armored", LLegTendons = "Armored", RLegTendons = "Armored" },
    },
    BeastTitan = { Kind = "Beast", Parts = { SNape = true, SEyes = true, LLegTendons = true, RLegTendons = true } },
    CartTitan = { Kind = "Cart", Parts = { SNape = true, SEyes = true, LLegTendons = true, RLegTendons = true } },
    WarhammerTitan = {
        Kind = "Warhammer",
        Gated = { SNape = "Armored", SEyes = "Armored", LLegTendons = "Armored", RLegTendons = "Armored" },
    },
    WeakArmoredTitan = {
        Kind = "WeakArmored",
        Parts = { SEyes = true },
        Gated = { LLegTendons = "Armored", RLegTendons = "Armored" },
    },
    JawTitan = {
        Kind = "Jaw",
        Gated = { SNape = "Armored", SEyes = "Armored", LLegTendons = "Armored", RLegTendons = "Armored" },
    },
}
do
    local attackRule = { Kind = "Attack", Parts = { SNape = true, SEyes = true, LLegTendons = true, RLegTendons = true } }
    for _, n in ipairs(Config.AttackTitanModelNames) do ShifterRules[n] = attackRule end
end

-- Returns kind and an optional gate value name for a watched part, or nil.
local function partRule(part)
    if not part:IsA("BasePart") then return nil end
    local model = part.Parent
    local name = part.Name
    if name == "Nape" then
        if isTitanModel(model) then return "Titan" end
        return nil
    end
    if MindlessArmNames[name] then
        if isTitanModel(model) then return "KneelArms", "Kneel" end
        return nil
    end
    if not isShifterModel(model) then return nil end
    if ShifterArmNames[name] then return "KneelArms", "Kneel" end
    local rule = ShifterRules[model.Name]
    if rule then
        local gate = rule.Gated and rule.Gated[name]
        if gate then return rule.Kind, gate end
        if rule.Parts and rule.Parts[name] then return rule.Kind end
        return nil
    end
    if name == "SNape" then return "Shifter" end
    return nil
end

local function isNapeName(name)
    return WatchedNames[name] == true
end

local KindColor = {
    Titan = Color3.fromRGB(255, 60, 60),
    Colossal = Color3.fromRGB(255, 120, 40),
    Armored = Color3.fromRGB(80, 200, 255),
    Female = Color3.fromRGB(255, 90, 200),
    Attack = Color3.fromRGB(120, 255, 120),
    Beast = Color3.fromRGB(190, 140, 90),
    Cart = Color3.fromRGB(170, 120, 255),
    Warhammer = Color3.fromRGB(235, 225, 120),
    Jaw = Color3.fromRGB(120, 230, 200),
    WeakArmored = Color3.fromRGB(255, 170, 110),
    KneelArms = Color3.fromRGB(255, 255, 255),
    Shifter = Color3.fromRGB(255, 170, 40),
}

local ShortPartName = { SNape = "nape", SEyes = "eyes", LLegTendons = "Lleg", RLegTendons = "Rleg",
    LArmTendons = "Larm", RArmTendons = "Rarm", LeftUpperArm = "Larm", RightUpperArm = "Rarm" }

------------------------------------------------------------------------
-- Pure size math
------------------------------------------------------------------------
local function clampScale(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.clamp(v, Config.MinScale, Config.MaxScale)
end

local function targetSize(original, kind)
    local sc = Config.Scales[kind] or Config.Scales.Shifter
    return Vector3.new(original.X * sc.X, original.Y * sc.Y, original.Z * sc.Z)
end

------------------------------------------------------------------------
-- Apply / restore
------------------------------------------------------------------------
local ExcludeDirty = true  -- hook/visibility exclude list needs rebuilding

local function boolTrue(parent, name)
    local v = parent and parent:FindFirstChild(name)
    return v ~= nil and v:IsA("BoolValue") and v.Value == true
end

-- Legs-cut kneel state of a shifter (debounces inside the leg tendon parts) or a mindless titan (on the root).
local function isKneeling(model)
    if not model then return false end
    local l, r
    local lt, rt = model:FindFirstChild("LLegTendons"), model:FindFirstChild("RLegTendons")
    if lt or rt then
        l, r = boolTrue(lt, "LLDebounce"), boolTrue(rt, "RLDebounce")
    else
        l, r = boolTrue(model, "LLDebounce"), boolTrue(model, "RLDebounce")
    end
    if Config.KneelNeedsBothLegs then return l and r end
    return l or r
end

local function gateOpen(part, entry)
    if not entry.Gate then return true end
    if entry.Gate == "Kneel" then
        if MindlessArmNames[part.Name] then
            if not Config.KneelArmsMindless then return false end
            if boolTrue(part, "Cutted") or part.Transparency >= 1 then return false end
        elseif boolTrue(part, "Armored") then
            return false
        end
        return isKneeling(part.Parent)
    end
    -- Armored legs: decided by the model's CalfArmorHealth (see header).
    if entry.Gate == "CalfArmor" then
        local h = part.Parent and part.Parent:FindFirstChild("CalfArmorHealth")
        if h and h:IsA("ValueBase") and type(h.Value) == "number" then
            if Config.ArmoredLegsOnCracked then
                local maxV = h:FindFirstChild("CalfArmorMaxHealth")
                local maxHealth = maxV and tonumber(maxV.Value) or 20
                return h.Value < maxHealth
            end
            return h.Value <= 0
        end
    end
    local v = part:FindFirstChild(entry.Gate)
    return v ~= nil and v:IsA("BoolValue") and v.Value == false
end

local function isExpanded(part, entry)
    return Config.Enabled and Config.Kinds[entry.Kind] == true and gateOpen(part, entry)
end

local function updateAdornment(part, entry)
    local want = Config.Visualize and isExpanded(part, entry)
    if want then
        if not entry.Adornment or not entry.Adornment.Parent then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "NapeExpanderBox"
            -- Drawn over the titan's own body; walls are handled by the line-of-sight check.
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Color3 = KindColor[entry.Kind] or Color3.fromRGB(255, 60, 60)
            box.Transparency = 0.6
            box.Visible = false
            box.Adornee = part
            box.Parent = part
            entry.Adornment = box
        end
        entry.Adornment.Size = part.Size
    elseif entry.Adornment then
        entry.Adornment:Destroy()
        entry.Adornment = nil
    end
end

local function applyToPart(part)
    local entry = Tracked[part]
    if not entry or not part.Parent then return end
    Applying = true
    local expanded = isExpanded(part, entry)
    if expanded then
        part.Size = targetSize(entry.OriginalSize, entry.Kind)
    else
        part.Size = entry.OriginalSize
    end
    -- Visible collidable arm meshes (mindless) must not block the player while scaled up.
    if entry.OriginalCollide ~= nil then
        part.CanCollide = (not expanded) and entry.OriginalCollide or false
    end
    Applying = false
    if entry.LastExpanded ~= expanded then
        entry.LastExpanded = expanded
        ExcludeDirty = true
    end
    updateAdornment(part, entry)
end

local function untrack(part, restore)
    local entry = Tracked[part]
    if not entry then return end
    Tracked[part] = nil
    ExcludeDirty = true
    for _, c in ipairs(entry.Conns) do c:Disconnect() end
    if entry.Adornment then entry.Adornment:Destroy() end
    if restore and part.Parent then
        Applying = true
        pcall(function()
            part.Size = entry.OriginalSize
            if entry.OriginalCollide ~= nil then part.CanCollide = entry.OriginalCollide end
        end)
        Applying = false
    end
end

local function track(part)
    if Tracked[part] then return end
    local kind, gate = partRule(part)
    if not kind then return end
    local entry = { Kind = kind, Gate = gate, OriginalSize = part.Size, Adornment = nil, Conns = {} }
    if MindlessArmNames[part.Name] then entry.OriginalCollide = part.CanCollide end
    Tracked[part] = entry
    ExcludeDirty = true

    -- Gate (e.g. Armored CalfArmor): re-apply whenever it changes or appears.
    if gate then
        local function bindGateValue(v)
            if v.Name == gate and v:IsA("BoolValue") then
                table.insert(entry.Conns, v.Changed:Connect(function()
                    applyToPart(part)
                end))
                applyToPart(part)
            end
        end
        local existing = part:FindFirstChild(gate)
        if existing then bindGateValue(existing) end
        table.insert(entry.Conns, part.ChildAdded:Connect(bindGateValue))

        if gate == "CalfArmor" then
            local model = part.Parent
            local function bindHealth(h)
                if h.Name == "CalfArmorHealth" and h:IsA("ValueBase") then
                    table.insert(entry.Conns, h.Changed:Connect(function() applyToPart(part) end))
                    applyToPart(part)
                end
            end
            local h = model and model:FindFirstChild("CalfArmorHealth")
            if h then bindHealth(h) end
            if model then table.insert(entry.Conns, model.ChildAdded:Connect(bindHealth)) end
        end
    end

    -- If the game rewrites the size (respawn/regeneration), take it as the new original.
    table.insert(entry.Conns, part:GetPropertyChangedSignal("Size"):Connect(function()
        if Applying then return end
        entry.OriginalSize = part.Size
        task.defer(applyToPart, part)
    end))
    table.insert(entry.Conns, part.AncestryChanged:Connect(function(_, parent)
        if parent == nil or not part:IsDescendantOf(workspace) then
            untrack(part, false)
        end
    end))

    applyToPart(part)
end

local function applyAll()
    for part in pairs(Tracked) do applyToPart(part) end
end

local function scanAll()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isNapeName(d.Name) then track(d) end
    end
end

-- Status text plus armor/hardening sensor: lists gated parts that are currently armored, per shifter.
local function statusText()
    local titans, shifterParts = 0, 0
    local armored = {}   -- [kind] = { "Lleg", "nape", ... }
    local gatedKinds = {}
    for part, entry in pairs(Tracked) do
        if entry.Kind == "Titan" then
            titans += 1
        else
            shifterParts += 1
        end
        if entry.Gate then
            gatedKinds[entry.Kind] = true
            if not gateOpen(part, entry) then
                armored[entry.Kind] = armored[entry.Kind] or {}
                table.insert(armored[entry.Kind], ShortPartName[part.Name] or part.Name)
            end
        end
    end
    local lines = { string.format("Titans %d | shifter parts %d", titans, shifterParts) }
    local sensor = {}
    for _, kind in ipairs({ "Armored", "WeakArmored", "Female", "Warhammer", "Jaw" }) do
        if gatedKinds[kind] then
            local list = armored[kind]
            if list and #list > 0 then
                table.sort(list)
                table.insert(sensor, kind .. " ARMOR: " .. table.concat(list, " "))
            else
                table.insert(sensor, kind .. ": no armor")
            end
        end
    end
    local armoredModel = workspace:FindFirstChild("ArmoredTitan")
    local calf = armoredModel and armoredModel ~= LocalPlayer.Character and armoredModel:FindFirstChild("CalfArmorHealth")
    if calf then table.insert(sensor, "calf HP " .. tostring(calf.Value)) end
    if #sensor > 0 then table.insert(lines, table.concat(sensor, " | ")) end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Line of sight ("Show hitbox" only when directly visible)
------------------------------------------------------------------------
local VisParams = RaycastParams.new()
VisParams.FilterType = Enum.RaycastFilterType.Exclude
VisParams.IgnoreWater = true

-- Visible if nothing opaque lies between the camera and the nape center.
-- The nape's own model and invisible parts (other hitboxes, trigger volumes) do not block.
local function isNapeVisible(part)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local exclude = { part.Parent }
    if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
    for _ = 1, 8 do
        VisParams.FilterDescendantsInstances = exclude
        local result = workspace:Raycast(origin, part.Position - origin, VisParams)
        if not result then return true end
        local hit = result.Instance
        if hit.Transparency >= 0.9 or Tracked[hit] then
            table.insert(exclude, hit)
        else
            return false
        end
    end
    return false
end

local function updateVisibility()
    for part, entry in pairs(Tracked) do
        local box = entry.Adornment
        if box and box.Parent then
            local ok, visible = pcall(isNapeVisible, part)
            box.Visible = ok and visible or false
        end
    end
end

------------------------------------------------------------------------
-- Hook pass-through: PlayerMouse.Hit/Target ignore expanded napes
------------------------------------------------------------------------
local HookParams = RaycastParams.new()
HookParams.FilterType = Enum.RaycastFilterType.Exclude
local HookExclude = {}
local FrameId = 0
local HookCache = { Frame = -1, Handled = false, Hit = nil, Target = nil }

local function rebuildExclude()
    table.clear(HookExclude)
    if LocalPlayer.Character then table.insert(HookExclude, LocalPlayer.Character) end
    for part, entry in pairs(Tracked) do
        if entry.LastExpanded then table.insert(HookExclude, part) end
    end
    HookParams.FilterDescendantsInstances = HookExclude
    ExcludeDirty = false
end

-- Called from the __index hook with the original __index. Must not error or index the mouse normally.
local function resolveMouse(oldIndex, mouse, key)
    if HookCache.Frame ~= FrameId then
        HookCache.Frame = FrameId
        HookCache.Handled = false
        if Config.Enabled and Config.HookPassThrough then
            local target = oldIndex(mouse, "Target")
            local entry = target ~= nil and Tracked[target] or nil
            if entry ~= nil and isExpanded(target, entry) then
                if ExcludeDirty then rebuildExclude() end
                local ray = oldIndex(mouse, "UnitRay")
                local dir = ray.Direction * Config.HookRayLength
                local result = workspace:Raycast(ray.Origin, dir, HookParams)
                local pos = result and result.Position or (ray.Origin + dir)
                HookCache.Hit = CFrame.lookAt(pos, pos + ray.Direction)
                HookCache.Target = result and result.Instance or nil
                HookCache.Handled = true
            end
        end
    end
    if not HookCache.Handled then return false end
    if key == "Hit" or key == "hit" then return true, HookCache.Hit end
    return true, HookCache.Target
end

-- The metamethod hook is installed once per session and survives re-runs; each run only swaps the
-- resolver it calls, and Unload clears it so the hook becomes a plain pass-through.
local function installMouseHook()
    if not (hookmetamethod and newcclosure and checkcaller) then
        warn("[AOTFR Tools] hookmetamethod/newcclosure/checkcaller missing: hook pass-through disabled")
        return false
    end
    if not ENV.__AOTFRMouseHookInstalled then
        local mouse = LocalPlayer:GetMouse()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if rawequal(self, mouse) and (key == "Hit" or key == "Target" or key == "hit" or key == "target")
                and not checkcaller() then
                local resolver = ENV.__AOTFRMouseResolver
                if resolver then
                    local ok, handled, value = pcall(resolver, oldIndex, self, key)
                    if ok and handled then return value end
                end
            end
            return oldIndex(self, key)
        end))
        ENV.__AOTFRMouseHookInstalled = true
    end
    ENV.__AOTFRMouseResolver = resolveMouse
    return true
end

------------------------------------------------------------------------
-- Gear (gas / blades)
------------------------------------------------------------------------
local GearState = {
    Folder = nil,           -- current Character.Humanoid.Gear
    Conns = {},
    ServerBlades = nil,     -- last value seen from server replication
    ServerDurability = nil,
    WritingLocal = false,
    LastReload = 0,
}

local function findGearFolder()
    local ch = LocalPlayer.Character
    if not ch then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    return hum:FindFirstChild("Gear")
end

local function gearValue(name, class)
    local g = GearState.Folder
    if not g or not g.Parent then return nil end
    local v = g:FindFirstChild(name)
    if v and v:IsA(class) then return v end
    return nil
end

local function bladesMaxDurability()
    local g = GearState.Folder
    local up = g and g:FindFirstChild("Upgrades")
    local eff = up and up:FindFirstChild("BladesEfficiency")
    if eff and eff:IsA("IntValue") and eff.Value > 0 and eff.Value < 1000 then return eff.Value end
    return nil
end

local function disconnectGear()
    for _, c in ipairs(GearState.Conns) do c:Disconnect() end
    table.clear(GearState.Conns)
end

local function bindGear(folder)
    disconnectGear()
    GearState.Folder = folder
    GearState.ServerBlades, GearState.ServerDurability = nil, nil
    if not folder then return end
    local blades = gearValue("Blades", "IntValue")
    local dur = gearValue("BladeDurability", "IntValue")
    if blades then
        GearState.ServerBlades = blades.Value
        table.insert(GearState.Conns, blades.Changed:Connect(function(v)
            if not GearState.WritingLocal then GearState.ServerBlades = v end
        end))
    end
    if dur then
        GearState.ServerDurability = dur.Value
        table.insert(GearState.Conns, dur.Changed:Connect(function(v)
            if not GearState.WritingLocal then GearState.ServerDurability = v end
        end))
    end
end

local function pressReload()
    if UserInputService:GetFocusedTextBox() then return end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

-- Original values we overwrote, so turning the option off (or unloading) puts them back.
local SkillOriginals = setmetatable({}, { __mode = "k" })     -- [BoolValue] = bool
local SkillGuiOriginals = setmetatable({}, { __mode = "k" })  -- [LayerCollector/GuiObject] = bool

local function forceSkills(folder)
    local skills = folder:FindFirstChild("Skills")
    if not skills then return end
    local skillsGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    skillsGui = skillsGui and skillsGui:FindFirstChild("SkillsGui")
    for _, v in ipairs(skills:GetChildren()) do
        if v:IsA("BoolValue") then
            if v.Value ~= true then
                if SkillOriginals[v] == nil then SkillOriginals[v] = v.Value end
                v.Value = true
            end
            local g = skillsGui and skillsGui:FindFirstChild(v.Name)
            if g then
                local ok, enabled = pcall(function() return g.Enabled end)
                if ok and enabled == false then
                    if SkillGuiOriginals[g] == nil then SkillGuiOriginals[g] = false end
                    pcall(function() g.Enabled = true end)
                end
            end
        end
    end
end

local function restoreSkills()
    for v, orig in pairs(SkillOriginals) do
        if v.Parent then v.Value = orig end
    end
    for g, orig in pairs(SkillGuiOriginals) do
        if g.Parent then pcall(function() g.Enabled = orig end) end
    end
    table.clear(SkillOriginals)
    table.clear(SkillGuiOriginals)
end

------------------------------------------------------------------------
-- Auto Hood (same call and same client-side conditions as MenuGui's HoodButton)
------------------------------------------------------------------------
local HoodState = { Busy = false, LastTry = 0 }
local HoodBlockedTeams = { Warriors = true, ["Interior Police"] = true, Rogue = true }

local function boolChild(parent, name)
    local v = parent and parent:FindFirstChild(name)
    return v ~= nil and v:IsA("BoolValue") and v.Value == true
end

-- Base conditions the MenuGui HoodButton checks, minus the cloak-part test (handled separately so the
-- keybind can equip the cloak first).
local function hoodBaseAllowed(hum)
    if boolChild(hum, "Stunned") or boolChild(hum, "Grabbed") or boolChild(hum, "Burning") then return false end
    if LocalPlayer.Team and HoodBlockedTeams[LocalPlayer.Team.Name] then return false end
    local gsv = workspace:FindFirstChild("GameStateValues")
    return boolChild(gsv, "HoodsEnabled")
end

local function hasCloakPart(ch)
    return ch:FindFirstChild("Cloak") ~= nil or ch:FindFirstChild("BrownCloak") ~= nil
        or ch:FindFirstChild("GreyCloak") ~= nil
end

local function clothesRemote()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local menu = pg and pg:FindFirstChild("MenuGui")
    local remote = menu and menu:FindFirstChild("ClothesChange")
    if remote and remote:IsA("RemoteFunction") then return remote, menu end
    return nil, menu
end

-- Hood on/off, mirroring MenuGui's HoodButton (InvokeServer("Hood", nil, true/false)). When turning the
-- hood ON, the cloak is equipped first if it isn't worn (PlayersDataFolder.<name>.Cloak == 0 / no cloak
-- part), via InvokeServer("Cloak", nil, true) -- same call as the Cloak button -- so the hood has a cloak
-- to sit on. Taking it off removes the hood and then the cloak.
local function hoodSet(on)
    if HoodState.Busy then return end
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hood = hum and hum:FindFirstChild("Hood")
    if not hood or not hood:IsA("BoolValue") or hum.Health <= 0 then return end
    if not hoodBaseAllowed(hum) then return end
    local remote, menu = clothesRemote()
    if not remote then return end

    HoodState.LastTry = os.clock()
    HoodState.Busy = true
    task.spawn(function()
        local ok, err = pcall(function()
            if on then
                if not hasCloakPart(ch) then
                    local df = workspace:FindFirstChild("PlayersDataFolder")
                    local data = df and df:FindFirstChild(LocalPlayer.Name)
                    local cloakVal = data and data:FindFirstChild("Cloak")
                    if not cloakVal or cloakVal.Value == 0 then
                        remote:InvokeServer("Cloak", nil, true)
                    end
                    local t0 = os.clock()
                    while not hasCloakPart(ch) and os.clock() - t0 < 1 do task.wait(0.05) end
                end
                if hasCloakPart(ch) then
                    remote:InvokeServer("Hood", nil, true)
                end
            else
                remote:InvokeServer("Hood", nil, false)
                -- Also take the cloak off (same call as the Cloak button at Cloak.Value == 1).
                local df = workspace:FindFirstChild("PlayersDataFolder")
                local data = df and df:FindFirstChild(LocalPlayer.Name)
                local cloakVal = data and data:FindFirstChild("Cloak")
                if (cloakVal and cloakVal.Value == 1) or hasCloakPart(ch) then
                    remote:InvokeServer("Cloak", nil, false)
                end
            end
        end)
        if not ok then warn("[AOTFR Tools] hood: " .. tostring(err)) end
        local cs = menu and menu:FindFirstChild("CustomizationScreen")
        local btn = cs and cs:FindFirstChild("HoodButton")
        if btn and hood.Parent then btn.Text = (hood.Value == true) and "X" or " " end
        HoodState.Busy = false
    end)
end

-- Keybind: toggle the hood (and equip the cloak on the way on).
local function hoodToggle()
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hood = hum and hum:FindFirstChild("Hood")
    if not hood or not hood:IsA("BoolValue") then return end
    hoodSet(hood.Value ~= true)
end

local function hoodTick()
    if not Config.AutoHood then return end
    if os.clock() - HoodState.LastTry < Config.AutoHoodCooldown then return end
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hood = hum and hum:FindFirstChild("Hood")
    if not hood or not hood:IsA("BoolValue") or hood.Value == true then return end
    hoodSet(true)
end

-- Infinite Stamina while shifted: keep Humanoid.Stamina at the form's TotalStamina (both client-side).
local function staminaTick()
    if not Config.InfiniteStamina then return end
    local ch = LocalPlayer.Character
    if not ch or not ch:FindFirstChild("Shifter") then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local stam = hum and hum:FindFirstChild("Stamina")
    if not stam or not (stam:IsA("IntValue") or stam:IsA("NumberValue")) then return end
    local maxv = stam.Value
    local total = ch:FindFirstChild("TotalStamina", true)
    if total and (total:IsA("NumberValue") or total:IsA("IntValue")) and total.Value > 0 then
        maxv = total.Value
    end
    if stam.Value < maxv then stam.Value = maxv end
end

-- Dodge boost: on our own character's Dodge animation, add extra backward impulse (same way Gear pushes it).
local DodgeConns = {}
local function bindDodge(ch)
    for _, c in ipairs(DodgeConns) do pcall(function() c:Disconnect() end) end
    table.clear(DodgeConns)
    local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    DodgeConns[#DodgeConns + 1] = animator.AnimationPlayed:Connect(function(track)
        if not Config.DodgeBoost then return end
        local gear = ch:FindFirstChild("Gear")
        if not gear then return end   -- human gear form only
        local dodge = gear:FindFirstChild("Animations")
        dodge = dodge and dodge:FindFirstChild("Dodge")
        local id = track.Animation and track.Animation.AnimationId
        if not dodge or not id or id ~= dodge.AnimationId then return end
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp:ApplyImpulse(hrp.CFrame.LookVector * -math.abs(Config.DodgeBoostImpulse))
    end)
end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(bindDodge))
if LocalPlayer.Character then task.spawn(bindDodge, LocalPlayer.Character) end

------------------------------------------------------------------------
-- Infinite Shift: disable the shifter script's timer -> Unshift handler
------------------------------------------------------------------------
local DisabledTimerConns = {}   -- list of RBXScriptConnection proxies we disabled
local ShiftInfo = ""

-- The shifter's client script is a LocalScript child of the character with Stats.Time (IntValue).
local function findShifterTime()
    local ch = LocalPlayer.Character
    if not ch then return nil end
    for _, s in ipairs(ch:GetChildren()) do
        if s:IsA("LocalScript") then
            local stats = s:FindFirstChild("Stats")
            local t = stats and stats:FindFirstChild("Time")
            if t and t:IsA("IntValue") then return s, t end
        end
    end
    return nil
end

local function restoreShiftTimer()
    for _, c in ipairs(DisabledTimerConns) do pcall(function() c:Enable() end) end
    table.clear(DisabledTimerConns)
end

local function shiftTick()
    local script_, timeValue = findShifterTime()
    if not timeValue then
        ShiftInfo = ""
        return
    end
    local blocked = 0
    if Config.InfiniteShift and getconnections then
        for _, c in ipairs(getconnections(timeValue.Changed)) do
            if c.Enabled then
                local ok = pcall(function() c:Disable() end)
                if ok then table.insert(DisabledTimerConns, c) end
            end
            if not c.Enabled then blocked += 1 end
        end
    end
    ShiftInfo = string.format("%s time %d%s", script_.Name, timeValue.Value,
        Config.InfiniteShift and (blocked > 0 and " | timer unshift BLOCKED" or " | no handler found") or "")
end

------------------------------------------------------------------------
-- Staff Alert
------------------------------------------------------------------------
local StaffKnown = setmetatable({}, { __mode = "k" })   -- [Player] = "Role (rank N)"

local function staffRole(name, rank)
    -- Role names from GroupService:GetGroupInfoAsync(11141380) ("Freedom War Community").
    if Config.StaffNames[name] then return Config.StaffNames[name] end
    if rank >= 255 then return "Owner" end
    if rank >= 101 then return "Developer" end
    if rank >= 100 then return "Head of Staff" end
    if rank >= 99 then return "Head Department" end
    if rank >= 98 then return "Administrator" end
    if rank >= 97 then return "Moderator" end
    if rank >= Config.StaffMinRank then return "Junior Moderator" end
    return nil
end

local function staffNotify(title, text)
    warn("[AOTFR Tools] " .. title .. ": " .. text)
    if not Config.StaffAlert then return end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = text, Duration = 20 })
    end)
end

local function dataRank(p)
    local pdf = workspace:FindFirstChild("PlayersDataFolder")
    local d = pdf and pdf:FindFirstChild(p.Name)
    local g = d and d:FindFirstChild("GroupRank")
    local v = g and g:IsA("ValueBase") and tonumber(g.Value)
    return v or -1
end

local function evaluateStaff(p, liveRank)
    if p == LocalPlayer or StaffKnown[p] or not p.Parent then return end
    local rank = math.max(dataRank(p), liveRank or -1)
    local role = staffRole(p.Name, rank)
    if role then
        StaffKnown[p] = string.format("%s (rank %d)", role, rank)
        staffNotify("STAFF IN SERVER", p.Name .. " - " .. StaffKnown[p])
    end
end

local function watchStaff(p)
    task.spawn(function()
        local ok, live = pcall(function() return p:GetRankInGroup(Config.StaffGroupId) end)
        live = ok and tonumber(live) or -1
        evaluateStaff(p, live)
        -- The game's data folder for a new player can arrive a few seconds later.
        for _ = 1, 20 do
            if StaffKnown[p] or not p.Parent or not ENV.__NapeExpander then break end
            task.wait(1)
            evaluateStaff(p, live)
        end
    end)
end

local function staffListText()
    local list = {}
    for p, desc in pairs(StaffKnown) do
        if p.Parent then table.insert(list, p.Name .. " " .. desc) end
    end
    table.sort(list)
    return #list > 0 and ("STAFF: " .. table.concat(list, ", ")) or "Staff: none"
end

------------------------------------------------------------------------
-- Auto Counter
------------------------------------------------------------------------
local CounterState = {
    SwingIds = {},       -- [animationId] = name  (players' blade swings, from own Gear.Animations)
    ChargeIds = {},      -- [animationId] = name  (players' blade charge)
    SpinIds = {},        -- [animationId] = name  (players' counter / counter spin)
    KickIds = {},        -- [animationId] = name  (players' kick)
    KickArmed = {},      -- [Model] = { Reason, Until }  (kickers waiting to come into reach)
    LastKickResponse = 0,
    TitanAttackIds = {}, -- [animationId] = name  (titan grabs/eats, shifter charge/throw)
    TitanSafeIds = {},   -- [animationId] = name  (titan movement/roar/etc., never a trigger)
    ScannedScripts = {}, -- [scriptName] = true   (shifter client scripts already parsed)
    ScannedTitans = setmetatable({}, { __mode = "k" }),
    IdsFromGear = nil,   -- Gear instance the player ids were read from
    CharConns = {},      -- [Model] = { connections }
    PlayerConns = {},    -- [Player] = connection
    TitanFolderConn = nil,
    LastTitanScan = 0,
    Armed = {},          -- [Model] = { Track, Reason, Until, Grace }  (players mid charge/swing)
    Last = 0,
    LastInfo = "",
}

local function isTitanAttackName(name)
    for _, w in ipairs(Config.TitanAttackWords) do
        if string.find(name, w, 1, true) then return true end
    end
    return false
end

local function learnTitanAnim(id, name)
    if id == "" or CounterState.TitanAttackIds[id] or CounterState.TitanSafeIds[id] then return end
    if isTitanAttackName(name) then
        CounterState.TitanAttackIds[id] = name
    else
        CounterState.TitanSafeIds[id] = name
    end
end

local function refreshCounterIds()
    local ch = LocalPlayer.Character
    local gear = ch and ch:FindFirstChild("Gear")
    local anims = gear and gear:FindFirstChild("Animations")
    if anims and CounterState.IdsFromGear ~= gear then
        CounterState.IdsFromGear = gear
        table.clear(CounterState.SwingIds)
        table.clear(CounterState.ChargeIds)
        table.clear(CounterState.SpinIds)
        table.clear(CounterState.KickIds)
        for _, n in ipairs(Config.CounterKickAnims) do
            local a = anims:FindFirstChild(n)
            if a and a:IsA("Animation") and a.AnimationId ~= "" then CounterState.KickIds[a.AnimationId] = n end
        end
        for _, n in ipairs(Config.CounterSpinAnims) do
            local a = anims:FindFirstChild(n)
            if a and a:IsA("Animation") and a.AnimationId ~= "" then CounterState.SpinIds[a.AnimationId] = n end
        end
        for _, n in ipairs(Config.CounterSwingAnims) do
            local a = anims:FindFirstChild(n)
            if a and a:IsA("Animation") and a.AnimationId ~= "" then CounterState.SwingIds[a.AnimationId] = n end
        end
        for _, n in ipairs(Config.CounterChargeAnims) do
            local a = anims:FindFirstChild(n)
            if a and a:IsA("Animation") and a.AnimationId ~= "" then CounterState.ChargeIds[a.AnimationId] = n end
        end
    end

    -- Titan animation names, at most every 5 s.
    local now = os.clock()
    if now - CounterState.LastTitanScan < 5 then return end
    CounterState.LastTitanScan = now
    -- Shifter client scripts (ATLocal, ARLocal, FELocal, CALocal, ...) sit in players' characters and hold a
    -- Name = "rbxassetid://id" table of the shifter's non-combat animations (+ Charge/Throw abilities).
    if decompile then
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c then
                for _, s in ipairs(c:GetChildren()) do
                    if s:IsA("LocalScript") and string.match(s.Name, "^%u%u?Local$") and not CounterState.ScannedScripts[s.Name] then
                        CounterState.ScannedScripts[s.Name] = true
                        local ok, src = pcall(decompile, s)
                        if ok and type(src) == "string" then
                            for name, id in string.gmatch(src, '([%a_][%w_]*)%s*=%s*"rbxassetid://(%d+)"') do
                                if name ~= "AnimationId" and not string.match(name, "^v%d+$") then
                                    learnTitanAnim("rbxassetid://" .. id, name)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Mindless titans carry their Animations folder (BGrab/FGrab/.../Eat).
    local folder = workspace:FindFirstChild("OnGameTitans")
    if folder then
        for _, t in ipairs(folder:GetChildren()) do
            if not CounterState.ScannedTitans[t] then
                local a = t:FindFirstChild("Animations")
                if a then
                    CounterState.ScannedTitans[t] = true
                    for _, x in ipairs(a:GetDescendants()) do
                        if x:IsA("Animation") then learnTitanAnim(x.AnimationId, x.Name) end
                    end
                end
            end
        end
    end
end

local function boolValueTrue(parent, name)
    local v = parent and parent:FindFirstChild(name)
    return v ~= nil and v:IsA("BoolValue") and v.Value == true
end

local StuckState = { Since = nil, Info = "" }
local StuckParams = RaycastParams.new()
StuckParams.FilterType = Enum.RaycastFilterType.Exclude

local function antiStuckTick(now)
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not Config.AntiStuck or not hum or not root or not ch:FindFirstChild("Gear") or hum.Health <= 0
        or not hum.PlatformStand then
        StuckState.Since = nil
        return
    end
    local blocked = boolValueTrue(hum, "Stunned") or boolValueTrue(hum, "Grabbed") or boolValueTrue(hum, "Grabbing")
        or boolValueTrue(hum, "PGrabbed") or boolValueTrue(hum, "Ragdolling") or boolValueTrue(hum, "TiedUp")
    local shifting = hum:FindFirstChild("Shifting")
    if shifting and boolValueTrue(shifting, "Shift") then blocked = true end
    local center = root:FindFirstChild("Center")
    if center and center:FindFirstChild("DragForce") then blocked = true end
    local v = root.AssemblyLinearVelocity
    if blocked or math.abs(v.Y) > 2 or Vector3.new(v.X, 0, v.Z).Magnitude > Config.StuckMaxSlide then
        StuckState.Since = nil
        return
    end
    StuckParams.FilterDescendantsInstances = { ch }
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -Config.StuckGroundDist, 0), StuckParams)
    if not hit then
        StuckState.Since = nil
        return
    end
    StuckState.Since = StuckState.Since or now
    if now - StuckState.Since >= Config.StuckDelay then
        StuckState.Since = nil
        hum.PlatformStand = false
        hum.JumpPower = 11
        StuckState.Info = "Anti stuck: freed at " .. os.date("%H:%M:%S")
    end
end

local function pressCounter()
    if UserInputService:GetFocusedTextBox() then return end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.V, false, game)
    task.wait(0.03)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.V, false, game)
end

-- Gear swings on MouseButton1 release after a press; a short tap is a plain swing.
local function pressAttack()
    if UserInputService:GetFocusedTextBox() then return end
    local pos = UserInputService:GetMouseLocation()
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
    if Config.AttackTapHold > 0 then task.wait(Config.AttackTapHold) else RunService.Heartbeat:Wait() end
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
end

local function respondToKick(attacker, reason)
    if not Config.KickResponse then return end
    local now = os.clock()
    if now - CounterState.LastKickResponse < Config.KickResponseCooldown then return end
    local me = LocalPlayer.Character
    local hum = me and me:FindFirstChildOfClass("Humanoid")
    if not me or not me:FindFirstChild("Gear") or not hum or hum.Health <= 0 then return end
    local myRoot = me:FindFirstChild("HumanoidRootPart")
    local theirRoot = attacker:FindFirstChild("HumanoidRootPart")
    if not myRoot or not theirRoot then return end
    local dist = (theirRoot.Position - myRoot.Position).Magnitude
    if dist ~= dist or dist > Config.KickResponseRange then return end
    local p = Players:GetPlayerFromCharacter(attacker)
    if Config.CounterSkipTeammates and p and p.Team ~= nil and p.Team == LocalPlayer.Team then return end
    CounterState.LastKickResponse = now
    if Config.KickResponseFace then
        local look = Vector3.new(theirRoot.Position.X, myRoot.Position.Y, theirRoot.Position.Z)
        if (look - myRoot.Position).Magnitude > 0.1 then
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, look)
        end
    end
    CounterState.LastInfo = string.format("Swing -> %s (%s, %.0f studs)", attacker.Name, reason, dist)
    task.spawn(pressAttack)
end

-- kind: "swing" | "charge" | "titan"
local function tryCounter(attacker, reason, kind)
    if not Config.AutoCounter then return end
    if Config.CounterIgnoreModels[attacker.Name] then return end
    if kind == "titan" and not Config.CounterTitans then return end
    if kind == "charge" and not Config.CounterOnCharge then return end
    local now = os.clock()
    if now - CounterState.Last < Config.CounterCooldown then return end
    local me = LocalPlayer.Character
    if not me or not me:FindFirstChild("Gear") then return end   -- human form with gear only
    local myRoot = me:FindFirstChild("HumanoidRootPart")
    local theirRoot = attacker:FindFirstChild("HumanoidRootPart")
    if not myRoot or not theirRoot then return end
    local dist = (theirRoot.Position - myRoot.Position).Magnitude
    if dist ~= dist then return end
    local limit = Config.CounterRange
    if kind == "titan" then
        -- Distance to the surface of the titan's nearest part (point-to-box), not to its centre.
        local pos = myRoot.Position
        local best = math.huge
        for _, part in ipairs(attacker:GetDescendants()) do
            if part:IsA("BasePart") then
                local lp = part.CFrame:PointToObjectSpace(pos)
                local h = part.Size / 2
                local clamped = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
                local d = (lp - clamped).Magnitude
                if d < best then best = d end
            end
        end
        dist = best
        limit = Config.TitanCounterRange
    elseif kind == "charge" then
        limit = Config.CounterChargeRange
    elseif kind == "predict" then
        limit = Config.CounterPredictMaxRange   -- the time-to-contact test already decided
    end
    if dist > limit then return end
    local p = Players:GetPlayerFromCharacter(attacker)
    if Config.CounterSkipTeammates and p and p.Team ~= nil and p.Team == LocalPlayer.Team then return end
    CounterState.Last = now
    CounterState.LastInfo = string.format("Counter -> %s (%s, %.0f studs)", attacker.Name, reason, dist)
    CounterState.LastAttacker = attacker
    task.spawn(pressCounter)
end

-- Pure: should a predicted counter fire now? closing > 0 means the attacker approaches.
local function predictFire(dist, closing, lead, reach)
    if dist ~= dist or closing ~= closing then return false end
    return dist <= reach + math.max(closing, 0) * lead
end

local function armAttacker(model, track, reason, minClosing)
    if not Config.CounterPredict then return end
    local now = os.clock()
    local a = CounterState.Armed[model]
    if a then
        a.Track, a.Reason = track, reason
        a.Grace = now + Config.CounterSwingGrace
        a.MinClosing = math.min(a.MinClosing or 0, minClosing or 0)
        return
    end
    CounterState.Armed[model] = {
        Track = track, Reason = reason, MinClosing = minClosing or 0,
        Until = now + Config.CounterArmMax,
        Grace = now + Config.CounterSwingGrace,
    }
end

-- Pure: should we swing at a kicker now? closing > 0 means the kicker approaches.
local function kickSwingNow(dist, closing, lead, reach)
    if dist ~= dist or closing ~= closing then return false end
    return dist <= reach + math.max(closing, 0) * lead
end

local function ownPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and type(p) == "number" and p == p and p >= 0 and p < 2 then return p end
    return 0.1
end

local function kickerState(model)
    local me = LocalPlayer.Character
    local myRoot = me and me:FindFirstChild("HumanoidRootPart")
    local theirRoot = model:FindFirstChild("HumanoidRootPart")
    if not myRoot or not theirRoot then return nil end
    local offset = theirRoot.Position - myRoot.Position
    local dist = offset.Magnitude
    if dist <= 0 then return 0, 0 end
    local rel = theirRoot.AssemblyLinearVelocity - myRoot.AssemblyLinearVelocity
    return dist, -offset.Unit:Dot(rel)
end

-- Kick animation seen: swing now if the kicker is (about to be) in reach, else arm and re-check per frame.
local function onKick(model, name)
    if not Config.KickResponse then return end
    local dist, closing = kickerState(model)
    if not dist or dist > Config.KickResponseRange then return end
    if kickSwingNow(dist, closing, Config.CounterLeadTime + ownPing(), Config.KickSwingReach) then
        CounterState.KickArmed[model] = nil
        respondToKick(model, name)
        return
    end
    CounterState.KickArmed[model] = { Reason = name, Until = os.clock() + Config.KickArmTime }
end

local function kickPredictTick()
    if not next(CounterState.KickArmed) then return end
    local now = os.clock()
    local lead = Config.CounterLeadTime + ownPing()
    for model, a in pairs(CounterState.KickArmed) do
        if not model.Parent or now > a.Until or not Config.KickResponse then
            CounterState.KickArmed[model] = nil
        else
            local dist, closing = kickerState(model)
            if dist and dist <= Config.KickResponseRange
                and kickSwingNow(dist, closing, lead, Config.KickSwingReach) then
                CounterState.KickArmed[model] = nil
                respondToKick(model, string.format("%s, predicted", a.Reason))
            end
        end
    end
end

local function counterPredictTick()
    if not next(CounterState.Armed) then return end
    local now = os.clock()
    local me = LocalPlayer.Character
    local myRoot = me and me:FindFirstChild("HumanoidRootPart")
    local lead = Config.CounterLeadTime + ownPing()
    for model, a in pairs(CounterState.Armed) do
        local playing = a.Track ~= nil and a.Track.IsPlaying
        if playing then a.Grace = now + Config.CounterSwingGrace end
        if not model.Parent or now > a.Until or now > a.Grace or not Config.AutoCounter then
            CounterState.Armed[model] = nil
        elseif myRoot then
            local theirRoot = model:FindFirstChild("HumanoidRootPart")
            if theirRoot then
                local offset = theirRoot.Position - myRoot.Position
                local dist = offset.Magnitude
                if dist > 0 and dist <= Config.CounterPredictMaxRange then
                    local rel = theirRoot.AssemblyLinearVelocity - myRoot.AssemblyLinearVelocity
                    local closing = -offset.Unit:Dot(rel)
                    if closing >= a.MinClosing and predictFire(dist, closing, lead, Config.CounterHitReach) then
                        tryCounter(model, string.format("%s, predicted, %.0f st/s", a.Reason, math.max(closing, 0)),
                            "predict")
                        if CounterState.Last >= now then CounterState.Armed[model] = nil end
                    end
                end
            end
        end
    end
end

local ActionPriorities = {
    [Enum.AnimationPriority.Action] = true,
    [Enum.AnimationPriority.Action2] = true,
    [Enum.AnimationPriority.Action3] = true,
    [Enum.AnimationPriority.Action4] = true,
}

local function classifyAnim(model, id, track)
    local n = CounterState.SwingIds[id]
    if n then return "swing", n end
    n = CounterState.ChargeIds[id]
    if n then return "charge", n end
    n = CounterState.SpinIds[id]
    if n then return "spin", n end
    n = CounterState.KickIds[id]
    if n then return "kick", n end
    local isShifter = model:FindFirstChild("SNape") ~= nil
    local isMindless = not isShifter and model:FindFirstChild("Titan") ~= nil
        and Players:GetPlayerFromCharacter(model) == nil
    if not isShifter and not isMindless then return nil end
    n = CounterState.TitanAttackIds[id]
    if n then return "titan", n end
    if CounterState.TitanSafeIds[id] then return nil end
    -- Shifter attacks are played by the server and are named nowhere on the client: an unnamed animation
    -- counts as an attack only if it is a short, non-looping Action-priority one (see header).
    if isShifter then
        if track.Looped or not ActionPriorities[track.Priority] then return nil end
        if track.Length > Config.TitanAttackMaxLength then return nil end
        return "titan", "titan anim " .. (string.match(id, "%d+") or "?")
    end
    return nil
end

local function unbindCounterChar(model)
    local list = CounterState.CharConns[model]
    if list then
        for _, c in ipairs(list) do c:Disconnect() end
        CounterState.CharConns[model] = nil
    end
end

local function bindCounterChar(model)
    if not model or model == LocalPlayer.Character or CounterState.CharConns[model] then return end
    local hum = model:WaitForChild("Humanoid", 10)
    if not hum or not model.Parent then return end
    local list = {}
    CounterState.CharConns[model] = list
    local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10)
    if animator then
        table.insert(list, animator.AnimationPlayed:Connect(function(track)
            local anim = track.Animation
            local id = anim and anim.AnimationId
            if not id then return end
            -- Looped/Priority/Length are only valid once the asset is loaded; wait briefly if it is not.
            -- Named animations are classified by id alone, so they never wait.
            local named = CounterState.SwingIds[id] or CounterState.ChargeIds[id] or CounterState.SpinIds[id]
                or CounterState.KickIds[id] or CounterState.TitanAttackIds[id] or CounterState.TitanSafeIds[id]
            if not named and track.Length == 0 then
                for _ = 1, 6 do
                    task.wait(0.02)
                    if track.Length > 0 then break end
                end
            end
            local kind, name = classifyAnim(model, id, track)
            if kind then
                -- Players: arm first, so an out-of-range charge/swing is re-checked every frame.
                if kind == "swing" or (kind == "charge" and Config.CounterOnCharge) then
                    armAttacker(model, track, name)
                end
                if kind == "kick" then
                    onKick(model, name)
                    return
                end
                if kind == "spin" then
                    armAttacker(model, track, name, Config.CounterSpinMinClosing)
                    return   -- spins only counter through prediction (closing speed required)
                end
                tryCounter(model, name, kind)
                if os.clock() - CounterState.Last < 0.05 then CounterState.Armed[model] = nil end
            end
        end))
    end
    local ba = hum:FindFirstChild("BladeAttacking")
    if ba and ba:IsA("BoolValue") then
        table.insert(list, ba.Changed:Connect(function(v)
            if v == true then
                armAttacker(model, nil, "BladeAttacking")
                tryCounter(model, "BladeAttacking", "swing")
            end
        end))
    end
    table.insert(list, model.AncestryChanged:Connect(function(_, parent)
        if parent == nil then unbindCounterChar(model) end
    end))
end

local function watchCounterPlayer(p)
    if p == LocalPlayer or CounterState.PlayerConns[p] then return end
    CounterState.PlayerConns[p] = p.CharacterAdded:Connect(function(c) task.spawn(bindCounterChar, c) end)
    if p.Character then task.spawn(bindCounterChar, p.Character) end
end

local function watchMindlessTitans()
    local folder = workspace:FindFirstChild("OnGameTitans")
    if not folder or CounterState.TitanFolderConn then return end
    for _, t in ipairs(folder:GetChildren()) do task.spawn(bindCounterChar, t) end
    CounterState.TitanFolderConn = folder.ChildAdded:Connect(function(t) task.spawn(bindCounterChar, t) end)
end

local function unloadCounter()
    table.clear(CounterState.Armed)
    table.clear(CounterState.KickArmed)
    for model in pairs(CounterState.CharConns) do unbindCounterChar(model) end
    for p, c in pairs(CounterState.PlayerConns) do c:Disconnect(); CounterState.PlayerConns[p] = nil end
    if CounterState.TitanFolderConn then CounterState.TitanFolderConn:Disconnect(); CounterState.TitanFolderConn = nil end
end

local function gearTick()
    hoodTick()
    shiftTick()
    refreshCounterIds()
    watchMindlessTitans()
    local folder = findGearFolder()
    if folder ~= GearState.Folder then bindGear(folder) end
    if not folder then return end

    if Config.UnlockSkills then forceSkills(folder) end

    if Config.InfiniteGas then
        local gas = gearValue("Gas", "NumberValue")
        if gas and gas.Value < Config.GasMax then gas.Value = Config.GasMax end
    end

    local blades = gearValue("Blades", "IntValue")
    local dur = gearValue("BladeDurability", "IntValue")

    if Config.LockBlades and blades and blades.Value < Config.BladesMax then
        -- Only the local copy: removes the client's "Blades <= 0" reload gate; the server still decides.
        GearState.WritingLocal = true
        blades.Value = Config.BladesMax
        GearState.WritingLocal = false
    end

    if Config.AutoReload and dur and blades then
        local serverDur = GearState.ServerDurability or dur.Value
        local serverBlades = GearState.ServerBlades or blades.Value
        local now = os.clock()
        if serverDur <= 0 and serverBlades > 0 and now - GearState.LastReload >= Config.AutoReloadCooldown then
            GearState.LastReload = now
            task.spawn(pressReload)
        end
    end
end

------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------
local TweenService = game:GetService("TweenService")

local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then
        local test = pcall(function() local f = Instance.new("Folder"); f.Parent = core; f:Destroy() end)
        if test then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local Theme = {
    Bg = Color3.fromRGB(15, 15, 19),
    Panel = Color3.fromRGB(23, 23, 29),
    Card = Color3.fromRGB(31, 31, 39),
    CardHover = Color3.fromRGB(38, 38, 48),
    Field = Color3.fromRGB(20, 20, 26),
    Stroke = Color3.fromRGB(52, 52, 66),
    Text = Color3.fromRGB(236, 236, 242),
    Sub = Color3.fromRGB(146, 146, 162),
    Accent = Color3.fromRGB(124, 92, 255),
    Off = Color3.fromRGB(66, 66, 80),
    Danger = Color3.fromRGB(225, 72, 72),
}

local Screen = Instance.new("ScreenGui")
Screen.Name = "NapeExpanderGui"
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Screen.Parent = guiParent()

-- Small UI kit ----------------------------------------------------------
local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = o
end

local function stroke(o, color)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o
end

local function pad(o, px)
    local u = Instance.new("UIPadding")
    u.PaddingLeft, u.PaddingRight = UDim.new(0, px), UDim.new(0, px)
    u.PaddingTop, u.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
    u.Parent = o
end

local function vlist(o, gap)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, gap or 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = o
end

local function text(parent, str, size, color, bold)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize = size or 13
    l.TextColor3 = color or Theme.Text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = str
    l.Parent = parent
    return l
end

local LayoutCounters = setmetatable({}, { __mode = "k" })
local function place(o, parent)
    LayoutCounters[parent] = (LayoutCounters[parent] or 0) + 1
    o.LayoutOrder = LayoutCounters[parent]
    o.Parent = parent
    return o
end

local function tween(o, props, t)
    TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function makeDraggable(handle, target)
    local dragging, startInput, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, startInput, startPos = true, input.Position, target.Position
        end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

-- Window with title bar, accent line, close button and a scrolling body.
local function makeWindow(title, subtitle, size, position)
    local win = Instance.new("Frame")
    win.Size = size
    win.Position = position
    win.BackgroundColor3 = Theme.Bg
    win.BorderSizePixel = 0
    win.Active = true
    win.Parent = Screen
    corner(win, 10)
    stroke(win)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 46)
    bar.BackgroundColor3 = Theme.Panel
    bar.BorderSizePixel = 0
    bar.Parent = win
    corner(bar, 10)
    local barFill = Instance.new("Frame")   -- squares off the bar's bottom corners
    barFill.Size = UDim2.new(1, 0, 0, 10)
    barFill.Position = UDim2.new(0, 0, 1, -10)
    barFill.BackgroundColor3 = Theme.Panel
    barFill.BorderSizePixel = 0
    barFill.Parent = bar
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 2)
    accent.Position = UDim2.new(0, 0, 1, 0)
    accent.BackgroundColor3 = Theme.Accent
    accent.BorderSizePixel = 0
    accent.Parent = bar

    local t = text(bar, title, 15, Theme.Text, true)
    t.Position = UDim2.fromOffset(14, 7)
    t.Size = UDim2.new(1, -60, 0, 18)
    local st = text(bar, subtitle, 11, Theme.Sub)
    st.Position = UDim2.fromOffset(14, 25)
    st.Size = UDim2.new(1, -60, 0, 14)

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(26, 26)
    close.Position = UDim2.new(1, -36, 0, 10)
    close.BackgroundColor3 = Theme.Card
    close.Text = "X"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 12
    close.TextColor3 = Theme.Sub
    close.AutoButtonColor = false
    close.Parent = bar
    corner(close, 6)
    close.MouseEnter:Connect(function() tween(close, { BackgroundColor3 = Theme.Danger, TextColor3 = Theme.Text }) end)
    close.MouseLeave:Connect(function() tween(close, { BackgroundColor3 = Theme.Card, TextColor3 = Theme.Sub }) end)

    makeDraggable(bar, win)

    local body = Instance.new("ScrollingFrame")
    body.Size = UDim2.new(1, 0, 1, -48)
    body.Position = UDim2.fromOffset(0, 48)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ScrollBarThickness = 4
    body.ScrollBarImageColor3 = Theme.Accent
    body.CanvasSize = UDim2.new()
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.Parent = win
    pad(body, 12)
    vlist(body, 6)
    return win, body, close
end

local function section(parent, str)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, 22)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = Theme.Accent
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Bottom
    l.Text = string.upper(str)
    return place(l, parent)
end

-- Pill switch; returns refresh() so external code can resync it.
local function makePill(parent, getter)
    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(38, 20)
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.Position = UDim2.new(1, -10, 0.5, 0)
    pill.BackgroundColor3 = Theme.Off
    pill.BorderSizePixel = 0
    pill.Parent = parent
    corner(pill, 10)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    corner(knob, 7)
    return function(animate)
        local on = getter()
        local props1 = { BackgroundColor3 = on and Theme.Accent or Theme.Off }
        local props2 = { Position = UDim2.fromOffset(on and 21 or 3, 3) }
        if animate then
            tween(pill, props1)
            tween(knob, props2)
        else
            pill.BackgroundColor3 = props1.BackgroundColor3
            knob.Position = props2.Position
        end
    end
end

local function switchRow(parent, title, desc, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, desc and 46 or 36)
    row.BackgroundColor3 = Theme.Card
    row.BorderSizePixel = 0
    corner(row, 8)
    local t = text(row, title, 13, Theme.Text, true)
    t.Position = UDim2.fromOffset(12, desc and 7 or 0)
    t.Size = UDim2.new(1, -70, 0, desc and 18 or 36)
    if desc then
        local d = text(row, desc, 11, Theme.Sub)
        d.Position = UDim2.fromOffset(12, 25)
        d.Size = UDim2.new(1, -70, 0, 14)
        d.TextTruncate = Enum.TextTruncate.AtEnd
    end
    local refresh = makePill(row, getter)
    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.fromScale(1, 1)
    hit.Text = ""
    hit.Parent = row
    hit.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = Theme.CardHover }) end)
    hit.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = Theme.Card }) end)
    hit.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh(true)
    end)
    refresh(false)
    place(row, parent)
    return refresh
end

-- Rebindable key row: shows the current key; click, then press a key (Escape cancels).
local function keybindRow(parent, title, getKey, setKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Theme.Card
    row.BorderSizePixel = 0
    corner(row, 8)
    local t = text(row, title, 13, Theme.Text, true)
    t.Position = UDim2.fromOffset(12, 0)
    t.Size = UDim2.new(1, -120, 1, 0)
    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, -10, 0.5, 0)
    btn.Size = UDim2.fromOffset(96, 24)
    btn.BackgroundColor3 = Theme.Off
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Theme.Text
    btn.AutoButtonColor = true
    btn.Parent = row
    corner(btn, 6)
    local capturing = false
    local function show() btn.Text = getKey().Name end
    btn.MouseButton1Click:Connect(function()
        if capturing then return end
        capturing = true
        Rebinding = true
        btn.Text = "press..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()
            capturing = false
            Rebinding = false
            if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.Escape then
                setKey(input.KeyCode)
                saveSettings(true)
            end
            show()
        end)
    end)
    show()
    place(row, parent)
end

local StepperRefreshers = {}

-- "-  [value]  +" row for a numeric setting.
local function stepperRow(parent, title, getValue, setValue)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    local t = text(row, title, 12, Theme.Sub)
    t.Size = UDim2.new(1, -130, 1, 0)
    t.Position = UDim2.fromOffset(2, 0)

    local function smallButton(str, x)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(28, 24)
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, x, 0.5, 0)
        b.BackgroundColor3 = Theme.Off
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Theme.Text
        b.Text = str
        b.AutoButtonColor = true
        b.Parent = row
        corner(b, 6)
        return b
    end
    local plus = smallButton("+", 0)
    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(56, 24)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, -32, 0.5, 0)
    box.BackgroundColor3 = Theme.Field
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    box.TextColor3 = Theme.Text
    box.ClearTextOnFocus = false
    box.Parent = row
    corner(box, 6)
    stroke(box)
    local minus = smallButton("-", -92)

    local function show() box.Text = string.format("%.1fx", getValue()) end
    local function set(v)
        local c = clampScale(v)
        if c then setValue(c) end
        show()
    end
    minus.MouseButton1Click:Connect(function() set(getValue() - 0.5) end)
    plus.MouseButton1Click:Connect(function() set(getValue() + 0.5) end)
    box.FocusLost:Connect(function() set((string.gsub(box.Text, "[^%d%.%-]", ""))) end)
    show()
    table.insert(StepperRefreshers, show)
    place(row, parent)
end

local function card(parent)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 0)
    c.AutomaticSize = Enum.AutomaticSize.Y
    c.BackgroundColor3 = Theme.Card
    c.BorderSizePixel = 0
    corner(c, 8)
    pad(c, 10)
    vlist(c, 4)
    return place(c, parent)
end

local function statusLabel(parent)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextColor3 = Theme.Sub
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Text = ""
    return place(l, parent)
end

-- Main window -------------------------------------------------------------
local Main, MainBody, MainClose = makeWindow("BandA aotfw",
    SettingsLoaded and "RightShift: show / hide  |  settings loaded" or "RightShift: show / hide  |  settings auto-save",
    UDim2.fromOffset(330, 560), UDim2.new(0, 40, 0.5, -280))

-- Hitbox settings window (created first so the main switch can open it)
local HitboxWin, HitboxBody, HitboxClose = makeWindow("Hitbox Settings", "Per-titan hitbox size",
    UDim2.fromOffset(360, 540), UDim2.new(0, 384, 0.5, -270))
HitboxWin.Visible = false
local HitboxOpen = false

section(MainBody, "Hitbox")
switchRow(MainBody, "Expander", "Enlarge weak-point hitboxes", function() return Config.Enabled end, function(v)
    Config.Enabled = v
    if v then scanAll() end
    applyAll()
end)
local refreshHitboxSwitch = switchRow(MainBody, "Hitbox settings", "Open the per-titan size window",
    function() return HitboxOpen end, function(v)
        HitboxOpen = v
        HitboxWin.Visible = v and Main.Visible
    end)

section(MainBody, "Gear")
switchRow(MainBody, "Infinite Gas", "Gas held at max", function() return Config.InfiniteGas end, function(v)
    Config.InfiniteGas = v
end)
switchRow(MainBody, "Auto Reload Blades", "Presses R when the server breaks your blades",
    function() return Config.AutoReload end, function(v) Config.AutoReload = v end)
switchRow(MainBody, "Lock Blade Count", "Experimental, local copy only",
    function() return Config.LockBlades end, function(v) Config.LockBlades = v end)
switchRow(MainBody, "Unlock all skills", "Local only, no skill points spent",
    function() return Config.UnlockSkills end, function(v)
        Config.UnlockSkills = v
        if not v then restoreSkills() end
    end)

section(MainBody, "Combat")
switchRow(MainBody, "Auto Counter (V)", "Counters nearby swings and titan attacks",
    function() return Config.AutoCounter end, function(v) Config.AutoCounter = v end)
switchRow(MainBody, "Counter titans", "Mindless grabs and shifter attacks",
    function() return Config.CounterTitans end, function(v) Config.CounterTitans = v end)
switchRow(MainBody, "Early counter", "Press on a close player's charge, before the swing",
    function() return Config.CounterOnCharge end, function(v) Config.CounterOnCharge = v end)
switchRow(MainBody, "Anti stuck", "Stand up when left lying after a counter",
    function() return Config.AntiStuck end, function(v) Config.AntiStuck = v end)
switchRow(MainBody, "Attack on kick", "A player's kick makes you swing instead of counter",
    function() return Config.KickResponse end, function(v) Config.KickResponse = v end)
switchRow(MainBody, "Predict flying hits", "Counter by approach speed + ping",
    function() return Config.CounterPredict end, function(v)
        Config.CounterPredict = v
        if not v then table.clear(CounterState.Armed) end
    end)
switchRow(MainBody, "Dodge boost", "Dodge skill dashes further",
    function() return Config.DodgeBoost end, function(v) Config.DodgeBoost = v end)

section(MainBody, "ESP")
switchRow(MainBody, "Player ESP", "Boxes on players (K: Warriors list)",
    function() return Config.EspEnabled end, function(v) Config.EspEnabled = v end)
switchRow(MainBody, "Boxes", "Outline each target",
    function() return Config.EspBox end, function(v) Config.EspBox = v end)
switchRow(MainBody, "Names", "Target display name",
    function() return Config.EspName end, function(v) Config.EspName = v end)
switchRow(MainBody, "Distance", "Studs to each target",
    function() return Config.EspDistance end, function(v) Config.EspDistance = v end)
switchRow(MainBody, "Health bars", "Bar left of the box",
    function() return Config.EspHealth end, function(v) Config.EspHealth = v end)
switchRow(MainBody, "Tracers", "Line from screen bottom to target",
    function() return Config.EspTracer end, function(v) Config.EspTracer = v end)
switchRow(MainBody, "Team color", "Off: all boxes red",
    function() return Config.EspTeamColor end, function(v) Config.EspTeamColor = v end)
switchRow(MainBody, "Only warriors", "ESP shows Warriors only, hidden ones too",
    function() return Config.EspWarriorsOnly end, function(v) Config.EspWarriorsOnly = v end)
switchRow(MainBody, "All teams", "When not warriors-only: include your team",
    function() return Config.EspAllTeams end, function(v) Config.EspAllTeams = v end)

section(MainBody, "Shifter")
switchRow(MainBody, "Infinite Shift", "Timer no longer unshifts you",
    function() return Config.InfiniteShift end, function(v)
        Config.InfiniteShift = v
        if not v then restoreShiftTimer() end
    end)
switchRow(MainBody, "Infinite Stamina", "Titan stamina bar held full while shifted",
    function() return Config.InfiniteStamina end, function(v) Config.InfiniteStamina = v end)

section(MainBody, "Misc")
switchRow(MainBody, "Auto Hood", "Puts the hood back on when allowed",
    function() return Config.AutoHood end, function(v) Config.AutoHood = v end)
switchRow(MainBody, "Staff Alert", "Notify when staff is in the server",
    function() return Config.StaffAlert end, function(v) Config.StaffAlert = v end)

section(MainBody, "Keybinds")
keybindRow(MainBody, "Hood toggle (+cloak)",
    function() return Config.HoodKey end, function(k) Config.HoodKey = k end)
keybindRow(MainBody, "Warriors list",
    function() return Config.WarriorListKey end, function(k) Config.WarriorListKey = k end)
keybindRow(MainBody, "Menu show/hide",
    function() return Config.ToggleMenuKey end, function(k) Config.ToggleMenuKey = k end)

section(MainBody, "Status")
local StatusCard = card(MainBody)
local Status = statusLabel(StatusCard)
local GearStatus = statusLabel(StatusCard)
local StaffStatus = statusLabel(StatusCard)
local CounterStatus = statusLabel(StatusCard)

-- Hitbox settings window content ---------------------------------------------
section(HitboxBody, "Display")
switchRow(HitboxBody, "Show hitbox", "Boxes only when in direct line of sight",
    function() return Config.Visualize end, function(v)
        Config.Visualize = v
        applyAll()
    end)
switchRow(HitboxBody, "Hook pass-through", "Q/E hooks ignore expanded hitboxes",
    function() return Config.HookPassThrough end, function(v) Config.HookPassThrough = v end)

local KindOrder = {
    { Kind = "Titan", Name = "Normal titans", Parts = "nape" },
    { Kind = "Colossal", Name = "Colossal", Parts = "nape + eyes" },
    { Kind = "Armored", Name = "Armored", Parts = "eyes + legs (when calf armor breaks)" },
    { Kind = "Female", Name = "Female", Parts = "nape + eyes + legs (unhardened parts)" },
    { Kind = "Attack", Name = "Attack Titan", Parts = "nape + eyes + legs" },
    { Kind = "Beast", Name = "Beast", Parts = "nape + eyes + legs" },
    { Kind = "Cart", Name = "Cart", Parts = "nape + eyes + legs" },
    { Kind = "Warhammer", Name = "War Hammer", Parts = "nape + eyes + legs (unhardened parts)" },
    { Kind = "Jaw", Name = "Jaw", Parts = "nape + eyes + legs (unhardened parts)" },
    { Kind = "WeakArmored", Name = "Weak Armored", Parts = "eyes + legs (no calf plates)" },
    { Kind = "Shifter", Name = "Other shifters", Parts = "nape" },
    { Kind = "KneelArms", Name = "Arms while kneeling", Parts = "arms only while legs are cut" },
}
local Axes = { { "X", "Width (X)" }, { "Y", "Height (Y)" }, { "Z", "Depth (Z)" } }

section(HitboxBody, "All titans")
do
    local c = card(HitboxBody)
    local hint = text(c, "Sets every titan type below at once", 11, Theme.Sub)
    hint.Size = UDim2.new(1, 0, 0, 16)
    place(hint, c)
    for _, axis in ipairs(Axes) do
        local key = axis[1]
        stepperRow(c, axis[2], function()
            return Config.Scales.Titan[key]
        end, function(v)
            for _, k in ipairs(KindOrder) do Config.Scales[k.Kind][key] = v end
            applyAll()
            for _, show in ipairs(StepperRefreshers) do show() end
        end)
    end
end

section(HitboxBody, "Per titan")
for _, k in ipairs(KindOrder) do
    local c = card(HitboxBody)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundTransparency = 1
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(10, 10)
    dot.Position = UDim2.fromOffset(2, 5)
    dot.BackgroundColor3 = KindColor[k.Kind] or Theme.Accent
    dot.BorderSizePixel = 0
    dot.Parent = header
    corner(dot, 5)
    local name = text(header, k.Name, 13, Theme.Text, true)
    name.Position = UDim2.fromOffset(18, 0)
    name.Size = UDim2.new(1, -70, 0, 20)
    local parts = text(header, k.Parts, 11, Theme.Sub)
    parts.Position = UDim2.fromOffset(18, 19)
    parts.Size = UDim2.new(1, -70, 0, 14)
    parts.TextTruncate = Enum.TextTruncate.AtEnd
    local refresh = makePill(header, function() return Config.Kinds[k.Kind] == true end)
    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.fromScale(1, 1)
    hit.Text = ""
    hit.Parent = header
    hit.MouseButton1Click:Connect(function()
        Config.Kinds[k.Kind] = not Config.Kinds[k.Kind]
        refresh(true)
        applyAll()
    end)
    refresh(false)
    place(header, c)
    if k.Kind == "KneelArms" then
        switchRow(c, "Mindless titans too", "Scales their visible upper-arm mesh",
            function() return Config.KneelArmsMindless end, function(v)
                Config.KneelArmsMindless = v
                applyAll()
            end)
        switchRow(c, "Need both legs cut", "Off: one cut leg is enough",
            function() return Config.KneelNeedsBothLegs end, function(v)
                Config.KneelNeedsBothLegs = v
                applyAll()
            end)
    end
    if k.Kind == "Armored" then
        switchRow(c, "Legs at cracked stage", "Off: legs open only when fully broken",
            function() return Config.ArmoredLegsOnCracked end, function(v)
                Config.ArmoredLegsOnCracked = v
                applyAll()
            end)
    end
    for _, axis in ipairs(Axes) do
        local key = axis[1]
        stepperRow(c, axis[2], function()
            return Config.Scales[k.Kind][key]
        end, function(v)
            Config.Scales[k.Kind][key] = v
            applyAll()
        end)
    end
end

local function setHitboxOpen(open)
    HitboxOpen = open
    HitboxWin.Visible = open and Main.Visible
    refreshHitboxSwitch(true)
end
HitboxClose.MouseButton1Click:Connect(function() setHitboxOpen(false) end)

local function toggleMenu()
    Main.Visible = not Main.Visible
    HitboxWin.Visible = HitboxOpen and Main.Visible
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------
table.insert(Connections, workspace.DescendantAdded:Connect(function(d)
    if isNapeName(d.Name) then
        -- Model children (Titan flag, Humanoid) may replicate after the Nape.
        task.delay(0.5, function()
            if d.Parent then track(d) end
        end)
    end
end))

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp or Rebinding then return end
    if input.KeyCode == Config.ToggleMenuKey then
        toggleMenu()
    elseif input.KeyCode == Config.HoodKey then
        hoodToggle()
    end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    ExcludeDirty = true
end))

table.insert(Connections, Players.PlayerAdded:Connect(watchStaff))
table.insert(Connections, Players.PlayerAdded:Connect(watchCounterPlayer))
table.insert(Connections, Players.PlayerRemoving:Connect(function(p)
    local cc = CounterState.PlayerConns[p]
    if cc then cc:Disconnect(); CounterState.PlayerConns[p] = nil end
    local desc = StaffKnown[p]
    if desc then
        StaffKnown[p] = nil
        staffNotify("STAFF LEFT", p.Name .. " - " .. desc)
    end
end))

------------------------------------------------------------------------
-- Player ESP (Drawing API) - boxes / names / distance / health / tracers
------------------------------------------------------------------------
local EspObjects = {}        -- [player] = { box, healthBg, healthFill, name, dist, tracer }
local EspAvailable = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

local function espNew(class, props)
    local ok, d = pcall(Drawing.new, class)
    if not ok or not d then return nil end
    for k, v in pairs(props) do pcall(function() d[k] = v end) end
    return d
end

local function espMakeSet()
    return {
        box = espNew("Square", { Thickness = 1, Filled = false, Visible = false, Color = Config.EspFallbackColor, ZIndex = 2 }),
        healthBg = espNew("Square", { Thickness = 1, Filled = true, Visible = false, Color = Color3.new(0, 0, 0), Transparency = 0.5, ZIndex = 1 }),
        healthFill = espNew("Square", { Thickness = 1, Filled = true, Visible = false, Color = Color3.fromRGB(0, 255, 0), ZIndex = 2 }),
        name = espNew("Text", { Size = Config.EspTextSize, Center = true, Outline = true, Visible = false, Color = Config.EspFallbackColor, ZIndex = 3 }),
        dist = espNew("Text", { Size = Config.EspTextSize, Center = true, Outline = true, Visible = false, Color = Color3.fromRGB(230, 230, 230), ZIndex = 3 }),
        tracer = espNew("Line", { Thickness = 1, Visible = false, Color = Config.EspFallbackColor, ZIndex = 1 }),
    }
end

local function espHide(set)
    if not set then return end
    for _, d in pairs(set) do if d then pcall(function() d.Visible = false end) end end
end

local function espRemove(set)
    if not set then return end
    for _, d in pairs(set) do if d then pcall(function() d:Remove() end) end end
end

local function espClear()
    for pl, set in pairs(EspObjects) do espRemove(set) EspObjects[pl] = nil end
end

-- Warriors infiltrate: an infiltrated Warrior stays on another team (seen live: slidepms on Soldiers with
-- PlayersDataFolder.slidepms.Warrior = true, Infiltrated = true). The direct child is used, not SaveCopy.
local function warriorInfo(player)
    local df = workspace:FindFirstChild("PlayersDataFolder")
    local f = df and df:FindFirstChild(player.Name)
    local w = f and f:FindFirstChild("Warrior")
    local inf = f and f:FindFirstChild("Infiltrated")
    local isW = (w ~= nil and w:IsA("BoolValue") and w.Value == true)
        or (player.Team ~= nil and player.Team.Name == "Warriors")
    local hidden = inf ~= nil and inf:IsA("BoolValue") and inf.Value == true
    return isW, hidden
end

-- Which titan a Warrior holds, from WarriorsCandidatesFolder.ShifterHolders (StringValue per titan type,
-- Value = holder's player name, Variant child e.g. Colossal/Bertholdt, Jaw/Porco). Falls back to a live
-- shifted model's Shifter value.
local function shifterTitan(player)
    local wc = workspace:FindFirstChild("WarriorsCandidatesFolder")
    local sh = wc and wc:FindFirstChild("ShifterHolders")
    if sh then
        for _, holder in ipairs(sh:GetChildren()) do
            if holder:IsA("StringValue") and holder.Value == player.Name then
                local variant = holder:FindFirstChild("Variant")
                local vtxt = (variant and variant.Value ~= "" and variant.Value ~= "None")
                    and (" / " .. variant.Value) or ""
                return holder.Name .. vtxt
            end
        end
    end
    local m = workspace:FindFirstChild(player.Name)
    if m and m:FindFirstChild("Shifter") then return tostring(m.Shifter.Value) end
    return nil
end

local function espTeamColor(player)
    if warriorInfo(player) then return Config.EspFallbackColor end   -- Warriors always red
    if Config.EspTeamColor and player.Team then
        local ok, c = pcall(function() return player.TeamColor.Color end)
        if ok and c then return c end
    end
    return Config.EspFallbackColor
end

local function espShouldShow(player)
    if player == LocalPlayer or not player.Character then return false end
    if Config.EspWarriorsOnly then return (warriorInfo(player)) end
    if not Config.EspAllTeams and player.Team == LocalPlayer.Team then return false end
    return true
end

-- x, y, width, height of the on-screen box, or nil when behind the camera / too small.
local function espBounds(cam, char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local head = char:FindFirstChild("Head")
    local topWorld = (head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))) + Vector3.new(0, 0.5, 0)
    local botWorld = hrp.Position - Vector3.new(0, 3, 0)
    local top = cam:WorldToViewportPoint(topWorld)
    local bot = cam:WorldToViewportPoint(botWorld)
    if top.Z <= 0 or bot.Z <= 0 then return nil end
    local h = bot.Y - top.Y
    if h < 2 then return nil end
    local w = h * 0.5
    return top.X - w / 2, top.Y, w, h
end

local function espUpdate()
    if not EspAvailable then return end
    if not Config.EspEnabled then
        for _, set in pairs(EspObjects) do espHide(set) end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local vp = cam.ViewportSize
    for _, player in ipairs(Players:GetPlayers()) do
        local set = EspObjects[player]
        if not espShouldShow(player) then
            espHide(set)
        else
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp or not hum or hum.Health <= 0 then
                espHide(set)
            else
                local dist = myRoot and (hrp.Position - myRoot.Position).Magnitude or 0
                if Config.EspMaxDistance > 0 and dist > Config.EspMaxDistance then
                    espHide(set)
                else
                    local x, y, w, h = espBounds(cam, char)
                    if not x then
                        espHide(set)
                    else
                        if not set then set = espMakeSet() EspObjects[player] = set end
                        local col = espTeamColor(player)

                        if set.box then
                            if Config.EspBox then
                                set.box.Color = col
                                set.box.Size = Vector2.new(w, h)
                                set.box.Position = Vector2.new(x, y)
                                set.box.Visible = true
                            else
                                set.box.Visible = false
                            end
                        end

                        if set.healthBg and set.healthFill then
                            if Config.EspHealth then
                                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                local barX, barW = x - 5, 2
                                set.healthBg.Size = Vector2.new(barW, h)
                                set.healthBg.Position = Vector2.new(barX, y)
                                set.healthBg.Visible = true
                                local fillH = h * pct
                                set.healthFill.Size = Vector2.new(barW, fillH)
                                set.healthFill.Position = Vector2.new(barX, y + (h - fillH))
                                set.healthFill.Color = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 60)
                                set.healthFill.Visible = true
                            else
                                set.healthBg.Visible = false
                                set.healthFill.Visible = false
                            end
                        end

                        if set.name then
                            if Config.EspName then
                                set.name.Color = col
                                local _, hidden = warriorInfo(player)
                                set.name.Text = hidden and (player.DisplayName .. " [hidden]") or player.DisplayName
                                set.name.Position = Vector2.new(x + w / 2, y - Config.EspTextSize - 2)
                                set.name.Visible = true
                            else
                                set.name.Visible = false
                            end
                        end

                        if set.dist then
                            if Config.EspDistance then
                                set.dist.Text = string.format("%d m", math.floor(dist))
                                set.dist.Position = Vector2.new(x + w / 2, y + h + 1)
                                set.dist.Visible = true
                            else
                                set.dist.Visible = false
                            end
                        end

                        if set.tracer then
                            if Config.EspTracer then
                                set.tracer.Color = col
                                set.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                                set.tracer.To = Vector2.new(x + w / 2, y + h)
                                set.tracer.Visible = true
                            else
                                set.tracer.Visible = false
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Warriors name list, bottom-right of the screen, toggled with Config.WarriorListKey.
local WarriorPanel = Instance.new("Frame")
WarriorPanel.Name = "WarriorList"
WarriorPanel.AnchorPoint = Vector2.new(1, 1)
WarriorPanel.Position = UDim2.new(1, -12, 1, -12)
WarriorPanel.Size = UDim2.fromOffset(300, 0)
WarriorPanel.AutomaticSize = Enum.AutomaticSize.Y
WarriorPanel.BackgroundColor3 = Theme.Panel
WarriorPanel.BackgroundTransparency = 0.04
WarriorPanel.BorderSizePixel = 0
WarriorPanel.Visible = false
WarriorPanel.Parent = Screen
corner(WarriorPanel, 12)
stroke(WarriorPanel)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
    pad.Parent = WarriorPanel
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = WarriorPanel
end
local WarriorTitle = text(WarriorPanel, "WARRIORS", 15, Theme.Accent, true)
WarriorTitle.Size = UDim2.new(1, 0, 0, 24)
WarriorTitle.LayoutOrder = 0

local WarriorDivider = Instance.new("Frame")
WarriorDivider.Size = UDim2.new(1, 0, 0, 1)
WarriorDivider.BackgroundColor3 = Theme.Accent
WarriorDivider.BackgroundTransparency = 0.45
WarriorDivider.BorderSizePixel = 0
WarriorDivider.LayoutOrder = 1
WarriorDivider.Parent = WarriorPanel

local WarriorRows = {}

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Remaining shift time (seconds) of a currently shifted player, from <XXLocal>.Stats.Time.
local function shifterTime(player)
    local ch = player.Character
    if not ch or not ch:FindFirstChild("Shifter") then return nil end
    for _, d in ipairs(ch:GetDescendants()) do
        if (d:IsA("IntValue") or d:IsA("NumberValue")) and d.Name == "Time"
            and d.Parent and d.Parent.Name == "Stats" then
            return d.Value
        end
    end
    return nil
end

local function warriorRow(i)
    local row = WarriorRows[i]
    if row then return row end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 21)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = i + 1
    frame.Parent = WarriorPanel
    local left = text(frame, "", 14, Theme.Text)
    left.Size = UDim2.new(1, -70, 1, 0)
    left.TextYAlignment = Enum.TextYAlignment.Center
    left.TextTruncate = Enum.TextTruncate.AtEnd
    local right = text(frame, "", 14, Theme.Sub, true)
    right.AnchorPoint = Vector2.new(1, 0)
    right.Position = UDim2.new(1, 0, 0, 0)
    right.Size = UDim2.fromOffset(66, 21)
    right.TextXAlignment = Enum.TextXAlignment.Right
    right.TextYAlignment = Enum.TextYAlignment.Center
    row = { frame = frame, left = left, right = right }
    WarriorRows[i] = row
    return row
end

local function warriorListRefresh()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local isW, hidden = warriorInfo(p)
        if isW then
            local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local dist = (myRoot and hrp) and (hrp.Position - myRoot.Position).Magnitude or math.huge
            found[#found + 1] = { p = p, hidden = hidden, dist = dist,
                titan = shifterTitan(p), time = shifterTime(p) }
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    WarriorTitle.Text = string.format("WARRIORS  (%d)", #found)
    local count = math.max(#found, 1)
    for i = 1, count do
        local row = warriorRow(i)
        local e = found[i]
        if e then
            local nm = (e.p.DisplayName ~= e.p.Name) and (e.p.DisplayName .. " (@" .. e.p.Name .. ")") or e.p.Name
            local titan = e.titan and ("  <" .. e.titan .. ">") or ""
            row.left.Text = nm .. titan .. (e.hidden and "  [hidden]" or "")
            row.left.TextColor3 = e.hidden and Theme.Danger or Theme.Text
            if e.time then
                row.right.Text = fmtTime(e.time)
                row.right.TextColor3 = (e.time <= 30) and Theme.Danger or Theme.Accent
            elseif e.dist < math.huge then
                row.right.Text = string.format("%dm", math.floor(e.dist))
                row.right.TextColor3 = Theme.Sub
            else
                row.right.Text = ""
            end
        else
            row.left.Text = "none found"
            row.left.TextColor3 = Theme.Sub
            row.right.Text = ""
        end
        row.frame.Visible = true
    end
    for i = count + 1, #WarriorRows do WarriorRows[i].frame.Visible = false end
end

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp or Rebinding or input.KeyCode ~= Config.WarriorListKey then return end
    WarriorPanel.Visible = not WarriorPanel.Visible
    if WarriorPanel.Visible then pcall(warriorListRefresh) end
end))

local lastWarriorList = 0
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not WarriorPanel.Visible then return end
    local now = os.clock()
    if now - lastWarriorList < Config.WarriorListInterval then return end
    lastWarriorList = now
    local ok, err = pcall(warriorListRefresh)
    if not ok then warn("[AOTFR Tools] warrior list: " .. tostring(err)) end
end))

table.insert(Connections, Players.PlayerRemoving:Connect(function(pl)
    espRemove(EspObjects[pl])
    EspObjects[pl] = nil
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    FrameId += 1
    local okE, errE = pcall(espUpdate)
    if not okE then warn("[AOTFR Tools] esp: " .. tostring(errE)) end
end))

local lastStatus, lastVis, lastKneel = 0, 0, 0
table.insert(Connections, RunService.Heartbeat:Connect(function()
    local ok, err = pcall(gearTick)
    if not ok then warn("[AOTFR Tools] gear tick: " .. tostring(err)) end
    local okS, errS = pcall(antiStuckTick, os.clock())
    if not okS then warn("[AOTFR Tools] anti stuck: " .. tostring(errS)) end
    local okK, errK = pcall(kickPredictTick)
    if not okK then warn("[AOTFR Tools] kick predict: " .. tostring(errK)) end
    local okP, errP = pcall(counterPredictTick)
    if not okP then warn("[AOTFR Tools] counter predict: " .. tostring(errP)) end
    local okSt, errSt = pcall(staminaTick)
    if not okSt then warn("[AOTFR Tools] stamina: " .. tostring(errSt)) end

    local now = os.clock()
    if Config.Enabled and Config.Kinds.KneelArms and now - lastKneel >= 0.1 then
        lastKneel = now
        for part, entry in pairs(Tracked) do
            if entry.Gate == "Kneel" and isExpanded(part, entry) ~= (entry.LastExpanded == true) then
                applyToPart(part)
            end
        end
    end
    if Config.Enabled and Config.Visualize and now - lastVis >= Config.VisibilityInterval then
        lastVis = now
        updateVisibility()
    end

    if now - lastStatus < 0.5 then return end
    lastStatus = now
    Status.Text = statusText()
    saveSettings(false)
    local staffText = staffListText()
    StaffStatus.Text = staffText
    StaffStatus.TextColor3 = staffText == "Staff: none" and Color3.fromRGB(150, 150, 160) or Color3.fromRGB(255, 80, 80)
    local titanAtk, titanSafe = 0, 0
    for _ in pairs(CounterState.TitanAttackIds) do titanAtk += 1 end
    for _ in pairs(CounterState.TitanSafeIds) do titanSafe += 1 end
    CounterStatus.Text = CounterState.LastInfo ~= "" and CounterState.LastInfo
        or string.format("Counter: ready | titan anims: %d attack, %d ignored", titanAtk, titanSafe)
    if ShiftInfo ~= "" then
        GearStatus.Text = ShiftInfo
    else
        local gas = gearValue("Gas", "NumberValue")
        GearStatus.Text = string.format("Gas %s | Server blades %s, dur %s/%s",
            gas and tostring(math.floor(gas.Value)) or "?",
            tostring(GearState.ServerBlades or "?"),
            tostring(GearState.ServerDurability or "?"),
            tostring(bladesMaxDurability() or "?"))
    end
end))

local function Unload()
    saveSettings(true)
    ENV.__AOTFRMouseResolver = nil   -- mouse hook stays installed but passes everything through
    for _, c in ipairs(Connections) do c:Disconnect() end
    for _, c in ipairs(DodgeConns) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    disconnectGear()
    restoreSkills()
    restoreShiftTimer()
    unloadCounter()
    local parts = {}
    for part in pairs(Tracked) do table.insert(parts, part) end
    for _, part in ipairs(parts) do untrack(part, true) end
    espClear()
    if Screen then Screen:Destroy() end
    ENV.__NapeExpander = nil
end

MainClose.MouseButton1Click:Connect(Unload)
ENV.__NapeExpander = { Unload = Unload, Config = Config }

installMouseHook()
scanAll()
for _, p in ipairs(Players:GetPlayers()) do
    watchStaff(p)
    watchCounterPlayer(p)
end