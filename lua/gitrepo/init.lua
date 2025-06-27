local Path = require("plenary.path")
local M = {}

local default_opts = {
    root = vim.fn.getcwd(),
    excluded_dir = {},
    setup_load = true,
}

local function logging(msg, level)
    vim.notify(msg, level, { title = 'GitRepo' })
end

local function open_lazygit(gpath)
    local old_cwd = vim.fn.getcwd()
    vim.fn.execute('cd ' .. gpath)

    local cmd = [[lua require"lazygit".lazygit(nil)]]
    vim.api.nvim_command(cmd)

    vim.cmd('stopinsert')
    vim.cmd([[execute "normal i"]])
    vim.fn.feedkeys('j')
    vim.api.nvim_buf_set_keymap(0, 't', '<Esc>', '<Esc>', {noremap = true, silent = true})
    -- Restore old working directory
    vim.fn.execute('cd ' .. old_cwd)
end

-- Utility: Deep merge tables
local function tbl_deep_extend(defaults, overrides)
    local result = {}
    for k, v in pairs(defaults) do
        if overrides[k] ~= nil then
            if type(v) == "table" and type(overrides[k]) == "table" then
                result[k] = tbl_deep_extend(v, overrides[k])
            else
                result[k] = overrides[k]
            end
        else
            result[k] = v
        end
    end
    for k, v in pairs(overrides) do
        if result[k] == nil then
            result[k] = v
        end
    end
    return result
end

-- Scan for git repositories under root, excluding specified directories
local function is_excluded_dir(dir, excluded_dirs)
    for _, excluded in ipairs(excluded_dirs) do
        if dir == excluded then
            return true
        end
    end
    return false
end

local function scan_git_repos(root, excluded_dirs)
    local repos = {}
    local scanned = {}
    local function scan(current_path)
        if scanned[current_path] then return end
        scanned[current_path] = true
        local handle = vim.loop.fs_scandir(current_path)
        if not handle then return end
        while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then break end
            if name:sub(1, 1) == "." or is_excluded_dir(name, excluded_dirs) then goto continue end
            if type ~= "directory" then goto continue end
            local full_path = Path:new(current_path, name):absolute()
            local stat = vim.loop.fs_lstat(full_path)
            if stat and stat.type == "link" then goto continue end
            if vim.loop.fs_stat(full_path .. "/.git") then
                table.insert(repos, {
                    name = name,
                    path = full_path,
                    parent = current_path:match("/([^/]+)$") or "root",
                })
                goto continue
            end
            scan(full_path)
            ::continue::
        end
    end
    scan(root)
    if vim.loop.fs_stat(root .. "/.git") then
        local name = "." .. (vim.fn.fnamemodify(root, ":t") ~= "" and " (" .. vim.fn.fnamemodify(root, ":t") .. ")" or "")
        table.insert(repos, 1, {
            name = name,
            path = root,
            parent = "current",
        })
    end
    return repos
end

-- Initialize repo list
function M.gitrepo_init()
    local opt = M._opts or {}
    local root = opt.root or vim.fn.getcwd()
    local excluded_dirs = opt.excluded_dir or {}
    M.repos = scan_git_repos(root, excluded_dirs)
end

-- Load repo display options (name, dirty, branch)
function M.gitrepo_load()
    if not M.repos or #M.repos == 0 then
        logging("No repositories found. Please run :GitRepoInit first.", vim.log.levels.WARN)
        return
    end
    local display_options = {}
    local name_counts = {}
    for _, repo in ipairs(M.repos) do
        name_counts[repo.name] = (name_counts[repo.name] or 0) + 1
    end
    for _, repo in ipairs(M.repos) do
        local text = (name_counts[repo.name] > 1 or repo.parent)
            and (repo.name .. " (" .. (repo.parent or "") .. ")")
            or repo.name
        local dirty, branch = false, ""
        if vim.fn.isdirectory(repo.path .. "/.git") == 1 and vim.fn.executable("git") == 1 then
            local esc_path = vim.fn.shellescape(repo.path)
            -- get branch
            local branch_cmd = string.format('git -C %s rev-parse --abbrev-ref HEAD 2>/dev/null', esc_path)
            local okb, branch_handle = pcall(io.popen, branch_cmd)
            if okb and branch_handle then
                branch = branch_handle:read("*l") or ""
                branch_handle:close()
            end
            -- get dirty
            local status_cmd = string.format('git -C %s status --porcelain 2>/dev/null', esc_path)
            local oks, status_handle = pcall(io.popen, status_cmd)
            if oks and status_handle then
                local output = status_handle:read("*a")
                status_handle:close()
                if output and output:find("%S") then dirty = true end
            end
        end
        table.insert(display_options, {
            text = text,
            repo = repo,
            dirty = dirty,
            branch = branch,
        })
    end
    table.sort(display_options, function(a, b) return a.text < b.text end)
    M.display_options = display_options
    logging("Repositories loaded with display options.", vim.log.levels.INFO)
end

-- Select dirty repos using vim.ui.select
function M.gitrepo_select()
    if not M.display_options or #M.display_options == 0 then
        logging("No display options available. Please run :GitRepoLoad first.", vim.log.levels.WARN)
        return
    end
    local icon = ""
    local dirty_options = {}
    for _, opt in ipairs(M.display_options) do
        if opt.dirty then
            local branch_str = opt.branch and opt.branch ~= "" and (" |  " .. opt.branch) or ""
            table.insert(dirty_options, {
                text = icon .. " " .. opt.text .. branch_str,
                repo = opt.repo,
                branch = opt.branch,
            })
        end
    end
    if #dirty_options == 0 then
        logging("No dirty repositories found.", vim.log.levels.INFO)
        return
    end
    local display_texts = {}
    for _, opt in ipairs(dirty_options) do
        table.insert(display_texts, opt.text)
    end
    vim.ui.select(display_texts, {
        prompt = "Select Repo by LazyGit",
        format_item = function(item) return item end,
    }, function(choice)
        if not choice then return end
        for _, opt in ipairs(dirty_options) do
            if opt.text == choice then
                open_lazygit(opt.repo.path)
                break
            end
        end
    end)
end

function M.setup(opt)
    M._opts = tbl_deep_extend(default_opts, opt or {})
    M.gitrepo_init()
    if M._opts.setup_load then
        M.gitrepo_load()
    end
    vim.api.nvim_create_user_command("GitRepoInit", M.gitrepo_init, {})
    vim.api.nvim_create_user_command("GitRepoLoad", M.gitrepo_load, {})
    vim.api.nvim_create_user_command("GitRepoSelect", M.gitrepo_select, {})
end

return M
