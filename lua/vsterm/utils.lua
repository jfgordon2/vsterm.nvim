local M = {}

--- Checks if a given filename is a valid file.
---@param filename string The name of the file to check.
---@return boolean Returns true if the file exists and is a regular file, false otherwise.
function M.is_valid_file(filename)
  if not filename or filename == "" then
    return false
  end
  local ok, stat = pcall(vim.uv.fs_stat, filename)
  ---@diagnostic disable-next-line: return-type-mismatch
  return ok and stat and stat.type == "file"
end

--- Find the first non-terminal window.
---@return number|nil Returns the window ID of the first non-terminal window, or nil if none found.
function M.get_first_non_terminal_window()
  local wins = vim.api.nvim_list_wins()
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
    if buftype ~= "terminal" and buftype ~= "nofile" then
      return win
    end
  end
  return nil
end

--- Find the filename and pytest path from the current line
---@return string|nil filename
---@return string[]|nil pytest details in ordered list (ex: Class, Function)
function M.extract_pytest_path_from_line()
  local filename = vim.fn.expand "<cfile>"
  local line = vim.fn.getline "."

  if filename == "" or not M.is_valid_file(filename) then
    return nil, nil
  end

  -- Get the two characters immediately after the filename
  local path_end = line:find(filename)
  local after_filename = line:sub(path_end + #filename)
  local two_characters_after_filename = after_filename:sub(0, 2)
  if two_characters_after_filename ~= "::" then
    return filename, nil
  end
  -- Create pytest parts
  local first_space = after_filename:find " "
  local pytest_path = after_filename:sub(0, first_space and first_space - 1 or -1)
  local parts = vim.split(pytest_path, "::", { trimempty = true })
  return filename, parts
end

--- Get line and column number from the current line
---@return string|nil filename
---@return number|nil line_number
---@return number|nil column_number
function M.extract_line_and_column_from_line()
  local filename = vim.fn.expand "<cfile>"
  local line = vim.fn.getline "."

  if filename == "" or not M.is_valid_file(filename) then
    return nil, nil, nil
  end

  -- Get the two characters immediately after the filename
  local path_end = line:find(filename)
  local after_filename = line:sub(path_end + #filename)
  local character_after_filename = after_filename:sub(0, 1)
  if character_after_filename ~= ":" then
    return filename, nil, nil
  end

  -- Extract line
  local rest_of_line = after_filename:sub(2)
  local line_number = rest_of_line:match "^%d+"
  if line_number then
    line_number = tonumber(line_number)
  else
    return filename, nil, nil
  end
  rest_of_line = rest_of_line:sub(#tostring(line_number) + 1)
  if rest_of_line:sub(0, 1) ~= ":" then
    return filename, line_number, nil
  end
  rest_of_line = rest_of_line:sub(2)
  local column_number = rest_of_line:match "^%d+"
  if column_number then
    column_number = tonumber(column_number)
  else
    return filename, line_number, nil
  end
  return filename, line_number, column_number
end

--- Open file at a specific window and pytest function
---@param win number|nil The window ID to open the file in. If nil, the first non-terminal window will be used.
---@param filename string The name of the file to open.
---@param pytest_parts string[]|nil A table containing pytest parts (e.g., class, function) to navigate to.
function M.open_file_at_window_and_pytest_function(win, filename, pytest_parts)
  if not win or not vim.api.nvim_win_is_valid(win) then
    -- Find the first non-terminal window as fallback
    win = M.get_first_non_terminal_window()
  end

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    vim.cmd("edit " .. vim.fn.fnameescape(filename))
    -- Verify that pytest parts are valid
    if pytest_parts and #pytest_parts > 0 then
      -- in the order of available parts, find the first full match
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local line_num = nil
      local line_count = 0
      for _, part in ipairs(pytest_parts) do
        for i, line in ipairs(lines) do
          line_count = line_count + 1
          local start_pos, end_pos = line:find(part)
          if start_pos and end_pos then
            local next_char = line:sub(end_pos + 1, end_pos + 1)
            if next_char == "(" or next_char == ":" then
              -- Found a match
              line_num = line_count
              lines = vim.api.nvim_buf_get_lines(buf, i, -1, false)
              break
            end
          end
        end
      end
      -- Move cursor to the first match
      if line_num then
        vim.api.nvim_win_set_cursor(win, { line_num, 0 })
      end
    end
  else
    vim.notify("No valid window found to open the file.", vim.log.levels.ERROR)
  end
end

--- Open file at a specific window and line/column number
---@param win number|nil The window ID to open the file in. If nil, the first non-terminal window will be used.
---@param filename string The name of the file to open.
---@param line_number number|nil The line number to navigate to. If nil, the cursor will not be moved.
---@param column_number number|nil The column number to navigate to. If nil, the cursor will not be moved.
function M.open_file_at_window(win, filename, line_number, column_number)
  if not win or not vim.api.nvim_win_is_valid(win) then
    -- Find the first non-terminal window as fallback
    win = M.get_first_non_terminal_window()
  end

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    vim.cmd("edit " .. vim.fn.fnameescape(filename))
    -- Verify that line number exists on file
    local num_lines = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
    if line_number and line_number > num_lines then
      vim.notify("Line number " .. line_number .. " exceeds the number of lines in the file.", vim.log.levels.WARN)
      line_number = nil
    end
    if line_number then
      vim.api.nvim_win_set_cursor(win, { line_number, 0 })
      if column_number then
        -- Verify that column number exists on line
        local num_columns = vim.fn.col { line_number, "$" }
        if column_number <= num_columns then
          vim.api.nvim_win_set_cursor(win, { line_number, column_number })
        end
      end
    end
  else
    vim.notify("No valid window found to open the file.", vim.log.levels.ERROR)
  end
end

return M
