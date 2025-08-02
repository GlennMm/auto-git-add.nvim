# auto-git-add.nvim

A Neovim plugin that automatically runs `git add` on newly created files when you're working in a git repository.

## Features

- 🚀 **Automatic git add** for newly created files
- 🎯 **Smart filtering** with include/exclude patterns  
- 📏 **File size limits** to avoid adding huge files
- 📁 **Directory restrictions** to only add files in specific folders
- ⏱️ **Delayed processing** to avoid rapid-fire git operations
- 🔔 **Configurable notifications**
- 🎛️ **Multiple trigger modes** for different workflows
- 🧹 **Proper cleanup** and resource management

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'GlennMm/auto-git-add.nvim',
  event = 'VeryLazy',
  config = function()
    require('auto-git-add').setup({
      -- your configuration here
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'GlennMm/auto-git-add.nvim',
  config = function()
    require('auto-git-add').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'GlennMm/auto-git-add.nvim'
```

Then in your `init.lua`:
```lua
require('auto-git-add').setup()
```

### Using vim.pack (Neovim's built-in package manager)

Add this to your `init.lua`:

```lua
-- Add the plugin
vim.pack.add({
  'https://github.com/GlennMm/auto-git-add.nvim'
})

-- Configure it
require('auto-git-add').setup({
  -- your configuration here
})
```

For more advanced usage with version constraints:

```lua
vim.pack.add({
  {
    src = 'https://github.com/GlennMm/auto-git-add.nvim',
    name = 'auto-git-add',
    -- Use latest stable version
    version = vim.version.range('1.*'),
  }
})

require('auto-git-add').setup()
```

Then restart Neovim with `:restart`. The plugin will be automatically installed and loaded.

To update the plugin later, run:
```vim
:lua vim.pack.update()
```

## Configuration

### Default Configuration

```lua
require('auto-git-add').setup({
  -- Enable/disable the plugin
  enabled = true,
  
  -- Trigger modes: 'all', 'manual', 'edit-command-only'
  trigger_mode = 'manual',
  
  -- Patterns to exclude from auto-adding
  exclude_patterns = {
    '%.tmp$', '%.log$', '%.swp$', '%.swo$', '%.DS_Store$',
    '^%.git/', 'node_modules/', '__pycache__/',
    '%.min%.js$', '%.min%.css$', '%.pyc$', '%.o$'
  },
  
  -- File patterns to include (if empty, includes all)
  include_patterns = {},
  
  -- Show notification when file is added
  show_notifications = true,
  
  -- Notification level
  notification_level = vim.log.levels.INFO,
  
  -- Auto-add files only in specific directories relative to git root
  restrict_to_dirs = {},
  
  -- Maximum file size to auto-add (in bytes, 0 = no limit)
  max_file_size = 10 * 1024 * 1024, -- 10MB
  
  -- Delay before adding (in ms)
  delay_ms = 500,
})
```

### Trigger Modes

- **`'all'`**: Add any new file when saved (most permissive)
- **`'manual'`**: Only add files created via `:e`, `:new`, etc. (excludes plugin-generated files)
- **`'edit-command-only'`**: Only add files created via `:e`/`:edit` commands (most restrictive)

### Example Configurations

#### For JavaScript/TypeScript projects:
```lua
require('auto-git-add').setup({
  include_patterns = {
    '%.js$', '%.ts$', '%.jsx$', '%.tsx$',
    '%.json$', '%.md$'
  },
  restrict_to_dirs = { 'src', 'lib', 'components', 'pages' },
  max_file_size = 5 * 1024 * 1024, -- 5MB
})
```

#### For Python projects:
```lua
require('auto-git-add').setup({
  include_patterns = { '%.py$', '%.md$', '%.txt$', '%.yml$', '%.yaml$' },
  exclude_patterns = { 
    '__pycache__/', '%.pyc$', '%.pyo$', '%.egg-info/',
    'venv/', '%.env$', 'dist/', 'build/'
  },
  restrict_to_dirs = { 'src', 'tests', 'docs' },
})
```

## Commands

- `:AutoGitAddEnable` - Enable the plugin
- `:AutoGitAddDisable` - Disable the plugin  
- `:AutoGitAddToggle` - Toggle the plugin on/off
- `:AutoGitAddStatus` - Show current status and configuration
- `:AutoGitAddFile [file]` - Manually add a file (defaults to current file)

## Default Keymaps

The plugin provides these default keymaps (can be disabled):

- `<leader>ga` - Add current file to git
- `<leader>gt` - Toggle auto git add
- `<leader>gs` - Show status

To disable default keymaps:
```lua
vim.g.auto_git_add_no_default_mappings = true
```

## Advanced Configuration

### Global Configuration (before plugin loads)
```lua
-- In your init.lua, before plugin loads
vim.g.auto_git_add_config = {
  enabled = true,
  trigger_mode = 'edit-command-only',
  show_notifications = false
}
```

### Custom Keymaps
```lua
vim.keymap.set('n', '<leader>gA', '<cmd>AutoGitAddFile<CR>')
vim.keymap.set('n', '<leader>gT', '<cmd>AutoGitAddToggle<CR>')
vim.keymap.set('n', '<leader>gS', '<cmd>AutoGitAddStatus<CR>')
```

## Requirements

- Neovim 0.8+
- Git installed and available in PATH
- Working in a git repository

## How It Works

1. **File Creation Detection**: Monitors file creation via autocommands
2. **Git Repository Check**: Verifies you're in a git repository
3. **Filter Application**: Applies include/exclude patterns and other filters
4. **Git Status Check**: Checks if file is already tracked
5. **Delayed Addition**: Waits for configured delay to avoid rapid operations
6. **Git Add**: Runs `git add` asynchronously using `vim.loop`

## Troubleshooting

### Plugin not working?
1. Check `:AutoGitAddStatus` to see current configuration
2. Verify you're in a git repository
3. Check if files match your include/exclude patterns
4. Ensure git is installed and accessible

### Too many notifications?
```lua
require('auto-git-add').setup({
  show_notifications = false,
  -- or change level
  notification_level = vim.log.levels.WARN
})
```

### Files not being added?
- Check your `exclude_patterns` and `include_patterns`
- Verify `max_file_size` setting
- Check `restrict_to_dirs` if you've set it
- Try different `trigger_mode`

## Contributing

Issues and pull requests are welcome! Please:

1. Check existing issues first
2. Add tests for new features
3. Update documentation
4. Follow the existing code style

## License

MIT License - see [LICENSE](LICENSE) file for details.