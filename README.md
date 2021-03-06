# Neo-tree-zk

A [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) source for [zk-nvim](https://github.com/mickael-menu/zk-nvim).

## Installation

Via [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "prncss-xyz/neo-tree-zk.nvim",
  requires = {
    "nvim-neo-tree/neo-tree.nvim",
    "mickael-menu/zk-nvim"
  },
}
```

## Setup

In your [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) config:

```lua
  require("neo-tree").setup {
    sources = {
      -- default sources
      "filesystem",
      "buffers",
      "git_status",
      -- user sources goes here
      "zk",
    },
    -- ...
    zk = {
      follow_current_file = true,
      window = {
        mappings = {
          ["n"] = "change_query",
        },
      },
    }
```

## Usage

From you zk directory, call `:Neotree source=zk`.

Then use the 'change_query' command (`n`) to see notes belonging to the selected query.
