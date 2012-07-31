--[[
*************************************************************
 * This script is developed by Arturs Sosins aka ar2rsawseen, http://appcodingeasy.com
 * Feel free to distribute and modify code, but keep reference to its creator
 *
 * Gideros Localize class provides localization support for gideros, 
 * by loading string constants from specific files based on user locale.
 * This class also has function, that allows string formating printf style, 
 * and dynamic loading of language specific images (images with texts).
 *
 * For more information, examples and online documentation visit: 
 * http://appcodingeasy.com/Gideros-Mobile/Localization-in-Gideros
**************************************************************
]]--

module("Localize", package.seeall)

--public properties
path = "locales"
filetype = "lua"

--local properties
local locale = application:getLocale()
local file
local data = {}

--initialziation
if filetype == "lua" then
	file = loadfile(path.."/"..locale.."."..filetype)
	data = assert(file)()
elseif filetype == "json" then
	file = io.open(path.."/"..locale.."."..filetype, "r")
	data = Json.Decode(file:read( "*a" ))
end

--public method for overriding methods
function load(object, func, index)
	if object ~= nil and object[func] ~= nil and object.__LCfunc == nil then
		object.__LCfunc = object[func]
		object[func] = function(...)
			arg[index] = data[arg[index]] or arg[index]
			return object.__LCfunc(unpack(arg))
		end
	end
end

--overriding native objects
load(string, "format", 1)
load(TextField, "new", 2)
load(Texture, "new", 1)