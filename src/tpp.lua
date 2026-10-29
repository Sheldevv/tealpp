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

local function data_tostring_expr(class_name, params)
    local parts = { ('"%s("'):format(class_name) }
    for idx, p in ipairs(params) do
        if idx > 1 then parts[#parts + 1] = '", "' end
        parts[#parts + 1] = ('"%s="'):format(p.name)
        parts[#parts + 1] = ("tostring(self.%s)"):format(p.name)
    end
    parts[#parts + 1] = '")"'
    return table.concat(parts, " .. ")
end

local function data_eq_expr(params)
    if #params == 0 then return "true" end
    local exprs = {}
    for _, p in ipairs(params) do
        exprs[#exprs + 1] = ("self.%s == other.%s"):format(p.name, p.name)
    end
    return table.concat(exprs, " and ")
end

function M.compile(source)
    local lines = {}

    for line in (source .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local class_name
    local is_data_class = false
    local data_params = nil
    local fields = {}
    local methods = {}
    local constructor
    local i = 1

    while i <= #lines do
        local line = trim(lines[i])

        if line == "" or line:match("^%-%-") then
            i = i + 1

        elseif line:match("^data%s+class%s+") then
            local name, params_text =
                line:match("^data%s+class%s+([%a_][%w_]*)%s*%((.-)%)$")

            if not name then
                fail("invalid data class declaration; expected 'data class Name(params)'", i)
            end
            if class_name then
                fail("only one class per file is supported", i)
            end

            class_name = name
            is_data_class = true
            data_params = split_params(params_text, i)
            for _, p in ipairs(data_params) do
                p.name = p.name:gsub("^@", "")
                p.auto = true
            end

            for _, p in ipairs(data_params) do
                fields[#fields + 1] = {
                    name = p.name,
                    type = p.type,
                    visibility = "public",
                }
            end

            constructor = {
                params = data_params,
                body = {},
            }

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

    if is_data_class then
        local defined = {}
        for _, m in ipairs(methods) do
            defined[m.name] = true
        end

        if not defined.__tostring then
            methods[#methods + 1] = {
                name = "__tostring",
                params = {},
                return_type = "string",
                visibility = "public",
                body = { "    return " .. data_tostring_expr(class_name, data_params) },
            }
        end

        if not defined.__eq then
            methods[#methods + 1] = {
                name = "__eq",
                params = { { name = "other", type = class_name } },
                return_type = "boolean",
                visibility = "public",
                body = { "    return " .. data_eq_expr(data_params) },
            }
        end

        if not defined.copy then
            local args = {}
            for _, p in ipairs(data_params) do
                args[#args + 1] = "self." .. p.name
            end
            methods[#methods + 1] = {
                name = "copy",
                params = {},
                return_type = class_name,
                visibility = "public",
                body = { ("    return %s.new(%s)"):format(
                    class_name, table.concat(args, ", ")
                ) },
            }
        end
    end

    local out = {}

    local function emit(s)
        out[#out + 1] = s
    end

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


-- Scan forward from `start` for the matching `end` of a class/data-class body.
-- Depth tracking handles nested `public ... )` / `private ... )` / `constructor(`
-- scopes. Returns the line index AFTER the closing `end`.
local function find_class_end(lines, start)
    local depth = 1
    local i = start + 1

    while i <= #lines and depth > 0 do
        local s = trim(lines[i])
        if s == "end" then
            depth = depth - 1
        elseif s:match("^public%s+[%a_][%w_]*%b()") then
            depth = depth + 1
        elseif s:match("^private%s+[%a_][%w_]*%b()") then
            depth = depth + 1
        elseif s:match("^constructor%(") then
            depth = depth + 1
        elseif s:match("^data%s+class%s+") or s:match("^class%s+") then
            fail("nested class declarations are not supported", i)
        end
        i = i + 1
    end

    return depth, i
end

-- Extract a `data class Name(...)` block starting at line `start`.
local function extract_data_class(lines, start)
    local decl = trim(lines[start])
    local after_paren = decl:match("%)%s*(.*)$") or ""

    -- Single-line data class: `data class Name(params)` with nothing after `)`.
    -- Accept both `data class Name(...)` and `data class Name(...)` + `end`.
    if after_paren == "" then
        local next_line = start + 1
        if next_line <= #lines and trim(lines[next_line]) == "end" then
            return decl, next_line + 1
        end
        return decl, start + 1
    end

    local depth, i = find_class_end(lines, start)
    if depth > 0 then
        fail("unterminated data class (missing 'end')", start)
    end

    local block = {}
    for j = start, i - 1 do
        block[#block + 1] = lines[j]
    end
    return table.concat(block, "\n"), i
end

-- Extract a `class Name` block starting at line `start`.
-- `class Foo` is always a single line; the body follows.
local function extract_class(lines, start)
    local decl = trim(lines[start])
    local name = decl:match("^class%s+([%a_][%w_]*)")
    if not name then
        fail("invalid class declaration", start)
    end

    local depth, i = find_class_end(lines, start)
    if depth > 0 then
        fail("unterminated class (missing 'end')", start)
    end

    local block = {}
    for j = start, i - 1 do
        block[#block + 1] = lines[j]
    end
    return table.concat(block, "\n"), i
end


-- Strip the boilerplate M.compile adds that we don't want in program mode:
-- the "Generated by Teal++" header and the trailing `return Name` statement.
local function strip_module_boilerplate(compiled)
    compiled = compiled:gsub("^%-%- Generated by Teal%+%+;[^\n]*\n", "")
    compiled = compiled:gsub("(.-)%s*return%s+[%a_][%w_]*%s*$", "%1")
    return compiled
end


function M.compile_program(source)
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local out = {}
    local i = 1

    while i <= #lines do
        local stripped = trim(lines[i])

        if stripped:match("^data%s+class%s+") then
            local block, next_i = extract_data_class(lines, i)
            local compiled = M.compile(block .. "\n")
            compiled = strip_module_boilerplate(compiled)
            out[#out + 1] = compiled
            i = next_i

        elseif stripped:match("^class%f[%W]") then
            local block, next_i = extract_class(lines, i)
            local compiled = M.compile(block .. "\n")
            compiled = strip_module_boilerplate(compiled)
            out[#out + 1] = compiled
            i = next_i

        elseif stripped:match("^import%f[%W]") then
            local statement = stripped:match("^(.-)%s*%-%-") or stripped
            local module, alias = statement:match(
                "^import%s+([%a_][%w_%.]*)%s+as%s+([%a_][%w_]*)%s*$"
            )

            if not module or module:find("..", 1, true) or module:sub(-1) == "." then
                fail("invalid import; expected 'import module.path as Alias'", i)
            end

            out[#out + 1] = ("local %s = require(%q)"):format(alias, module)
            i = i + 1

        elseif stripped:match("^import%s") then
            fail("invalid import; expected 'import module.path as Alias'", i)

        else
            out[#out + 1] = lines[i]
            i = i + 1
        end
    end

    return table.concat(out, "\n")
end

return M
