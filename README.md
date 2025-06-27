# nvim-gitrepo

A Neovim plugin for fast Git repo discovery and dirty repo management, with seamless integration for lazygit.

## Features
- Recursively scan for Git repositories under a root directory, with support for excluding directories.
- List all dirty (modified) repositories and select them via `vim.ui.select`.
- One-click open the selected repo in lazygit, auto-switching working directory and restoring after exit.
- Branch and dirty status display.

## Requirements
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [kdheepak/lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) (and [lazygit](https://github.com/jesseduffield/lazygit) installed)

## Project Structure

```
nvim-gitrepo/
├── lua/
│   └── gitrepo/
│       └── init.lua      # Main plugin code
├── README.md             # This file
├── LICENSE               # Apache 2.0 License
```

## Installation (with lazy.nvim)

```lua
{
  "liYony/nvim-gitrepo.nvim",
  dependencies = {
    'nvim-lua/plenary.nvim',
    'kdheepak/lazygit.nvim',
  }
}
```

## Usage

- `:GitRepoInit`   — Scan and cache all git repos under root
- `:GitRepoLoad`   — Load repo info (branch, dirty status)
- `:GitRepoSelect` — Select dirty repo and open in lazygit

You can also call `require('gitrepo').gitrepo_init()`, `gitrepo_load()`, `gitrepo_select()` in Lua.

## Example

```lua
require('gitrepo').setup({
  root = '/your/project/root',
  excluded_dir = { 'build', 'output' },
  setup_load = true,
})
```

## License
Apache-2.0. See LICENSE for details.
