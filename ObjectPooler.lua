local RELEASE_TIMEOUT = 30				-- How long until the object gets automatically released if not already done

local AUTO_SIZE = true					-- Toggle if you want the pool to grow if it can't find an object. If false, CreateObjectPool() must be initialized
local RESTORATION = false				-- Toggle if you want pooled object properties to be restored back to the original states
local RESTORE_DESCENDANTS = true		-- Toggle if you want pooled object descendant properties to be restored back to the original states
local RESTORE_PROPERTIES = 				-- Specify which properties you would like to be restored
{
	["BasePart"] = 			{["Transparency"] = true, ["Size"] = true}, -- Parts, MeshParts, Unions
		
	["ParticleEmitter"] = 	{["Enabled"] = true},
	["Trail"] = 			{["Enabled"] = true},
	["Decal"] = 			{["Transparency"] = true},
		
	["ImageButton"] =		{["ImageTransparency"] = true, ["Size"] = true},
	["TextButton"] =		{["BackgroundTransparency"] = true, ["Size"] = true},
	["TextLabel"] =			{["BackgroundTransparency"] = true, ["Size"] = true},
	["ImageLabel"] =		{["ImageTransparency"] = true, ["Size"] = true},
	["Frame"] =				{["ImageTransparency"] = true, ["Size"] = true},
}

--[[
**************************************** Pooler Functions ****************************************

	 GetObject(objectReference [Instance || String]
		* Takes an instance or string (if you set a variable) and attempts to pull an
		  object from it's table. If it cannot find one, it will call 'AddToPool' to
		  create a new object.
		  
		ex. ObjectPooler:GetObject(game.ReplicatedStorage.Bullet)
		
		
	 AddToPool(objectReference [Instance])
	 	* Takes an instance and creates/adds it to a pooled object table for later use.
	 	
		ex. ObjectPooler:AddToPool(game.ReplicatedStorage.Bullet)
		
		
	 SetVariable(variableName [String], objectReference [Instance])
		* Takes a string to set as the object's variable, and an instance to map it to.
		  This can be used to shorten code to use single strings instead of the entire path.
		  
		ex. ObjectPooler:SetVariable("Bullet", game.ReplicatedStorage.Bullet)
		
***************************************************************************************************



**************************************** Wrapped Functions ****************************************
	 obj:Secure()
		* Secures the object preventing it from being selected from the pool. This is done automatically 
		  by the pooler, but can used carefully to secure an object for later use
		
		
	 obj:Release(delayTime [number])
		* Takes an OPTIONAL delay time and releases the object which allows it to be selected from the pool again.
		  
		ex. obj:Release(3)
		
	 obj:Restore()
		* Depending on your settings it will restore the object's properties back to before it was secured. This is done
		  automatically by the pooler if you have the setting enabled.
***************************************************************************************************



********************************************* Examples ********************************************
	1. This example will create a bullet, fire it, and release it for use again after 3 seconds
	
		local ObjectPooler = require(game.ReplicatedStorage.ObjectPooler)
		
		local bullet = ObjectPooler:GetObject(game.ReplicatedStorage.Bullet)
		bullet.object.CFrame = CFrame.new(0,5,0)
		bullet.object.Velocity = Vector3.new(250,0,0)
		bullet:Release(3)
		
		
	2. This example will create a bullet, fire it, and wait until it hits something before being released or
		if it doesn't hit anything, release it after 3 seconds
		
		local ObjectPooler = require(game.ReplicatedStorage.ObjectPooler)
		ObjectPooler:SetVariable("bullet", game.ReplicatedStorage.Bullet)
		
		local bullet = ObjectPooler:GetObject("bullet")
		bullet.object.CFrame = CFrame.new(0,5,0)
		bullet.object.Velocity = Vector3.new(250,0,0)
		bullet:Release(3)
		
		local touchConnection = bullet.Touched:Connect(function(hitObject)
			local character = hitObject.Parent
			if character:FindFirstChild("Humanoid") then
				touchConnection:Disconnect()
				bullet:Release()
			end
		end)
		
***************************************************************************************************
]]

local RunService = game:GetService("RunService")
local FastWait = require(script.FastWait)

local CurrentPool = {}
local VariableMapping = {}

local IsStudio = RunService:IsStudio()
local FarCFrame = CFrame.new(10e5,0,0)

local function createNewObject(objectReference)
	local newObject = {
		secured = false,
		connections = {},
		object = objectReference:Clone()
	}
	
	newObject.object.CFrame = FarCFrame
	newObject.object.Parent = workspace.Folder

	if RESTORATION then
		newObject.props = {}

		local className = newObject.object.ClassName
		if newObject.object:IsA("BasePart") then
			className = "BasePart"
		end

		if RESTORE_PROPERTIES[className] then
			for property,_ in pairs(RESTORE_PROPERTIES[className]) do
				newObject.props[property] = newObject.object[property]
			end
		end

		if RESTORE_DESCENDANTS then
			newObject.decProps = {}

			for _,obj in pairs(newObject.object:GetDescendants()) do
				newObject.decProps[obj] = {}

				local className = obj.ClassName
				if obj:IsA("BasePart") then
					className = "BasePart"
				end

				if RESTORE_PROPERTIES[className] then
					for property,_ in pairs(RESTORE_PROPERTIES[className]) do
						newObject.decProps[obj][property] = obj[property]
					end
				end
			end
		end
	end
	
	
	function newObject:Secure()
		self.secured = tick() + RELEASE_TIMEOUT
	end

	function newObject:Restore()
		if RESTORATION then
			if self.props then
				for property,value in pairs(self.props) do
					self.object[property] = value
				end
			end

			if RESTORE_DESCENDANTS then
				for _,obj in pairs(self.object:GetDescendants()) do
					if self.decProps[obj] then
						for property,value in pairs(self.decProps[obj]) do
							obj[property] = value
						end
					end
				end
			end
		end
	end
	
	function newObject:Release(delayTime)
		if delayTime then
			local releaseTime = tick() + delayTime
			self.secured = releaseTime
			
			coroutine.wrap(function()
				if IsStudio and not RunService:IsRunning() then
					wait(delayTime)
				else
					FastWait(delayTime)
				end
				
				if self.secured == releaseTime then
					self:Release()
				end
			end)()
		else
			if #newObject.connections > 0 then
				for _,connection in pairs(newObject.connections) do
					connection:Disconnect()
				end
			end
			
			self.object.CFrame = FarCFrame
			self:Restore()
            self.secured = false
        end
	end
	
	return newObject
end

local ObjectPooler = {}
local function waitForObject(objectReference)
	local pooledObject
	repeat
		RunService.Heartbeat:Wait()
		pooledObject = ObjectPooler:GetObject(objectReference, true)
	until pooledObject
	
	return pooledObject
end

function ObjectPooler:ClearPool(objectReference)
	for _,object in pairs(CurrentPool[objectReference]) do
		object:Destroy()
	end
	
	table.clear(CurrentPool[objectReference])
	
	if typeof(objectReference) == "string" then
		VariableMapping[objectReference] = nil
	end
end

function ObjectPooler:CreatePool(objectReference, amount)
	CurrentPool[objectReference] = CurrentPool[objectReference] or {}
	
	local variableName
	if typeof(objectReference) == "string" then
		variableName = objectReference
		objectReference = VariableMapping[objectReference] 
	end
	
	for i = 1, amount-#CurrentPool[variableName or objectReference] do
		table.insert(CurrentPool[variableName or objectReference], createNewObject(objectReference))
	end
end

function ObjectPooler:AddToPool(objectReference)
	if not CurrentPool[objectReference] then CurrentPool[objectReference] = {} end
	
	local variableName
	if typeof(objectReference) == "string" then
		variableName = objectReference
		objectReference = VariableMapping[objectReference] 
	end
	
	local newObject = createNewObject(objectReference)
	newObject:Secure()

	table.insert(CurrentPool[variableName or objectReference], newObject)
	
	return newObject
end

function ObjectPooler:SetVariable(variableName, objectReference)
	CurrentPool[variableName] = {}
	VariableMapping[variableName] = objectReference
end

function ObjectPooler:GetObject(objectReference, dontWait)
	if CurrentPool[objectReference] then
		for _,obj in pairs(CurrentPool[objectReference]) do
			local securedObject = false
			if not obj.secured then
				securedObject = true
			elseif tick() >= obj.secured then
				securedObject = true
				obj:Restore()
			end

			if securedObject then
				obj:Secure()
				return obj
			end
		end
	end
	
	if AUTO_SIZE then
		return ObjectPooler:AddToPool(objectReference)
	elseif not dontWait then
		return waitForObject(objectReference)
	end
end

return ObjectPooler