--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: Networking module internally
--]]

--[[
[DOCUMENTATION]:
	.CreateEvent()
	.CreateFunction()
	.CreateBindable()
	
	:HookEvent()
	:HookFunction()
	:UnhookEvent()
	:UnhookFunction()
	
	:FireServer()
	:FireClient()
	:FireClients()
	:FireAllClients()
	
	:InvokeServer()
	:InvokeClient()
	
	:BindEvent()
	:BindFunction()
	
	:FireBindable()
	:InvokeBindable()
--]]

--// logic
local Network = {}
Network.Events = {}
Network.Bindables = {}
Network.Enums = {
	['Event'] = 1;
	['Function'] = 2;
}

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// variables
local IsStudio = Services['RunService']:IsStudio()
local IsServer = Services['RunService']:IsServer()
local IsClient = Services['RunService']:IsClient()
local Container; do
	if IsServer and not Services['ReplicatedStorage']:FindFirstChild('DiceNetwork') then
		local Folder = Instance.new('Folder')
		Folder.Name = 'DiceNetwork'
		Folder.Parent = Services['ReplicatedStorage']
		Container = Folder
	else
		Container = Services['ReplicatedStorage']:WaitForChild('DiceNetwork')
	end
end

--// functions
local function GetRemote(name,enum)
	if IsServer then
		local remote = Container:FindFirstChild(name)
		if not remote then
			local new; do
				if enum == Network.Enums.Event then
					new = Network.CreateEvent(name)
				elseif enum == Network.Enums.Function then
					new = Network.CreateFunction(name)
				end
			end
			remote = new
		end
		
		return remote
	elseif IsClient then
		local remote = Container:WaitForChild(name, 3)
		assert(remote ~= nil)
		return remote
	end
end

local function GetBindable(name,enum)
	if enum then
		local bindable = Container:FindFirstChild(name)
		if not bindable then
			local new; do
				if enum == Network.Enums.Event then
					new = Network.CreateBindableEvent(name)
				elseif enum == Network.Enums.Function then
					new = Network.CreateBindableFunction(name)
				end
			end
			bindable = new
		end
		return bindable
	else
		local bindable = Container:WaitForChild(name, 3)
		assert(bindable ~= nil)
		return bindable
	end
end

function Network.CreateEvent(name)
	local remote = Container:FindFirstChild(name)
	if not remote then
		local new = Instance.new('RemoteEvent')
		new.Name = name
		new.Parent = Container
		remote = new
	end
	return remote
end

function Network.CreateFunction(name)
	local remote = Container:FindFirstChild(name)
	if not remote then
		local new = Instance.new('RemoteFunction')
		new.Name = name
		new.Parent = Container
		remote = new
	end
	return remote
end

function Network.CreateBindableEvent(name)
	local bindable = Container:FindFirstChild(name)
	if not bindable then
		local new = Instance.new('BindableEvent')
		new.Name = name
		new.Parent = Container
		bindable = new
	end
	return bindable
end

function Network.CreateBindableFunction(name)
	local bindable = Container:FindFirstChild(name)
	if not bindable then
		local new = Instance.new('BindableFunction')
		new.Name = name
		new.Parent = Container
		bindable = new
	end
	return bindable
end

function Network:HookEvent(name,code)
	assert(typeof(name) == 'string')
	assert(typeof(code) == 'function')
	
	local remote = GetRemote(name,Network.Enums.Event)
	local event = IsClient and remote.OnClientEvent or remote.OnServerEvent
	local connection = event:Connect(function(...)
		code(...)
	end)
	
	Network.Events[name] = connection
end

function Network:UnhookEvent(name)
	assert(typeof(name) == 'string')
	
	local connection = Network.Events[name]
	if connection then
		connection:Disconnect()
	end
end

function Network:HookFunction(name,code)
	assert(typeof(name) == 'string')
	assert(typeof(code) == 'function')
	
	local remote = GetRemote(name,Network.Enums.Function)
	local callbackKey = IsClient and 'OnClientInvoke' or 'OnServerInvoke'
	remote[callbackKey] = code
	Network.Events[name] = remote
end

function Network:UnhookFunction(name)
	assert(typeof(name) == 'string')
	
	local connection = Network.Events[name]
	if connection then
		connection:Disconnect()
	end
end

function Network:FireServer(name,...)
	assert(typeof(name) == 'string')
	assert(IsClient)
	
	local remote = GetRemote(name,Network.Enums.Event)
	remote:FireServer(...)
end

function Network:FireClient(name,plr,...)
	assert(typeof(name) == 'string')
	assert(typeof(plr) == 'Instance' and plr:IsA('Player'))
	assert(IsServer)
	
	local remote = GetRemote(name,Network.Enums.Event)
	remote:FireClient(plr,...)
end

function Network:FireClients(name,plrs,...)
	assert(typeof(name) == 'string')
	assert(typeof(plrs) == 'table')
	assert(IsServer)
	
	for index,plr in pairs(plrs) do
		assert(typeof(plr) == 'Instance' and plr:IsA('Player'))
		
		local remote = GetRemote(name,Network.Enums.Event)
		remote:FireClient(plr,...)
	end
end

function Network:FireAllClients(name,...)
	assert(typeof(name) == 'string')
	assert(IsServer)
	
	local remote = GetRemote(name,Network.Enums.Event)
	remote:FireAllClients(...)
end

function Network:InvokeServer(name,...)
	assert(typeof(name) == 'string')
	assert(IsClient)
	
	local remote = GetRemote(name)
	return remote:InvokeServer(...)
end

function Network:InvokeClient(name,...)
	assert(typeof(name) == 'string')
	assert(IsServer)
	
	local remote = GetRemote(name)
	return remote:InvokeClient(...)
end

function Network:BindEvent(name,code)
	assert(typeof(name) == 'string')
	assert(typeof(code) == 'function')
	
	local bindable = GetBindable(name,Network.Enums.Event)
	local event = bindable.Event
	local connection = event:Connect(function(...)
		code(...)
	end)
	
	Network.Bindables[name] = connection
end

function Network:BindFunction(name,code)
	assert(typeof(name) == 'string')
	assert(typeof(code) == 'function')
	
	local bindable = GetBindable(name,Network.Enums.Function)
	local callbackKey = 'Invoke'
	bindable[callbackKey] = code
	Network.Bindables[name] = bindable
end

function Network:FireBindable(name,...)
	assert(typeof(name) == 'string')
	
	local bindable = GetBindable(name)
	bindable:Fire(...)
end

function Network:InvokeBindable(name,...)
	assert(typeof(name) == 'string')
	local bindable = GetBindable(name)
	return bindable:Invoke(...)
end

return Network