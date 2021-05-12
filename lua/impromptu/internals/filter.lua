-- luacheck: globals unpack vim
local utils = require("impromptu.utils")
local shared = require("impromptu.internals.shared")
local proxy = require("impromptu.proxy")


local filter = {}

local ns = vim.api.nvim_create_namespace("impromptu.filter")

filter.at_max_width = function(width)
  return function(str)
    local sz = utils.displaywidth(str)
    if sz > (width - 4) then
      str = "..." .. string.sub(str, (sz - width + 7), sz)
    end
    return str
  end
end

filter.render_line = function(width)
  local at_width = filter.at_max_width(width)
  return function(line)
    return "   " .. at_width(line.description)
  end
end

local to_mapping = function(key, session_id, callback_id)
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
  to_mapping("<C-l>", obj.session_id, "__clear")
  to_mapping("<C-x>", obj.session_id, "__clear_word")
  to_mapping("<C-n>", obj.session_id, "__down")
  to_mapping("<C-p>", obj.session_id, "__up")
  to_mapping("<C-c>", obj.session_id, "__quit")

  for key, callback_id in pairs(obj.mappings) do
    to_mapping(key, obj.session_id, callback_id)
  end

  -- TODO try vim.register_keystroke_callback

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
  local lines = utils.map(opts, filter.render_line(window_ops.width))

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

filter.rank = function(tbl)
  table.sort(tbl, function(a, b)
    if a.score ~= nil and b.score ~= nil then
      return a.score > b.score
    else
      return #a.description < #b.description
    end
  end)
end

filter._set_hl = function(_, _, bufnr, _, _)
  local obj = proxy.reverse_lookup("buffer", bufnr)
  if obj == nil or obj.type ~= "filter"  then
    return true
  end
  local window_ops = shared.with_bottom_offset(shared.window_for_obj(obj))
  local lines = vim.api.nvim_buf_get_lines(
    bufnr, window_ops.top_offset, -1 * (window_ops.bottom_offset + 1), false)

  for i, line in ipairs(lines) do
    if line == "" then
      break
    end

    local line_descr = obj.current_opts[i]
    local posno = #line_descr.positions
    local maxc = vim.fn.strlen(line)
    local space = 2
    local line_ix = i + window_ops.top_offset - 1

    local highlight = "Function"

    if i == obj.offset then
      space = space + 2
      vim.api.nvim_buf_set_extmark(
        bufnr,
        ns,
        line_ix,
        0,
        {
          hl_group = "WarningMsg",
          end_col = 4,
          ephemeral = true
        })
    end

    for cnt, chunk in ipairs(line_descr.positions) do

      if cnt == posno then
        highlight = "Keyword"
      end

      vim.api.nvim_buf_set_extmark(
        bufnr,
        ns,
        line_ix,
        math.min(maxc, chunk[1] + space),
        {
          hl_group = highlight,
          end_col = math.min(maxc, chunk[2] + space + 1),
          ephemeral = true
        })
    end

  end

  -- No need to run down the chain
  return false
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
    line.positions = line.positions or {}
    table.insert(options, line)
  end

  if #options == 0 then
    return {}
  elseif #options == max_items then
    obj.full = true
  end

  filter.rank(options)

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

  if #filter_exprs == 1 and filter_exprs[1] == "" then
    return function()
      local itm = lines[ix]
      ix = ix + 1
      return itm
    end
  end

  local function nxt()
    local itm = lines[ix]
    ix = ix + 1

    if itm == nil then
      return
    elseif itm.description == "" then
      return nxt()
    end

    local positions = {}

    for _, filter_expr in ipairs(filter_exprs) do
      local fnd, x = string.find(itm.description:lower(), filter_expr:lower())
      if not fnd then
        return nxt()
      end
      table.insert(positions, {fnd, x})
    end
    itm.positions = positions
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

filter.cleanup = function(obj)
  obj.first = nil
end

filter.render = function(obj)
  local first_run = obj.first == nil
  obj.first = 1
  local window_ops = shared.with_bottom_offset(shared.window_for_obj(obj))

  if first_run then
    --vim.fn.matchadd("WarningMsg", " →")
    filter.do_mappings(obj)
  end

  if #obj.staged_expr == 0 and obj.full == nil then
    local opts = filter.get_options(obj, window_ops)
    local content = filter.draw(obj, opts, window_ops)
    obj.current_opts = opts

    vim.api.nvim_buf_set_option(obj.buffer, "modifiable", true)
    vim.api.nvim_buf_set_option(obj.buffer, "readonly", false)
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

filter.clear_word = function(obj)
  local lst
  local filter_exprs = {}
  for i, v in ipairs(obj.filter_exprs) do
    if v == "" then
      break
    else
      lst = i
    end
  end
  for i=1, lst - 1, 1  do
    filter_exprs[i] = obj.filter_exprs[i]
  end
  table.insert(filter_exprs, "")
  obj.filter_exprs = filter_exprs
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
  elseif option == "__clear" then
    obj.filter_exprs = {""}
  elseif option == "__clear_word" then
    filter.clear_word(obj)
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


vim.api.nvim_set_decoration_provider(ns, {
    on_win = filter._set_hl
})

return filter
