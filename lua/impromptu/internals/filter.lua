-- luacheck: globals unpack vim
local utils = require("impromptu.utils")
local shared = require("impromptu.internals.shared")

local filter = {}

filter.render_line = function(line)
    return "   " .. line.description
end

local to_mapping = function(key, session_id, callback_id, modes)
  vim.api.nvim_command(
    "imap <buffer> ".. key .." " ..
    "<Cmd>lua require('impromptu').callback("  ..
    session_id ..
    ", '".. callback_id .."')<CR>"
  )

  vim.api.nvim_command(
    "nmap <buffer> ".. key .." " ..
    "<Cmd>lua require('impromptu').callback("  ..
    session_id ..
    ", '".. callback_id .."')<CR>"
  )

end

filter.do_mappings = function(obj)
  vim.api.nvim_command("mapclear <buffer>")
  to_mapping("<BS>", obj.session_id, "__backspace")
  to_mapping("<CR>", obj.session_id, "__select")
  to_mapping("<C-n>", obj.session_id, "__down")
  to_mapping("<C-p>", obj.session_id, "__up")
  to_mapping("<C-c>", obj.session_id, "__quit")

  for key, callback_id in pairs(obj.mappings) do
    to_mapping(key, obj.session_id, callback_id)
  end

  vim.api.nvim_command(
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
  local content = {}
  local lines = utils.map(opts, filter.render_line)

  if lines[obj.offset] ~= nil then
    lines[obj.offset] = utils.replace_at(lines[obj.offset], "→", 2)
  end

  local add = function(coll)
    for _, line in ipairs(coll) do
      table.insert(content, line)
    end
  end

  add(shared.header(obj, window_ops))
  add(lines)
  add(shared.spacer(lines, window_ops))
  add(shared.footer(table.concat(obj.filter_exprs, " "), window_ops))

  return content
end

filter.get_options = function(obj, window_ops)
  local options = {}
  local max_items = shared.draw_area_size(window_ops)
  if obj.offset > max_items then
    obj.slide = obj.slide + 1
  elseif obj.offset < 1 then
    obj.offset = 1
    if obj.slide > 0 then
      obj.slide = obj.slide - 1
    end
  end

  local dropped = {}

  for line in utils.take(
    max_items,
    utils.drop(
      dropped,
      obj.slide,
      obj.filter_fn(obj.filter_exprs, obj.lines)
      )
    ) do
    table.insert(options, line)
  end

  if #options == 0 then
    return {}
  elseif #options == max_items then
    obj.full = true
  end

  if obj.offset >= #options then
    obj.offset = #options
  end

  obj.selected = options[obj.offset]

  return options
end

filter.filter_fn = function(filter_exprs, lines)
  local ix = 1
  local max = #lines

  if max == 0 then
    return function() return end
  end

  local function nxt()
    local itm = lines[ix]
    ix = ix + 1

    if itm == nil then
      return
    elseif itm.description == "" then
      return nxt()
    end

    for _, filter_expr in ipairs(filter_exprs) do
      if not string.find(itm.description:lower(), filter_expr:lower(), 1, true) then
        return nxt()
      end
    end
    return itm
  end

  return nxt
end

filter.append = function(obj, opt)

  obj.full = nil

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

filter.do_hl = function(obj)
  for ix = #obj.hls, 1, -1 do
    vim.fn.matchdelete(obj.hls[ix])
    table.remove(obj.hls, ix)
  end

  local exprs_sz = #obj.filter_exprs
  table.insert(obj.hls, vim.fn.matchaddpos("Operator", {1, 20}))
  for ix, expr in ipairs(obj.filter_exprs) do
    if expr ~= "" then
      local hl

      if ix == exprs_sz then
        hl = "Keyword"
      else
        hl = "Function"
      end

      table.insert(obj.hls, vim.fn.matchadd(hl, "\\c" .. expr))
    end
  end

end

filter.render = function(obj)
  local first_run = obj.first == nil
  obj.first = 1
  local window_ops = shared.with_bottom_offset(shared.window_for_obj(obj))

  if first_run then
    vim.fn.matchadd("WarningMsg", " →")
    filter.do_mappings(obj)
  end

  if #obj.staged_expr == 0 and obj.full == nil then
    local opts = filter.get_options(obj, window_ops)
    local content = filter.draw(obj, opts, window_ops)

    filter.do_hl(obj)
    vim.api.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
    vim.api.nvim_win_set_cursor(window_ops.window, {#content, utils.displaywidth(content[#content])})
    vim.api.nvim_command("startinsert!")
  end

  return obj
end

filter.move_selection = function(obj, direction)
  obj.offset = obj.offset + direction
  obj.full = nil
  return true
end

filter.handle = function(obj, option)
  if option == "__select" then
    vim.api.nvim_command("stopinsert")
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
  elseif utils.starts_with(option, "__") then
    return obj:handler(option)
  else
    filter.stage(obj, option)
  end

  return false
end

filter.update = function(obj, data)
  if data.description ~= "" then
    table.insert(obj.lines, data)
    return filter.render(obj)
  end
end

return filter
