-- luacheck: globals unpack vim utf8
local nvim = vim.api
local sessions = require("impromptu.sessions")
local internals = {
  types = {
    ask = require("impromptu.internals.ask"),
    filter = require("impromptu.internals.filter"),
    form = require("impromptu.internals.form")
  },
  shared = require("impromptu.internals.shared")
}

internals.destroy = function(obj_or_session)
  local obj

  if type(obj_or_session) == "table" then
    obj = obj_or_session
  else
    obj = sessions[obj_or_session]
  end

  local window = math.floor(nvim.nvim_call_function("bufwinnr", {obj.buffer}))
  nvim.nvim_command(window .. ' wincmd w | q')

  obj.destroyed = true
end

internals.render = function(obj)
  return internals.types[obj.type].render(obj)
end

internals.handle = function(obj, option)
  return internals.types[obj.type].handle(obj, option)
end


return internals
