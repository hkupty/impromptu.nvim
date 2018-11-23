-- luacheck: globals unpack vim utf8
local nvim = vim.api
local utils = require("impromptu.utils")
local shared = require("impromptu.internals.shared")

local form = {}

form.line = function(opt)
    return  "  • " .. opt.description .. ": "
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
 end

form.draw = function(obj, window_ops)
  local header = form.get_header(obj)

  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, shared.div(window_ops.width))
  end

  table.insert(content, "")

  for _, line in pairs(obj.questions) do
    table.insert(content, form.line(line))
  end

  if #content < window_ops.height then
    local fill = window_ops.height - #content
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  return content
 end

form.render = function(obj)
  local window_ops = shared.window_for_obj(obj)

  form.do_mappings(obj)
  local content = form.draw(obj, window_ops)

  nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
end

form.handle = function(obj, option)
  local lines = nvim.nvim_buf_get_lines(obj.buffer, 0, -1, false)
  local mapping = {}
  local answers = {}

  for _, v in ipairs(lines) do
    local question, answer = v:gmatch("  • (%s+): (%s+)")
    if question ~= nil then
      mapping[question] = answer
    end
  end

  for k, v in pairs(obj.questsions) do
    answers[k] = mapping[v.description]
  end

  return answers
end

return form

