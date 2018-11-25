-- luacheck: globals unpack vim utf8
local nvim = vim.api
local utils = require("impromptu.utils")
local shared = {}

shared.show = function(obj)
  if obj.buffer == nil then
    nvim.nvim_command("belowright 15 new")
    nvim.nvim_command("setl breakindent nonu nornu nobuflisted buftype=nofile bufhidden=wipe nolist")
    local cb = nvim.nvim_get_current_buf()
    obj.buffer = cb
  end

  return obj
end

shared.window_for_obj = function(obj)
  obj = shared.show(obj)

  local winnr = nvim.nvim_call_function("bufwinnr", {obj.buffer})
  local window = nvim.nvim_call_function("win_getid", {winnr})
  local sz = nvim.nvim_win_get_width(window)
  local h = nvim.nvim_win_get_height(window)

  return {
    window = window,
    width = sz,
    height = h
  }
end

shared.sort = function(a, b)
    return a.description < b.description
  end

shared.div = function(sz)
  return string.rep("─", sz)
end

shared.sub_div = function(sz)
  return string.rep("•", sz)
end

shared.get_footer = function(obj)
  local footer = ""

  if obj.footer ~= nil then
    footer = obj.footer
  end

   return footer
 end

shared.line = function(opts, columns, window_ops)
  local opt_to_line = function(line)
    return  "  [" .. line.key .. "] " .. line.description
  end
  local lines = {}
  local column_width = math.floor(window_ops.width / columns)

  for ix = 0, #opts + (#opts - 1) % columns, columns do
    local ln = {}
    for j = 1, columns do
      local k = opts[ix + j]
      if k ~= nil then
        local line = opt_to_line(k)
        local padding = column_width - utils.displaywidth(line, 0)
        if j == columns or opts[ix + j + 1] == nil then
          table.insert(ln, line)
        else
          table.insert(ln, line .. string.rep(" ", padding))
        end
      end
    end
    table.insert(lines, table.concat(ln, ""))
  end

    return lines
end

return shared
