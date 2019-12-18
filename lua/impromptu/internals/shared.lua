-- luacheck: globals unpack vim utf8
local nvim = vim.api
local shared = {}

local bottom = function(_)
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")
  return {
    relative = "editor",
    width = width,
    height = 20,
    row = height - 20,
    col = 0
  }
end

local center = function(obj)
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")
  local offset = #obj.lines

  if obj.header ~= nil then
    offset = offset + 4
  end

  return {
    relative = "editor",
    width = math.ceil(width * 0.5),
    height = offset,
    row = math.ceil(height * 0.5) - math.ceil(offset * 0.5),
    col = math.ceil(width * 0.25)
  }
end


shared.show = function(obj)
  local cwin = vim.api.nvim_call_function("win_getid", {})
  if obj.buffer == nil then
    local cb
    if vim.api.nvim_open_win ~= nil then
      cb = vim.api.nvim_create_buf(false, true)
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
      vim.api.nvim_buf_set_option(cb, "bufhidden", "wipe")
      obj:set("winid", winid)
    else
      vim.api.nvim_command("botright 15 new")
      cb = vim.api.nvim_get_current_buf()
      -- TODO Change to API-based when nvim_win_set_option exists.
      vim.api.nvim_command("setl breakindent nonu nornu nobuflisted buftype=nofile bufhidden=wipe nolist wfh wfw nowrap")
    end
    obj:set("buffer", math.ceil(cb))
  end

  return obj
end

shared.window_for_obj = function(obj)
  obj = shared.show(obj)

  local bufnr = vim.api.nvim_call_function("bufnr", {obj.buffer})
  local window = obj.winid or vim.api.nvim_call_function("win_getid", {
    vim.api.nvim_call_function("bufwinnr", {obj.buffer})
  })
  local sz = vim.api.nvim_win_get_width(window)
  local h = vim.api.nvim_win_get_height(window)
  local top_offset = 0
  if obj.header ~= nil then
    top_offset = top_offset + 2
  end

  return {
    bufnr = bufnr,
    window = window,
    width = sz,
    height = h,
    top_offset = top_offset,
    bottom_offset = 0
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
  table.insert(footer, content)

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


return shared
