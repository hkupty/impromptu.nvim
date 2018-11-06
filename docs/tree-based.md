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
        child = {
          description = "Child value"
        },
        leaf = {
          description = "Leaf value"
        }
      }
    },
  handler = function(...)
  -- ..
  end
}
```

Note that it either traverses the tree or calls the handler, meaning that only "leaf" objects will trigger the provided function.

