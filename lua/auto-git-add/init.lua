local config = require('auto-git-add.config')
local git = require('auto-git-add.git')

local M = {}

-- Track pending operations to avoid duplicates
local pending_operations = {}

-- Timers for delayed operations
local timers = {}

function M.setup(opts)
  config.setup(opts)
  
  -- Clear git cache when setup is called
  git.clear_cache()
end

local function notify(message, level)
  if config.should_notify() then
    vim.notify(message, level or config.get_notification_level(), {
      title = 'Auto Git Add'
    })
  end
end

local function is_file_size_ok(filepath)
  local max_size = config.get_max_file_size()
  if max_size <= 0 then
    return true -- No size limit
  end
  
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return false -- File doesn't exist
  end
  
  return stat.size <= max_size
end

local function is_in_restricted_dirs(filepath)
  local restricted_dirs = config.get_restricted_dirs()
  if #restricted_dirs == 0 then
    return false -- No restrictions
  end
  
  local git_root = git.find_git_root(filepath)
  if not git_root then
    return true -- Not in git repo, so restricted
  end
  
  local relative_path = git.get_relative_path(filepath, git_root)
  if not relative_path then
    return true -- Can't determine relative path
  end
  
  -- Check if file is in any of the allowed directories
  for _, dir in ipairs(restricted_dirs) do
    if relative_path:match('^' .. vim.pesc(dir)) then
      return false -- File is in allowed directory
    end
  end
  
  return true -- File is not in any allowed directory
end

local function should_process_file(filepath)
  -- Check if plugin is enabled
  if not config.is_enabled() then
    return false, 'Plugin disabled'
  end
  
  -- Check if file exists
  local stat = vim.loop.fs_stat(filepath)
  if not stat or stat.type ~= 'file' then
    return false, 'Not a regular file'
  end
  
  -- Check exclude patterns
  if config.should_exclude(filepath) then
    return false, 'File matches exclude pattern'
  end
  
  -- Check file size
  if not is_file_size_ok(filepath) then
    return false, 'File too large'
  end
  
  -- Check directory restrictions
  if is_in_restricted_dirs(filepath) then
    return false, 'File not in allowed directory'
  end
  
  -- Check if in git repo
  if not git.is_git_repo(filepath) then
    return false, 'Not in git repository'
  end
  
  return true, 'OK'
end

local function process_file_addition(filepath)
  local should_process, reason = should_process_file(filepath)
  if not should_process then
    return
  end
  
  -- Check if file is already tracked
  git.is_file_tracked(filepath, function(is_tracked, status)
    if is_tracked then
      return -- File already tracked, nothing to do
    end
    
    -- Add the file
    git.add_file(filepath, function(success, message)
      if success then
        local relative_path = git.get_relative_path(filepath)
        notify(string.format('Added to git: %s', relative_path or filepath), vim.log.levels.INFO)
      else
        notify(string.format('Failed to add %s: %s', filepath, message), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function schedule_file_addition(filepath)
  -- Cancel existing timer for this file
  if timers[filepath] then
    timers[filepath]:stop()
    timers[filepath]:close()
  end
  
  -- Avoid duplicate operations
  if pending_operations[filepath] then
    return
  end
  
  pending_operations[filepath] = true
  
  local delay = config.get_delay()
  if delay <= 0 then
    -- Process immediately
    process_file_addition(filepath)
    pending_operations[filepath] = nil
  else
    -- Process after delay
    local timer = vim.loop.new_timer()
    timers[filepath] = timer
    
    timer:start(delay, 0, function()
      vim.schedule(function()
        process_file_addition(filepath)
        pending_operations[filepath] = nil
        timer:close()
        timers[filepath] = nil
      end)
    end)
  end
end

function M.add_file_if_new(filepath)
  if not filepath or filepath == '' then
    filepath = vim.fn.expand('%:p')
  end
  
  -- Make sure we have an absolute path
  filepath = vim.fn.fnamemodify(filepath, ':p')
  
  schedule_file_addition(filepath)
end

function M.enable()
  config.set('enabled', true)
  notify('Auto git add enabled', vim.log.levels.INFO)
end

function M.disable()
  config.set('enabled', false)
  notify('Auto git add disabled', vim.log.levels.INFO)
end

function M.toggle()
  if config.is_enabled() then
    M.disable()
  else
    M.enable()
  end
end

function M.status()
  local status_info = {
    enabled = config.is_enabled(),
    current_file = vim.fn.expand('%:p'),
    in_git_repo = false,
    git_root = nil,
    relative_path = nil,
    would_process = false,
    reason = nil
  }
  
  local current_file = status_info.current_file
  status_info.git_root = git.find_git_root(current_file)
  status_info.in_git_repo = status_info.git_root ~= nil
  
  if status_info.in_git_repo then
    status_info.relative_path = git.get_relative_path(current_file, status_info.git_root)
  end
  
  status_info.would_process, status_info.reason = should_process_file(current_file)
  
  return status_info
end

function M.show_status()
  local status = M.status()
  
  local lines = {
    'Auto Git Add Status:',
    '==================',
    '',
    'Plugin enabled: ' .. tostring(status.enabled),
    'Current file: ' .. (status.current_file or 'none'),
    'In git repo: ' .. tostring(status.in_git_repo),
  }
  
  if status.in_git_repo then
    table.insert(lines, 'Git root: ' .. (status.git_root or 'unknown'))
    table.insert(lines, 'Relative path: ' .. (status.relative_path or 'unknown'))
  end
  
  table.insert(lines, '')
  table.insert(lines, 'Would process file: ' .. tostring(status.would_process))
  if not status.would_process then
    table.insert(lines, 'Reason: ' .. (status.reason or 'unknown'))
  end
  
  -- Show in a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = 60,
    height = #lines + 2,
    row = math.floor((vim.o.lines - #lines) / 2),
    col = math.floor((vim.o.columns - 60) / 2),
    border = 'rounded',
    title = 'Auto Git Add Status',
    title_pos = 'center'
  })
  
  -- Close on escape
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
end

-- Cleanup function
function M.cleanup()
  -- Stop all timers
  for filepath, timer in pairs(timers) do
    timer:stop()
    timer:close()
  end
  timers = {}
  pending_operations = {}
  git.clear_cache()
end

return M