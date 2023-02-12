#@
-- This wrapper allows the program to run headless on any OS (in theory)
-- It can be run using a standard lua interpreter, although LuaJIT is preferable


-- Callbacks
local callbackTable = {}
local mainObject
function runCallback(name, ...)
	if callbackTable[name] then
		return callbackTable[name](...)
	elseif mainObject and mainObject[name] then
		return mainObject[name](mainObject, ...)
	end
end

function SetCallback(name, func)
	callbackTable[name] = func
end

function GetCallback(name)
	return callbackTable[name]
end

function SetMainObject(obj)
	mainObject = obj
end

-- Image Handles
local imageHandleClass = {}
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
	return setmetatable({}, imageHandleClass)
end

function imageHandleClass:Load(fileName, ...)
	self.valid = true
end

function imageHandleClass:Unload()
	self.valid = false
end

function imageHandleClass:IsValid()
	return self.valid
end

function imageHandleClass:SetLoadingPriority(pri)
end

function imageHandleClass:ImageSize()
	return 1, 1
end

-- Rendering
function RenderInit()
end

function GetScreenSize()
	return 1920, 1080
end

function SetClearColor(r, g, b, a)
end

function SetDrawLayer(layer, subLayer)
end

function SetViewport(x, y, width, height)
end

function SetDrawColor(r, g, b, a)
end

function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
end

function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4)
end

function DrawString(left, top, align, height, font, text)
end

function DrawStringWidth(height, font, text)
	return 1
end

function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
	return 0
end

function StripEscapes(text)
	return text:gsub("^%d", ""):gsub("^x%x%x%x%x%x%x", "")
end

function GetAsyncCount()
	return 0
end

local open = io.open

-- Search Handles
function NewFileSearch(path)
end

-- General Functions
function SetWindowTitle(title)
end

function GetCursorPos()
	return 0, 0
end

function SetCursorPos(x, y)
end

function ShowCursor(doShow)
end

function IsKeyDown(keyName)
end

function Copy(text)
end

function Paste()
end

function Deflate(data)
	-- TODO: Might need this
	return ""
end

function Inflate(data)
	-- TODO: And this
	return ""
end

function GetTime()
	return 0
end

function GetScriptPath()
	return ""
end

function GetRuntimePath()
	return ""
end

function GetUserPath()
	return ""
end

function MakeDir(path)
end

function RemoveDir(path)
end

function SetWorkDir(path)
end

function GetWorkDir()
	return ""
end

function LaunchSubScript(scriptText, funcList, subList, ...)
end

function AbortSubScript(ssID)
end

function IsSubScriptRunning(ssID)
end

function LoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return func(...)
	else
		error("LoadModule() error loading '" .. fileName .. "': " .. err)
	end
end

function PLoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return PCall(func, ...)
	else
		error("PLoadModule() error loading '" .. fileName .. "': " .. err)
	end
end

function PCall(func, ...)
	local ret = { pcall(func, ...) }
	if ret[1] then
		table.remove(ret, 1)
		return nil, unpack(ret)
	else
		return ret[2]
	end
end

function ConPrintf(fmt, ...)
	-- Optional
	print(string.format(fmt, ...))
	io.flush()
end

function ConPrintTable(tbl)
	for key, value in pairs(tbl) do
		ConPrintf(key .. "," .. string.format("%s", value) .. "\n")
	end
end

function ConExecute(cmd)
end

function ConClear()
end

function SpawnProcess(cmdName, args)
end

function OpenURL(url)
end

function SetProfiling(isEnabled)
end

function Restart()
end

function Exit()
end

local l_require = require
function require(name)
	-- Hack to stop it looking for lcurl, which we don't really need
	if name == "lcurl.safe" then
		return
	end
	return l_require(name)
end

dofile("Launch.lua")

-- Prevents loading of ModCache
-- Allows running mod parsing related tests without pushing ModCache
-- The CI env var will be true when run from github workflows but should be false for other tools using the headless wrapper
mainObject.continuousIntegrationMode = os.getenv("CI")

runCallback("OnInit")
runCallback("OnFrame") -- Need at least one frame for everything to initialise

if mainObject.promptMsg then
	-- Something went wrong during startup
	print(mainObject.promptMsg)
	io.read("*l")
	return
end

-- The build module; once a build is loaded, you can find all the good stuff in here
build = mainObject.main.modes["BUILD"]

-- Here's some helpful helper functions to help you get started
function newBuild()
	mainObject.main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
	runCallback("OnFrame")
end

function loadBuildFromXML(xmlText, name)
	mainObject.main:SetMode("BUILD", false, name or "", xmlText)
	runCallback("OnFrame")
end

function loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
	mainObject.main:SetMode("BUILD", false, "")
	runCallback("OnFrame")
	local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
	build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
	runCallback("OnFrame")
	return charData
end

local function read_file(path)
	local file = open(path, "rb") -- r read mode and b binary mode
	if not file then return nil end
	local content = file:read "*a" -- *a or *all reads the whole file
	file:close()
	return content
end

io.stdout:setvbuf 'no'

while true do
	ConPrintf("Awaiting input")
	local jobId = io.read()
	local passives = read_file("../data/" .. jobId .. "_passives.json");
	local items = read_file("../data/" .. jobId .. "_items.json");
	local charData = loadBuildFromJSON(items, passives);

	local mainTableFile = io.open("../data/" .. jobId .. "_maintable.txt", 'w')
	local mainOut = "";
	for key, value in pairs(build.calcsTab.mainOutput) do
		mainOut = mainOut .. key .. "," .. string.format("%s", value) .. "\n"
	end

	if (build.mainSocketGroup) then
		local mainSocketGroup = build.skillsTab.socketGroupList[build.mainSocketGroup]
		if (mainSocketGroup) then
			local srcInstance = mainSocketGroup.displaySkillList[mainSocketGroup.mainActiveSkill]
			if srcInstance then
				mainOut = mainOut ..
					'mainSkill' .. "," .. string.format("%s", srcInstance.activeEffect.srcInstance.nameSpec) .. "\n"
			end
		end
	end

	mainTableFile:write(mainOut);
	mainTableFile:flush();
	mainTableFile:close();

	local codeFile = io.open("../data/" .. jobId .. "_code.xml", 'w')
	codeFile:write(build:SaveDB("code"));
	codeFile:flush();
	codeFile:close();

	local completeFile = io.open("../data/" .. jobId .. "_complete.txt", 'w')
	completeFile:write(" ");
	completeFile:flush();
	completeFile:close();

	ConPrintf("wrote output,%s", charData.name)
end
