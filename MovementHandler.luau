--Roblox: Jayplayz943
--Discord: Jaythepro9
--HiddenDevs Application
--play with shiftlock its easier

-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionsService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
-----------------------------
-- VARIABLES --
-----------------------------
local MovementService = {}

local modules = ReplicatedStorage:WaitForChild("Modules")
local configs = modules:WaitForChild("Configs")
local gameObjects = modules:WaitForChild("GameObjects")
local movmentSounds = SoundService:WaitForChild("Movement")

local Signal = require(modules.Signal)

local movementConfig = require(configs:WaitForChild("MovementConfig"))
local movementContext = script.Parent.Parent:WaitForChild("MovementContext")

local VFXPlayer = require(modules:WaitForChild("VFXPlayer"))

local JumpPad = require(gameObjects.JumpPadClass)
local LedgeClass = require(gameObjects.LedgeClass)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:WaitForChild("Animator") :: Animator
local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

local VFX = script:WaitForChild("VFX")

local rolls = {
	animator:LoadAnimation(script.Rolls.Roll),
	animator:LoadAnimation(script.Rolls.Roll2)
}

local land = animator:LoadAnimation(script.Land)

--store it similiar to the one above, and link the direction to the index
local wallJumpLeft = animator:LoadAnimation(script.WallJumpLeft)
wallJumpLeft.Looped = false
local wallJumpRight = animator:LoadAnimation(script.WallJumpRight)
local camera = workspace.CurrentCamera

local horizontalVelocity = Instance.new("LinearVelocity")
horizontalVelocity.Parent = rootPart
horizontalVelocity.Attachment0 = rootPart:WaitForChild("RootAttachment")
horizontalVelocity.Visible = true
horizontalVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
horizontalVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
horizontalVelocity.MaxAxesForce = Vector3.new(60000, 0, 60000)

--local collider = Instance.new("Part")
--collider.Shape = Enum.PartType.Ball
--collider.Size = Vector3.one * 6
--collider.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
--collider.Parent = rootPart
--collider.CollisionGroup = "WallCollider"
--collider.CFrame = rootPart.CFrame
--collider.Transparency = 0.90
--local weld = Instance.new("WeldConstraint")
--weld.Part0 = rootPart
--weld.Part1 = collider
--weld.Parent = collider
--signals

local jumpSignal = Signal.new()

local jumpPadTag = "JumpPad"
--runTime

local isSliding = false
local canSlide = true

local currentVelocity = Vector3.zero

local jumpCount = 0
local jumpResetVarCooldown = 0.1
local lastJumpTick = tick()

local wallJumpCount = 0

local canWallRun = true
local previousNormal = nil
local lastWallRunTick = tick()
local sameWallCooldown = 1.67
local previousRunWall = nil
local isWallRunning = false

local stepTimer = 0
local stepFoot = 1 -- 1 = right, 2 = left
local rightFoot = character["Right Leg"]:WaitForChild("RightFootAttachment")
local leftFoot = character["Left Leg"]:WaitForChild("LeftFootAttachment")
local footAttachments = { rightFoot, leftFoot }

local airTime = 0

local ignorers = {}

local previousImpulseTick = tick()

local continiousParticles = {}
--

_G.ImpulseCooldown = 0.25 --s prevent piling up impulses to get massive speed
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function setupCharacter(char)
	character = char -- get character
	humanoid = character:WaitForChild("Humanoid") --get humanoid
	animator = humanoid:WaitForChild("Animator") -- get animator
	rootPart = character:WaitForChild("HumanoidRootPart")

	rightFoot = character["Right Leg"]:WaitForChild("RightFootAttachment") -- atts for vfx
	leftFoot = character["Left Leg"]:WaitForChild("LeftFootAttachment")  -- atts for vfx
	footAttachments = { rightFoot, leftFoot } -- save them in table so its easier to get

	if horizontalVelocity then -- remove old
		horizontalVelocity:Destroy()
	end

	horizontalVelocity = Instance.new("LinearVelocity") -- new linearVelocity
	horizontalVelocity.Parent = rootPart -- parent it to root
	horizontalVelocity.Attachment0 = rootPart:WaitForChild("RootAttachment") -- wait for att0
	horizontalVelocity.Visible = true -- visible for debugging
	horizontalVelocity.RelativeTo = Enum.ActuatorRelativeTo.World -- have the axis be relative to the world
	horizontalVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis -- make the force limits per axis
	horizontalVelocity.MaxAxesForce = Vector3.new(60000, 0, 60000) -- void y axis force, let roblox handle that 

--save anims
	rolls = {
		animator:LoadAnimation(script.Rolls.Roll), 
		animator:LoadAnimation(script.Rolls.Roll2)
	}

	land = animator:LoadAnimation(script.Land)

	wallJumpLeft = animator:LoadAnimation(script.WallJumpLeft)
	wallJumpLeft.Looped = false

	wallJumpRight = animator:LoadAnimation(script.WallJumpRight)

--reset variables
	currentVelocity = Vector3.zero
	jumpCount = 0
	wallJumpCount = 0
	airTime = 0
	isWallRunning = false
	isSliding = false
end

local function isGrounded()
	local state = humanoid:GetState() -- get state
	return state == Enum.HumanoidStateType.Landed or humanoid.FloorMaterial ~= Enum.Material.Air -- landed isnt gaurenteed so check if the ground is air or not
end

local function resetGroundVariables()
	
	if tick() - lastJumpTick < jumpResetVarCooldown then return end
	-- if cooldown finished then reset
	
	jumpCount = 0
	wallJumpCount = 0
	airTime = 0
end

local function stopContinousParticles(key) -- old not needed to be read
	--if continiousParticles[key] then
	--	-- VFXPart destruction cascades to all cloned emitters parented under it
	--	continiousParticles[key].VFXPart:Destroy()
	--	continiousParticles[key] = nil
	--end
end



local function playVFX(folder: Folder, cF: CFrame | Part, emit, continious, key) -- old not needed to be read
	--if continiousParticles[key] then
	--	continiousParticles[key].VFXPart.CFrame = typeof(cF) == "CFrame" and cF or cF.CFrame
	--	return
	--end



	--local resolvedCF = typeof(cF) == "CFrame" and cF or (cF:IsA("BasePart") and cF.CFrame or CFrame.new())

	--local part = Instance.new("Part")
	--part.Anchored = true
	--part.CanCollide = false
	--part.Transparency = 1
	--part.CanTouch = false
	--part.CanQuery = false
	--part.Shape = Enum.PartType.Ball
	--part.Color = Color3.new(0.626535, 1, 0.582193)
	--part.Size = Vector3.one
	--part.CFrame = resolvedCF
	--part.Parent = rootPart
	--part.Name = "VFXPart"

	--local att = Instance.new("Attachment")
	--att.Parent = part

	--local particles = folder:GetChildren()

	--if continious then
	--	continiousParticles[key] = {
	--		VFXPart = part,
	--		Particles = {}
	--	}
	--end

	--for i, child in ipairs(particles) do
	--	local pEmit: ParticleEmitter = child:Clone()
	--	pEmit.Parent = att

	--	if continious then
	--		pEmit.Enabled = true
	--		pEmit:Emit(pEmit.Rate /1)
	--		table.insert(continiousParticles[key].Particles, pEmit)
	--	else
	--		pEmit:Emit(emit)
	--		task.delay(pEmit.Lifetime.Max, function()
	--			pEmit:Destroy()
	--			if i == #particles then part:Destroy() end
	--		end)
	--	end
	--end
	VFXPlayer:playVFXClient(folder, cF, emit, continious, key, true)
end



local function isRagdolled() -- check if the player has the ragdoll tag or not
	local tags = player:GetTags()
	for _, tag in ipairs(tags) do -- look through all tags
		if tag == "Ragdoll" then
			return true
		end
	end
	return false
end


local function setUpJumpPads() -- setup client jumppads, this is being converted to be server authorative as this was just for testing purposes
	for _, jumpPad in ipairs(CollectionsService:GetTagged(jumpPadTag)) do
		local pad = JumpPad.new(jumpPad)
	end

	CollectionsService:GetInstanceAddedSignal(jumpPadTag):Connect(function(instance)

	end)

	CollectionsService:GetInstanceRemovedSignal(jumpPadTag):Connect(function(instance)
		-- just make another pad i just never ended up doing it
	end)
end

local function isRaycastIgnored(instance)
	local tags = instance:GetTags()
	
	for _, tag in ipairs(tags) do
		if not (tag == "IgnoreWallCollider") then continue end -- ensure invisble walls dont mess with the functions that prevent
		-- sticking to walls
		
		return true
	end
	
	
end

local function getWallNormal()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local origin = rootPart.Position
	local directions = { -- shoot in multiple directions to increase the chance of a hit
		rootPart.CFrame.LookVector, -- 1st
		rootPart.CFrame.RightVector, --2nd
		-rootPart.CFrame.RightVector, --3rd
	}

	for i, direction in ipairs(directions) do
		

		
		local result = workspace:Raycast(origin, direction * movementConfig.WallJumping.WallThreshold, raycastParams) :: Instance

		if result and not isRaycastIgnored(result.Instance) then return result.Normal, i end -- check if the raycast hit a valid wall, return direction, and normal of the wall
	end

	return nil
end

local function checkImpulse() -- this is quite and old piece of code so I don't really remember to much
	--but im pretty sure I scrapped the whole impulse thing, and plus global variable :o
	if tick() - previousImpulseTick < _G.ImpulseCooldown then return false end
	previousImpulseTick = tick()
	return true
end

local function setupColliderIgnores() -- sets up the wall collide ignorers
	--pretty self explanotory
	--checks for instances tagged with "IgnoreWallCollider"

	for _, instance in ipairs(CollectionsService:GetTagged("IgnoreWallCollider")) do

		if instance:IsA("BasePart") or instance:IsA("MeshPart") then
			--instance.CollisionGroup = "IgnoreCollider"
			table.insert(ignorers, instance)
		end
	end

	CollectionsService:GetInstanceAddedSignal("IgnoreWallCollider"):Connect(function(part)
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			--part.CollisionGroup = "IgnoreCollider"
			table.insert(ignorers, part)
		end
	end)

	CollectionsService:GetInstanceRemovedSignal("IgnoreWallCollider"):Connect(function(part)
		local index = table.find(ignorers, part)
		table.remove(ignorers, index)
		print(ignorers[index])
	end)

end

-- important to prevent clinging to walls
local function projectVelocityOnWall(velocity)
	if velocity.Magnitude < 0.05 then -- player is not moving basically, s
		return velocity
	end

	local origin = rootPart.Position
	local dir = velocity.Unit * 3

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character, ignorers}

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.CollisionGroup = "WallCollider"
	-- offsets (left/right relative to character)
	local right = rootPart.CFrame.RightVector

	local offsets = { -- again helps imporve the chances of a hit, 
		Vector3.zero,
		right * 2,
		-right * 2,
	}

	local finalVelocity = velocity -- if nothing hits, then just return orgingla

	for _, offset in ipairs(offsets) do
		local rayOrigin = origin + offset -- add offset

		local ray = workspace:Raycast(rayOrigin, dir, params)
		if ray then
			local normal = ray.Normal

			local intoWall = finalVelocity:Dot(normal) -- get how much its going into the wall

			if intoWall < 0 then -- if its greater than zero we'd be adding velocity, so we dont do that(plus its not facing the wall)
				finalVelocity -= normal * intoWall -- we remove teh velocity towards the wall so they dont cling
			end
		end
	end

	return finalVelocity
end

--essentially the same thing as the previous function, but the previous one was too leniant for wall runs, and we still ended
--up clinging
local function projectVelocityOnWallRunWalls(velocity)
	if velocity.Magnitude < 0.05 then
		return velocity
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local origin = rootPart.Position
	local dir = velocity.Unit * 2
	local right = rootPart.CFrame.RightVector

	local offsets = {
		Vector3.zero,
		right * 2,
		-right * 2,
	}

	local finalVelocity = velocity

	for _, offset in ipairs(offsets) do
		local ray = workspace:Raycast(origin + offset, dir, params)
		if ray and ray.Instance:HasTag("WallRun") then
			-- Only block if this specific wall is still on cooldown

			--added to prevent clinging to walls
			if offset == Vector3.zero then
				local normal = ray.Normal
				local intoWall = finalVelocity:Dot(normal)
				if intoWall < 0 then
					finalVelocity -= normal * 2 * intoWall -- multiplying it by two just overcompensates to ensure it is not clingin
				end
				return finalVelocity
			end
			--
			local isOnCooldown = ray.Instance == previousRunWall
				and tick() - lastWallRunTick < sameWallCooldown

			if offset == Vector3.zero then
				-- Only bounce off center ray if this is the wall we just left,
				-- otherwise we'd push the player away from a new wall they're trying to grab
				if isOnCooldown then
					local normal = ray.Normal
					local intoWall = finalVelocity:Dot(normal)
					if intoWall < 0 then
						finalVelocity -= normal * 2 * intoWall
					end
				end
				return finalVelocity
			end

			if isOnCooldown then
				local normal = ray.Normal
				local intoWall = finalVelocity:Dot(normal)
				if intoWall < 0 then
					finalVelocity -= normal * intoWall
				end
			end
		end
	end

	return finalVelocity
end

local function playFootstep(delta)
	local speed = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Magnitude -- get horizontal speed
	if speed < 15 then
		stepTimer = 0
		return
	end

	if not isGrounded() and not isWallRunning then return end

	if horizontalVelocity.VectorVelocity.Magnitude < .5 then return end
	local stepInterval = math.clamp(math.sqrt(2/rootPart.AssemblyLinearVelocity.Magnitude), 0.1, 2) -- get how often the steps should come
	stepTimer += delta

	if stepTimer >= stepInterval then -- if elapsed is greater or equal to how long between each step then play
		stepTimer = 0
		local foot = footAttachments[stepFoot] -- get wich foot the effect should play from
		local footCF = foot.WorldCFrame

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude

		local ray
		if isWallRunning then -- if wall running hten position it with the wall
			ray = workspace:Raycast(footCF.Position + previousNormal, -previousNormal * 2, params) -- two studs backwards to get hit
		else
			ray = workspace:Raycast(footCF.Position + Vector3.yAxis * 2, Vector3.new(0, -3, 0), params) -- otherwise just normal
		end

		local moveDir = -Vector3.new(horizontalVelocity.VectorVelocity.X, 0, horizontalVelocity.VectorVelocity.Z).Unit

		local spawnCF
		if ray then
			if isWallRunning then
				local wallUp = previousNormal --local up direction for it
				local wallForward = (moveDir - moveDir:Dot(wallUp) * wallUp).Unit -- remove the perpendicular part so we get it along the wall
				spawnCF = CFrame.fromMatrix(ray.Position, wallForward:Cross(wallUp), wallUp, -wallForward) -- at hit, get the x axis with the cross product, set y up to the wall,  set z opposite to the forward
			else
				spawnCF = CFrame.lookAt(ray.Position, ray.Position + moveDir) -- else its just place at the floor
			end
		else
			spawnCF = CFrame.lookAt(footCF.Position, footCF.Position + moveDir)
		end

		playVFX(VFX.Run, spawnCF)
		stepFoot = stepFoot == 1 and 2 or 1 -- alternate foot
	end
end

local function runningCalculations(delta)

	local direction = humanoid.MoveDirection
	local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)

	if direction.Magnitude > 0.1 then -- not nmoving

		horizontalVelocity = horizontalVelocity:Lerp( -- lerp speed to max 
			direction * movementConfig.Running.MaxSpeed,
			movementConfig.Running.AccelRate * delta
		)

	else

		horizontalVelocity = horizontalVelocity:Lerp( -- lerp to stop
			Vector3.zero,
			movementConfig.Running.DecelRate * delta
		)

	end

	humanoid.WalkSpeed = 0 -- void walk  speed

	currentVelocity = horizontalVelocity

	return currentVelocity
end

local function wallJump(normal, i)
	if not normal then return end
	if wallJumpCount >= movementConfig.WallJumping.MaxWallJumps then return end

	local cameraLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit

	local direction = (normal + cameraLook * movementConfig.WallJumping.CameraBias).Unit -- multiply by camerabias to 
	--control how much affect the camera orientation has on the jump
	--if direction:Dot(cameraLook) < .5 then
	--	direction = normal + cameraLook * movementConfig.WallJumping.CameraBias
	--end

	local jumpDirection = direction * movementConfig.WallJumping.Force

	local jumpHorizontal = Vector3.new(jumpDirection.X, 0, jumpDirection.Z) -- void y
	local jumpVertical = Vector3.yAxis * movementConfig.WallJumping.Force * 1.2 -- seperate y

	rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, jumpVertical.Y, rootPart.AssemblyLinearVelocity.Z)
	--set linear
	--the old impulsecooldown, was because instead of setting we used the impulse() function by roblox, which had bad side effects
	currentVelocity = currentVelocity * 0.3 + jumpHorizontal -- feels better
	wallJumpCount +=1 -- increment
	jumpCount = math.max(0, jumpCount-1) -- return one jump back

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	playVFX(VFX.Jump, CFrame.lookAt(rootPart.Position - Vector3.yAxis *2, rootPart.Position +  normal * vector.one, Vector3.yAxis*1)) -- position below feet
	if i == 1 then -- forwards

	elseif i == 2 then -- right
		wallJumpRight:Play()

	elseif i == 3 then -- left
		wallJumpLeft:Play()
	end
	
	--wall jump variations above
end

local function getWallDirection(forwardV, normal)
	local dir = (forwardV - forwardV:Dot(normal)*normal) -- remove perpendicular to the wall
	return dir.Unit -- normalize
end


local function startWallRun(rayResult: RaycastResult, i)
	local function dirCalc()
		local speed = horizontalVelocity.VectorVelocity.Magnitude * movementConfig.WallRunning.WallRunSpeedFactor
		local runDir = getWallDirection(rootPart.CFrame.LookVector, rayResult.Normal) -- get the run directon
		horizontalVelocity.VectorVelocity = Vector3.new(runDir.X * speed, movementConfig.WallRunning.FallSpeed/speed, runDir.Z * speed)
		horizontalVelocity.MaxAxesForce = Vector3.one * 60000
		-- give horizontal velocity y axis control( yeah ik the name doesnt make sense anymore)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}


	if i then -- i is the direction based on the table
		if i == 1 then
			player:SetAttribute("WallRunning", "Right")
			local rightAttCF =  character["Right Arm"].RightGripAttachment.WorldCFrame -- play on right arm
			local origin = rayResult.Normal * 2 + rightAttCF.Position -- all of thse or just positioning vfx
			local dir = -rayResult.Normal * 3
			local ray = workspace:Raycast(origin, dir, params)
			if ray then
				local newCF = CFrame.new(ray.Position)

				playVFX(VFX.WallRun, newCF, 0, true, "WallRun"..player.UserId) -- same thing but play on wall
			else
				--print("Raycast failed for right wall run")
			end

		elseif i == 2 then -- same but left arm
			player:SetAttribute("WallRunning", "Left")

			local leftAttCF =  character["Left Arm"].LeftGripAttachment.WorldCFrame
			local origin = rayResult.Normal * 2 + leftAttCF.Position
			local dir = -rayResult.Normal * 3
			local ray = workspace:Raycast(origin, dir, params)
			if ray then
				local newCF = CFrame.new(ray.Position)

				playVFX(VFX.WallRun, newCF, 0, true, "WallRun"..player.UserId)
			else
				--	print("Raycast failed for left wall run")
			end

		else
			player:SetAttribute("WallRunning", "Unknown")
		end
	end

	if rayResult then
		previousNormal = rayResult.Normal -- set previous normal for other calcs
	end

	if isWallRunning then
		dirCalc() -- calculate
		return
	end

	isWallRunning = true -- first time we should calc too

	dirCalc()
end

local function stopWallRun(normal)

	if not isWallRunning then return end -- if not then dont

	player:SetAttribute("WallRunning", nil) -- set attri 

	lastWallRunTick = tick() -- prevent jumping off and recconected to run forever

	horizontalVelocity.MaxAxesForce = Vector3.new(60000, 0, 60000) -- void y again
	--task.delay(0.16, function() isWallRunning = false end) -- idk it feels a little smoother
	isWallRunning = false
	if not normal then return end

	--if continiousParticles["WallRun"] then	
	--	for _, vfx in continiousParticles["WallRun"].Particles do
	--		vfx:Destroy()
	--	end

	--	continiousParticles["WallRun"].VFXPart:Destroy()
	--	continiousParticles["WallRun"] = nil
	--end

	VFXPlayer:stopContinuousVFX("WallRun"..player.UserId, true) -- stop vfx
	wallJump(normal) -- wall jump off feels better
	wallJumpCount = math.max(0, wallJumpCount-1) -- wall jump counts
end

local function wallRunCalc(dt)

	--if humanoid.MoveDirection.Magnitude < 0.1 then stopWallRun() return end
	if not canWallRun then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local origin = rootPart.Position
	local raysDirs = { -- get both left and right
		rootPart.CFrame.RightVector,
		-rootPart.CFrame.RightVector,
		--horizontalVelocity.VectorVelocity.Unit,
	}

	local rayResult = nil :: RaycastResult

	local side
	for i, dir in ipairs(raysDirs) do -- 1 right, 2 left
		local r = workspace:Raycast(origin, dir * movementConfig.WallRunning.WallThreshold, params)
		if r then rayResult = r side = i break end
		-- we get which side, i represents that, its 1 == right 2 == left
	end

	if not rayResult then stopWallRun(previousNormal) return end

	if rayResult.Instance == previousRunWall and tick() - lastWallRunTick < sameWallCooldown and not isWallRunning then -- fails to meet conditions
		return 
	end

	previousRunWall = rayResult.Instance

	if not rayResult.Instance:HasTag("WallRun") then stopWallRun(previousNormal) return end -- if not wlalrun then dont


	startWallRun(rayResult, side) -- start!

end

local function jump()
	
	if isWallRunning then stopWallRun(previousNormal) return end -- if jump then wall run stops and jumps
	
	if isRagdolled() then return end -- cant while ragdolled
	
	local normal, i = getWallNormal() -- gert the side of the jump, for wall jumping
	if normal and not isGrounded() and wallJumpCount < movementConfig.WallJumping.MaxWallJumps then
		wallJump(normal, i) -- if normal then walljump
		return
	end

	if jumpCount >= movementConfig.Jumping.MaxJumps then return end

	jumpCount += 1 -- increment
	lastJumpTick = tick()
	local vel = horizontalVelocity.VectorVelocity

	rootPart.AssemblyLinearVelocity = Vector3.new(
		rootPart.AssemblyLinearVelocity.X,
		movementConfig.Jumping.Force, -- override Y here
		rootPart.AssemblyLinearVelocity.Z
	)
	--set linear velocity, let roblox handle the grafity
	playVFX(VFX.Jump, CFrame.new(rootPart.Position - Vector3.yAxis *2))
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- set the humanoid state to jumping
	--old me hadnt thought of state handlers yet :(
end

local function sinkKeys(bool)
	local ContextActionService = game:GetService("ContextActionService")
	if bool then -- sink wasd, doesnt work for mobile forgot
		ContextActionService:BindAction("W", function() end, false, Enum.KeyCode.W)
		ContextActionService:BindAction("A", function() end, false, Enum.KeyCode.A)
		ContextActionService:BindAction("S", function() end, false, Enum.KeyCode.S)
		ContextActionService:BindAction("D", function() end, false, Enum.KeyCode.D)
	else -- unbind; unsiks then
		ContextActionService:UnbindAction("W")
		ContextActionService:UnbindAction("A")
		ContextActionService:UnbindAction("S")
		ContextActionService:UnbindAction("D")
	end
end

local function ifMobile() -- 
	
	local isMobile = UserInputService.TouchEnabled
	if not isMobile then return end --if touch is enabled then they are mobile
	--tho doesn't consider touch screen laptops flaw
	
	local playerGui = player:WaitForChild("PlayerGui")
	local movementGui = playerGui:WaitForChild("MovementGui")
	local MobileCanvas = movementGui.MobileCanvas :: CanvasGroup
	
	MobileCanvas.Visible = true
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function MovementService:Init()

	setupCharacter(player.Character or player.CharacterAdded:Wait()) -- on join set vars

	player.CharacterAdded:Connect(function(char)
		setupCharacter(char) -- die? then set vars
	end)

	movementContext.Jump.Pressed:Connect(jump) -- conect the jump context

	setupColliderIgnores() -- ignore

	humanoid.JumpHeight = 0 -- void 

	ifMobile() -- useless 
end

function MovementService:Start()
	RunService.RenderStepped:Connect(function(delta)
		
		
		if isRagdolled() then -- if ragdoll then sink keys so they cant move
			sinkKeys(true)
		else
			sinkKeys(false)
		end
		player:SetAttribute("Jumps", movementConfig.Jumping.MaxJumps - jumpCount) -- set the jumps attribute
		
		wallRunCalc() -- calcs for wall run already explained
		local velocity = runningCalculations(delta)

		if isWallRunning and previousNormal then
			local intoWall = velocity:Dot(-previousNormal) -- check if they are facing relative to towrads wall
			if intoWall > 0 then 
				velocity = velocity + previousNormal * intoWall -- just seems to keep them away from clinging
			end
		end

		if not isWallRunning then
			velocity = projectVelocityOnWall(velocity) -- stop clinging

			velocity = projectVelocityOnWallRunWalls(velocity) -- stops clinging
			--now that i look uh this is redundant
		end

		currentVelocity = velocity
		--rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.as, rootPart.AssemblyLinearVelocity.Y, 0)
		horizontalVelocity.VectorVelocity = Vector3.new(currentVelocity.X, horizontalVelocity.VectorVelocity.Y, currentVelocity.Z) -- set horizontal vel
		playFootstep(delta) -- footstep fx

		if isGrounded() then
			if airTime > 1 then
				rolls[math.random(1, #rolls)]:Play()
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = {character}
				params.FilterType = Enum.RaycastFilterType.Exclude
				local ray = workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), params)
				if ray then
					local normal = ray.Normal
					local pos = ray.Position
					local cf = CFrame.new(pos)
					local hit = ray.Instance
					--local color = ColorSequence.new({
					--	ColorSequenceKeypoint.new(0, hit.Color),
					--	ColorSequenceKeypoint.new(1, hit.Color)
					--})
					--	or ColorSequence.new(
					--		{
					--			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
					--			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
					--		}
					--	)
					--VFX.Land.Realistic.Color = color

					playVFX(VFX.Land, cf) -- positions it on the floor
					
					--for landing effects
				end
			end

			resetGroundVariables() -- grounded? then reset related variables
		else
			airTime += delta -- increase elapsed air
		end

		if not player:GetAttribute("ShiftLock") then 
			local vel = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)

			local look
			if vel.Magnitude > 0.05 then
				look = vel.Unit
			else
				look = rootPart.CFrame.LookVector
			end

			rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + look) -- follow along with the camera look
		end

	end)
end

-----------------------------
-- MAIN --
-----------------------------
return MovementService
