-- Prevent loading twice
if vim.g.loaded_auto_git_add then
  return
end
vim.g.loaded_auto_git_add = true

-- Only load in Neovim 0.8+
if vim.fn.has('nvim-0.8') == 0 then
  vim.api.nvim_err_writeln('auto-git-add.nvim requires Neovim 0.8+')
  return
end

local auto_git_add = require('auto-git-add')

-- Setup with user configuration or defaults
local config = vim.g.auto_git_add_config or {}
auto_git_add.setup(config)

-- Create autocommand group
local augroup = vim.api.nvim_create_augroup('AutoGitAdd', { clear = true })

-- Different tracking strategies based on trigger_mode
local edit_command_files = {}
local manual_files = {}

local function setup_autocommands()
  local trigger_mode = require('auto-git-add.config').get('trigger_mode')
  
  if trigger_mode == 'all' then
    -- Add any new file when saved
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = augroup,
      pattern = '*',
      callback = function(args)
        local filepath = args.file
        if filepath and filepath ~= '' then
          auto_git_add.add_file_if_new(filepath)
        end
      end,
      desc = 'Auto-add any new files to git when saved'
    })
    
  elseif trigger_mode == 'edit-command-only' then
    -- Track :e/:edit commands only
    vim.api.nvim_create_autocmd('CmdlineLeave', {
      group = augroup,
      pattern = ':',
      callback = function()
        local cmdline = vim.fn.getcmdline()
        local edit_patterns = { '^e%s+(.+)$', '^edit%s+(.+)$' }
        
        for _, pattern in ipairs(edit_patterns) do
          local filename = cmdline:match(pattern)
          if filename then
            local filepath = vim.fn.fnamemodify(filename, ':p')
            local stat = vim.loop.fs_stat(filepath)
            if not stat then
              edit_command_files[filepath] = { command = cmdline, time = vim.loop.hrtime() }
              break
            end
          end
        end
      end,
      desc = 'Track files created via :e/:edit commands'
    })
    
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = augroup,
      pattern = '*',
      callback = function(args)
        local filepath = args.file
        if filepath and filepath ~= '' and edit_command_files[filepath] then
          auto_git_add.add_file_if_new(filepath)
          edit_command_files[filepath] = nil
        end
      end,
      desc = 'Auto-add files created via :e/:edit commands when saved'
    })
    
  else -- 'manual' mode (default)
    vim.api.nvim_create_autocmd('BufNewFile', {
      group = augroup,
      pattern = '*',
      callback = function(args)
        local filepath = vim.fn.expand('<afile>:p')
        if filepath and filepath ~= '' and filepath ~= vim.fn.getcwd() then
          manual_files[filepath] = { created_time = vim.loop.hrtime(), method = 'manual' }
        end
      end,
      desc = 'Track manually created files'
    })
    
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = augroup,
      pattern = '*',
      callback = function(args)
        local filepath = args.file
        if filepath and filepath ~= '' and manual_files[filepath] then
          auto_git_add.add_file_if_new(filepath)
          manual_files[filepath] = nil
        end
      end,
      desc = 'Auto-add manually created files when saved'
    })
  end
end

-- Setup autocommands
setup_autocommands()

-- User commands
vim.api.nvim_create_user_command('AutoGitAddEnable', function()
  auto_git_add.enable()
end, { desc = 'Enable auto git add' })

vim.api.nvim_create_user_command('AutoGitAddDisable', function()
  auto_git_add.disable()
end, { desc = 'Disable auto git add' })

vim.api.nvim_create_user_command('AutoGitAddToggle', function()
  auto_git_add.toggle()
end, { desc = 'Toggle auto git add' })

vim.api.nvim_create_user_command('AutoGitAddStatus', function()
  auto_git_add.show_status()
end, { desc = 'Show auto git add status' })

vim.api.nvim_create_user_command('AutoGitAddFile', function(opts)
  local filepath = opts.args ~= '' and opts.args or vim.fn.expand('%:p')
  auto_git_add.add_file_if_new(filepath)
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Manually trigger auto git add for a file'
})

-- Default keymaps (can be disabled by user)
if not vim.g.auto_git_add_no_default_mappings then
  vim.keymap.set('n', '<leader>ga', '<cmd>AutoGitAddFile<CR>', { 
    desc = 'Auto git add current file', silent = true 
  })
  vim.keymap.set('n', '<leader>gt', '<cmd>AutoGitAddToggle<CR>', { 
    desc = 'Toggle auto git add', silent = true 
  })
  vim.keymap.set('n', '<leader>gs', '<cmd>AutoGitAddStatus<CR>', { 
    desc = 'Show auto git add status', silent = true 
  })
end

-- Cleanup on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = function()
    auto_git_add.cleanup()
  end,
  desc = 'Cleanup auto git add on exit'
})