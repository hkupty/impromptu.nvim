-- luacheck: globals unpack vim utf8
local nvim = vim.api
local utils = require("impromptu.utils")
local shared = require("impromptu.internals.shared")

local form = {}

form.line = function(key, opt)
    return  key .. "| " .. opt.description .. ": "
end

form.get_header = function(obj)
  local header = ""

  if obj.header ~= nil then
    header = obj.header
  end

   return header
 end

 form.do_mappings = function(obj)
  nvim.nvim_command("mapclear <buffer>")
  nvim.nvim_command(
    "nmap <buffer> <Tab> <Cmd>lua require('impromptu').callback(" ..
    obj.session_id ..
    ", '__next')<CR>"
  )
  nvim.nvim_command(
    "imap <buffer> <Tab> <Cmd>lua require('impromptu').callback(" ..
    obj.session_id ..
    ", '__next')<CR>"
  )

  nvim.nvim_command(
    "nmap <buffer> <CR> <Cmd>lua require('impromptu').callback(" ..
    obj.session_id ..
    ", '__submit')<CR>"
  )

  nvim.nvim_command(
    "imap <buffer> <CR> <Cmd>lua require('impromptu').callback(" ..
    obj.session_id ..
    ", '__submit')<CR>"
  )
 end

form.set_cursor = function(obj, key)
  local pos = obj.pos[key]
  local window_ops = shared.window_for_obj(obj)

  nvim.nvim_win_set_cursor(window_ops.window, pos)
  obj.current = key
end

form.draw = function(obj, window_ops)
  local header = form.get_header(obj)
  local first
  local order = {}
  local ix
  obj.pos = {}
  nvim.nvim_command("setl conceallevel=2 concealcursor=nvic")


  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, shared.div(window_ops.width))
  end

  table.insert(content, "")

  for key, line in pairs(obj.questions) do
    if first == nil then
      first = key
    end

    nvim.nvim_call_function("matchadd", {"Conceal", key .. "|", 10, -1, { conceal = "•"}})
    local ln_str = form.line(key, line)
    table.insert(content, ln_str)
    obj.pos[key] = {#content, utils.displaywidth(ln_str) }

    if ix ~= nil then
      order[ix] = key
    end
    ix = key
  end
  order[ix] = first

  if #content < window_ops.height then
    local fill = window_ops.height - #content
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  obj.order = order
  obj.current = first
  return content
end

form.render = function(obj)
  local first_run = obj.form == nil
  local window_ops = shared.window_for_obj(obj)

  if first_run then
    obj.form = true
    -- FIXME: Stack/pop should cleanup type specific settings from buffer
    nvim.nvim_buf_set_option(obj.buffer, "modifiable", true)
    nvim.nvim_buf_set_option(obj.buffer, "readonly", false)

    form.do_mappings(obj)
    local content = form.draw(obj, window_ops)

    nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
    form.set_cursor(obj, obj.current)
  end

  return obj
end

form.handle = function(obj, arg)
  local lines = nvim.nvim_buf_get_lines(obj.buffer, 0, -1, false)
  local answers = {}

  if arg == "__submit" then
    for _, v in ipairs(lines) do
      local key, content = unpack(utils.split(v, "|"))
      if content ~= nil then
        answers[key] = utils.trim(utils.split(content, ":")[2])
      end
    end

    if nvim.nvim_get_mode().mode ~= "n" then
      nvim.nvim_command("stopinsert")
    end

    return obj:handler(answers)
  elseif arg == "__next" then
    local nxt = obj.order[obj.current]
    form.set_cursor(obj, nxt)
  end
  return false
end

return form

