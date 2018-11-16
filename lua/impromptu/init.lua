-- luacheck: globals unpack vim
local nvim = vim.api

local utils = require("impromptu.utils")
local heuristics = require("impromptu.heuristics")


local impromptu = {
  config = {},
  sessions = {},
  ll = {},
  core = {}
}


setmetatable(impromptu.sessions, utils.LRU(impromptu.config.lru_size or 10))

local new_obj = function()
  local session = math.random(10000, 99999)
  local obj = {}

  impromptu.sessions[session] = {}

  setmetatable(obj, {
    __index = function(_, key)
      return impromptu.sessions[session][key]
    end,
    __newindex = function(_, key, value)
      impromptu.sessions[session][key] = value
    end})

  obj.session_id = session

  return obj
end

impromptu.ll.show = function(obj)
  if obj.buffer == nil then
    nvim.nvim_command("belowright 15 new | setl nonu nornu nobuflisted buftype=nofile bufhidden=wipe")
    local cb = nvim.nvim_get_current_buf()
    obj.buffer = cb
  end

  return obj
end

impromptu.ll.line = function(line)
    local str = "  [" .. line.key .. "] " .. line.description

    return str
end

impromptu.ll.div = function(sz)
  return string.rep("─", sz)
end

impromptu.ll.sub_div = function(sz)
  return string.rep("•", sz)
end

impromptu.ll.window_for_obj = function(obj)
  obj = impromptu.ll.show(obj)

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

impromptu.ll.get_options = function(obj)
  local opts = {}
  local selected = {}
  local process = function(line)
    local key = line.key or heuristics.get_unique_key(selected, line.description)
    selected[key] = 1

    line.key = key
    line.item = line.item or line.key_name
    return line
  end

  if #obj.breadcrumbs >= 1 then
    table.insert(opts, {
        key = "h",
        description = "Move up one level",
        item = "__up"
      })
    selected.h = 1
  end

  if obj.quitable then
    selected.q = 1
  end

  local line_lvl = utils.get_in(obj.lines, utils.interleave(obj.breadcrumbs, 'children'))

  if #line_lvl == 0 then
    line_lvl = utils.sorted_by(utils.key_to_attr(line_lvl, "key_name"), function(i) return i.description end)
  end

  if #line_lvl > 12 then
    -- TODO fallback to fuzzy finder when available
    nvim.nvim_err_writeln("More than 12 items on the list. Visualization won't be optimal")
  end

  for _, line in ipairs(line_lvl) do
    table.insert(opts, process(line))
  end

  if obj.quitable then
    table.insert(opts, {
      key = "q",
      item = "__quit",
      description = "Close this prompt",
    })
  end

  return opts
end

impromptu.ll.get_header = function(obj)
  local header = ""

  if obj.header ~= nil then
    header = obj.header

    if #obj.breadcrumbs >= 1 then
       header = header .. " [" ..table.concat(obj.breadcrumbs, "/") .. "]"
     end
  end

   return header
 end

impromptu.ll.get_footer = function(obj)
  local footer = ""

  if obj.footer ~= nil then
    footer = obj.footer
  end

   return footer
 end

 impromptu.ll.do_mappings = function(obj, opts)
  nvim.nvim_command("mapclear <buffer>")

   for _, v in ipairs(opts) do
     nvim.nvim_command(
       "map <buffer> " ..
       v.key ..
       " <Cmd>lua require('impromptu').core.callback("  ..
       obj.session_id ..
       ", '" ..
       v.item ..
       "')<CR>"
     )
   end
 end

impromptu.ll.draw = function(obj, opts, window_ops)
  local header = impromptu.ll.get_header(obj)
  local footer = impromptu.ll.get_footer(obj)
  local footer_sz = footer ~= "" and 2 or 1

  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, impromptu.ll.div(window_ops.width))
  end

  table.insert(content, "")

  for _, opt in ipairs(opts) do
    table.insert(content, impromptu.ll.line(opt))
  end

  if #content + footer_sz < window_ops.height then
    local fill = window_ops.height - #content  - footer_sz
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  if footer ~= "" then
    table.insert(content, impromptu.ll.div(window_ops.width))
    table.insert(content, footer)
  end

  return content
 end

impromptu.ll.render = function(obj)

  local opts = impromptu.ll.get_options(obj)
  local window_ops = impromptu.ll.window_for_obj(obj)

  impromptu.ll.do_mappings(obj, opts)
  local content = impromptu.ll.draw(obj, opts, window_ops)

  nvim.nvim_buf_set_option(obj.buffer, "modifiable", true)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", false)
  nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
  nvim.nvim_buf_set_option(obj.buffer, "modifiable", false)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", true)
end

impromptu.core.destroy = function(obj_or_session)
  local obj

  if type(obj_or_session) == "table" then
    obj = obj_or_session
  else
    obj = impromptu.sessions[obj_or_session]
  end

  local window = math.floor(nvim.nvim_call_function("bufwinnr", {obj.buffer}))
  nvim.nvim_command(window .. ' wincmd w | q')
end

impromptu.core.ask = function(args)
  local obj = new_obj()

  obj.quitable = utils.default(args.quitable, true)
  obj.header = args.question
  obj.breadcrumbs = {}
  obj.lines = args.options
  obj.handler = args.handler

  obj = impromptu.ll.render(obj)

  return obj
end

impromptu.core.tree = function(session, option)

  local breadcrumbs = utils.clone(session.breadcrumbs)

  if option == "__up" then
    breadcrumbs[#breadcrumbs] = nil
  else
    table.insert(breadcrumbs, option)
  end

  local lens = utils.interleave(breadcrumbs, 'children')

  local at = utils.get_in(session.lines, lens)

  if at ~= nil then
    session.breadcrumbs = breadcrumbs
    return true
  else
    return false
  end
end

impromptu.core.callback = function(session, option)
  local obj = impromptu.sessions[session]
  local should_close

  if obj == nil then
    -- TODO warning
     return
  elseif option == "__quit" then
    impromptu.core.destroy(obj)
    return
  end

  if impromptu.core.tree(obj, option) then
    should_close = false
  else
    should_close = obj:handler(option)
  end

  if should_close then
    impromptu.core.destroy(obj)
  else
    impromptu.ll.render(obj)
  end
end

return impromptu
