-- luacheck: globals unpack vim
local nvim = vim.api

local utils = require("impromptu.utils")
local heuristics = require("impromptu.heuristics")


local impromptu = {
  config = {},
  memory = {},
  ll = {},
  core = {}
}


setmetatable(impromptu.memory, utils.LRU(impromptu.config.lru_size or 10))

local new_obj = function()
  local session = math.random(10000, 99999)
  local obj = {}

  impromptu.memory[session] = {}

  setmetatable(obj, {
    __index = function(table, key)
      return impromptu.memory[session][key]
    end,
    __newindex = function(table, key, value)
      impromptu.memory[session][key] = value
    end})

  obj.session = session

  return obj
end

impromptu.ll.show = function(obj)
  if obj.buffer == nil then
    nvim.nvim_command("belowright 8 new | setl nonu nornu nobuflisted buftype=nofile bufhidden=wipe")
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

impromptu.ll.render = function(obj)
  local content = {}

  local winnr = nvim.nvim_call_function("bufwinnr", {obj.buffer})
  local window = nvim.nvim_call_function("win_getid", {winnr})

  local sz = nvim.nvim_win_get_width(window)
  local h = nvim.nvim_win_get_height(window)
  local has_footer = obj.footer and true or false
  local footer_sz = has_footer and 2 or 0

  local selected = {q = 1}

  nvim.nvim_command("mapclear <buffer>")

  if obj.header ~= nil then
    local header = obj.header
    local up = nil

    if #obj.breadcrumbs >= 1 then
       header = header .. " [" ..table.concat(obj.breadcrumbs, "/") .. "]"

      up = impromptu.ll.line{
        key = "h",
        description = "Move up one level",
      }

    nvim.nvim_command("map <buffer> h <Cmd>lua require('impromptu').core.callback("  .. obj.session .. ", '__up')<CR>")

    selected.h = 1
    end

    table.insert(content, header)
    table.insert(content, impromptu.ll.div(sz))
    table.insert(content, "")

    if up ~= nil then
      table.insert(content, up)
    end
  end

  local process = function(item, line)
    local key = heuristics.get_unique_key(selected, line.description)
    selected[key] = 1

    line.key = key

    table.insert(content, impromptu.ll.line(line))
    nvim.nvim_command("map <buffer> " .. line.key .. " <Cmd>lua require('impromptu').core.callback("  .. obj.session .. ", '" .. item .. "')<CR>")
  end

  local line_lvl = utils.get_in(obj.lines, utils.interleave(obj.breadcrumbs, 'children'))

  if #line_lvl == 0 then
    for item, line in pairs(line_lvl) do
      process(item, line)
    end
  else
    for _, line in ipairs(line_lvl) do
      process(line.item, line)
    end
  end

  if obj.quitable then
    table.insert(content, impromptu.ll.line{
      key = "q",
      item = "quit",
      description = "Close this prompt",
    })

    nvim.nvim_command("map <buffer> q <Cmd>lua require('impromptu').core.destroy("  .. obj.session .. ")<CR>")
  end

  if #content + footer_sz < h then
    local fill = h - #content  - footer_sz
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  if has_footer then
    table.insert(content, impromptu.ll.div(sz))
    table.insert(content, obj.footer)
  end

  nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
end

impromptu.core.destroy = function(obj_or_session)
  local obj = nil

  if type(obj_or_session) == "table" then
    obj = obj_or_session
  else
    obj = impromptu.memory[obj_or_session]
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

  obj = impromptu.ll.show(obj)
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
  local obj = impromptu.memory[session]
  local should_close = true

  if obj ~= nil then
    if impromptu.core.tree(obj, option) then
      should_close = false
    else
      should_close = obj:handler(option)
    end
  end

  if should_close then
    impromptu.core.destroy(obj)
  else
    impromptu.ll.render(obj)
  end
end

return impromptu
