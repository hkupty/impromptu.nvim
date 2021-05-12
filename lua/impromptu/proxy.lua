-- luacheck: globals vim
local sessions = require("impromptu.sessions")

local proxy = function(session)
  local obj = {
    session_id = session,
    _debug = function(this)
      print(vim.inspect(sessions[this.session_id]))
    end
  }

  setmetatable(obj, {
    __index = function(_, key)
      local s = sessions[session]
      return s._col[#s._col][key] or s[key]
    end,
    __newindex = function(_, key, value)
      local s = sessions[session]
      s._col[#s._col][key] = value
    end})

    return obj
end

local reverse_lookup = function(key, value)
  for k, v in pairs(sessions) do
    if v[key] == value then
      return proxy(k)
    end
  end
  return nil
end

return {
  proxy = proxy,
  reverse_lookup = reverse_lookup
}
