-- luacheck: globals unpack vim
local nvim = vim.api

local LRU = require("impromptu.utils").LRU
local heuristics = require("impromptu.heuristics")


local impromptu = {
  config = {},
  memory = {},
  ll = {},
  core = {}
}


setmetatable(impromptu.memory, LRU(impromptu.config.lru_size or 10))

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
    table.insert(content, obj.header)
    table.insert(content, impromptu.ll.div(sz))
    table.insert(content, "")
  end

  local lines = {}
  for k, v in ipairs(obj.lines) do
    local line = v
    local key = heuristics.get_unique_key(selected, line.description)
    selected[key] = 1

    line.key = key

    table.insert(content, impromptu.ll.line(line))
    table.insert(lines, impromptu.ll.line(line))
    nvim.nvim_command("map <buffer> " .. line.key .. " <Cmd>lua require('impromptu').core.callback("  .. obj.session .. ", '" .. line.item .. "')<CR>")
  end

  table.insert(content, impromptu.ll.line{
    key = "q",
    item = "quit",
    description = "Close this prompt",
    command = "q!"
  })

  nvim.nvim_command("map <buffer> q <Cmd>lua require('impromptu').core.destroy("  .. obj.session .. ")<CR>")

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

  obj.header = args.question
  obj.lines = args.options
  obj.handler = args.handler

  obj = impromptu.ll.show(obj)
  obj = impromptu.ll.render(obj)

  return obj
end

impromptu.core.callback = function(session, option)
  local obj = impromptu.memory[session]

  if obj ~= nil then
    obj:handler(option)
  end

  if obj.should_close == nil or obj.should_close then
    impromptu.core.destroy(obj)
  end
end

return impromptu
