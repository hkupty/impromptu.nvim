-- luacheck: globals unpack vim utf8
local utils = require("impromptu.utils")
local shared = {}

local bottom = function(_)
  local width = vim.o.columns
  local height = vim.o.lines
  return {
    relative = "editor",
    width = width,
    height = 20,
    row = height - 20,
    col = 0
  }
end

local center = function(obj)
  local width = vim.o.columns
  local height = vim.o.lines
  local offset = #obj.lines

  if obj.header ~= nil then
    offset = offset + 4
  end

  offset = obj.height or offset

  return {
    relative = "editor",
    width = math.ceil(width * 0.5),
    height = offset,
    row = math.ceil(height * 0.5) - math.ceil(offset * 0.5),
    col = math.ceil(width * 0.25)
  }
end

shared.resize = function(obj)
  local location
  if obj.location == "center" then
    location = center
  else
    location = bottom
  end

  if obj.winid ~= nil then
    vim.api.nvim_win_set_config(obj.winid, location(obj))
    end
end

shared.show = function(obj)
  local cb = vim.api.nvim_create_buf(false, true)
  local location

  if obj.location == "center" then
    location = center
  else
    location = bottom
  end

  local winid = vim.api.nvim_open_win(cb, true, location(obj))

  vim.api.nvim_win_set_option(winid, "breakindent", true)
  vim.api.nvim_win_set_option(winid, "number", false)
  vim.api.nvim_win_set_option(winid, "relativenumber", false)
  vim.api.nvim_win_set_option(winid, "fillchars", "eob: ")
  vim.api.nvim_buf_set_option(cb, "bufhidden", "wipe")

  obj:set("winid", winid)
  obj:set("buffer", math.ceil(cb))

  return obj
end

shared.window_for_obj = function(obj)
  if obj.winid == nil then
    obj = shared.show(obj)
  end

  local sz = vim.api.nvim_win_get_width(obj.winid)
  local h = vim.api.nvim_win_get_height(obj.winid)
  local top_offset = 0
  local bottom_offset = 0

  if obj.header ~= nil then
    top_offset = top_offset + 2
  end

  if obj.footer ~= nil then
    bottom_offset = bottom_offset + 2
  end

  return {
    bufnr = vim.fn.bufnr(obj.buffer),
    window = obj.winid,
    width = sz,
    height = h,
    top_offset = top_offset,
    bottom_offset = bottom_offset
  }
end

shared.header = function(obj, window_ops)
  local header = {}

  if obj.header ~= nil then
    table.insert(header, obj.header)
    table.insert(header, shared.div(window_ops.width))
  end

 return header
end

shared.footer = function(content, window_ops)
  local footer = {}

  table.insert(footer, shared.sub_div(window_ops.width))
  if type(content) == "string" then
    table.insert(footer, content)
  elseif type(content) == "table" then
    footer = utils.extend{footer, content}
  end

 return footer
end

shared.draw_area_size = function(window_ops)
  return window_ops.height - window_ops.top_offset - window_ops.bottom_offset
end

shared.spacer = function(content, window_ops)
  local whitespace = {}
  local draw_area_size = shared.draw_area_size(window_ops)

  if #content < draw_area_size then
    local fill = draw_area_size - #content

    for _ = 1, fill do
      table.insert(whitespace, "")
    end
  end

  return whitespace
end

shared.with_bottom_offset = function(window_ops)
  window_ops.bottom_offset = 2

  return window_ops
end

shared.sort = function(a, b)
    return a.description < b.description
  end

shared.div = function(sz)
  return string.rep("─", sz)
end

shared.sub_div = function(sz)
  return string.rep("─", sz)
end

shared.get_footer = function(obj)
  local footer = ""

  if obj.footer ~= nil then
    footer = obj.footer
  end

   return footer
 end

shared.lines_to_grid = function(opts, max_sz)
  local grid = {}

  for ix = 0, #opts + (#opts - 1) % max_sz, max_sz do
    local column = {}
    for j = 1, max_sz do
      local k = opts[ix + j]
      if k ~= nil then
        table.insert(column, "  " .. k)
      else
        break
      end
    end

    if #column ~= 0 then
      table.insert(grid, column)
    end
  end

  return grid
end

shared.render_grid = function(grid, is_compact)
  local columns = #grid
  local lines = {}
  local widths = {}
  local max_width = 0

  for column = 1, #grid do
    local max = 0

    for row = 1, #grid[column] do
      local sz = utils.displaywidth(grid[column][row])

      if sz > max then
        max = sz
      end
    end

    if max > max_width then
      max_width = max
    end

    widths[column] = max
  end

  -- Inverted the order since we produce a table of lines
  for row = 1, #grid[1] do
    local line = {}

    for column = 1, columns do
      local item = grid[column][row]

      if item == nil then
        break
      end

      local col_width

      if is_compact then
        col_width = widths[column]
      else
        col_width = max_width
      end

      local cur_width = utils.displaywidth(item)

      if column ~= columns then
        table.insert(line, item .. string.rep(" ", col_width - cur_width))
      else
        table.insert(line, item)
      end
    end

    table.insert(lines, table.concat(line, ""))
  end

  return lines
end

shared.render_line = function(line)
    return  "[" .. line.key .. "] " .. line.description
end

return shared
