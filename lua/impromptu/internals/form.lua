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

  return content
end

form.render = function(obj)
  local first_run = obj.form == nil
  local window_ops = shared.window_for_obj(obj)
  local header = form.draw(obj, window_ops)

  if first_run then
    obj.form = true
    obj.index = 1
    obj.answers = {}
    -- FIXME: Stack/pop should cleanup type specific settings from buffer
    vim.api.nvim_buf_set_option(obj.buffer, "buftype", "prompt")
    vim.api.nvim_buf_set_option(obj.buffer, "modifiable", true)
    vim.api.nvim_buf_set_option(obj.buffer, "readonly", false)

    vim.fn.prompt_setcallback(obj.buffer, function(text)
      obj.answers[obj.lines[obj.index].index] = text
      obj.index = obj.index + 1
      require("impromptu").callback(obj.session_id, "__next")
    end)

    vim.fn.prompt_setinterrupt(obj.buffer, function()
      require("impromptu").callback(obj.session_id, "__quit")
    end)

  end
  vim.api.nvim_buf_set_lines(obj.buffer, 0, -1, false, header)
  vim.fn.prompt_setprompt(obj.buffer, obj.lines[obj.index].description .. ": ")
  vim.api.nvim_command("startinsert")

  return obj
end

form.handle = function(obj, arg)
  local curr_index = obj.index

  if arg == "__next" then
    if curr_index >= #obj.lines then
      if vim.api.nvim_get_mode().mode ~= "n" then
        vim.api.nvim_command("stopinsert")
      end

      return obj:handler(obj.answers)
    end
  elseif arg == "__previous" then
    obj.index = curr_index - 1
  end
  return false
end

return form

