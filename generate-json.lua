-- Load in underscore.lua
package.path = "underscore.lua/lib/?.lua;" .. package.path
local _ = require('underscore')

-- Patch in a deterministic pairs function.
local unordered_pairs = pairs
pairs = function(t)
  local keys = {}
  for k, v in unordered_pairs(t) do table.insert(keys, k) end

  -- Abort if any of the keys are not strings.
  if _.any(keys, function(key) return type(key) ~= "string" end) then
    return unordered_pairs(t)
  end

  -- Sort the keys and return an iterator that iterates in the order of those keys.
  table.sort(keys)
  local i, n = 0, #keys
  return function ()
    i = i + 1
    if i <= n then return keys[i], t[keys[i]] end
  end
end

-- Load in the rest of the dependencies.
package.path = "love-api/?.lua;" .. "dkjson/?.lua;" .. package.path
local loveapi = require('love_api')
local json = require('dkjson')

local WIKI_ROOT = 'https://love2d.org/wiki/'
local API = {}
local CONFIG_API = {}

function format_function_args(variant)
  local arguments = ""

  local i = 0
  if variant.arguments ~= nil then
    arguments = _(variant.arguments):chain():map(function(arg)
      i = i + 1
      return "${" .. i .. ":" .. arg.name .. "}"
    end):join(', '):value()
  end
  return arguments
end

function process_function(modulename, func)
  local funcname = modulename .. '.' .. func.name
  local args = format_function_args(func.variants[1])

  local snippet = funcname .. "(" .. args .. ")"
  API[funcname] = {
    type = 'function',
    description = func.description,
    url = WIKI_ROOT .. funcname,
    snippet = snippet
  }
end

-- Process the API entry for configurations.
function process_conf(argument, parent)
  -- The root URL to concatenate names to.
  local CONF_ROOT = "https://love2d.org/wiki/Config_Files#"

  local name = argument.name
  if parent ~= nil then name = parent .. '.' .. name end

  if argument.type == 'table' then
    for _, v in ipairs(argument.table) do
      process_conf(v, name)
    end
    return
  end

  CONFIG_API[name] = {
    default = argument.default,
    description = argument.description,
    type = argument.type,
    url = CONF_ROOT .. name:sub(3)
  }
end

-- Generate data for root module.
API['love'] = {
  type = 'module',
  description = 'The root LOVE module.',
  url = WIKI_ROOT .. 'love'
}
for i, func in ipairs(loveapi.functions) do
  if func.name == "conf" then process_conf(func.variants[1].arguments[1])
  else process_function('love', func) end
end

-- Generate data for the sub-modules.
for i, module in ipairs(loveapi.modules) do
  local modulename = 'love.' .. module.name
  API[modulename] = {
    type = 'module',
    description = module.description,
    url = WIKI_ROOT .. modulename
  }

  for j, func in ipairs(module.functions) do
    process_function(modulename, func)
  end
end

-- Generate data for all of the callbacks.
for i, callback in ipairs(loveapi.callbacks) do
  local name = 'love.' .. callback.name
  local args = format_function_args(callback.variants[1])

  local snippet = "function " .. name .. "(" .. args .. ")\n\t${0:-- body...}\nend"
  API[name] = {
    type = 'callback',
    description = callback.description,
    url = WIKI_ROOT .. name,
    snippet = snippet
  }
end

-- Write out the API data.
local file = io.open('api.json', 'w')
file:write(json.encode(API, {indent = true}))
file:close()

-- Write out the configuation API data.
local file = io.open('config-api.json', 'w')
file:write(json.encode(CONFIG_API, {indent = true}))
file:close()
