# Implementing tree-based prompts

This is a small documentation for tree-based prompts.

## How it works?

It is the same thing as the normal ones, except that you can have multiple levels before handling the option.

On your handle function, you'll receive the session object, which contains the `breadcrumbs` object.

It is both the breadcrumbs for the display and the 'lens' for selecting the nested options.

## How to

You'll need to supply a `children` key to your options.

```lua
{
  options = {
    item = {
      description = "Tree option",
      children = {
        child1 = {
          description = "Child1 value", -- A leaf object
        },
        child2 = {
          description = "Child2 value", -- A leaf object
        }
      }
    },
    item2 = {
      description = "A option", -- Another leaf object
    },
  handler = function(...)
  -- ..
  end
}
```

Note that choosing a menu entry either traverses the tree or calls the handler, meaning that only "leaf" objects will trigger the provided function.

When choosing e.g. menu options "Tree option" and then "Child1 value", the table `session.breadcrumbs` will be `{ {"item"} }`, while the second argument to the handler will be `"child1"`, allowing the handler function to both infer the chosen option as well as the path taken through the menus.
