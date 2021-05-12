-- luacheck: globals unpack vim utf8
local shared = require("impromptu.internals.shared")

local form = {}

form.get_header = function(obj)
  local header = ""

  if obj.header ~= nil then
    header = obj.header
  end

  return header
end


form.draw = function(obj, window_ops)
  local header = form.get_header(obj)

  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, shared.div(window_ops.width))
  end

  for key, line in pairs(obj.lines) do
    if first == nil then
      first = key
    end

    vim.fn.matchadd("Conceal", key .. "|", 10, -1, { conceal = "•"})
    local ln_str = form.line(key, line)
    table.insert(content, ln_str)
    obj.pos[key] = {#content, utils.strwidth(ln_str) }

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
    vim.api.nvim_buf_set_option(obj.buffer, "modifiable", true)
    vim.api.nvim_buf_set_option(obj.buffer, "readonly", false)

    form.do_mappings(obj)
    local content = form.draw(obj, window_ops)

    vim.api.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
    form.set_cursor(obj, obj.current)
    vim.api.nvim_command("startinsert")
  end

  return obj
end

form.handle = function(obj, arg)
  local lines = vim.api.nvim_buf_get_lines(obj.buffer, 0, -1, false)
  local answers = {}

  if arg == "__submit" then
    for _, v in ipairs(lines) do
      local key, content = unpack(utils.split(v, "|"))
      if content ~= nil then
        answers[key] = utils.trim(utils.split(content, ":")[2])
      end
    end

    if vim.api.nvim_get_mode().mode ~= "n" then
      vim.api.nvim_command("stopinsert")
    end

    return obj:handler(answers)
  elseif arg == "__next" then
    local nxt = obj.order[obj.current]
    form.set_cursor(obj, nxt)
  end
  return false
end

return form

