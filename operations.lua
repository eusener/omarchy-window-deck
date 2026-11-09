-- Evaluated as one compositor request: no external client can interleave a move
-- between these guards and the mutation. No globals or persistent hooks.
return function(action, address, expected_workspace, was_minimized)
    if action == "restore-last" then
        local active = hl.get_active_workspace()
        assert(active and active.id == expected_workspace and active.id > 0, "Active workspace changed")
        action = "restore"
    end
    local selector = "address:" .. address
    local window = hl.get_window(selector)
    assert(window and window.mapped and window.workspace, "Window no longer exists")

    local function apply(dispatcher)
        local result = hl.dispatch(dispatcher)
        assert(type(result) == "table" and result.ok, "Window operation rejected")
    end

    local prefix = "omarchy-minimized-from-"
    local tags = window.tags or {}
    local workspace = window.workspace

    if action == "minimize" then
        assert(workspace.id == expected_workspace and workspace.id > 0, "Window moved")
        -- Only an explicit minimize from a valid regular workspace may repair
        -- malformed provenance. Pass tag values as data, never as Lua code.
        for _, tag in ipairs(tags) do
            if tag:sub(1, #prefix) == prefix then
                apply(hl.dsp.window.tag({tag = "-" .. tag, window = selector}))
            end
        end
        apply(hl.dsp.window.tag({tag = "+" .. prefix .. tostring(expected_workspace), window = selector}))
        apply(hl.dsp.window.move({workspace = "special:minimized", follow = false, window = selector}))
        apply(hl.dsp.focus({workspace = tostring(expected_workspace)}))
    elseif action == "restore" then
        local minimized = workspace.name == "special:minimized"
        assert(minimized == was_minimized, "Window state changed")
        if minimized then
            local origin = nil
            for _, tag in ipairs(tags) do
                if tag:sub(1, #prefix) == prefix then
                    local suffix = tag:sub(#prefix + 1)
                    assert(suffix:match("^[1-9]%d*$") and #suffix <= 6, "Invalid window origin")
                    local current = tonumber(suffix)
                    assert(not origin or origin == current, "Ambiguous window origin")
                    origin = current
                end
            end
            assert(origin == expected_workspace, "Window origin changed")
            apply(hl.dsp.window.move({workspace = tostring(expected_workspace), follow = false, window = selector}))
        else
            assert(workspace.id == expected_workspace, "Window moved")
        end
        apply(hl.dsp.focus({window = selector}))
        if window.floating then
            apply(hl.dsp.window.alter_zorder({mode = "top", window = selector}))
        end
    else
        error("Invalid window action")
    end
end
