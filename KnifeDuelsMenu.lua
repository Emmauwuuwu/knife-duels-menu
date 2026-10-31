-- KNIFE DUELS | Meowthjr's legit menu (local only)  |  made by meowthjr & Claude
--
-- WHAT IT DOES
--   Hold any knife in the game in your own view, with its real first-person animations (a Butterfly flips, a Karambit
--   spins), even knives you don't own. Only YOU see it: your equipped knife, your character and what other players
--   see are never touched, and nothing is ever sent to the server.
--   How: the game's own ViewmodelRigFactory builds a view model for the knife you pick. Every frame it is put where
--   the game's own view model is, the game's one is made invisible on your screen, and whenever the game plays an
--   animation on its view model, the animation with the same name plays on yours. No game function is replaced.
--
-- HOW TO USE
--   1. Run the script. A window opens. RightShift hides or shows it.
--   2. Pick a knife type on the left, then click a knife. Click it again (or "My own knife") to go back to yours.
--   3. The panel right of the window shows the knife and can tint its colors.
--   4. Star knives to favorite them, or turn on Shuffle for a random knife every round.
--   5. Effects: spin, and tracers behind your thrown knives and on your swings. Boost: more FPS. Display: stretched resolution, overlay, self highlight. World: color looks.
--      Camera: motion blur, field of view, knife position. Settings: hotkeys, window size, accent color.
--
-- LEFT OUT ON PURPOSE
--   Changing your third-person knife or what others see (that would mean changing your real character), and removing
--   fog, haze, smoke or particles in Boost (that would let you see further than other players).

if _G.KnifeDuelsMenu and _G.KnifeDuelsMenu.unload then pcall(_G.KnifeDuelsMenu.unload) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local SAVE_FILE = "knife_duels_menu.json"
local alive = true
local conns = {}
local function keep(c) conns[#conns + 1] = c; return c end

-- the game's modules are required from a thread with identity 2 (executors run at 8), so anything that touches them
-- goes through g(): it runs the function in such a thread, waits for it, and returns pcall's results
local setIdentity = (type(setthreadidentity) == "function" and setthreadidentity)
	or (type(set_thread_identity) == "function" and set_thread_identity)
	or (type(setidentity) == "function" and setidentity)
	or (type(setthreadcontext) == "function" and setthreadcontext)
	or (type(syn) == "table" and type(syn.set_thread_identity) == "function" and syn.set_thread_identity)
	or nil
local function g(fn, ...)
	local args, res, done = table.pack(...), nil, false
	task.spawn(function()
		if setIdentity then pcall(setIdentity, 2) end
		res = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 5 do task.wait() end
	if not res then return false, "timed out" end
	return table.unpack(res, 1, res.n)
end

local KnifeConfig, KnifeTypesConfig, RarityConfig, RigFactory
g(function()
	local shared = RS:FindFirstChild("Shared")
	if not shared then return end
	KnifeConfig = require(shared.KnifeConfig)
	KnifeTypesConfig = require(shared.KnifeTypesConfig)
	pcall(function() RarityConfig = require(shared.RarityConfig) end)
	local ps = lp:FindFirstChildOfClass("PlayerScripts")
	RigFactory = require(ps.Controllers.Combat.ViewmodelRigFactory)
end)
if not (type(KnifeConfig) == "table" and type(RigFactory) == "table" and type(RigFactory.Build) == "function") then
	warn("[KnifeMenu] Couldn't load the game's knife list. Either this isn't Knife Duels or your executor can't run the game's own scripts. Nothing was changed.")
	return
end

-- ===================== saved choices =====================
local sel = nil   -- the knife id shown in your view (nil = your own)
local seenHelp = false
local hideArms = false
local spin = { on = false, speed = 180, dir = 1, axis = "Y", mode = "Continuous" }   -- knife spin (Effects tab)
local tr = { on = false, color = "Cyan", thick = 0.25, life = 0.35, glow = true, throw = true, swing = true }   -- tracers (Effects tab)
local st = { on = false, amount = 0.35 }   -- stretched resolution (Display tab)
local hud = { on = false, keys = true, stats = true, px = 24, py = 240 }   -- keystrokes + FPS/ping overlay (Display tab)
local sh = { on = false, color = "Cyan", fill = 0.65, outline = 0.0, onTop = true }   -- highlight on your own character (Display tab)
local wd = { on = false, preset = "Natural", tint = 1, sat = 0, con = 0, dark = 0, bloom = 0, rays = 0 }   -- World look (World tab)
local mb = { on = false, strength = 12, threshold = 120, smooth = 0.12 }   -- motion blur when turning fast (Camera tab)
local vm = { on = false, fov = 0, x = 0, y = 0, z = 0 }   -- field of view and knife position (Camera tab)
local opt = { on = false, cap = 240, quality = 3, post = true, textures = false, plain = false }   -- FPS boost (Boost tab)
local tn = { on = false, color = "Cyan", strength = 0.45 }   -- tint on the knife in your view (Skins tab)
local ui = { scale = 1, accent = "Blue", keyMenu = "RightShift", keyCursor = "RightControl" }   -- window size, accent, hotkeys (Settings tab)
local shuffle = { on = false }   -- a random knife every round (Skins tab)
local fav = {}   -- knife id -> true (starred knives sort first)
pcall(function()
	local function mergeInto(dst, src)
		if type(src) ~= "table" then return end
		for k, v in pairs(dst) do if type(src[k]) == type(v) then dst[k] = src[k] end end
	end
	if type(readfile) == "function" and type(isfile) == "function" and isfile(SAVE_FILE) then
		local d = HttpService:JSONDecode(readfile(SAVE_FILE))
		if type(d) == "table" then
			if type(d.sel) == "string" then sel = d.sel end
			seenHelp = d.seenHelp == true
			hideArms = d.hideArms == true
			mergeInto(spin, d.spin); mergeInto(tr, d.tr); mergeInto(st, d.st); mergeInto(hud, d.hud); mergeInto(sh, d.sh); mergeInto(wd, d.wd); mergeInto(mb, d.mb)
			mergeInto(vm, d.vm); mergeInto(opt, d.opt); mergeInto(tn, d.tn); mergeInto(ui, d.ui); mergeInto(shuffle, d.shuffle)
			for k, v in pairs(type(d.fav) == "table" and d.fav or {}) do if v == true then fav[k] = true end end
		end
	end
end)
local function save()
	pcall(function()
		if type(writefile) == "function" then
			writefile(SAVE_FILE, HttpService:JSONEncode({ sel = sel, seenHelp = seenHelp, hideArms = hideArms, spin = spin, tr = tr, st = st, hud = hud, sh = sh, wd = wd, mb = mb,
				vm = vm, opt = opt, tn = tn, ui = ui, shuffle = shuffle, fav = fav }))
		end
	end)
end

local function keyOf(name)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	return ok and k or nil
end
if not keyOf(ui.keyMenu) then ui.keyMenu = "RightShift" end
if not keyOf(ui.keyCursor) then ui.keyCursor = "RightControl" end
ui.scale = math.clamp(ui.scale, 0.6, 1.4)

-- ===================== knife list =====================
-- Every knife in the game's own list, grouped by its type (Butterfly, Karambit, ...).
local types, knivesOf, byId = {}, {}, {}
g(function()
	local function rarityInfo(r)
		local cfg = type(RarityConfig) == "table" and RarityConfig[r] or nil
		local col, rank
		if type(cfg) == "table" then
			for _, k in ipairs({ "Color", "Color3", "MainColor", "TextColor", "PrimaryColor" }) do
				if typeof(cfg[k]) == "Color3" then col = cfg[k]; break end
			end
			if not col then
				for _, k in ipairs({ "Gradient", "ColorSequence", "UIGradient" }) do
					if typeof(cfg[k]) == "ColorSequence" then col = cfg[k].Keypoints[1].Value; break end
				end
			end
			for _, k in ipairs({ "SortOrder", "Order", "Rank", "LayoutOrder", "Priority", "Index" }) do   -- the game uses SortOrder (Common 1 ... Secret 8)
				if type(cfg[k]) == "number" then rank = cfg[k]; break end
			end
		end
		return col, rank
	end
	for id, k in pairs(KnifeConfig) do
		if type(k) == "table" and type(id) == "string" then
			local t = type(k.Type) == "string" and k.Type or "Default"
			if not knivesOf[t] then knivesOf[t] = {}; types[#types + 1] = t end
			local col, rank = rarityInfo(k.Rarity)
			local e = {
				id = id, display = type(k.Name) == "string" and k.Name or id, rarity = tostring(k.Rarity or ""), rank = rank or 0,
				color = col, type = t, image = type(k.Image) == "string" and k.Image or "",
			}
			table.insert(knivesOf[t], e)
			byId[id] = e
		end
	end
end)
if #types == 0 then warn("[KnifeMenu] Found no knives in the game's list, so nothing was changed."); return end
table.sort(types, function(a, b)
	if a == "Default" then return true elseif b == "Default" then return false end
	return string.lower(a) < string.lower(b)
end)
for _, list in pairs(knivesOf) do
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then return a.rank > b.rank end
		return string.lower(a.display) < string.lower(b.display)
	end)
end
if sel and not byId[sel] then sel = nil end

local fxWarned = {}
local function guarded(name, fn)
	local ok, e = pcall(fn)
	if not ok and not fxWarned[name] then fxWarned[name] = true; warn("[KnifeMenu] " .. name .. " error: " .. tostring(e)) end
end

local TRACER_COLORS = {   -- the color swatches used all over the window
	Cyan = Color3.fromRGB(80, 220, 255), Pink = Color3.fromRGB(255, 105, 200), Gold = Color3.fromRGB(255, 205, 80),
	Green = Color3.fromRGB(100, 255, 140), Red = Color3.fromRGB(255, 80, 80), White = Color3.fromRGB(255, 255, 255),
	Purple = Color3.fromRGB(170, 110, 255),
}
local COLOR_ORDER = { "Cyan", "Pink", "Gold", "Green", "Red", "White", "Purple", "Rainbow" }

-- ===================== the knife in your view =====================
local myKnifeId   -- the knife you really have equipped (read only)
local function equippedKnifeId()
	local ch = lp.Character
	local ek = ch and ch:FindFirstChild("EquippedKnife")
	local id = ek and ek:GetAttribute("KnifeId")
	return type(id) == "string" and id or nil
end
local function isOurs(o) return o:GetAttribute("KDMenu") == true end
local function gameRig()   -- the game's own view model in your camera
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	for _, c in ipairs(cam:GetChildren()) do
		if c:IsA("Model") and not isOurs(c) and c:FindFirstChildWhichIsA("Humanoid") then return c end
	end
	return nil
end
local function gameVisual()   -- the game's own skinned copy of its knife (only some knives have one)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	for _, c in ipairs(cam:GetChildren()) do
		if c.Name == "ViewmodelKnifeVisual" and not isOurs(c) then return c end
	end
	return nil
end

local rolled          -- Shuffle: the knife rolled for this round
local function swingTrailOn() return tr.on and tr.swing end
-- the knife to show: Shuffle's roll, your pick, or (for the swing trail, which needs our own copy) your own knife
local function wantId() return (shuffle.on and rolled) or sel or (swingTrailOn() and myKnifeId) or nil end
local function rollKnife()
	local favs, all = {}, {}
	for id, e in pairs(byId) do
		all[#all + 1] = id
		if fav[id] then favs[#favs + 1] = id end
	end
	local from = #favs > 0 and favs or all
	rolled = from[math.random(1, math.max(#from, 1))]
end

local mirror = { rig = nil, forId = nil, game = nil, playing = {}, links = {}, knifeShown = true }
local gameLTM = {}   -- part of the game's view model -> the LocalTransparencyModifier the game last gave it
local HIDE = 0.999   -- written to the game's parts; the game only ever writes 0 or 1, so a change shows what it wants
local function unhideGame()
	for p, v in pairs(gameLTM) do if p.Parent then pcall(function() p.LocalTransparencyModifier = v end) end end
	table.clear(gameLTM)
end
local function dropRig()
	for _, c in ipairs(mirror.links) do pcall(function() c:Disconnect() end) end
	table.clear(mirror.links); table.clear(mirror.playing)
	local r = mirror.rig
	if r then
		pcall(function() r.model:Destroy() end)
		pcall(function() if r.knifeVisual then r.knifeVisual:Destroy() end end)
	end
	mirror.rig, mirror.forId, mirror.game = nil, nil, nil
	unhideGame()
end
local function knifeParts(rig)   -- the knife parts of one of our rigs (its skinned copy if it has one, else the knife itself)
	local out = {}
	local function add(m) if m then for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then out[#out + 1] = d end end end end
	if rig.knifeVisual then add(rig.knifeVisual) else add(rig.knifeProxy) end
	return out
end
local function buildRig(id, gm)
	local ok, res = g(function()
		return RigFactory.Build({ knifeId = id, forceHeldKnife = true, initialLocalTransparencyModifier = 0, parent = workspace.CurrentCamera })
	end)
	if not (ok and type(res) == "table" and typeof(res.model) == "Instance" and typeof(res.root) == "Instance") then
		error("couldn't build a view model for " .. tostring(id) .. (ok and "" or (": " .. tostring(res))))
	end
	res.model:SetAttribute("KDMenu", true)
	if res.knifeVisual then res.knifeVisual:SetAttribute("KDMenu", true) end
	res.root.Anchored = true
	res.knifeList = knifeParts(res)
	mirror.rig, mirror.forId, mirror.game = res, id, gm
	-- the game's knife is visible right now unless it already hid it
	local gk = gameVisual() or gm:FindFirstChild("Knife", true)
	local first = gk and gk:FindFirstChildWhichIsA("BasePart", true)
	local v = first and first.LocalTransparencyModifier or 0
	mirror.knifeShown = (math.abs(v - HIDE) <= 1e-4) or v < 0.5
	-- play on our rig whatever the game plays on its own, by name (Idle, Equip, Attack1, Inspect, Throw, ...)
	local hum = gm:FindFirstChildWhichIsA("Humanoid")
	local animator = hum and hum:FindFirstChildWhichIsA("Animator")
	local function follow(track)
		local name = track.Animation and track.Animation.Name
		local ours = name and res.tracks and res.tracks[name]
		if not ours then return end
		mirror.playing[track] = ours
		pcall(function() ours:Play(0.1, math.max(track.WeightTarget, 0.01), track.Speed) end)
		mirror.links[#mirror.links + 1] = track.Stopped:Connect(function()
			if mirror.playing[track] == ours then mirror.playing[track] = nil end
			pcall(function() ours:Stop(0.1) end)
		end)
	end
	if animator then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do follow(t) end
		mirror.links[#mirror.links + 1] = animator.AnimationPlayed:Connect(follow)
	end
end
local function hideGame(gm)   -- make the game's view model invisible on your screen, and read whether it shows its knife
	local knifeRoots = { gm:FindFirstChild("Knife", true), gameVisual() }
	local function hidePart(p, isKnife)
		local v = p.LocalTransparencyModifier
		if math.abs(v - HIDE) > 1e-4 then   -- the game changed it since last frame (Roblox stores 0.999 as 0.99900001)
			gameLTM[p] = v
			if isKnife then mirror.knifeShown = v < 0.5 end
			p.LocalTransparencyModifier = HIDE
		end
	end
	for _, d in ipairs(gm:GetDescendants()) do
		if d:IsA("BasePart") then
			local isKnife = knifeRoots[1] ~= nil and d:IsDescendantOf(knifeRoots[1])
			hidePart(d, isKnife)
		end
	end
	if knifeRoots[2] then for _, d in ipairs(knifeRoots[2]:GetDescendants()) do if d:IsA("BasePart") then hidePart(d, true) end end end
end

-- ===================== tracers =====================
-- Glowing trails on YOUR knife only: behind a knife you throw (the game's ThrownKnife models carry the thrower's
-- user id, so other players' throws are skipped), and along the blade while you attack. Only on your screen.
local function tracerColor()
	return tr.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[tr.color] or TRACER_COLORS.Cyan
end
local function newTrail(part, a0, a1, transparency, faceCamera)
	local t = Instance.new("Trail")
	t.Name = "KDMenuTrail"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Lifetime = math.max(tr.life, 0.05)
	t.LightEmission, t.LightInfluence = 1, 0
	t.FaceCamera = faceCamera
	t.MinLength = 0
	t.Color = ColorSequence.new(tracerColor())
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.15)
	t.Parent = part
	return t
end
local function biggestPart(list)
	local best, size = nil, -1
	for _, p in ipairs(list) do
		local s = p.Size.Magnitude
		if s > size then best, size = p, s end
	end
	return best
end
local function attachmentPair(part, axis, half)
	local a0 = Instance.new("Attachment"); a0.Name = "KDMenuTrailA"; a0.Position = axis * half; a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Name = "KDMenuTrailB"; a1.Position = -axis * half; a1.Parent = part
	return a0, a1
end
local function makeSwingTrails(r)   -- along the blade of our own copy of the knife: from its base to its tip
	local blade = biggestPart(r.knifeList)
	if not blade then return {} end
	local s = blade.Size
	local axis = (s.X >= s.Y and s.X >= s.Z) and Vector3.xAxis or ((s.Y >= s.Z) and Vector3.yAxis or Vector3.zAxis)
	local half = math.max(s.X, s.Y, s.Z) * 0.45
	local a0, a1 = attachmentPair(blade, axis, half)
	local out = { newTrail(blade, a0, a1, 0.25, false) }
	for _, t in ipairs(out) do t.Enabled = false end
	return out
end
-- Your thrown knives (the game's ThrownKnife models with your user id):
--   * with a knife picked here, the game's own projectile factory builds that knife's throw model, which is kept on
--     top of the game's one every frame (in flight and stuck in a wall) while the game's one is hidden on your screen;
--   * the tracer rides on a separate invisible marker that follows the knife. When the game removes the knife (a hit,
--     a headshot) the marker stays where it was last seen, so the trail fades out normally instead of vanishing.
local ProjFactory
local throws = {}   -- the game's ThrownKnife -> { main, parts, visual, vmain, tracer, fadeAt }
local makingVisual = false
local function setupThrow(c)
	local parts = {}
	for _, d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then parts[#parts + 1] = d end end
	local main = c:IsA("Model") and (c.PrimaryPart or biggestPart(parts)) or (c:IsA("BasePart") and c or nil)
	if not main then return end
	if c:IsA("BasePart") then parts[#parts + 1] = c end
	local rec = { main = main, parts = parts }
	local want = wantId()
	if want and want ~= c:GetAttribute("KnifeId") then
		makingVisual = true
		local ok, m, mm = g(function()
			if not ProjFactory then ProjFactory = require(lp:FindFirstChildOfClass("PlayerScripts").Controllers.Combat.KnifeProjectileVisualFactory) end
			return ProjFactory.Create(want, nil, false)
		end)
		makingVisual = false
		if ok and typeof(m) == "Instance" and typeof(mm) == "Instance" then
			for _, d in ipairs(m:GetDescendants()) do   -- its flight effect: the game's knife already has one
				if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then d:Destroy() end
			end
			m.Name = "KDMenuThrownKnife"
			m:SetAttribute("KDMenu", true)
			m.Parent = workspace
			rec.visual, rec.vmain = m, mm
		end
	end
	if tr.on and tr.throw then
		local p = Instance.new("Part")
		p.Name = "KDMenuTracer"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.Transparency = 1; p.Size = Vector3.one * 0.05; p.CFrame = main.CFrame; p.Parent = workspace
		local half = math.max(tr.thick, 0.02) / 2
		local a0, a1 = attachmentPair(p, Vector3.yAxis, half)
		newTrail(p, a0, a1, 0, true)
		if tr.glow then
			local g0, g1 = attachmentPair(p, Vector3.yAxis, half * 3.2)
			newTrail(p, g0, g1, 0.55, true)
		end
		rec.tracer = p
	end
	if rec.visual or rec.tracer then throws[c] = rec end
end
keep(workspace.ChildAdded:Connect(function(c)
	if makingVisual and c:GetAttribute("ProjectileFX") then task.defer(function() pcall(function() c:Destroy() end) end); return end
	if c.Name ~= "ThrownKnife" then return end
	task.defer(function()   -- its attributes and parts are filled in right after it appears
		if c:GetAttribute("KillCamThrowerUserId") ~= lp.UserId then return end
		guarded("throws", function() setupThrow(c) end)
	end)
end))
local function stepThrows()
	local now = os.clock()
	for c, rec in pairs(throws) do
		if c.Parent and rec.main.Parent then
			if rec.visual then
				rec.visual:PivotTo(rec.main.CFrame)
				for _, p in ipairs(rec.parts) do if p.LocalTransparencyModifier ~= 1 then p.LocalTransparencyModifier = 1 end end
			end
			if rec.tracer then rec.tracer.CFrame = rec.main.CFrame end
		else   -- the game removed its knife: drop our copy, let the trail fade where it was
			if rec.visual then pcall(function() rec.visual:Destroy() end); rec.visual = nil end
			if rec.tracer and not rec.fadeAt then rec.fadeAt = now + math.max(tr.life, 0.05) + 0.25 end
			if not rec.tracer or now > rec.fadeAt then
				if rec.tracer then pcall(function() rec.tracer:Destroy() end) end
				throws[c] = nil
			end
		end
	end
end
local function clearThrows()
	for c, rec in pairs(throws) do
		pcall(function() if rec.visual then rec.visual:Destroy() end end)
		pcall(function() if rec.tracer then rec.tracer:Destroy() end end)
		for _, p in ipairs(rec.parts) do if p.Parent then pcall(function() p.LocalTransparencyModifier = 0 end) end end
	end
	table.clear(throws)
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuThrows", Enum.RenderPriority.Last.Value + 12, function() guarded("throws", stepThrows) end) end); if not okB then warn("[KnifeMenu] could not start throws: " .. tostring(eB)) end end

local buildBlockedUntil, buildWarned = 0, false
local lastGame
local spinAngle, spinLast, spinEquip = 0, os.clock(), os.clock()
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
local function stepMirror()
	local now = os.clock()
	local dt = math.min(now - spinLast, 0.1)
	spinLast = now
	myKnifeId = equippedKnifeId()
	local gm = gameRig()
	if gm ~= lastGame then   -- a new round / respawn: the game built a new view model
		lastGame = gm
		spinEquip = now; spinAngle = 0
		if gm and shuffle.on then rollKnife() end
	end
	local id = wantId()
	if not (id and gm) or (id == myKnifeId and not swingTrailOn()) then
		if mirror.rig then dropRig() end
		return
	end
	if mirror.rig and (mirror.forId ~= id or mirror.game ~= gm or not mirror.rig.model.Parent) then dropRig() end
	if not mirror.rig then
		if now < buildBlockedUntil then return end
		local ok, err = pcall(buildRig, id, gm)
		if not ok then
			buildBlockedUntil = now + 3
			if mirror.rig then dropRig() end
			if not buildWarned then buildWarned = true; warn("[KnifeMenu] " .. tostring(err)) end
			return
		end
	end
	local r = mirror.rig
	local gRoot = gm:FindFirstChild("HumanoidRootPart") or gm.PrimaryPart
	if not gRoot then return end
	-- where the game put its own view model this frame, plus your position offset and spin
	local cam = workspace.CurrentCamera
	local cf = gRoot.CFrame
	if cam and vm.on and (vm.x ~= 0 or vm.y ~= 0 or vm.z ~= 0) then
		cf = cam.CFrame * CFrame.new(vm.x, vm.y, -vm.z) * cam.CFrame:ToObjectSpace(cf)
	end
	if cam and spin.on then
		local ang
		if spin.mode == "Swing" then
			ang = 60 * math.sin(math.rad(spin.speed) * (now - spinEquip) * 0.5) * spin.dir
		elseif spin.mode == "On equip" then
			local dur = math.max(360 / math.max(spin.speed, 1), 0.25)
			local p = math.clamp((now - spinEquip) / dur, 0, 1)
			ang = 360 * (1 - (1 - p) ^ 3) * spin.dir
		else
			spinAngle = (spinAngle + spin.speed * spin.dir * dt) % 360
			ang = spinAngle
		end
		local center = r.knifeList[1] and r.knifeList[1].Position or cf.Position
		local camRot = cam.CFrame.Rotation
		local rot = camRot * CFrame.fromAxisAngle(AXES[spin.axis] or Vector3.yAxis, math.rad(ang)) * camRot:Inverse()
		local rel = cf.Position - center
		cf = CFrame.new(center + rot * rel) * rot * cf.Rotation
	end
	r.root.CFrame = cf
	for track, ours in pairs(mirror.playing) do   -- keep the speeds in step (attacks speed up / slow down)
		if track.IsPlaying and math.abs(ours.Speed - track.Speed) > 1e-3 then pcall(function() ours:AdjustSpeed(track.Speed) end) end
	end
	hideGame(gm)
	local knifeLTM = mirror.knifeShown and 0 or 1
	for _, p in ipairs(r.knifeList) do if p.LocalTransparencyModifier ~= knifeLTM then p.LocalTransparencyModifier = knifeLTM end end
	-- swing trail: on while an attack plays (and the knife is shown)
	local attacking = false
	if swingTrailOn() and mirror.knifeShown then
		for track in pairs(mirror.playing) do
			if track.IsPlaying and string.find(track.Animation.Name, "Attack", 1, true) then attacking = true; break end
		end
	end
	if attacking and not r.swingTrails then r.swingTrails = makeSwingTrails(r) end
	for _, t in ipairs(r.swingTrails or {}) do
		if t.Enabled ~= attacking then t.Enabled = attacking end
		if attacking then t.Color = ColorSequence.new(tracerColor()); t.Lifetime = math.max(tr.life, 0.05) end
	end
	local armLTM = hideArms and 1 or 0
	for _, p in ipairs(r.model:GetChildren()) do
		if p:IsA("BasePart") and string.find(string.lower(p.Name), "arm", 1, true) and p.LocalTransparencyModifier ~= armLTM then
			p.LocalTransparencyModifier = armLTM
		end
	end
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuMirror", Enum.RenderPriority.Last.Value + 10, function() guarded("knife", stepMirror) end) end); if not okB then warn("[KnifeMenu] could not start: " .. tostring(eB)) end end

-- tint: recolors the knife's own texture in your view (SurfaceAppearance.Color multiplies it). Only our own copy of
-- the knife is changed, so nothing needs putting back: turning it off just uses plain white again.
do
	local touched = {}
	local function stepTint()
		local r = mirror.rig
		if not r then return end
		local c = Color3.new(1, 1, 1)
		if tn.on then
			local col = tn.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[tn.color] or TRACER_COLORS.Cyan
			c = Color3.new(1, 1, 1):Lerp(col, math.clamp(tn.strength, 0, 1))
		end
		for _, p in ipairs(r.knifeList) do
			for _, sa in ipairs(p:GetChildren()) do
				if sa:IsA("SurfaceAppearance") then
					if touched[sa] == nil then touched[sa] = sa.Color end
					local o = touched[sa]
					local want = Color3.new(o.R * c.R, o.G * c.G, o.B * c.B)
					if sa.Color ~= want then sa.Color = want end
				end
			end
		end
	end
	local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuTint", Enum.RenderPriority.Last.Value + 11, function() guarded("tint", stepTint) end) end)
	if not okB then warn("[KnifeMenu] could not start tint: " .. tostring(eB)) end
end

-- ===================== free cursor =====================
local freeCursor = false
local function enforceCursor()
	if not freeCursor then return end
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuCursor", Enum.RenderPriority.Last.Value + 1, enforceCursor) end); if not okB then warn("[KnifeMenu] could not start cursor: " .. tostring(eB)) end end

-- ===================== stretched resolution and field of view =====================
-- Both are taken off again right before the game's camera code runs each frame, so the game never sees them.
local unstretch, unFov
do
local stretchedCF, cleanCF = nil, nil
function unstretch()
	local cam = workspace.CurrentCamera
	if stretchedCF and cam and cam.CFrame == stretchedCF then cam.CFrame = cleanCF end
	stretchedCF, cleanCF = nil, nil
end
local function applyStretch()
	local cam = workspace.CurrentCamera
	if not (cam and st.on) then return end
	cleanCF = cam.CFrame
	stretchedCF = cleanCF * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1 - math.clamp(st.amount, 0, 0.7), 0, 0, 0, 1)
	cam.CFrame = stretchedCF
end
local fovSet, fovClean = nil, nil
function unFov()
	local cam = workspace.CurrentCamera
	if fovSet and cam and math.abs(cam.FieldOfView - fovSet) < 1e-3 then cam.FieldOfView = fovClean end
	fovSet, fovClean = nil, nil
end
local function applyFov()
	local cam = workspace.CurrentCamera
	if not (cam and vm.on and vm.fov ~= 0) then return end
	fovClean = cam.FieldOfView
	fovSet = math.clamp(fovClean + vm.fov, 1, 120)
	cam.FieldOfView = fovSet
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuStretchA", 1, function() unstretch(); unFov() end) end); if not okB then warn("[KnifeMenu] could not start stretch: " .. tostring(eB)) end end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuStretchB", Enum.RenderPriority.Last.Value + 3, function() guarded("stretch", applyStretch); guarded("fov", applyFov) end) end); if not okB then warn("[KnifeMenu] could not start stretch: " .. tostring(eB)) end end
end

-- ===================== motion blur =====================
local mbBlur
do
local mbLook, mbLast = nil, os.clock()
local function stepBlur()
	local now = os.clock()
	local dt = math.max(now - mbLast, 1 / 240)
	mbLast = now
	local cam = workspace.CurrentCamera
	if not (mb.on and cam) then
		if mbBlur then mbBlur.Enabled = false; mbBlur.Size = 0 end
		mbLook = nil
		return
	end
	if not mbBlur or not mbBlur.Parent then
		mbBlur = Instance.new("BlurEffect"); mbBlur.Name = "KDMenuMotionBlur"; mbBlur.Size = 0; mbBlur.Parent = game:GetService("Lighting")
	end
	local look = cam.CFrame.LookVector
	local target = 0
	if mbLook then
		local ang = math.deg(math.acos(math.clamp(mbLook:Dot(look), -1, 1)))
		if ang < 60 then   -- a bigger jump in one frame is a camera cut (respawn, spectate), not you turning
			target = mb.strength * math.clamp((ang / dt - mb.threshold) / 540, 0, 1)
		end
	end
	mbLook = look
	local k = 1 - math.exp(-dt / math.max(mb.smooth, 0.01))
	mbBlur.Size = mbBlur.Size + (target - mbBlur.Size) * k
	mbBlur.Enabled = mbBlur.Size > 0.05
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuBlur", Enum.RenderPriority.Camera.Value + 5, function() guarded("motion blur", stepBlur) end) end); if not okB then warn("[KnifeMenu] could not start motion blur: " .. tostring(eB)) end end
end

-- ===================== window =====================
local ACCENTS = {
	{ id = "Blue", color = Color3.fromRGB(94, 138, 255) }, { id = "Purple", color = Color3.fromRGB(150, 105, 255) },
	{ id = "Pink", color = Color3.fromRGB(236, 92, 170) }, { id = "Red", color = Color3.fromRGB(230, 80, 80) },
	{ id = "Orange", color = Color3.fromRGB(240, 145, 60) }, { id = "Green", color = Color3.fromRGB(70, 185, 120) },
	{ id = "Teal", color = Color3.fromRGB(40, 170, 190) },
}
local function accentOf(id)
	for _, a in ipairs(ACCENTS) do if a.id == id then return a.color end end
	return ACCENTS[1].color
end
local C = {
	bg = Color3.fromRGB(13, 14, 19), white = Color3.fromRGB(255, 255, 255), accent = accentOf(ui.accent),
	text = Color3.fromRGB(240, 241, 246), dim = Color3.fromRGB(158, 163, 181),
	good = Color3.fromRGB(110, 214, 144), warn = Color3.fromRGB(243, 186, 98),
}
local accentObjs = {}   -- { instance, property } drawn in the accent color, recolored when it changes
local gui = Instance.new("ScreenGui")
gui.Name = "KnifeDuelsMenu"; gui.ResetOnSpawn = false; gui.DisplayOrder = 50; gui.IgnoreGuiInset = true
pcall(function() if type(syn) == "table" and syn.protect_gui then syn.protect_gui(gui) end end)
do   -- gethui can throw on some executors, so every parent is tried in turn
	local parents = {
		function() return type(gethui) == "function" and gethui() or nil end,
		function() return game:GetService("CoreGui") end,
		function() return lp:WaitForChild("PlayerGui", 5) end,
	}
	for _, get in ipairs(parents) do
		local ok, p = pcall(get)
		if ok and typeof(p) == "Instance" then
			local okP = pcall(function() gui.Parent = p end)
			if okP and gui.Parent == p then break end
		end
	end
	if not gui.Parent then warn("[KnifeMenu] Couldn't place the window anywhere."); return end
end

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = o end
local make
local function stroke(o, transparency, color, thickness)
	return make("UIStroke", { Color = color or C.white, Transparency = transparency or 0.88, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
make = function(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function text(parent, str, size, color, pos, sz, align, font)
	return make("TextLabel", {
		BackgroundTransparency = 1, Text = str, TextSize = size, Font = font or Enum.Font.BuilderSans, TextColor3 = color or C.text,
		Position = pos, Size = sz, TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = true,
	}, parent)
end
-- soft "glass" button: see-through, brightens on hover
local function button(parent, str, pos, sz, accent)
	local base = accent and 0.15 or 0.92
	local b = make("TextButton", {
		Text = str, Position = pos, Size = sz, BackgroundColor3 = accent and C.accent or C.white, BackgroundTransparency = base,
		TextColor3 = C.text, Font = Enum.Font.BuilderSansMedium, TextSize = 13, AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	if accent then accentObjs[#accentObjs + 1] = { b, "BackgroundColor3" } end
	b.MouseEnter:Connect(function() b.BackgroundTransparency = accent and 0.05 or 0.84 end)
	b.MouseLeave:Connect(function() b.BackgroundTransparency = base end)
	return b
end

local applyHud
local SIDE = 146   -- width of the menu on the left; every page sits to the right of it
local win = make("Frame", {
	Size = UDim2.fromOffset(640 + SIDE, 500), Position = UDim2.new(0.5, -(640 + SIDE) / 2, 0.5, -250), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.2, BorderSizePixel = 0,
}, gui)
corner(win, 14)
stroke(win, 0.86)

-- no on-screen tab when hidden (so nobody can see you use it): RightShift brings the window back
local function setOpen(open) win.Visible = open end

-- header: logo and title on the left, switches and small buttons on the right
local top = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, win)
do
	local mark = make("Frame", { Position = UDim2.fromOffset(16, 11), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, top)
	corner(mark, 9)
	accentObjs[#accentObjs + 1] = { mark, "BackgroundColor3" }
	make("UIGradient", { Rotation = 45, Transparency = NumberSequence.new(0, 0.35) }, mark)
	text(mark, "KD", 13, C.white, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, Enum.Font.BuilderSansBold)
	text(top, "Meowthjr's legit menu", 17, C.text, UDim2.fromOffset(56, 9), UDim2.fromOffset(220, 20), nil, Enum.Font.BuilderSansBold)
	text(top, "Knife Duels  ·  made by meowthjr & Claude", 11, C.dim, UDim2.fromOffset(56, 28), UDim2.fromOffset(260, 14))
end
local closeBtn = button(top, "×", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(30, 28))
local hideBtn = button(top, "–", UDim2.new(1, -78, 0, 12), UDim2.fromOffset(30, 28))
local helpBtn = button(top, "?", UDim2.new(1, -112, 0, 12), UDim2.fromOffset(30, 28))
closeBtn.TextSize = 18

-- small on/off switches in the header
local setStatus
local function makeSwitch(label, labelX, switchX, labelW, get)
	text(top, label, 12, C.dim, UDim2.new(1, labelX, 0, 0), UDim2.fromOffset(labelW, 52), Enum.TextXAlignment.Right)
	local sw = make("TextButton", {
		Text = "", AutoButtonColor = false, Position = UDim2.new(1, switchX, 0, 16), Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = C.white, BackgroundTransparency = 0.82,
	}, top)
	corner(sw, 10)
	local knob = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.text, BorderSizePixel = 0 }, sw)
	corner(knob, 8)
	local function paint(animate)
		local on = get()
		local goal = { BackgroundColor3 = on and C.accent or C.white, BackgroundTransparency = on and 0.1 or 0.82 }
		local kpos = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		if animate then
			TweenService:Create(sw, TweenInfo.new(0.15), goal):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), { Position = kpos }):Play()
		else
			for k, v in pairs(goal) do sw[k] = v end
			knob.Position = kpos
		end
	end
	paint(false)
	return sw, paint
end

local armsSw, paintArms = makeSwitch("Hide arms", -226, -158, 62, function() return hideArms end)
armsSw.MouseButton1Click:Connect(function()
	hideArms = not hideArms
	paintArms(true); save()
	setStatus(hideArms and "Arms hidden (on a knife picked here)." or "Arms are back.", "good")
end)

-- Free cursor: keeps your mouse unlocked in first person so you can click the window without pressing Esc
local cursorSw, paintCursor = makeSwitch("Free cursor", -334, -260, 70, function() return freeCursor end)
local function setFreeCursor(on)
	freeCursor = on and true or false
	paintCursor(true)
	if freeCursor then enforceCursor() end
end
cursorSw.MouseButton1Click:Connect(function()
	setFreeCursor(not freeCursor)
	setStatus(freeCursor and ("Cursor unlocked. Move the mouse freely. (" .. ui.keyCursor .. " turns it off again.)") or "Cursor is locked to the camera again.", "good")
end)
make("Frame", { Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = C.white, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, top)

-- dragging by the header
do
	local dragging, startPos, startMouse
	keep(top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = win.Position; startMouse = i.Position end
	end))
	keep(UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startMouse
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	keep(UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
end

-- bottom row: status text on the left, buttons on the right
local bar = make("Frame", { Position = UDim2.new(0, SIDE + 10, 1, -50), Size = UDim2.new(1, -SIDE - 24, 0, 38), BackgroundTransparency = 1 }, win)
local status = text(bar, "", 12, C.dim, UDim2.fromOffset(2, 0), UDim2.new(1, -130, 1, 0))
local resetAll = button(bar, "My own knife", UDim2.new(1, -120, 0, 4), UDim2.fromOffset(120, 30))
local resetFx = button(bar, "Reset effects", UDim2.new(1, -126, 0, 4), UDim2.fromOffset(126, 30))
resetFx.Visible = false
setStatus = function(t, kind)
	status.Text = t
	status.TextColor3 = (kind == "good" and C.good) or (kind == "warn" and C.warn) or C.dim
end

-- menu on the left: one row per page, the open one marked with an accent bar
local tabBtns = {}   -- page name -> menu row
do
	local side = make("Frame", { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(0, SIDE - 18, 1, -72), BackgroundColor3 = C.white, BackgroundTransparency = 0.96, BorderSizePixel = 0 }, win)
	corner(side, 12); stroke(side, 0.94)
	text(side, "MENU", 10, C.dim, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 12), nil, Enum.Font.BuilderSansMedium)
	for i, t in ipairs({ { "skins", "Knives" }, { "fx", "Effects" }, { "boost", "Boost" }, { "display", "Display" }, { "world", "World" }, { "camera", "Camera" }, { "settings", "Settings" } }) do
		local b = make("TextButton", {
			Position = UDim2.fromOffset(6, 28 + (i - 1) * 36), Size = UDim2.new(1, -12, 0, 32), BackgroundColor3 = C.white, BackgroundTransparency = 1,
			Text = t[2], TextColor3 = C.dim, Font = Enum.Font.BuilderSansMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
		}, side)
		corner(b, 8)
		make("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
		local mark = make("Frame", { Name = "Bar", Position = UDim2.new(0, -10, 0.5, -8), Size = UDim2.fromOffset(3, 16), BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false }, b)
		corner(mark, 2)
		b.MouseEnter:Connect(function() if not b:GetAttribute("Active") then b.BackgroundTransparency = 0.93 end end)
		b.MouseLeave:Connect(function() if not b:GetAttribute("Active") then b.BackgroundTransparency = 1 end end)
		tabBtns[t[1]] = b
	end
	text(side, ui.keyMenu .. "  hide\n" .. ui.keyCursor .. "  cursor", 10, C.dim, UDim2.new(0, 14, 1, -36), UDim2.new(1, -28, 0, 28))
end

-- ===================== Knives page =====================
local X0, Y0 = SIDE + 10, 62   -- top-left corner of every page
local function column(title)
	local f = make("Frame", { BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, win)
	corner(f, 12)
	stroke(f, 0.93)
	local t = text(f, title, 11, C.dim, UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
	local s = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.white,
		ScrollBarImageTransparency = 0.6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, f)
	make("UIListLayout", { Padding = UDim.new(0, 4) }, s)
	make("UIPadding", { PaddingRight = UDim.new(0, 4) }, s)
	return { frame = f, title = t, scroll = s }
end
local left = column("KNIFE TYPES")
left.frame.Position = UDim2.fromOffset(X0, Y0); left.frame.Size = UDim2.new(0, 168, 1, -Y0 - 60)
left.scroll.Position = UDim2.fromOffset(6, 30); left.scroll.Size = UDim2.new(1, -12, 1, -76)   -- shuffle sits below
local right = column("KNIVES")
right.frame.Position = UDim2.fromOffset(X0 + 176, Y0); right.frame.Size = UDim2.new(1, -X0 - 176 - 14, 1, -Y0 - 60)
local search = make("TextBox", {
	Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = C.white, BackgroundTransparency = 0.92,
	TextColor3 = C.text, PlaceholderText = "Search knives, rarity, or \"fav\"...", PlaceholderColor3 = C.dim, Text = "", Font = Enum.Font.BuilderSans,
	TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
}, right.frame)
corner(search, 8)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, search)
right.scroll.Position = UDim2.fromOffset(6, 66); right.scroll.Size = UDim2.new(1, -12, 1, -72)

local current      -- selected knife type
local typeRows, knifeRows = {}, {}
local refreshTypes, refreshKnives
local showPreview   -- set by the preview panel

-- a list row: optional rarity dot, name, small tag on the right; accent colour when in use
local function row(parent, name, tag, active, dot, star)   -- star = { on = bool, click = fn } adds a favorite star
	local b = make("TextButton", {
		Size = UDim2.new(1, -2, 0, 32), BackgroundColor3 = active and C.accent or C.white,
		BackgroundTransparency = active and 0.25 or 0.94, Text = "", AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	local x = 12
	if dot then
		local d = make("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 12, 0.5, -4), BackgroundColor3 = dot, BorderSizePixel = 0 }, b)
		corner(d, 4)
		x = 28
	end
	local label = text(b, name, 13, C.text, UDim2.fromOffset(x, 0), UDim2.new(1, -x - (star and 112 or 62), 1, 0))
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if tag and tag ~= "" then
		text(b, tag, 11, active and C.text or C.dim, UDim2.new(1, star and -114 or -62, 0, 0), UDim2.fromOffset(star and 80 or 52, 32), Enum.TextXAlignment.Right)
	end
	if star then
		local s = make("TextButton", {
			Text = star.on and "★" or "☆", Position = UDim2.new(1, -30, 0, 4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1,
			TextColor3 = star.on and Color3.fromRGB(255, 205, 80) or C.dim, Font = Enum.Font.BuilderSansBold, TextSize = 16, AutoButtonColor = false,
		}, b)
		s.MouseButton1Click:Connect(star.click)
	end
	b.MouseEnter:Connect(function() if not active then b.BackgroundTransparency = 0.86 end end)
	b.MouseLeave:Connect(function() if not active then b.BackgroundTransparency = 0.94 end end)
	return b
end
local function note(parent, str, store)
	local l = text(parent, str, 12, C.dim, UDim2.new(), UDim2.new(1, -8, 0, 0))
	l.AutomaticSize = Enum.AutomaticSize.Y
	store[#store + 1] = l
	return l
end

function refreshTypes()
	for _, b in pairs(typeRows) do b:Destroy() end
	typeRows = {}
	local mine = myKnifeId and byId[myKnifeId] and byId[myKnifeId].type
	local picked = sel and byId[sel] and byId[sel].type
	for _, t in ipairs(types) do
		local tag = (t == picked and "in view") or (t == mine and "yours") or tostring(#knivesOf[t])
		local b = row(left.scroll, t, tag, t == current)
		typeRows[#typeRows + 1] = b
		b.MouseButton1Click:Connect(function() current = t; search.Text = ""; refreshTypes(); refreshKnives() end)
	end
end

local function picked(id, msg)
	sel = id
	save(); refreshTypes(); refreshKnives()
	setStatus(msg, "good")
end

function refreshKnives()
	for _, b in pairs(knifeRows) do b:Destroy() end
	knifeRows = {}
	if not current then
		right.title.Text = "KNIVES"
		note(right.scroll, "Pick a knife type on the left.", knifeRows)
		return
	end
	local q = string.lower(search.Text or "")
	local favOnly = (q == "fav" or q == "favs" or q == "favorites")
	local source = {}
	if q ~= "" and not favOnly then   -- a search looks through every type
		for _, t in ipairs(types) do for _, e in ipairs(knivesOf[t]) do source[#source + 1] = e end end
		table.sort(source, function(a, b)   -- results from every type: rarest first, like each type's own list
			if a.rank ~= b.rank then return a.rank > b.rank end
			return string.lower(a.display) < string.lower(b.display)
		end)
	else
		source = knivesOf[current] or {}
	end
	local d = row(right.scroll, "My own knife" .. (myKnifeId and byId[myKnifeId] and (" (" .. byId[myKnifeId].display .. ")") or ""), sel == nil and "in use" or "", sel == nil)
	knifeRows[#knifeRows + 1] = d
	d.MouseButton1Click:Connect(function() picked(nil, "Your own knife is back.") end)
	local ordered = {}
	for _, e in ipairs(source) do if fav[e.id] then ordered[#ordered + 1] = e end end
	for _, e in ipairs(source) do if not fav[e.id] then ordered[#ordered + 1] = e end end
	local shown = 0
	for _, e in ipairs(ordered) do
		local match
		if favOnly then match = fav[e.id] == true and e.type == current
		else match = q == "" or string.find(string.lower(e.display), q, 1, true) or string.find(string.lower(e.rarity), q, 1, true) or string.find(string.lower(e.type), q, 1, true) end
		if match then
			shown += 1
			local on = sel == e.id
			local label = (q ~= "" and not favOnly) and (e.display .. "  ·  " .. e.type) or e.display
			local b = row(right.scroll, label, on and "in use" or e.rarity, on, e.color or C.dim, {
				on = fav[e.id] == true,
				click = function() fav[e.id] = (not fav[e.id]) or nil; save(); refreshKnives() end,
			})
			knifeRows[#knifeRows + 1] = b
			b.MouseEnter:Connect(function() if showPreview then showPreview(e.id) end end)
			b.MouseLeave:Connect(function() if showPreview then showPreview(nil) end end)
			b.MouseButton1Click:Connect(function()
				if sel == e.id then picked(nil, "Turned off. Your own knife is back.")
				else picked(e.id, e.display .. " (" .. e.type .. ") is in your hands, with its own animations.") end
			end)
		end
	end
	right.title.Text = (q ~= "" and not favOnly) and ("SEARCH  ·  " .. shown) or ("KNIVES: " .. string.upper(current) .. "  ·  " .. #(knivesOf[current] or {}))
	if shown == 0 then note(right.scroll, "No knives match \"" .. (search.Text or "") .. "\".", knifeRows) end
	if showPreview then showPreview(nil) end
end
keep(search:GetPropertyChangedSignal("Text"):Connect(refreshKnives))
resetAll.MouseButton1Click:Connect(function() picked(nil, "Your own knife is back.") end)

-- ===================== page helpers =====================
local repaints = {}
local function page()
	return make("Frame", { Position = UDim2.fromOffset(X0, Y0), Size = UDim2.new(1, -X0 - 14, 1, -Y0 - 60), BackgroundTransparency = 1, Visible = false }, win)
end
local fxPage = page()
local function card(x, w, title, parentPage)
	local f = make("Frame", { Position = UDim2.new(x, x == 0 and 0 or 6, 0, 0), Size = UDim2.new(w, -6, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, parentPage or fxPage)
	corner(f, 12); stroke(f, 0.93)
	text(f, title, 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
	return f
end
local function toggleAt(parent, pos, get, set)
	local sw = make("TextButton", {
		Text = "", AutoButtonColor = false, Position = pos, Size = UDim2.fromOffset(38, 20), BackgroundColor3 = C.white, BackgroundTransparency = 0.82,
	}, parent)
	corner(sw, 10)
	local knob = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.text, BorderSizePixel = 0 }, sw)
	corner(knob, 8)
	local function paint(animate)
		local on = get()
		local goal = { BackgroundColor3 = on and C.accent or C.white, BackgroundTransparency = on and 0.1 or 0.82 }
		local kpos = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		if animate then
			TweenService:Create(sw, TweenInfo.new(0.15), goal):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), { Position = kpos }):Play()
		else
			for k, v in pairs(goal) do sw[k] = v end
			knob.Position = kpos
		end
	end
	paint(false)
	sw.MouseButton1Click:Connect(function() set(not get()); paint(true); save() end)
	repaints[#repaints + 1] = function() paint(false) end
	return sw
end
local function toggleRow(parent, y, label, get, set)
	text(parent, label, 13, C.text, UDim2.fromOffset(14, y), UDim2.new(1, -70, 0, 20))
	toggleAt(parent, UDim2.new(1, -52, 0, y), get, set)
end
local function slider(parent, y, label, min, max, step, get, set, fmt)
	text(parent, label, 12, C.dim, UDim2.fromOffset(14, y), UDim2.new(1, -100, 0, 16))
	local val = text(parent, "", 12, C.text, UDim2.new(1, -94, 0, y), UDim2.fromOffset(80, 16), Enum.TextXAlignment.Right)
	local bar2 = make("Frame", { Position = UDim2.fromOffset(14, y + 26), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.white, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, parent)
	corner(bar2, 3)
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, bar2)
	corner(fill, 3)
	accentObjs[#accentObjs + 1] = { fill, "BackgroundColor3" }
	local knob = make("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 }, bar2)
	corner(knob, 7)
	local hit = make("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -9), Size = UDim2.new(1, 0, 1, 18) }, bar2)
	local function paint()
		local v = get()
		local a = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0); knob.Position = UDim2.new(a, 0, 0.5, 0); val.Text = fmt(v)
	end
	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - bar2.AbsolutePosition.X) / math.max(bar2.AbsoluteSize.X, 1), 0, 1)
		local v = math.floor((min + (max - min) * a) / step + 0.5) * step
		set(math.clamp(v, min, max)); paint()
	end
	hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(i.Position.X) end end)
	keep(UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end end))
	keep(UIS.InputEnded:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false; save() end end))
	paint()
	repaints[#repaints + 1] = paint
end
local function segmented(parent, y, label, options, get, set)
	text(parent, label, 12, C.dim, UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, 16))
	local holder = make("Frame", { Position = UDim2.fromOffset(14, y + 20), Size = UDim2.new(1, -28, 0, 28), BackgroundTransparency = 1 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, holder)
	local btns = {}
	local n = #options
	for i, o in ipairs(options) do
		local b = make("TextButton", {
			Text = o.text, Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.92,
			TextColor3 = C.text, Font = Enum.Font.BuilderSansMedium, TextSize = 12, AutoButtonColor = false,
		}, holder)
		corner(b, 8)
		btns[i] = b
		b.MouseButton1Click:Connect(function() set(o.id); for _, f in ipairs(repaints) do f() end; save() end)
	end
	local function paint()
		for i, o in ipairs(options) do
			local on = get() == o.id
			btns[i].BackgroundColor3 = on and C.accent or C.white
			btns[i].BackgroundTransparency = on and 0.2 or 0.92
		end
	end
	paint()
	repaints[#repaints + 1] = paint
end
local function swatchRow(parent, y, size, step, get, set)
	local rings = {}
	local function paint() for n2, r2 in pairs(rings) do r2.Transparency = (n2 == get()) and 0 or 1 end end
	for i, name in ipairs(COLOR_ORDER) do
		local b = make("TextButton", {
			Text = name == "Rainbow" and "R" or "", Position = UDim2.fromOffset(14 + (i - 1) * step, y), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = TRACER_COLORS[name] or Color3.fromRGB(255, 160, 60), AutoButtonColor = false, TextColor3 = C.bg,
			Font = Enum.Font.BuilderSansBold, TextSize = 11,
		}, parent)
		corner(b, math.floor(size / 2))
		rings[name] = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 1 }, b)
		b.MouseButton1Click:Connect(function() set(name); paint(); save() end)
	end
	paint()
	repaints[#repaints + 1] = paint
end
local function pct(v) return math.floor(v * 100 + 0.5) .. " %" end

-- Knives page, under the type list: shuffle
do
	text(left.frame, "Shuffle", 12, C.text, UDim2.new(0, 14, 1, -36), UDim2.new(1, -70, 0, 20))
	toggleAt(left.frame, UDim2.new(1, -50, 1, -36), function() return shuffle.on end, function(v)
		shuffle.on = v
		if v then rollKnife() else rolled = nil end
		setStatus(v and "Shuffle on: a random knife every round (from your starred knives if you have any)." or "Shuffle off. Your picked knife is back.", "good")
	end)
end

-- Knives page, right of the window: the knife's picture (from the game's own list) and the tint
local previewPanel
do
	previewPanel = make("Frame", { Position = UDim2.new(1, 10, 0, Y0), Size = UDim2.new(0, 230, 1, -Y0 - 60), BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, win)
	corner(previewPanel, 12); stroke(previewPanel, 0.86)
	text(previewPanel, "PREVIEW", 11, C.dim, UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
	local nameLabel = text(previewPanel, "", 13, C.text, UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 18), nil, Enum.Font.BuilderSansMedium)
	nameLabel.TextWrapped = false; nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local frame = make("Frame", { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 180), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, previewPanel)
	corner(frame, 10)
	local img = make("ImageLabel", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -40), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = "" }, frame)
	local info = text(frame, "", 11, C.dim, UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center)
	function showPreview(id)
		local sid = id or sel or myKnifeId
		local e = sid and byId[sid]
		nameLabel.Text = e and e.display or "Pick a knife"
		img.Image = e and e.image or ""
		info.Text = e and (e.type .. "  ·  " .. e.rarity) or ""
		info.TextColor3 = (e and e.color) or C.dim
	end
	text(previewPanel, "Tint the knife", 13, C.text, UDim2.fromOffset(14, 236), UDim2.new(1, -70, 0, 20))
	toggleAt(previewPanel, UDim2.new(1, -52, 0, 236), function() return tn.on end, function(v)
		tn.on = v
		setStatus(v and "Tint on. It colors the knife picked here, in your view." or "Tint off.", "good")
	end)
	swatchRow(previewPanel, 264, 20, 25, function() return tn.color end, function(v) tn.color = v end)
	slider(previewPanel, 292, "Strength", 0.05, 1, 0.05, function() return tn.strength end, function(v) tn.strength = v end, pct)
	text(previewPanel, "Works on a knife picked here (not on your own one, which the game draws).", 11, C.dim, UDim2.fromOffset(14, 328), UDim2.new(1, -28, 0, 28))
end

-- ===================== Effects page =====================
do
local spCard = card(0, 0.5, "Knife spin")
toggleAt(spCard, UDim2.new(1, -52, 0, 12), function() return spin.on end, function(v) spin.on = v end)
slider(spCard, 44, "Speed", 20, 720, 10, function() return spin.speed end, function(v) spin.speed = v end, function(v) return math.floor(v) .. " °/s" end)
segmented(spCard, 92, "Direction", { { id = 1, text = "Clockwise" }, { id = -1, text = "Counter" } }, function() return spin.dir end, function(v) spin.dir = v end)
segmented(spCard, 146, "Axis", { { id = "X", text = "X  tilt" }, { id = "Y", text = "Y  turn" }, { id = "Z", text = "Z  roll" } }, function() return spin.axis end, function(v) spin.axis = v end)
segmented(spCard, 200, "Behavior", { { id = "Continuous", text = "Continuous" }, { id = "Swing", text = "Swing" }, { id = "On equip", text = "On equip" } }, function() return spin.mode end, function(v) spin.mode = v end)
text(spCard, "Turns the knife in your view. Works on a knife picked on the Knives page.", 11, C.dim, UDim2.fromOffset(14, 254), UDim2.new(1, -28, 0, 30))

local trCard = card(0.5, 0.5, "Tracers")
toggleAt(trCard, UDim2.new(1, -52, 0, 12), function() return tr.on end, function(v) tr.on = v end)
text(trCard, "Color", 12, C.dim, UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 16))
swatchRow(trCard, 62, 24, 30, function() return tr.color end, function(v) tr.color = v end)
slider(trCard, 96, "Thickness (thrown)", 0.05, 0.8, 0.05, function() return tr.thick end, function(v) tr.thick = v end, function(v) return string.format("%.2f", v) end)
slider(trCard, 138, "Length", 0.1, 1.5, 0.05, function() return tr.life end, function(v) tr.life = v end, function(v) return string.format("%.2f s", v) end)
toggleRow(trCard, 184, "Behind thrown knives", function() return tr.throw end, function(v) tr.throw = v end)
toggleRow(trCard, 212, "On swings", function() return tr.swing end, function(v) tr.swing = v end)
toggleRow(trCard, 240, "Glow", function() return tr.glow end, function(v) tr.glow = v end)
text(trCard, "Only on your own knife and only on your screen. Other players' throws never get one.", 11, C.dim, UDim2.fromOffset(14, 270), UDim2.new(1, -28, 0, 30))
end

-- ===================== overlay: keystrokes + FPS / ping =====================
do
local hudFrame = make("Frame", {
	Position = UDim2.fromOffset(hud.px, hud.py), Size = UDim2.fromOffset(132, 40), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, Active = true,
}, gui)
corner(hudFrame, 10); stroke(hudFrame, 0.86)
local hudStats = text(hudFrame, "-- FPS", 12, C.text, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 18), Enum.TextXAlignment.Center, Enum.Font.BuilderSansMedium)
local keysHolder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 132) }, hudFrame)
local keyBoxes = {}
local function keyBox(label, x, y, w, h, test)
	local f = make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, keysHolder)
	corner(f, 6)
	text(f, label, 12, C.text, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, Enum.Font.BuilderSansMedium)
	keyBoxes[#keyBoxes + 1] = { frame = f, test = test, down = false }
end
local function kd(code) return function() return UIS:IsKeyDown(code) end end
local function md(btn) return function() return UIS:IsMouseButtonPressed(btn) end end
keyBox("W", 49, 0, 34, 34, kd(Enum.KeyCode.W))
keyBox("A", 8, 38, 34, 34, kd(Enum.KeyCode.A))
keyBox("S", 49, 38, 34, 34, kd(Enum.KeyCode.S))
keyBox("D", 90, 38, 34, 34, kd(Enum.KeyCode.D))
keyBox("LMB", 8, 76, 56, 26, md(Enum.UserInputType.MouseButton1))
keyBox("RMB", 68, 76, 56, 26, md(Enum.UserInputType.MouseButton2))
keyBox("Shift", 8, 106, 56, 26, function() return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) end)
keyBox("Space", 68, 106, 56, 26, kd(Enum.KeyCode.Space))
function applyHud()
	hudFrame.Visible = hud.on and (hud.keys or hud.stats)
	hudStats.Visible = hud.stats
	keysHolder.Visible = hud.keys
	local keysY = 6 + (hud.stats and 24 or 0)
	keysHolder.Position = UDim2.fromOffset(0, keysY)
	hudFrame.Size = UDim2.fromOffset(132, keysY + (hud.keys and 138 or 0))
end
local acc, frames = 0, 0
keep(RunService.Heartbeat:Connect(function(dt)
	if not hud.on then return end
	if hud.keys then
		for _, k in ipairs(keyBoxes) do
			local d = k.test()
			if d ~= k.down then
				k.down = d
				k.frame.BackgroundColor3 = d and C.accent or C.white
				k.frame.BackgroundTransparency = d and 0.15 or 0.9
			end
		end
	end
	if hud.stats then
		acc += dt; frames += 1
		if acc >= 0.5 then
			local fps = math.floor(frames / acc + 0.5)
			acc, frames = 0, 0
			local ok, ms = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
			hudStats.Text = fps .. " FPS  ·  " .. (ok and math.floor(ms + 0.5) or 0) .. " ms"
		end
	end
end))
local dragging, startPos, startMouse
hudFrame.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = hudFrame.Position; startMouse = i.Position end
end)
keep(UIS.InputChanged:Connect(function(i)
	if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
		local d = i.Position - startMouse
		hudFrame.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
	end
end))
keep(UIS.InputEnded:Connect(function(i)
	if dragging and i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
		local vs, sz = gui.AbsoluteSize, hudFrame.AbsoluteSize
		local x = math.clamp(hudFrame.Position.X.Offset, 0, math.max(vs.X - sz.X, 0))
		local y = math.clamp(hudFrame.Position.Y.Offset, 0, math.max(vs.Y - sz.Y, 0))
		hudFrame.Position = UDim2.fromOffset(x, y)
		hud.px, hud.py = x, y
		save()
	end
end))
end

-- ===================== World look =====================
-- Your own color grade, bloom and sun rays on top of the game's lighting. Brightness can only be lowered.
local PRESETS = {
	{ id = "Natural", tint = Color3.fromRGB(255, 255, 255), sat = 0,    con = 0,    dark = 0,    bloom = 0,   rays = 0 },
	{ id = "Sunset",  tint = Color3.fromRGB(255, 190, 140), sat = 0.15, con = 0.08, dark = 0,    bloom = 0.4, rays = 0.15 },
	{ id = "Neon",    tint = Color3.fromRGB(170, 140, 255), sat = 0.35, con = 0.15, dark = 0.12, bloom = 1.0, rays = 0 },
	{ id = "Frost",   tint = Color3.fromRGB(170, 210, 255), sat = -0.1, con = 0.05, dark = 0,    bloom = 0.3, rays = 0 },
	{ id = "Mono",    tint = Color3.fromRGB(255, 255, 255), sat = -1,   con = 0.2,  dark = 0,    bloom = 0,   rays = 0 },
	{ id = "Vintage", tint = Color3.fromRGB(255, 225, 180), sat = -0.3, con = 0.1,  dark = 0.05, bloom = 0.2, rays = 0 },
	{ id = "Toxic",   tint = Color3.fromRGB(170, 255, 170), sat = 0.3,  con = 0.12, dark = 0.08, bloom = 0.6, rays = 0 },
	{ id = "Rose",    tint = Color3.fromRGB(255, 170, 205), sat = 0.2,  con = 0.06, dark = 0,    bloom = 0.5, rays = 0.1 },
}
local PRESET_BY = {}
for _, p in ipairs(PRESETS) do PRESET_BY[p.id] = p end
local wGrade, wBloom, wRays
local function applyWorld()
	local L = game:GetService("Lighting")
	if not wd.on then
		if wGrade then wGrade.Enabled = false end
		if wBloom then wBloom.Enabled = false end
		if wRays then wRays.Enabled = false end
		return
	end
	if not (wGrade and wGrade.Parent) then wGrade = Instance.new("ColorCorrectionEffect"); wGrade.Name = "KDMenuWorldGrade"; wGrade.Parent = L end
	if not (wBloom and wBloom.Parent) then wBloom = Instance.new("BloomEffect"); wBloom.Name = "KDMenuWorldBloom"; wBloom.Size = 24; wBloom.Threshold = 1; wBloom.Parent = L end
	if not (wRays and wRays.Parent) then wRays = Instance.new("SunRaysEffect"); wRays.Name = "KDMenuWorldRays"; wRays.Spread = 0.8; wRays.Parent = L end
	local pr = PRESET_BY[wd.preset] or PRESETS[1]
	wGrade.Enabled = true
	wGrade.TintColor = Color3.new(1, 1, 1):Lerp(pr.tint, math.clamp(wd.tint, 0, 1))
	wGrade.Saturation = math.clamp(wd.sat, -1, 1)
	wGrade.Contrast = math.clamp(wd.con, 0, 0.5)
	wGrade.Brightness = -math.clamp(wd.dark, 0, 0.4)   -- can only darken, never brighten
	wBloom.Intensity = math.clamp(wd.bloom, 0, 2); wBloom.Enabled = wd.bloom > 0
	wRays.Intensity = math.clamp(wd.rays, 0, 0.5); wRays.Enabled = wd.rays > 0
end
local function setPreset(id)
	local pr = PRESET_BY[id]; if not pr then return end
	wd.preset, wd.tint, wd.sat, wd.con, wd.dark, wd.bloom, wd.rays = id, 1, pr.sat, pr.con, pr.dark, pr.bloom, pr.rays
	applyWorld()
end
do
	local acc = 0
	keep(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then acc = 0; if wd.on then guarded("world", applyWorld) end end
	end))
end
if wd.on then guarded("world", applyWorld) end

-- ===================== self highlight =====================
-- An outline/fill on YOUR OWN character only. Other players are never highlighted.
local shHl
do
	local function stepSelf()
		local ch = lp.Character
		if not (sh.on and ch) then
			if shHl then shHl.Enabled = false end
			return
		end
		if not shHl or not shHl.Parent then
			shHl = Instance.new("Highlight")
			shHl.Name = "KDMenuSelf"
			shHl.Parent = gui
		end
		local c = sh.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[sh.color] or TRACER_COLORS.Cyan
		shHl.Adornee = ch
		shHl.Enabled = true
		shHl.FillColor = c; shHl.OutlineColor = c
		shHl.FillTransparency = sh.fill; shHl.OutlineTransparency = sh.outline
		shHl.DepthMode = sh.onTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	end
	local okB, eB = pcall(function() RunService:BindToRenderStep("KDMenuSelf", Enum.RenderPriority.Last.Value + 4, function() guarded("self highlight", stepSelf) end) end)
	if not okB then warn("[KnifeMenu] could not start self highlight: " .. tostring(eB)) end
end

-- ===================== Display page =====================
local dispPage = page()
do
local stCard = card(0, 1 / 3, "Stretched res", dispPage)
toggleAt(stCard, UDim2.new(1, -52, 0, 12), function() return st.on end, function(v) st.on = v end)
slider(stCard, 48, "Stretch", 0, 0.7, 0.01, function() return st.amount end, function(v) st.amount = v end, pct)
text(stCard, "Makes everything look wider by flattening your view vertically, like a stretched monitor setting. Only your own screen changes.", 12, C.dim, UDim2.fromOffset(14, 100), UDim2.new(1, -28, 0, 150))

local ovCard = card(1 / 3, 1 / 3, "Overlay", dispPage)
toggleAt(ovCard, UDim2.new(1, -52, 0, 12), function() return hud.on end, function(v) hud.on = v; applyHud() end)
toggleRow(ovCard, 52, "Keystrokes", function() return hud.keys end, function(v) hud.keys = v; applyHud() end)
toggleRow(ovCard, 82, "FPS and ping", function() return hud.stats end, function(v) hud.stats = v; applyHud() end)
text(ovCard, "A small box with your movement keys, mouse buttons, FPS and ping. Drag it anywhere (turn on Free cursor first in first person). It stays visible when you hide this window.", 12, C.dim, UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 150))
applyHud()

local shCard = card(2 / 3, 1 / 3, "Self highlight", dispPage)
toggleAt(shCard, UDim2.new(1, -52, 0, 12), function() return sh.on end, function(v) sh.on = v end)
text(shCard, "Color", 12, C.dim, UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 16))
swatchRow(shCard, 58, 18, 21, function() return sh.color end, function(v) sh.color = v end)
slider(shCard, 90, "Fill", 0, 1, 0.05, function() return 1 - sh.fill end, function(v) sh.fill = 1 - v end, pct)
slider(shCard, 130, "Outline", 0, 1, 0.05, function() return 1 - sh.outline end, function(v) sh.outline = 1 - v end, pct)
toggleRow(shCard, 172, "Show over everything", function() return sh.onTop end, function(v) sh.onTop = v end)
text(shCard, "Outlines and tints your own character only. Other players are never highlighted and nothing about them is shown.", 12, C.dim, UDim2.fromOffset(14, 204), UDim2.new(1, -28, 0, 110))
end

-- ===================== World page =====================
local worldPage = page()
do
local wlCard = card(0, 0.5, "World look", worldPage)
toggleAt(wlCard, UDim2.new(1, -52, 0, 12), function() return wd.on end, function(v) wd.on = v; applyWorld() end)
text(wlCard, "Pick a look. It changes only your own screen. Fine tune it with the sliders on the right.", 12, C.dim, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 34))
local pBtns = {}
local function paintPresets()
	for id, b in pairs(pBtns) do
		local on = wd.preset == id
		b.BackgroundColor3 = on and C.accent or C.white
		b.BackgroundTransparency = on and 0.2 or 0.92
	end
end
local pGrid = make("Frame", { Position = UDim2.fromOffset(14, 80), Size = UDim2.new(1, -28, 0, 80), BackgroundTransparency = 1 }, wlCard)
make("UIGridLayout", { CellSize = UDim2.new(0.25, -3, 0, 36), CellPadding = UDim2.fromOffset(4, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pGrid)
for i, pr in ipairs(PRESETS) do
	local b = make("TextButton", {
		Text = pr.id, LayoutOrder = i, BackgroundColor3 = C.white, BackgroundTransparency = 0.92, TextColor3 = C.text,
		Font = Enum.Font.BuilderSansMedium, TextSize = 12, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Right,
	}, pGrid)
	corner(b, 8)
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }, b)
	local dot = make("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 8, 0.5, -5), BackgroundColor3 = pr.tint, BorderSizePixel = 0 }, b)
	corner(dot, 5)
	pBtns[pr.id] = b
	b.MouseButton1Click:Connect(function()
		wd.on = true; setPreset(pr.id)
		for _, f in ipairs(repaints) do f() end
		save()
	end)
end
repaints[#repaints + 1] = paintPresets
paintPresets()
text(wlCard, "Brightness can only be lowered, never raised, so a look can make a map moodier but not easier to see into. Fog and sky are left to the game.", 12, C.dim, UDim2.fromOffset(14, 176), UDim2.new(1, -28, 0, 90))

local wsCard = card(0.5, 0.5, "Fine tune", worldPage)
local function wslider(y, label, min, max, key)
	slider(wsCard, y, label, min, max, 0.01, function() return wd[key] end, function(v) wd[key] = v; applyWorld() end, pct)
end
wslider(38, "Color strength", 0, 1, "tint")
wslider(76, "Saturation", -1, 1, "sat")
wslider(114, "Contrast", 0, 0.5, "con")
wslider(152, "Darkness", 0, 0.4, "dark")
wslider(190, "Glow", 0, 2, "bloom")
wslider(228, "Sun rays", 0, 0.5, "rays")
end

-- ===================== Camera page =====================
local camPage = page()
do
local mbCard = card(0, 0.5, "Motion blur", camPage)
toggleAt(mbCard, UDim2.new(1, -52, 0, 12), function() return mb.on end, function(v) mb.on = v end)
slider(mbCard, 44, "Strength", 2, 24, 1, function() return mb.strength end, function(v) mb.strength = v end, function(v) return tostring(math.floor(v + 0.5)) end)
slider(mbCard, 92, "Starts at", 30, 360, 10, function() return mb.threshold end, function(v) mb.threshold = v end, function(v) return math.floor(v) .. " °/s" end)
slider(mbCard, 140, "Fade", 0.03, 0.4, 0.01, function() return mb.smooth end, function(v) mb.smooth = v end, function(v) return string.format("%.2f s", v) end)
text(mbCard, "Your screen blurs while you flick or turn fast and gets sharp again when you stop. Lower \"Starts at\" to blur on slower turns, raise Fade for a longer trail.", 12, C.dim, UDim2.fromOffset(14, 192), UDim2.new(1, -28, 0, 140))

local vwCard = card(0.5, 0.5, "View", camPage)
toggleAt(vwCard, UDim2.new(1, -52, 0, 12), function() return vm.on end, function(v) vm.on = v end)
slider(vwCard, 44, "Field of view", -20, 30, 1, function() return vm.fov end, function(v) vm.fov = v end,
	function(v) v = math.floor(v + 0.5); return (v > 0 and "+" or "") .. v .. "°" end)
text(vwCard, "KNIFE POSITION", 11, C.dim, UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
local function studs(v) return string.format("%.2f", v) end
slider(vwCard, 110, "Left / right", -1, 1, 0.05, function() return vm.x end, function(v) vm.x = v end, studs)
slider(vwCard, 148, "Down / up", -1, 1, 0.05, function() return vm.y end, function(v) vm.y = v end, studs)
slider(vwCard, 186, "Near / far", -1, 1.5, 0.05, function() return vm.z end, function(v) vm.z = v end, studs)
text(vwCard, "Field of view is added on top of the game's own. Knife position works on a knife picked on the Knives page; 0 is where the game puts it.", 12, C.dim, UDim2.fromOffset(14, 230), UDim2.new(1, -28, 0, 100))
end

-- ===================== FPS boost =====================
-- Lower graphics quality, a higher FPS cap, and (optionally) no bloom / blur / color effects, no decals, plain
-- materials. Fog, haze, depth of field, smoke and particles are left alone on purpose. Everything is put back on turn-off.
local applyOpt, restoreOpt
do
	local saved = { post = {}, textures = {}, plain = {} }
	local OURS = { KDMenuMotionBlur = true, KDMenuWorldGrade = true, KDMenuWorldBloom = true, KDMenuWorldRays = true }
	local POST = { BloomEffect = true, BlurEffect = true, ColorCorrectionEffect = true, SunRaysEffect = true }
	local function set(cat, inst, prop, value)
		local s = saved[cat][inst]
		if not s then s = {}; saved[cat][inst] = s end
		if s[prop] == nil then s[prop] = inst[prop] end
		if inst[prop] ~= value then inst[prop] = value end
	end
	local function restore(cat)
		for inst, props in pairs(saved[cat]) do
			for prop, v in pairs(props) do pcall(function() inst[prop] = v end) end
		end
		table.clear(saved[cat])
	end
	local function want(cat) return opt.on and opt[cat] end
	local function mine(d)
		local cam = workspace.CurrentCamera
		if cam and d:IsDescendantOf(cam) then return true end
		local ch = lp.Character
		return ch ~= nil and d:IsDescendantOf(ch)
	end
	local function consider(d)
		if want("textures") and d:IsA("Decal") then
			if not mine(d) then set("textures", d, "Transparency", 1) end
		elseif want("plain") and d:IsA("BasePart") and not d:IsA("Terrain") then
			if not mine(d) then set("plain", d, "Material", Enum.Material.SmoothPlastic); set("plain", d, "Reflectance", 0) end
		end
	end
	local function doPost()
		if not want("post") then return end
		for _, c in ipairs(game:GetService("Lighting"):GetChildren()) do
			if not OURS[c.Name] and POST[c.ClassName] then set("post", c, "Enabled", false) end
		end
	end
	local origQuality, origCap, rendered = nil, nil, false
	pcall(function() origQuality = settings().Rendering.QualityLevel end)
	pcall(function() if type(getfpscap) == "function" then origCap = getfpscap() end end)
	local function doRender()
		if opt.on then
			local q = Enum.QualityLevel["Level" .. string.format("%02d", math.clamp(math.floor(opt.quality + 0.5), 1, 21))]
			pcall(function() if settings().Rendering.QualityLevel ~= q then settings().Rendering.QualityLevel = q end end)
			if type(setfpscap) == "function" then pcall(setfpscap, opt.cap) end
			rendered = true
		elseif rendered then
			if origQuality then pcall(function() settings().Rendering.QualityLevel = origQuality end) end
			if origCap and type(setfpscap) == "function" then pcall(setfpscap, origCap) end
			rendered = false
		end
	end
	function applyOpt()
		for cat in pairs(saved) do if not want(cat) then restore(cat) end end
		doRender(); doPost()
		if want("textures") or want("plain") then
			for _, d in ipairs(workspace:GetDescendants()) do pcall(consider, d) end
		end
	end
	function restoreOpt()
		for cat in pairs(saved) do restore(cat) end
		local was = opt.on
		opt.on = false; doRender(); opt.on = was
	end
	keep(workspace.DescendantAdded:Connect(function(d) if opt.on then pcall(consider, d) end end))
	local acc = 0
	keep(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then acc = 0; if opt.on then guarded("boost", function() doPost(); doRender() end) end end
	end))
end

local boostPage = page()
do
local fpsCard = card(0, 0.5, "FPS boost", boostPage)
toggleAt(fpsCard, UDim2.new(1, -52, 0, 12), function() return opt.on end, function(v)
	opt.on = v; applyOpt()
	setStatus(v and "Boost on. Watch the FPS counter (Display tab overlay) to see the difference." or "Boost off. Everything is back the way it was.", "good")
end)
segmented(fpsCard, 44, "FPS cap", { { id = 60, text = "60" }, { id = 144, text = "144" }, { id = 240, text = "240" }, { id = 0, text = "Max" } },
	function() return opt.cap end, function(v) opt.cap = v; applyOpt() end)
slider(fpsCard, 100, "Graphics quality", 1, 21, 1, function() return opt.quality end, function(v) opt.quality = v; applyOpt() end,
	function(v) return tostring(math.floor(v + 0.5)) .. " / 21" end)
text(fpsCard, "Lower graphics quality is the biggest FPS win. Max takes the FPS cap off completely. Motion blur and the glow in World look cost FPS too.", 12, C.dim, UDim2.fromOffset(14, 150), UDim2.new(1, -28, 0, 120))

local lwCard = card(0.5, 0.5, "Lighter world", boostPage)
toggleRow(lwCard, 44, "No bloom, blur and color effects", function() return opt.post end, function(v) opt.post = v; applyOpt() end)
toggleRow(lwCard, 74, "Hide decals and textures", function() return opt.textures end, function(v) opt.textures = v; applyOpt() end)
toggleRow(lwCard, 104, "Plain materials", function() return opt.plain end, function(v) opt.plain = v; applyOpt() end)
text(lwCard, "These work while FPS boost is on. Fog, haze, depth of field, smoke and particles stay as the game made them, so nobody sees further than anyone else.", 12, C.dim, UDim2.fromOffset(14, 142), UDim2.new(1, -28, 0, 120))
end
if opt.on then applyOpt() end

-- ===================== Settings page =====================
local setFrame, binding, paintKeys, applyAccent   -- binding: "keyMenu" / "keyCursor" while waiting for a new key
do
setFrame = page()
local hkCard = card(0, 0.5, "Hotkeys", setFrame)
local keyBtns = {}
function paintKeys()
	for k, b in pairs(keyBtns) do b.Text = (binding == k) and "Press a key..." or ui[k] end
end
local function keyRow(y, label, key)
	text(hkCard, label, 13, C.text, UDim2.fromOffset(14, y + 4), UDim2.new(1, -150, 0, 20))
	local b = button(hkCard, ui[key], UDim2.new(1, -134, 0, y), UDim2.fromOffset(120, 28))
	b.TextSize = 12
	keyBtns[key] = b
	b.MouseButton1Click:Connect(function() binding = (binding ~= key) and key or nil; paintKeys() end)
end
keyRow(44, "Show / hide window", "keyMenu")
keyRow(80, "Free cursor", "keyCursor")
text(hkCard, "Click a key box, then press the new key. Esc cancels. Only keyboard keys can be used.", 12, C.dim, UDim2.fromOffset(14, 124), UDim2.new(1, -28, 0, 60))
paintKeys()

local uiCard = card(0.5, 0.5, "Interface", setFrame)
local uiScale = make("UIScale", { Scale = ui.scale }, win)
slider(uiCard, 44, "Window size", 0.6, 1.4, 0.05, function() return ui.scale end, function(v) ui.scale = v end, pct)
keep(UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 and uiScale.Scale ~= ui.scale then uiScale.Scale = ui.scale end
end))
text(uiCard, "Accent color", 12, C.dim, UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 16))
local accRings = {}
for i, a in ipairs(ACCENTS) do
	local b = make("TextButton", { Text = "", Position = UDim2.fromOffset(14 + (i - 1) * 30, 112), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = a.color, AutoButtonColor = false }, uiCard)
	corner(b, 12)
	accRings[a.id] = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = (ui.accent == a.id) and 0 or 1 }, b)
	b.MouseButton1Click:Connect(function()
		ui.accent = a.id
		for id, r in pairs(accRings) do r.Transparency = (id == a.id) and 0 or 1 end
		applyAccent(); save()
	end)
end
text(uiCard, "The window resizes when you let go of the slider. The overlay keeps its own size.", 12, C.dim, UDim2.fromOffset(14, 150), UDim2.new(1, -28, 0, 60))
end

local function defaults()
	spin.on, spin.speed, spin.dir, spin.axis, spin.mode = false, 180, 1, "Y", "Continuous"
	tr.on, tr.color, tr.thick, tr.life, tr.glow, tr.throw, tr.swing = false, "Cyan", 0.25, 0.35, true, true, true
	st.on, st.amount = false, 0.35
	hud.on, hud.keys, hud.stats = false, true, true
	sh.on, sh.color, sh.fill, sh.outline, sh.onTop = false, "Cyan", 0.65, 0, true
	wd.on = false; setPreset("Natural")
	mb.on, mb.strength, mb.threshold, mb.smooth = false, 12, 120, 0.12
	vm.on, vm.fov, vm.x, vm.y, vm.z = false, 0, 0, 0, 0
	opt.on, opt.cap, opt.quality, opt.post, opt.textures, opt.plain = false, 240, 3, true, false, false
	tn.on, tn.color, tn.strength = false, "Cyan", 0.45
	applyOpt()
	applyHud()
end

-- ===================== pages =====================
local pageName = "skins"
local pages = { fx = fxPage, boost = boostPage, display = dispPage, world = worldPage, camera = camPage, settings = setFrame }
local PAGE_MSG = {
	skins = "Pick a knife type, click a knife. It shows in your hands with its own animations. Only you see it.",
	fx = "Knife spin and tracers on your own throws and swings. Only you see them.",
	boost = "More FPS: lower graphics, higher FPS cap, lighter world. Only your own screen changes.",
	display = "Display options. Only your own screen changes.",
	world = "Pick a look for the lobby and maps. Only your own screen changes.",
	camera = "Motion blur, field of view and knife position. Only your own screen changes.",
	settings = "Hotkeys, window size and accent color.",
}
local function paintTabs()
	for name, b in pairs(tabBtns) do
		local on = (name == pageName)
		b:SetAttribute("Active", on)
		b.BackgroundColor3 = on and C.accent or C.white
		b.BackgroundTransparency = on and 0.8 or 1
		b.TextColor3 = on and C.text or C.dim
		local mk = b:FindFirstChild("Bar")
		if mk then mk.Visible = on; mk.BackgroundColor3 = C.accent end
	end
end
local function setPage(name)
	pageName = name
	local skinsPage = (name == "skins")
	left.frame.Visible = skinsPage; right.frame.Visible = skinsPage; previewPanel.Visible = skinsPage
	for n, f in pairs(pages) do f.Visible = (n == name) end
	resetAll.Visible = skinsPage
	resetFx.Visible = not skinsPage and name ~= "settings"
	paintTabs()
	setStatus(PAGE_MSG[name] or "")
end
for name, b in pairs(tabBtns) do b.MouseButton1Click:Connect(function() setPage(name) end) end

function applyAccent()
	C.accent = accentOf(ui.accent)
	for _, o in ipairs(accentObjs) do pcall(function() o[1][o[2]] = C.accent end) end
	for _, f in ipairs(repaints) do f() end
	paintArms(false); paintCursor(false)
	refreshTypes(); refreshKnives(); paintTabs()
end
resetFx.MouseButton1Click:Connect(function()
	defaults(); for _, f in ipairs(repaints) do f() end; save()
	setStatus("Effects are back to their defaults.", "good")
end)

-- the type list shows which knife is yours: redraw it when that changes
do
	local acc, last = 0, nil
	keep(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then return end
		acc = 0
		if myKnifeId ~= last then last = myKnifeId; guarded("types", refreshTypes); if showPreview then showPreview(nil) end end
	end))
end

-- help card (shown the first time, and with the ? button)
local help = make("Frame", {
	Size = UDim2.fromOffset(540, 400), Position = UDim2.new(0.5, -270, 0.5, -200), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.04, BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, win)
corner(help, 14)
accentObjs[#accentObjs + 1] = { stroke(help, 0.2, C.accent, 1.5), "Color" }
local function helpString()
	return "How it works\n\n"
		.. "1.  Pick a knife type on the left, then click a knife. It shows in your hands with that knife's own first-person animations. Click it again, or \"My own knife\", to go back.\n"
		.. "2.  Typing in the search looks through every type. Click the star to favorite a knife; \"fav\" shows only favorites.\n"
		.. "3.  The panel on the right shows the knife and can tint its colors. Shuffle gives you a random knife every round.\n"
		.. "4.  Effects: knife spin, and tracers behind your thrown knives and on your swings. Boost: more FPS. Display: stretched resolution, overlay, self highlight. World: color looks. Camera: motion blur, FOV, knife position. Settings: hotkeys, window size, accent color.\n\n"
		.. "Only you see the knife you pick. Your equipped knife, your character and what other players see are never changed, and nothing is sent to the server.\n\n"
		.. ui.keyMenu .. " hides or shows this window (there is no on-screen tab while it is hidden). " .. ui.keyCursor .. " frees the cursor."
end
local helpText = text(help, helpString(), 13, C.text, UDim2.fromOffset(20, 16), UDim2.new(1, -40, 1, -70))
helpText.ZIndex = 21
helpText.TextYAlignment = Enum.TextYAlignment.Top
local gotIt = button(help, "Got it", UDim2.new(0.5, -50, 1, -46), UDim2.fromOffset(100, 32), true)
gotIt.ZIndex = 21
local function showHelp(on) help.Visible = on end
helpBtn.MouseButton1Click:Connect(function() showHelp(not help.Visible) end)
gotIt.MouseButton1Click:Connect(function() showHelp(false); seenHelp = true; save() end)

hideBtn.MouseButton1Click:Connect(function() setOpen(false) end)
keep(UIS.InputBegan:Connect(function(i, gp)
	if binding then
		if i.UserInputType == Enum.UserInputType.Keyboard then
			if i.KeyCode ~= Enum.KeyCode.Escape then ui[binding] = i.KeyCode.Name; save() end
			binding = nil; paintKeys(); helpText.Text = helpString()
		end
		return
	end
	if gp then return end
	if i.KeyCode == keyOf(ui.keyMenu) then setOpen(not win.Visible)
	elseif i.KeyCode == keyOf(ui.keyCursor) then setFreeCursor(not freeCursor) end
end))

myKnifeId = equippedKnifeId()
do
	local t = (sel and byId[sel] and byId[sel].type) or (myKnifeId and byId[myKnifeId] and byId[myKnifeId].type)
	current = t or types[1]
end
if shuffle.on then rollKnife() end
refreshTypes(); refreshKnives(); setPage("skins")
if seenHelp then
	setStatus(PAGE_MSG.skins)
else
	showHelp(true)
end

local function unload()
	if not alive then return end
	alive = false
	pcall(clearThrows)   -- your thrown knives show as the game made them again
	for _, name in ipairs({ "KDMenuMirror", "KDMenuThrows", "KDMenuTint", "KDMenuCursor", "KDMenuSelf", "KDMenuBlur", "KDMenuStretchB", "KDMenuStretchA" }) do
		pcall(function() RunService:UnbindFromRenderStep(name) end)
	end
	pcall(dropRig)   -- removes our view model and makes the game's own one visible again
	pcall(function() if shHl then shHl:Destroy() end end)
	pcall(function() if mbBlur then mbBlur:Destroy() end end)
	pcall(restoreOpt)
	pcall(unFov)
	for _, i in ipairs({ wGrade, wBloom, wRays }) do pcall(function() i:Destroy() end) end
	st.on = false; pcall(unstretch)
	freeCursor = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	_G.KnifeDuelsMenu = nil
end
closeBtn.MouseButton1Click:Connect(unload)

_G.KnifeDuelsMenu = {
	unload = unload, setKnife = function(id) sel = id end, knife = function() return sel end, mirror = mirror,
	spin = spin, tr = tr, st = st, hud = hud, sh = sh, wd = wd, mb = mb, vm = vm, opt = opt, tn = tn, ui = ui, fav = fav, shuffle = shuffle,
	applyOpt = applyOpt, applyWorld = applyWorld,
}
print(("[KnifeMenu] ready: %d knife types, %d knives"):format(#types, (function() local n = 0 for _ in pairs(byId) do n += 1 end return n end)()))
