-- Window Deck operations, evaluated inside the compositor. Every guard runs in
-- the same Lua call as the mutation, so no external client can interleave a
-- move between them. The module keeps no globals and installs no hooks.
--
-- Shortcuts call minimize() and restore_last() directly from bindings.lua; the
-- shell overlay calls execute("restore", ...) through `hyprctl eval`.
local M = {}

local PREFIX = "omarchy-minimized-from-"
local MINIMIZED = "special:minimized"

local function apply(dispatcher)
    local result = hl.dispatch(dispatcher)
    assert(type(result) == "table" and result.ok, "Window operation rejected")
end

local function valid_workspace(id)
    return type(id) == "number" and id > 0 and id <= 999999 and id == math.floor(id)
end

-- The workspace a minimized window came from, or nil when its provenance tags
-- are missing, malformed or ambiguous. Invalid origins are never guessed.
function M.origin(window)
    local origin = nil
    for _, tag in ipairs(window.tags or {}) do
        if tag:sub(1, #PREFIX) == PREFIX then
            local suffix = tag:sub(#PREFIX + 1)
            if not suffix:match("^[1-9]%d*$") or #suffix > 6 then return nil end
            local current = tonumber(suffix)
            if origin and origin ~= current then return nil end
            origin = current
        end
    end
    return origin
end

local function is_minimized(window)
    return window.workspace ~= nil and window.workspace.name == MINIMIZED
end

-- The maximized or fullscreen window that would cover `address` on a workspace.
local function covering_window(workspace_id, address)
    for _, other in ipairs(hl.get_windows() or {}) do
        if other.address ~= address and other.mapped and other.workspace and other.workspace.id == workspace_id
            and type(other.fullscreen) == "number" and other.fullscreen ~= 0 then
            return other
        end
    end
end

-- Choosing a window must show it. The overlay still holds exclusive keyboard
-- focus when it restores, so Hyprland does not apply on_focus_under_fullscreen
-- to that focus request and the window would stay behind a maximized one.
-- Apply the setting here: 1 hands the maximized or fullscreen state over to
-- the chosen window; any other value only clears it, since an explicit choice
-- is never ignored.
local function uncover(selector, address, workspace_id)
    local cover = covering_window(workspace_id, address)
    if not cover then return end
    local mode = cover.fullscreen == 1 and "maximized" or "fullscreen"
    local ok, setting = pcall(hl.get_config, "misc:on_focus_under_fullscreen")
    apply(hl.dsp.window.fullscreen({mode = mode, action = "unset", window = cover}))
    if not ok or setting == 1 then
        apply(hl.dsp.window.fullscreen({mode = mode, action = "set", window = selector}))
    end
end

function M.execute(action, address, expected_workspace, was_minimized)
    if action == "restore-last" then
        local active = hl.get_active_workspace()
        assert(active and active.id == expected_workspace and valid_workspace(active.id), "Active workspace changed")
        local focused = hl.get_active_window()
        if focused and focused.mapped and focused.workspace and focused.workspace.id == expected_workspace and focused.fullscreen == 1 then
            apply(hl.dsp.window.fullscreen({mode = "maximized", action = "unset", window = focused}))
            return
        end
        if address == "" then return end
        action = "restore"
    end
    assert(type(address) == "string" and address:match("^0x%x+$") and #address <= 34, "Invalid window address")
    assert(valid_workspace(expected_workspace), "Invalid workspace")
    local selector = "address:" .. address
    local window = hl.get_window(selector)
    assert(window and window.mapped and window.workspace, "Window no longer exists")
    local workspace = window.workspace

    if action == "minimize" then
        assert(workspace.id == expected_workspace, "Window moved")
        -- Only an explicit minimize from a valid regular workspace may repair
        -- malformed provenance. Tag values are passed as data, never as code.
        for _, tag in ipairs(window.tags or {}) do
            if tag:sub(1, #PREFIX) == PREFIX then
                apply(hl.dsp.window.tag({tag = "-" .. tag, window = selector}))
            end
        end
        apply(hl.dsp.window.tag({tag = "+" .. PREFIX .. tostring(expected_workspace), window = selector}))
        apply(hl.dsp.window.move({workspace = MINIMIZED, follow = false, window = selector}))
        apply(hl.dsp.focus({workspace = tostring(expected_workspace)}))
    elseif action == "restore" then
        local minimized = is_minimized(window)
        -- The overlay omits was_minimized: either state is valid when its own
        -- check below holds. Shortcuts pass it to pin the state they observed.
        assert(was_minimized == nil or minimized == was_minimized, "Window state changed")
        if minimized then
            assert(M.origin(window) == expected_workspace, "Window origin changed")
            apply(hl.dsp.window.move({workspace = tostring(expected_workspace), follow = false, window = selector}))
        else
            assert(workspace.id == expected_workspace, "Window moved")
        end
        uncover(selector, address, expected_workspace)
        apply(hl.dsp.focus({window = selector}))
        if window.floating then
            apply(hl.dsp.window.alter_zorder({mode = "top", window = selector}))
        end
    else
        error("Invalid window action")
    end
end

-- Super+M: minimize the focused window of a regular workspace.
function M.minimize()
    local window = hl.get_active_window()
    if not (window and window.mapped and window.workspace and valid_workspace(window.workspace.id)) then
        return false
    end
    return pcall(M.execute, "minimize", window.address, window.workspace.id, false)
end

-- Super+Ctrl+M: unmaximize the focused window, otherwise bring back the most
-- recently focused minimized window of the active workspace. The compositor's
-- focus history provides the order; no timestamps or files are needed.
function M.restore_last()
    local active = hl.get_active_workspace()
    if not (active and valid_workspace(active.id)) then return false end
    local best, best_order = nil, math.huge
    for _, window in ipairs(hl.get_windows() or {}) do
        local order = window.focus_history_id
        if type(order) ~= "number" or order < 0 then order = math.huge end
        if window.mapped and is_minimized(window) and M.origin(window) == active.id
            and (best == nil or order < best_order) then
            best, best_order = window, order
        end
    end
    return pcall(M.execute, "restore-last", best and best.address or "", active.id, best ~= nil)
end

-- This file's path when it was loaded with dofile, nil inside `hyprctl eval`.
local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
local path = source:sub(1, 1) == "@" and source:sub(2) or nil

-- A bind action for minimize or restore_last. Each press reloads this file, so
-- `omarchy plugin update` applies without reloading Hyprland, and a removed
-- plugin turns the key into a no-op. The expression lets Omarchy's keybindings
-- menu replay the bind through `hyprctl dispatch`.
function M.shortcut(name)
    assert(name == "minimize" or name == "restore_last", "Invalid shortcut")
    if not path then return M[name] end
    local function action()
        local ok, current = pcall(dofile, path)
        if ok and type(current) == "table" and type(current[name]) == "function" then
            current[name]()
        end
    end
    if type(o) == "table" and type(o.bind_expressions) == "table" then
        o.bind_expressions[action] = "dofile(" .. string.format("%q", path) .. ")." .. name
    end
    return action
end

return M
