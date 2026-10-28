
local Timer = {}

local timers = {}
local next_id = 0

local MAX_CATCH_UP = 100

local function create_timer(delay, callback, interval, repetitions)
    assert(
        type(delay) == "number" and delay >= 0
            and delay == delay and delay < math.huge,
        "delay must be a finite, non-negative number"
    )

    assert(type(callback) == "function",
        "callback must be a function")

    if interval ~= nil then
        assert(
            type(interval) == "number"
                and interval > 0
                and interval < math.huge,
            "interval must be a finite number greater than zero"
        )
    end

    if repetitions ~= nil then
        assert(
            type(repetitions) == "number"
                and repetitions >= 1
                and repetitions % 1 == 0,
            "repetitions must be a positive integer"
        )
    end

    next_id = next_id + 1

    timers[#timers + 1] = {
        id = next_id,
        remaining = delay,
        callback = callback,
        interval = interval,
        repetitions = repetitions,
        calls = 0,
        cancelled = false,
    }

    return next_id
end

function Timer.after(delay, callback)
    return create_timer(delay, callback, nil, 1)
end

function Timer.every(interval, callback, repetitions)
    assert(
        type(interval) == "number"
            and interval > 0
            and interval < math.huge,
        "interval must be a finite number greater than zero"
    )

    return create_timer(interval, callback, interval, repetitions)
end

function Timer.cancel(id)
    for _, timer in ipairs(timers) do
        if timer.id == id and not timer.cancelled then
            timer.cancelled = true
            return true
        end
    end

    return false
end

function Timer.clear()
    for _, timer in ipairs(timers) do
        timer.cancelled = true
    end
end

function Timer.update(dt)
    assert(
        type(dt) == "number"
            and dt >= 0
            and dt == dt
            and dt < math.huge,
        "dt must be a finite, non-negative number"
    )

    -- The loop's initial index is fixed. Timers created by callbacks
    -- won't run until the next Timer.update().
    for i = #timers, 1, -1 do
        local timer = timers[i]

        if not timer.cancelled then
            timer.remaining = timer.remaining - dt
            local catch_up = 0

            while timer.remaining <= 0
                and not timer.cancelled
                and catch_up < MAX_CATCH_UP do

                timer.calls = timer.calls + 1
                catch_up = catch_up + 1

                timer.callback()

                if timer.cancelled then
                    break
                elseif timer.interval == nil then
                    timer.cancelled = true
                elseif timer.repetitions
                    and timer.calls >= timer.repetitions then
                    timer.cancelled = true
                else
                    timer.remaining = timer.remaining + timer.interval
                end
            end

            -- Drop excessive backlog after a long pause.
            if not timer.cancelled
                and catch_up >= MAX_CATCH_UP
                and timer.remaining <= 0 then
                timer.remaining = timer.interval or 0
            end
        end
    end

    for i = #timers, 1, -1 do
        if timers[i].cancelled then
            table.remove(timers, i)
        end
    end
end

return Timer
