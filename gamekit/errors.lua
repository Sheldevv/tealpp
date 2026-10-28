-- gamekit/errors.lua
-- Uniform error reporting for TGK callbacks.

local Errors = {}

function Errors.traceback(err)
    local msg = tostring(err)
    if debug and debug.traceback then
        return msg .. "\n" .. debug.traceback("", 2)
    end
    return msg
end

function Errors.guard(fn, on_error, label)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return ... end
        local tb = Errors.traceback(err)
        if label then tb = "[" .. label .. "] " .. tb end
        if on_error then
            on_error(tb, err)
        else
            io.stderr:write(tb .. "\n")
        end
        return nil, err
    end
end

function Errors.fail(msg)
    error("[GameKit] " .. tostring(msg), 2)
end

function Errors.assert(cond, msg)
    if not cond then Errors.fail(msg or "assertion failed") end
    return cond
end

return Errors
