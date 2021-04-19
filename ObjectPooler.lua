local RELEASE_TIMEOUT = 30

local RESTORATION = true
local RESTORE_DESCENDANTS = true
local RESTORE_PROPERTIES = 
{
	["ParticleEmitter"] = 	{["Enabled"] = true},
	["Trail"] = 			{["Enabled"] = true},
	["Decal"] = 			{["Transparency"] = true},
	["BasePart"] = 			{["Transparency"] = true, ["Size"] = true},
}

local CurrentPool = {}
local VariableMapping = {}

local function createNewObject(objectReference)
	local newObject = {
		secured = false,
		object = objectReference:Clone()
	}

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
				wait(delayTime)
				if self.secured == releaseTime then
					self:Release()
				end
			end)()
		else
			self.object.Parent = nil
			self:Restore()
            self.secured = false
        end
	end
	
	return newObject
end

local ObjectPooler = {}
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

function ObjectPooler:GetObject(objectReference)
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

	return ObjectPooler:AddToPool(objectReference)
end

return ObjectPooler