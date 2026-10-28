local M = {}

local function trim(s)
    return (s:match("^%s*(.-)%s*$"))
end

local function fail(message, line)
    error(("tpp:%d: %s"):format(line or 0, message), 0)
end

local function split_params(text, line)
    local params = {}

    if trim(text) == "" then
        return params
    end

    for part in text:gmatch("[^,]+") do
        part = trim(part)

        local name, typ =
            part:match("^(@?[%a_][%w_]*):%s*(.+)$")

        if not name then
            fail("parameters must have type annotations: " .. part, line)
        end

        params[#params + 1] = {
            name = name:gsub("^@", ""),
            auto = name:sub(1, 1) == "@",
            type = trim(typ),
        }
    end

    return params
end

local function parse_method(line)
    local visibility, name, params, ret

    visibility, name, params, ret =
        line:match(
            "^(public)%s+([%a_][%w_]*)%((.-)%)%s*:%s*(.+)$"
        )
    if name then
        return visibility, name, params, trim(ret)
    end

    visibility, name, params, ret =
        line:match(
            "^(private)%s+([%a_][%w_]*)%((.-)%)%s*:%s*(.+)$"
        )
    if name then
        return visibility, name, params, trim(ret)
    end

    visibility, name, params =
        line:match("^(public)%s+([%a_][%w_]*)%((.-)%)$")
    if name then
        return visibility, name, params, nil
    end

    visibility, name, params =
        line:match("^(private)%s+([%a_][%w_]*)%((.-)%)$")
    if name then
        return visibility, name, params, nil
    end

    return nil
end

local function params_decl(params)
    local result = {}

    for _, p in ipairs(params) do
        result[#result + 1] = p.name .. ": " .. p.type
    end

    return table.concat(result, ", ")
end

local function read_body(lines, start, description)
    local body = {}
    local i = start

    while i <= #lines and trim(lines[i]) ~= "end" do
        body[#body + 1] = lines[i]
        i = i + 1
    end

    if i > #lines then
        fail("unterminated " .. description, start)
    end

    return body, i + 1
end

function M.compile(source)
    local lines = {}

    for line in (source .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local class_name
    local fields = {}
    local methods = {}
    local constructor
    local i = 1

    while i <= #lines do
        local line = trim(lines[i])

        if line == "" or line:match("^%-%-") then
            i = i + 1

        elseif line:match("^class%s+") then
            local name = line:match("^class%s+([%a_][%w_]*)$")

            if not name then
                fail("invalid class declaration", i)
            end

            if class_name then
                fail("only one class per file is supported", i)
            end

            class_name = name
            i = i + 1

        elseif line == "end" then
            -- Closing end of the class.
            i = i + 1

        else
            local visibility, field_name, field_type

            visibility, field_name, field_type =
                line:match(
                    "^(public)%s+([%a_][%w_]*):%s*(.+)$"
                )

            if not field_name then
                visibility, field_name, field_type =
                    line:match(
                        "^(private)%s+([%a_][%w_]*):%s*(.+)$"
                    )
            end

            if field_name then
                fields[#fields + 1] = {
                    name = field_name,
                    type = trim(field_type),
                    visibility = visibility,
                }

                i = i + 1

            else
                local ctor_params =
                    line:match("^constructor%((.-)%)$")

                if ctor_params then
                    if constructor then
                        fail("only one constructor is supported", i)
                    end

                    local params = split_params(ctor_params, i)
                    local body

                    body, i = read_body(
                        lines, i + 1, "constructor"
                    )

                    constructor = {
                        params = params,
                        body = body,
                    }

                else
                    local method_name, method_params, return_type

                    visibility, method_name, method_params, return_type =
                        parse_method(line)

                    if not method_name then
                        fail("unsupported declaration: " .. line, i)
                    end

                    local params = split_params(method_params, i)
                    local body

                    body, i = read_body(
                        lines, i + 1, "method " .. method_name
                    )

                    methods[#methods + 1] = {
                        name = method_name,
                        params = params,
                        return_type = return_type,
                        visibility = visibility,
                        body = body,
                    }
                end
            end
        end
    end

    if not class_name then
        fail("missing class declaration")
    end

    local out = {}

    local function emit(s)
        out[#out + 1] = s
    end

    -- Type declaration.
    emit("-- Generated by Teal++; edit the .tpp source instead.")
    emit("local record " .. class_name)

    for _, field in ipairs(fields) do
        emit(("    %s: %s"):format(field.name, field.type))
    end

    local ctor_types = {}
    if constructor then
        for _, p in ipairs(constructor.params) do
            ctor_types[#ctor_types + 1] =
                p.name .. ": " .. p.type
        end
    end

    emit(("    new: function(%s): %s"):format(
        table.concat(ctor_types, ", "),
        class_name
    ))

    for _, method in ipairs(methods) do
        local args = { "self: " .. class_name }

        for _, p in ipairs(method.params) do
            args[#args + 1] = p.name .. ": " .. p.type
        end

        local ret = ""
        if method.return_type then
            ret = ": " .. method.return_type
        end

        emit(("    %s: function(%s)%s"):format(
            method.name,
            table.concat(args, ", "),
            ret
        ))
    end

    emit("end")
    emit("")

    -- Shared instance metatable. Lua looks up arithmetic and other
    -- metamethods on the instance metatable, not through __index.
    local mt_name = class_name .. "_mt"
    emit("local " .. mt_name .. " = {")
    emit("    __index = " .. class_name .. ",")

    for _, method in ipairs(methods) do
        if method.name:match("^__") then
            local wrapper_params = { "self: " .. class_name }
            local call_args = { "self" }

            for _, p in ipairs(method.params) do
                wrapper_params[#wrapper_params + 1] =
                    p.name .. ": " .. p.type
                call_args[#call_args + 1] = p.name
            end

            local ret = method.return_type or "nil"
            emit(("    %s = function(%s): %s"):format(
                method.name,
                table.concat(wrapper_params, ", "),
                ret
            ))
            emit(("        return %s.%s(%s)"):format(
                class_name, method.name, table.concat(call_args, ", ")
            ))
            emit("    end,")
        end
    end

    emit("}")
    emit("")

    -- Constructor.
    if constructor then
        emit(("function %s.new(%s): %s"):format(
            class_name,
            params_decl(constructor.params),
            class_name
        ))

        emit(("    local self = setmetatable({} as %s, %s)")
            :format(class_name, mt_name))

        for _, p in ipairs(constructor.params) do
            if p.auto then
                emit(("    self.%s = %s"):format(p.name, p.name))
            end
        end

        for _, body_line in ipairs(constructor.body) do
            emit(body_line)
        end

        emit("    return self")
        emit("end")
        emit("")

    else
        emit(("function %s.new(): %s"):format(class_name, class_name))
        emit(("    return setmetatable({} as %s, %s)")
            :format(class_name, mt_name))
        emit("end")
        emit("")
    end

    -- Methods, including Lua metamethods such as __add.
    for _, method in ipairs(methods) do
        local args = {}

        for _, p in ipairs(method.params) do
            args[#args + 1] = p.name .. ": " .. p.type
        end

        local signature = table.concat(args, ", ")

        if method.return_type then
            if signature ~= "" then
                signature = signature .. "): " .. method.return_type
            else
                signature = "): " .. method.return_type
            end
        else
            signature = signature .. ")"
        end

        emit(("function %s:%s(%s"):format(
            class_name, method.name, signature
        ))

        for _, body_line in ipairs(method.body) do
            emit(body_line)
        end

        emit("end")
        emit("")
    end

    emit("return " .. class_name)

    return table.concat(out, "\n") .. "\n"
end

function M.compile_program(source)
    local out = {}
    local line_number = 0

    for line in (source .. "\n"):gmatch("(.-)\n") do
        line_number = line_number + 1
        local stripped = trim(line)

        if stripped:match("^import%f[%W]") then
            local statement = stripped:match("^(.-)%s*%-%-") or stripped
            local module, alias = statement:match(
                "^import%s+([%a_][%w_%.]*)%s+as%s+([%a_][%w_]*)%s*$"
            )

            if not module or module:find("..", 1, true) or module:sub(-1) == "." then
                fail("invalid import; expected 'import module.path as Alias'", line_number)
            end

            out[#out + 1] = ("local %s = require(%q)"):format(alias, module)
        elseif stripped:match("^import%s") then
            fail("invalid import; expected 'import module.path as Alias'", line_number)
        else
            out[#out + 1] = line
        end
    end

    return table.concat(out, "\n")
end

return M
