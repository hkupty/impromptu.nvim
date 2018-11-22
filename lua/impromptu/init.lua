-- luacheck: globals unpack vim utf8
local utils = require("impromptu.utils")
local internals = require("impromptu.internals")
local sessions = require("impromptu.sessions")

local impromptu = {}

local new_obj = function()
  local session = math.random(10000, 99999)
  local obj = {}

  sessions[session] = {}

  setmetatable(obj, {
    __index = function(_, key)
      return sessions[session][key]
    end,
    __newindex = function(_, key, value)
      sessions[session][key] = value
    end})

  obj.session_id = session

  return obj
end

impromptu.ask = function(args)
  local obj = new_obj()

  obj.quitable = utils.default(args.quitable, true)
  obj.header = args.question
  obj.breadcrumbs = {}
  obj.lines = args.options
  obj.handler = args.handler
  obj.columns = utils.default(args.columns, 1)
  obj.type = "ask"

  obj = internals.render(obj)

  return obj
end

impromptu.form = function(args)
  local obj = new_obj()

  obj.header = args.title
  obj.questions = args.questions
  obj.handler = args.handler
  obj.type = "form"

  obj = internals.render(obj)

  return obj
end

impromptu.callback = function(session, option)
  local obj = sessions[session]

  if obj == nil then
     return
  elseif option == "__quit" then
    internals.destroy(obj)
    return
  end

  if internals.handle(obj, option) then
    internals.destroy(obj)
  else
    internals.render(obj)
  end
end

return impromptu
