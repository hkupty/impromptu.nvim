-- luacheck: globals unpack vim utf8
local impromptu = require("impromptu")
local nvim = vim.api

local test_functions = {}

test_functions.mixed = function()

  impromptu.ask{
    question = "Add stuff here",
    options = {
      add = {
        description = "Add something"
      }
    },
    quitable = true,
    handler = function(session, _)
      impromptu.session.stack_into(session, "form", {
          title = "Something awesome:",
          questions = {
              key = {
                description = "The key"
              },
              value = {
                description = "The value"
              }
          },
          handler = function(inner_session, ret)
            impromptu.session.pop_from(inner_session)

            inner_session.lines[ret.key] = {
              description = ret.value
            }
            return false
          end
        })


      return false
    end
  }
end


test_functions.form = function()

  impromptu.form{
    title = "Answer:",
    questions = {
      weight = {
        description = "The weight"
      },
      size = {
        description = "The size"
      }
    },
    handler = function(_, ret_obj)
      local result
      if ret_obj.size == "4" then
        result = "correct"
      else
        result = "wrong"
      end

      print("Result is .. " .. result)
      return true
    end
  }
end

test_functions.mutating = function()
  local opts = {
    first = {
      description = "First Item",
      children = {
        this = {
          description = "This is the one"
        }
      }
    }
  }

  impromptu.ask{
    question = "Do the mutation",
    quitable = false,
    options = opts,
    columns = function(_, copts)
      return math.ceil(#copts / 0.8)
    end,
    handler = function(session, opt)
      if opt == "this" then
        session.lines.exit = {
          description = "Quit here!",
        }
      elseif opt == "exit" then
        session.lines.exit.description = "I fooled you! Here!"
        session.lines.exit.children = {
          now = {
            description = "Now we're talking",
          }
        }
      elseif opt == "now" then
        table.remove(session.breadcrumbs, #session.breadcrumbs)
        session.lines.finally = {
          description = "The light! Quick! Come here!",
        }
      elseif opt == "finally" then
        return true
      end
      return false
    end
  }
end

_G.call_fn = function(fn)
  test_functions[fn]()
end

nvim.nvim_command("command! -nargs=1 ImpromptuTest lua call_fn(<f-args>)")
