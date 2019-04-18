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

  if vim.api.nvim_win_close ~= nil then
    vim.api.nvim_win_close(obj.winid, true)
    obj:set("winid", nil)
  else
    -- TODO Drop this once nvim 0.4 is out
    local winnr = math.floor(nvim.nvim_call_function("bufwinnr", {obj.buffer}))
    local save_winnr = nvim.nvim_call_function("bufwinnr", {nvim.nvim_get_current_buf()})
    vim.api.nvim_command(winnr .. ' wincmd w | q')
    if save_winnr ~= -1 and save_winnr ~= winnr then
      vim.api.nvim_command(save_winnr .. ' wincmd w')
    end
  end

  vim.api.nvim_command("stopinsert")

  obj.destroyed = true
end

internals.render = function(obj)
  return internals.types[obj.type].render(obj)
end

internals.handle = function(obj, option)
  return internals.types[obj.type].handle(obj, option)
end


return internals
