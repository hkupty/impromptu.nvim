-- luacheck: globals unpack
local utils = require("impromptu.utils")
local internals = require("impromptu.internals")
local sessions = require("impromptu.sessions")

local impromptu = {
  session = {}
}

local proxy = function(session)
  local obj = {session_id = session}

  setmetatable(obj, {
    __index = function(_, key)
      local s = sessions[session]
      return s._col[#s._col][key] or s[key]
    end,
    __newindex = function(_, key, value)
      local s = sessions[session]
      s._col[#s._col][key] = value
    end})

    return obj
end

local new_obj = function()
  local session = math.random(10000, 99999)

  sessions[session] = {
    _col = {{}},
    set = function(_, key, value)
      rawset(sessions[session], key, value)
    end,
    stack = function(this, new)
      table.insert(this._col, new)
      return this
    end,
    pop = function(this)
      table.remove(this._col, #this._col)
      return this
    end
  }

  return proxy(session)
end

local xf_args = {
  ask = function(args)
    return {
      quitable = utils.default(args.quitable, true),
      header = args.question,
      breadcrumbs = {},
      lines = args.options,
      handler = args.handler,
      sort = utils.default(args.sort, internals.shared.sort),
      is_compact = utils.default(args.compact_columns, false),
      type = "ask",
    }
  end,
  form = function(args)
    return {
      header = args.title,
      questions = args.questions,
      handler = args.handler,
      type = "form",
    }
  end
}

impromptu.session.stack_into = function(obj, tp, args)
  return obj:stack(xf_args[tp](args))
end

impromptu.session.pop_from = function(obj)
  return obj:pop()
end

impromptu.ask = function(args)
  return internals.render(impromptu.session.stack_into(new_obj(), "ask", args))
end

impromptu.form = function(args)
  return internals.render(impromptu.session.stack_into(new_obj(), "form", args))
end

impromptu.callback = function(session, option)
  local obj = proxy(session)

  if obj == nil then
     return
  elseif option == "__quit" then
    internals.destroy(obj)
    return
  end

  if internals.handle(obj, option) then
    internals.destroy(obj)
  else
    internals.render(obj)
  end
end

return impromptu
