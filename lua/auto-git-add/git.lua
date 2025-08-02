local config = require('auto-git-add.config')

local M = {}

-- Cache for git repo detection
local git_repo_cache = {}

function M.find_git_root(path)
  -- Check cache first
  if git_repo_cache[path] then
    return git_repo_cache[path]
  end
  
  local current_dir = path or vim.fn.expand('%:p:h')
  
  -- Walk up directory tree looking for .git
  while current_dir and current_dir ~= '/' do
    local git_dir = current_dir .. '/.git'
    
    -- Check if .git exists (file or directory)
    local stat = vim.loop.fs_stat(git_dir)
    if stat then
      git_repo_cache[path] = current_dir
      return current_dir
    end
    
    -- Move up one directory
    current_dir = vim.fn.fnamemodify(current_dir, ':h')
    if current_dir == '.' then
      break
    end
  end
  
  -- Cache negative result
  git_repo_cache[path] = nil
  return nil
end

function M.is_git_repo(path)
  return M.find_git_root(path) ~= nil
end

function M.get_relative_path(filepath, git_root)
  git_root = git_root or M.find_git_root(filepath)
  if not git_root then
    return nil
  end
  
  -- Make paths absolute for comparison
  local abs_file = vim.fn.fnamemodify(filepath, ':p')
  local abs_root = vim.fn.fnamemodify(git_root, ':p')
  
  -- Remove trailing slash from root
  abs_root = abs_root:gsub('/$', '')
  
  -- Check if file is within git repo
  if abs_file:sub(1, #abs_root) == abs_root then
    return abs_file:sub(#abs_root + 2) -- +2 to remove leading slash
  end
  
  return nil
end

function M.is_file_tracked(filepath, callback)
  local git_root = M.find_git_root(filepath)
  if not git_root then
    callback(false, 'Not in git repo')
    return
  end
  
  local relative_path = M.get_relative_path(filepath, git_root)
  if not relative_path then
    callback(false, 'File outside git repo')
    return
  end
  
  -- Use git ls-files to check if file is tracked
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()
  
  local handle, pid = vim.loop.spawn('git', {
    args = { 'ls-files', '--error-unmatch', relative_path },
    cwd = git_root,
    stdio = { nil, stdout, stderr }
  }, function(code, signal)
    stdout:close()
    stderr:close()
    
    vim.schedule(function()
      -- Exit code 0 means file is tracked
      callback(code == 0, code == 0 and 'tracked' or 'untracked')
    end)
  end)
  
  if not handle then
    callback(false, 'Failed to spawn git process')
    return
  end
  
  -- We don't need to read stdout/stderr for this check
  stdout:read_start(function() end)
  stderr:read_start(function() end)
end

function M.add_file(filepath, callback)
  local git_root = M.find_git_root(filepath)
  if not git_root then
    callback(false, 'Not in git repo')
    return
  end
  
  local relative_path = M.get_relative_path(filepath, git_root)
  if not relative_path then
    callback(false, 'File outside git repo')
    return
  end
  
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()
  local error_output = ''
  
  local handle, pid = vim.loop.spawn('git', {
    args = { 'add', relative_path },
    cwd = git_root,
    stdio = { nil, stdout, stderr }
  }, function(code, signal)
    stdout:close()
    stderr:close()
    
    vim.schedule(function()
      if code == 0 then
        callback(true, 'File added successfully')
      else
        callback(false, 'Git add failed: ' .. error_output)
      end
    end)
  end)
  
  if not handle then
    callback(false, 'Failed to spawn git process')
    return
  end
  
  -- Read stderr for error messages
  stderr:read_start(function(err, data)
    if data then
      error_output = error_output .. data
    end
  end)
  
  -- We don't expect stdout output from git add
  stdout:read_start(function() end)
end

function M.get_git_status(filepath, callback)
  local git_root = M.find_git_root(filepath)
  if not git_root then
    callback(nil, 'Not in git repo')
    return
  end
  
  local relative_path = M.get_relative_path(filepath, git_root)
  if not relative_path then
    callback(nil, 'File outside git repo')
    return
  end
  
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()
  local output = ''
  
  local handle, pid = vim.loop.spawn('git', {
    args = { 'status', '--porcelain', relative_path },
    cwd = git_root,
    stdio = { nil, stdout, stderr }
  }, function(code, signal)
    stdout:close()
    stderr:close()
    
    vim.schedule(function()
      if code == 0 then
        local status = output:match('^(..) ')
        callback(status, 'Success')
      else
        callback(nil, 'Git status failed')
      end
    end)
  end)
  
  if not handle then
    callback(nil, 'Failed to spawn git process')
    return
  end
  
  stdout:read_start(function(err, data)
    if data then
      output = output .. data
    end
  end)
  
  stderr:read_start(function() end)
end

function M.clear_cache()
  git_repo_cache = {}
end

-- Debug function to inspect cache
function M.get_cache()
  return vim.deepcopy(git_repo_cache)
end

return M