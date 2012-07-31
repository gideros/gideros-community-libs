-----------------------------------------------------------------------------------------
-- Load the json library
-----------------------------------------------------------------------------------------
local json = require("Json")


-----------------------------------------------------------------------------------------
-- Rest
-----------------------------------------------------------------------------------------
Rest = Core.class()

Rest.methods = {
   GET    = UrlLoader.GET,
   PUT    = UrlLoader.PUT,
   POST   = UrlLoader.POST,
   DELETE = UrlLoader.DELETE,
}

function Rest.defaultRestHandler(r)
   if r.error then 
      print("--------------- "..r.name)
      print("ERROR") 
      print("URL: "..r.url)
   else 
      print("--------------- "..r.name)
      print(inspect(r.data)) 
   end
end

function Rest.createRestHandler(t)
   return function(r)
      if r.error then 
         if t and t.error then
            t.error(r)
         else
            print("--------------- "..r.name)
            print("ERROR") 
         end
      else 
         if t and t.success then
            t.success(r)
         else
            print("--------------- "..r.name)
            print(inspect(r.data)) 
         end
      end
   end
end

function Rest:init(obj, filename)

   -- Save the api description
   if filename:find(".json") then
      local inp = assert(io.open(filename, "rb"))
      local data = inp:read("*all")
      self.api = json.Decode(data)
   else
      self.api = dofile(filename)
   end

   -- For each method
   if self.api.methods then
      for name, t in pairs(self.api.methods) do

         -- Create a function for the object
         obj[name] = function(self, ...)
            self:callMethod(name, t, ...)
         end
      end
   end

end

function Rest:call(name, t, headers, extraArgList, preCallbackHook, ...)
   local arg      = {n=select('#', ...), ...}
   local index    = 1
   local argList  = {}
   local callback = nil
   local body     = nil

   -- Copy in any extra args
   if extraArgList then
      for k,v in pairs(extraArgList) do
         argList[k] = v
      end
   end
   
   -- For each required argument
   if t.required_params then
      for _,a in ipairs(t.required_params) do
         argList[a] = arg[index]
         index = index + 1
      end
   end
  
   -- Handle optional parameters
   if t.optional_params then
      local optList = arg[index]
      index = index + 1
      if optList then
         for _,a in ipairs(t.optional_params) do
            argList[a] = optList[a]
         end
      end
   end

   -- Handle payload parameter
   if t.required_payload then
      body = arg[index]
      index = index + 1
   end

   -- Handle callback if necessary
   if arg[index] and type(arg[index]) == "function" then
      callback = arg[index]
   elseif arg[index] and type(arg[index]) == "table" then
      callback = Rest.createRestHandler(arg[index])
   else
      callback = Rest.defaultRestHandler
   end


   -- Handle args and path/arg substitution
   local args = ""
   local newpath = t.path
   for a,v in pairs(argList) do
      -- Try to substitue into path
      newpath, count = newpath:gsub(":"..a, v)
      if count == 0 then
         if args == "" then
            args = "?"..a.."="..v
         else
            args = args .."&".. a .."="..v
         end
      end
   end

   -- Encode the body if we can
   if body then
      local ok, newbody = pcall(function() return json.Encode(body) end)
      if ok then
         body = newbody
      end
   end
   
   -- Call load the url
   local url = self.api.base_url .. "/" .. newpath .. args
   local urlLoader = UrlLoader.new(url, self.methods[t.method], headers, body)

   -- Add event handlers
   local function handleResponse(error, response)
      response.name    = name
      response.url     = url
      response.method  = t.method
      response.error   = error
      if response.data then
         local ok, msg = pcall(function() return json.Decode(response.data) end)
         if ok then
            response.data    = msg
         end
      else
         response.data    = {}
      end
      if preCallbackHook then preCallbackHook(response) end
      if callback then callback(response) end
   end

   urlLoader:addEventListener(Event.COMPLETE, handleResponse, false)
   urlLoader:addEventListener(Event.ERROR,    handleResponse, true)
end

