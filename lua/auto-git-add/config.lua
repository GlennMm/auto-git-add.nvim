local M = {}

local defaults = {
  -- Enable/disable the plugin
  enabled = true,
  
  -- Patterns to exclude from auto-adding
  exclude_patterns = {
    '%.tmp$',
    '%.log$',
    '%.swp$',
    '%.swo$',
    '%.DS_Store$',
    '^%.git/',
    'node_modules/',
    '%.min%.js$',
    '%.min%.css$',
  },
  
  -- File patterns to include (if empty, includes all)
  include_patterns = {},
  
  -- Show notification when file is added
  show_notifications = true,
  
  -- Notification level (INFO, WARN, ERROR)
  notification_level = vim.log.levels.INFO,
  
  -- Auto-add files only in specific directories relative to git root
  restrict_to_dirs = {},
  
  -- Maximum file size to auto-add (in bytes, 0 = no limit)
  max_file_size = 10 * 1024 * 1024, -- 10MB
  
  -- Delay before adding (in ms) - useful for avoiding rapid fire additions
  delay_ms = 500,
}

local config = {}

function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})
end

function M.get(key)
  if key then
    return config[key]
  end
  return vim.deepcopy(config)
end

function M.set(key, value)
  config[key] = value
end

function M.is_enabled()
  return config.enabled
end

function M.should_exclude(filepath)
  -- Check exclude patterns
  for _, pattern in ipairs(config.exclude_patterns) do
    if filepath:match(pattern) then
      return true
    end
  end
  
  -- Check include patterns (if specified)
  if #config.include_patterns > 0 then
    for _, pattern in ipairs(config.include_patterns) do
      if filepath:match(pattern) then
        return false -- Explicitly included
      end
    end
    return true -- Not in include list
  end
  
  return false
end

function M.get_delay()
  return config.delay_ms
end

function M.get_max_file_size()
  return config.max_file_size
end

function M.should_notify()
  return config.show_notifications
end

function M.get_notification_level()
  return config.notification_level
end

function M.get_restricted_dirs()
  return config.restrict_to_dirs
end

-- Initialize with defaults
M.setup()

return M