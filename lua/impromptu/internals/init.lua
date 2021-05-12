-- luacheck: globals unpack vim utf8
local sessions = require("impromptu.sessions")
local internals = {
  types = {
    ask = require("impromptu.internals.ask"),
    filter = require("impromptu.internals.filter"),
    form = require("impromptu.internals.form"),
    showcase = require("impromptu.internals.showcase")
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

  local winnr = vim.fn.bufwinnr(obj.buffer)
  local window = vim.api.nvim_call_function("win_getid", {winnr})
  vim.api.nvim_win_close(window, true)
  vim.api.nvim_command("stopinsert")

  obj.hls = {}

  obj.destroyed = true
  local cleanup_fn = internals.types[obj.type].cleanup
  if cleanup_fn ~= nil then
    return cleanup_fn(obj)
  end
end

internals.render = function(obj)
  return internals.types[obj.type].render(obj)
end

internals.handle = function(obj, option)
  return internals.types[obj.type].handle(obj, option)
end


return internals
