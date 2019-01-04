-- luacheck: globals unpack vim
local nvim = vim.api
local utils = require("impromptu.utils")
local shared = require("impromptu.internals.shared")

local filter = {}

filter.render_line = function(line)
    return  (line.selected and " > " or "   ") .. line.description
end

filter.get_header = function(obj)
  local header = ""

  if obj.header ~= nil then
    header = obj.header
  end

   return header
 end

 filter.do_mappings = function(obj)
  nvim.nvim_command("mapclear <buffer>")
  nvim.nvim_command(
    "imap <buffer> <BS> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__backspace')<CR>"
    )
  nvim.nvim_command(
    "nmap <buffer> <CR> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__select')<CR>"
  )

  nvim.nvim_command(
    "imap <buffer> <CR> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__select')<CR>"
  )

  nvim.nvim_command(
    "nmap <buffer> j " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__down')<CR>"
  )
  nvim.nvim_command(
    "nmap <buffer> k " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__up')<CR>"
  )

  nvim.nvim_command(
    "imap <buffer> <C-j> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__down')<CR>"
  )
  nvim.nvim_command(
    "imap <buffer> <C-k> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__up')<CR>"
  )

  nvim.nvim_command(
    "imap <buffer> <C-c> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__quit')<CR>"
  )

  nvim.nvim_command(
    "nmap <buffer> <C-c> " ..
    "<Cmd>lua require('impromptu').callback("  ..
    obj.session_id ..
    ", '__quit')<CR>"
  )

  nvim.nvim_command(
    "augroup impromtpu | " ..
    "au! InsertCharPre <buffer="  .. obj.buffer .. "> " ..
    "exe 'lua require(\"impromptu\").callback(" ..
    obj.session_id ..
    ", \"' . v:char . '\")' | " ..
    "au! TextChangedI <buffer="  .. obj.buffer .. "> " ..
    "exe 'lua require(\"impromptu\").callback(" ..
    obj.session_id ..
    ", \"__flush\")' | " ..
    "augroup END"
  )

 end

filter.draw = function(obj, opts, window_ops)
  local header = filter.get_header(obj)
  local content = {}

  -- TODO move to own fn
  if header ~= "" then
    table.insert(content, header)
    table.insert(content, shared.div(window_ops.width))
  end

  table.insert(content, "")

  for _, line in ipairs(utils.map(opts, filter.render_line)) do
    table.insert(content, line)
  end

  if #content < (window_ops.height - window_ops.bottom_offset) then
    local fill = window_ops.height - #content - window_ops.bottom_offset
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  -- TODO move to own fn
  table.insert(content, "")
  table.insert(content, shared.sub_div(window_ops.width))
  table.insert(content, table.concat(obj.filter_exprs, " "))

  return content
 end

filter.get_options = function(obj, window_ops)
  local options = {}
  local max_items = window_ops.height - (window_ops.top_offset + window_ops.bottom_offset)

  local filtered = obj.filter_fn(obj.filter_exprs, obj.lines)

  for ix, line in ipairs(filtered) do
    local opt = utils.clone(line)
    opt.selected = false
    table.insert(options, opt)

    if ix == max_items then
      break
    end
  end

  if #options == 0 then
    return {}
  end


  if obj.offset >= #options then
    obj.offset = #options
  elseif obj.offset < 1 then
    obj.offset = 1
  end

  options[obj.offset].selected = true

  obj.selected = utils.clone(options[obj.offset])
  obj.selected['selected'] = nil

  return options
end

filter.filter_fn = function(filter_exprs, lines)
  local current = utils.clone(lines)

  for _, filter_expr in ipairs(filter_exprs) do
    local tmp = {}

    for _, line in ipairs(current) do
      if string.find(line.description, filter_expr) then
        table.insert(tmp, line)
      end
    end

    current = tmp
  end

  return current
end

filter.append = function(obj, opt)

  if opt == " " then
    table.insert(obj.filter_exprs, "")

  elseif type(opt) == "string" then
    obj.filter_exprs[#obj.filter_exprs] = obj.filter_exprs[#obj.filter_exprs] .. opt

  elseif type(opt) == "number" then
    if #obj.filter_exprs == 1 and obj.filter_exprs[1] == "" then
      return
    end

    local sz = utils.displaywidth(obj.filter_exprs[#obj.filter_exprs])

    if sz == 0 then
      table.remove(obj.filter_exprs, #obj.filter_exprs)
    else
      local tgt = sz + opt
      local ix = 0
      local tmp = {}

      for c in obj.filter_exprs[#obj.filter_exprs]:gmatch(".") do
        if ix == tgt then
          break
        end

        ix = ix + 1
        table.insert(tmp, c)
      end

      obj.filter_exprs[#obj.filter_exprs] = table.concat(tmp, "")
    end
  end
end

filter.stage = function(obj, opt)
  table.insert(obj.staged_expr, opt)
end

filter.render = function(obj)
  if #obj.staged_expr == 0 then
    local window_ops = shared.window_for_obj(obj)

    -- TODO move to own fn
    window_ops.top_offset = 1
    if obj.header ~= nil then
      window_ops.top_offset = window_ops.top_offset + 2
    end

    window_ops.bottom_offset = 3

    local opts = filter.get_options(obj, window_ops)
    local content = filter.draw(obj, opts, window_ops)

    filter.do_mappings(obj)

    nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
    nvim.nvim_win_set_cursor(window_ops.window, {#content, utils.displaywidth(content[#content])})
    nvim.nvim_command("startinsert")
  end

  return obj
end

filter.move_selection = function(obj, direction)
  obj.offset = obj.offset + direction
  return true
end

filter.handle = function(obj, option)
  if option == "__select" then
    return obj:handler(obj.selected)
  elseif option == "__up" then
    filter.move_selection(obj, -1)
  elseif option == "__down" then
    filter.move_selection(obj, 1)
  elseif option == "__backspace" then
    filter.append(obj, -1)
  elseif option == "__flush" then
    for _, opt in ipairs(obj.staged_expr) do
      filter.append(obj, opt)
    end
      obj.staged_expr = {}
  else
    filter.stage(obj, option)
  end

  return false
end

filter.update = function(obj, data)
  table.insert(obj.lines, data)
  return filter.render(obj)
end

return filter
