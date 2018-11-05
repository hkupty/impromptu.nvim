local impromptu = require("impromptu")
local nvim = vim.api

_G.test_tree = function()
  local opts = {
    one = {
      description = "Item 1",
      children = {
        eleven = {description = "Item 11"},
        twelve = {description = "Item 12"},
      }
    },
    two = {
      description = "Item 2",
      children = {
        twentyone = {
          description = "Item 21",
          children = {
            twohundredten = {description = "Item 210"}
          }
        },
        twentytwo = {
          description = "Item 22",
          children = {
            twohundredtwenty = {
              description = "Item 220",
              children = {
                really = {description  = "Really?"},
                no_way = {description  = "No way!"}
              }
            }
          }
        },
      }
    }
  }

  impromptu.core.ask{
    question = "Navigate over the tree",
    options = opts,
    handler = function(_, opt)
      print(opt)
      return true
    end
  }
end

nvim.nvim_command("command! -nargs=0 TestTree lua test_tree()")
