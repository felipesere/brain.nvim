local M = {}
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local conf = require("telescope.config").values
local job = require('plenary.job')

local flatten = vim.tbl_flatten

function list_contains(list, item)
  for _, l in ipairs(list) do
    if l == item then
      return true
    end
  end
  return false
end

function run_link(opts)
  job:new({
      command = 'neuron',
      args = { 'link', '--json', '--dir', opts.dir },
      on_exit = function(j, return_val)

        local response = vim.json.decode(j:result()[1])
        if response.success then
          for i, outcome in ipairs(response.data) do
            if outcome.updated_file ~= nil then
              vim.notify(string.format("Updated file %s", outcome.updated_file) , "info")
            else
              vim.notify(string.format("Added new file %s", outcome.added_new_file) , "info")
            end
          end
        else
          vim.notify("Failed to run link command", "error")
        end

      end,
    }):start()
end

function run_lint(opts)
  job:new({
      command = 'neuron',
      args = { 'lint', '--json', '--dir', opts.dir },
      on_exit = function(j, return_val)
        local response = vim.json.decode(j:result()[1])
        if response.success then
          if next(response.data) == nil then
              vim.notify("No linting issues found", "info", { title = "Brain lint"})
              return
          end

          for i, lint in ipairs(response.data) do
            if lint.data == nil then
              vim.notify(string.format("%s %s", lint.file, lint.lint), "warn", { title = "Brain lint"})
            else
              local bulleted = {}
              for i, d in ipairs(lint.data) do
                bulleted[i] = string.format("*  %s", d)
              end
              local joined_up = table.concat(bulleted, "\n")
              vim.notify(string.format("%s %s:\n%s", lint.file, lint.lint, joined_up) , "warn", { title = "Brain lint"})
            end
          end
        else
          vim.notify("Failed to run link command", "error")
        end

      end,
    }):start()
end

function list_files(opts)
  local args = flatten {
    "neuron",
    'list',
    '--dir',
    opts.dir,
  }
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
      prompt_title = "Brain",
      finder = finders.new_oneshot_job(args, opts),
      sorter = conf.generic_sorter(opts),
    }):find()
end

M.setup = function(setup_opts)
  local callback =function(args)
    args = args or {}

    if list_contains(args.fargs, "lint") then
      run_lint(setup_opts)
    elseif list_contains(args.fargs, "link") then
      run_link(setup_opts)
    else
      list_files(setup_opts)
    end
  end

  vim.api.nvim_create_user_command("Brain", callback, {nargs = "*"})
end

return M
