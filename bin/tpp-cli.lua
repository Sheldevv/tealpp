#!/usr/bin/env lua
-- Teal++ command-line driver.

local function usage()
    io.stdout:write([[
Teal++

Usage:
  tpp <file.tpp> [options]             Compile a class-definition file (legacy)
  tpp build <file.tpp> [options]       Compile a program or class automatically
  tpp check <file.tpp> [options]       Compile and type-check a program
  tpp run <file.tpp> [options]         Build and run a plain Lua program
  tpp love <file.tpp> [options]        Build and launch a LÖVE project
  tpp bundle <file.tpp> [options]      Stage a distributable bundle directory
  tpp package <file.tpp> [options]     Produce a distributable artifact
  tpp test                             Run the Teal++ test suite

Options:
  -o, --output <path>   Output .tl (build/check/run/love);
                        output directory (bundle/package)
  --program             Force application/program mode
  --class               Force class-definition mode
  --no-check            Skip `tl check` during build
  --name <name>         Artifact name (default: input filename stem)
  --target <os>         linux | windows | macos (required for package)
  --love-bin <path>     LÖVE binary (linux) or directory (windows, macos)
  -h, --help            Show this help

Packaging:
  tpp bundle examples/showcase/main.tpp
  tpp package examples/showcase/main.tpp --target linux
  tpp package examples/showcase/main.tpp --target linux --love-bin /usr/bin/love
  tpp package examples/showcase/main.tpp --target windows --love-bin ~/love-11.4-win64
  tpp package examples/showcase/main.tpp --target macos --love-bin ~/love.app
]])
end

local function fail(message, code)
    io.stderr:write("tpp: " .. message .. "\n")
    os.exit(code or 1)
end

local function quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function is_file(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then fail("cannot open " .. path .. ": " .. tostring(err)) end
    local value = f:read("*a")
    f:close()
    return value
end

local function write_file(path, value)
    local f, err = io.open(path, "w")
    if not f then fail("cannot write " .. path .. ": " .. tostring(err)) end
    f:write(value)
    if value:sub(-1) ~= "\n" then f:write("\n") end
    f:close()
end

local function write_executable(path, value)
    write_file(path, value)
    os.execute("chmod +x " .. quote(path) .. " 2>/dev/null")
end

local function command_ok(command)
    io.stdout:write("+ " .. command .. "\n")
    local a, b, c = os.execute(command)
    if a == true or a == 0 then return true end
    if b == "exit" and c == 0 then return true end
    return false
end

local function has_command(name)
    local a, b, c = os.execute("command -v " .. quote(name) .. " >/dev/null 2>&1")
    return a == true or a == 0 or (b == "exit" and c == 0)
end

local function stem(path)
    return (path:gsub("%.tpp$", ""))
end

local function dir_name(path)
    local dir = path:match("^(.*)/[^/]*$")
    if not dir or dir == "" then return "." end
    return dir
end

local function basename(path)
    return path:match("([^/]+)$") or path
end

local function directory_exists(path)
    local a, b, c = os.execute("test -d " .. quote(path) .. " >/dev/null 2>&1")
    return a == true or a == 0 or (b == "exit" and c == 0)
end

-- Resolve to absolute path for zip -f, which resolves relative to CWD at
-- command-execution time, not at the time we `cd`.
local CWD_CACHE = nil
local function get_cwd()
    if CWD_CACHE then return CWD_CACHE end
    local p = io.popen("pwd -P")
    local cwd = p:read("*l")
    p:close()
    CWD_CACHE = cwd
    return cwd
end

local function abs(path)
    if path:sub(1, 1) == "/" then return path end
    path = path:gsub("^%./", "")
    if path == "." then return get_cwd() end
    return get_cwd() .. "/" .. path
end

local function mkdir_p(path)
    return command_ok("mkdir -p " .. quote(path))
end

local function rm_rf(path)
    return command_ok("rm -rf " .. quote(path))
end

local function cp(src, dst)
    return command_ok("cp " .. quote(src) .. " " .. quote(dst))
end

local function cp_r(src, dst)
    return command_ok("cp -R " .. quote(src) .. " " .. quote(dst))
end

local function cp_r_contents(src_dir, dst_dir)
    return command_ok("cp -R " .. quote(src_dir .. "/.") .. " " .. quote(dst_dir))
end

local function zip_dir_contents(src_dir, out_zip)
    return command_ok("cd " .. quote(src_dir) .. " && zip -r -q " .. quote(abs(out_zip)) .. " .")
end

local function zip_dir(dir_to_zip, out_zip)
    local parent = dir_name(dir_to_zip)
    local name = basename(dir_to_zip)
    return command_ok("cd " .. quote(parent) .. " && zip -r -q " .. quote(abs(out_zip)) .. " " .. quote(name))
end

local function tar_gz_dir(dir_to_tar, out_tgz)
    local parent = dir_name(dir_to_tar)
    local name = basename(dir_to_tar)
    return command_ok("tar -czf " .. quote(abs(out_tgz)) .. " -C " .. quote(parent) .. " " .. quote(name))
end

local function script_root()
    local script = arg[0] or "bin/tpp"
    script = script:gsub("\\", "/")
    local bin_dir = script:match("^(.*)/[^/]+$")
    if not bin_dir then return "." end
    return bin_dir:gsub("/bin$", "")
end

local ROOT = script_root()

local function ensure_gamekit(project_dir, with_runtime)
    local gamekit_source = ROOT .. "/gamekit"
    local decl_source = ROOT .. "/gamekit.d.tl"
    if exists(decl_source) and not exists(project_dir .. "/gamekit.d.tl") then
        if not cp(decl_source, project_dir .. "/gamekit.d.tl") then
            fail("could not stage GameKit type declarations into " .. project_dir)
        end
    end
    if with_runtime and directory_exists(gamekit_source) and not directory_exists(project_dir .. "/gamekit") then
        if not cp_r(gamekit_source, project_dir .. "/gamekit") then
            fail("could not stage GameKit runtime into " .. project_dir)
        end
    end
end

local transpiler_path = ROOT .. "/src/tpp.lua"
local ok, transpiler = pcall(dofile, transpiler_path)
if not ok then
    ok, transpiler = pcall(dofile, "src/tpp.lua")
end
if not ok then fail("cannot load compiler source: " .. tostring(transpiler)) end

local commands = {
    build = true, check = true, run = true, love = true,
    bundle = true, package = true, test = true,
}
local first = arg[1]
if first == "--help" or first == "-h" then usage(); os.exit(0) end

if first == "uninstall" then
    local uninstaller = ROOT .. "/uninstall.sh"
    if exists(uninstaller) then
        os.exit(os.execute(quote(uninstaller) .. " " .. table.concat(arg, " ", 2)) and 0 or 1)
    end
    fail("uninstall.sh not found; run it manually from the repo")
end

if first == "test" then
    local tests = {
        "tests/run_program.lua", "tests/run_color.lua", "tests/run_gamekit.lua",
        "tests/run_gui.lua", "tests/run_window.lua", "tests/run_dock.lua",
        "tests/run_camera.lua", "tests/run_app.lua",
    }
    for _, test in ipairs(tests) do
        local test_path = ROOT .. "/" .. test
        if exists(test_path) then
            if not command_ok("cd " .. quote(ROOT) .. " && lua " .. quote(test)) then
                fail("test failed: " .. test)
            end
        else
            io.stderr:write("tpp: skipping missing test " .. test .. "\n")
        end
    end

    if exists(ROOT .. "/examples/hello/main.tpp") and has_command("zip") and is_file(ROOT .. "/bin/tpp") then
        local smoke_name = "_tpp_smoke"
        local smoke_dir = ROOT .. "/build/" .. smoke_name
        local smoke_love = ROOT .. "/build/" .. smoke_name .. ".love"
        local smoke_dist = ROOT .. "/dist/" .. smoke_name .. "-linux"
        local smoke_tgz = ROOT .. "/dist/" .. smoke_name .. "-linux.tar.gz"
        os.execute("rm -rf " .. quote(smoke_dir) .. " " .. quote(smoke_love)
            .. " " .. quote(smoke_dist) .. " " .. quote(smoke_tgz))

        if not command_ok("cd " .. quote(ROOT) .. " && ./bin/tpp bundle examples/hello/main.tpp --name " .. smoke_name) then
            fail("packaging smoke test: bundle failed")
        end
        if not exists(smoke_love) then fail("packaging smoke: missing " .. smoke_love) end
        if not exists(smoke_dir .. "/main.lua") then fail("packaging smoke: bundle missing main.lua") end
        if not exists(smoke_dir .. "/gamekit/init.lua") then fail("packaging smoke: bundle missing gamekit/") end

        if not command_ok("cd " .. quote(ROOT) .. " && ./bin/tpp package examples/hello/main.tpp --name " .. smoke_name .. " --target linux") then
            fail("packaging smoke test: package failed")
        end
        if not exists(smoke_tgz) then fail("packaging smoke: missing " .. smoke_tgz) end

        os.execute("rm -rf " .. quote(smoke_dir) .. " " .. quote(smoke_love)
            .. " " .. quote(smoke_dist) .. " " .. quote(smoke_tgz))
        print("OK: packaging smoke")
    else
        io.stderr:write("tpp: skipping packaging smoke test (missing example, bin/tpp, or zip)\n")
    end

    os.exit(0)
end

local action = "legacy"
local index = 1
if commands[first] then action = first; index = 2 end

local input, output_path
local force_mode, no_check = nil, false
local artifact_name, package_target, love_bin
while index <= #arg do
    local value = arg[index]
    if value == "-h" or value == "--help" then usage(); os.exit(0)
    elseif value == "-o" or value == "--output" then
        index = index + 1
        output_path = arg[index]
        if not output_path then fail(value .. " requires a path") end
    elseif value == "--program" then force_mode = "program"
    elseif value == "--class" then force_mode = "class"
    elseif value == "--no-check" then no_check = true
    elseif value == "--name" then
        index = index + 1
        artifact_name = arg[index]
        if not artifact_name then fail("--name requires a value") end
    elseif value == "--target" then
        index = index + 1
        package_target = arg[index]
        if not package_target then fail("--target requires a value") end
    elseif value == "--love-bin" then
        index = index + 1
        love_bin = arg[index]
        if not love_bin then fail("--love-bin requires a path") end
    elseif value:sub(1, 1) == "-" then fail("unknown option " .. value .. "\nTry 'tpp --help'.")
    elseif not input then input = value
    else fail("unexpected argument " .. value .. "\nTry 'tpp --help'.") end
    index = index + 1
end

if not input then usage(); os.exit(1) end
if not input:match("%.tpp$") then fail("input must end in .tpp: " .. input) end
local source = read_file(input)

local mode = force_mode
if not mode then
    if action == "legacy" then
        mode = "class"
    elseif source:match("^[^\n]*import%s+[%w_%.]+%s+as%s+[%w_]+")
        or source:match("\n%s*import%s+[%w_%.]+%s+as%s+[%w_]+") then
        mode = "program"
    else
        mode = "class"
    end
end

if (action == "bundle" or action == "package") and mode ~= "program" then
    fail(action .. " requires program mode; add an import or pass --program")
end

local compile = mode == "program" and transpiler.compile_program or transpiler.compile
if type(compile) ~= "function" then fail("this compiler does not support " .. mode .. " mode") end
local success, generated = pcall(compile, source)
if not success then fail("transpilation failed: " .. tostring(generated)) end

local tl_path
if action == "bundle" or action == "package" then
    tl_path = stem(input) .. ".tl"
else
    tl_path = output_path or (stem(input) .. ".tl")
end
write_file(tl_path, generated)
print("Generated " .. tl_path .. " (" .. mode .. " mode)")

if action == "legacy" then os.exit(0) end

local project_dir = dir_name(tl_path)
local tl_name = basename(tl_path)
local lua_path = tl_path:gsub("%.tl$", ".lua")
if lua_path == tl_path then
    fail("output path must end in .tl to derive the generated Lua path: " .. tl_path)
end
local lua_name = basename(lua_path)

if mode == "program" then
    ensure_gamekit(project_dir, action == "run" or action == "love")
end

local function run_in_project(command)
    return command_ok("cd " .. quote(project_dir) .. " && " .. command)
end

if action == "build" then
    if not no_check and not run_in_project("tl check " .. quote(tl_name)) then fail("Teal type-check failed") end
    if not run_in_project("tl gen " .. quote(tl_name)) then fail("Teal generation failed") end
    print("Build complete: " .. lua_path)
    os.exit(0)
end

if action == "check" then
    if not run_in_project("tl check " .. quote(tl_name)) then fail("Teal type-check failed") end
    print("Check passed: " .. tl_path)
    os.exit(0)
end

if action == "run" or action == "love" then
    if not no_check and not run_in_project("tl check " .. quote(tl_name)) then fail("Teal type-check failed") end
    if not run_in_project("tl gen " .. quote(tl_name)) then fail("Teal generation failed") end
    if not exists(lua_path) then fail("Teal did not produce expected output: " .. lua_path) end
    if action == "run" then
        if not run_in_project("lua " .. quote(lua_name)) then fail("program exited with an error") end
    else
        if lua_name ~= "main.lua" then
            io.stderr:write("tpp: note: LÖVE expects main.lua; this source generates " .. lua_name .. "\n")
        end
        if not command_ok("love " .. quote(project_dir)) then fail("LÖVE exited with an error") end
    end
    os.exit(0)
end

if action == "bundle" or action == "package" then
    if not no_check and not run_in_project("tl check " .. quote(tl_name)) then fail("Teal type-check failed") end
    if not run_in_project("tl gen " .. quote(tl_name)) then fail("Teal generation failed") end
    if not exists(lua_path) then fail("Teal did not produce expected output: " .. lua_path) end

    local name = artifact_name or basename(stem(input))
    if name == "" or name == "." or name == ".." or name:find("[/\\]") then
        fail("invalid --name: " .. tostring(name))
    end

    local build_root = ROOT .. "/build"
    local dist_root = ROOT .. "/dist"
    if action == "bundle" and output_path then
        build_root = output_path
    elseif action == "package" and output_path then
        dist_root = output_path
    end

    local bundle_dir = build_root .. "/" .. name
    local love_path = build_root .. "/" .. name .. ".love"

    if not mkdir_p(build_root) then fail("could not create " .. build_root) end
    if not rm_rf(bundle_dir) then fail("could not clear " .. bundle_dir) end
    if not mkdir_p(bundle_dir) then fail("could not create " .. bundle_dir) end

    if not cp(lua_path, bundle_dir .. "/main.lua") then
        fail("could not copy generated main.lua into bundle")
    end

    if exists(project_dir .. "/conf.lua") then
        if not cp(project_dir .. "/conf.lua", bundle_dir .. "/conf.lua") then
            fail("could not copy conf.lua")
        end
    end

    if directory_exists(project_dir .. "/assets") then
        if not cp_r(project_dir .. "/assets", bundle_dir .. "/assets") then
            fail("could not copy assets/")
        end
    end

    ensure_gamekit(bundle_dir, true)

    if not has_command("zip") then
        io.stderr:write("tpp: warning: 'zip' not installed; skipping .love creation\n")
        io.stderr:write("tpp:          install zip (apt install zip / brew install zip)\n")
    else
        if exists(love_path) then rm_rf(love_path) end
        if not zip_dir_contents(bundle_dir, love_path) then
            fail("could not create " .. love_path)
        end
        write_executable(build_root .. "/" .. name .. ".sh",
            "#!/bin/sh\nexec love \"$(dirname \"$0\")/" .. name .. ".love\" \"$@\"\n")
        print("Bundled:  " .. love_path)
        print("Launcher: " .. build_root .. "/" .. name .. ".sh")
    end
    print("Staging:  " .. bundle_dir)

    if action == "bundle" then os.exit(0) end

    if not package_target then
        fail("package requires --target <linux|windows|macos>")
    end
    if not exists(love_path) then
        fail("cannot package without .love; install zip and rerun")
    end
    if not mkdir_p(dist_root) then fail("could not create " .. dist_root) end

    local artifact

    if package_target == "linux" then
        local dist_pkg = dist_root .. "/" .. name .. "-linux"
        local tgz = dist_root .. "/" .. name .. "-linux.tar.gz"
        if not rm_rf(dist_pkg) then fail("could not clear " .. dist_pkg) end
        if not mkdir_p(dist_pkg) then fail("could not create " .. dist_pkg) end
        if not cp(love_path, dist_pkg .. "/" .. name .. ".love") then
            fail("could not stage .love")
        end

        if love_bin then
            if not is_file(love_bin) then
                fail("--love-bin must be a file (the love executable) for --target linux")
            end
            if not cp(love_bin, dist_pkg .. "/love") then fail("could not copy love binary") end
            os.execute("chmod +x " .. quote(dist_pkg .. "/love") .. " 2>/dev/null")
            write_executable(dist_pkg .. "/run.sh",
                "#!/bin/sh\nexec \"$(dirname \"$0\")/love\" \"$(dirname \"$0\")/" .. name .. ".love\" \"$@\"\n")
        else
            write_executable(dist_pkg .. "/run.sh",
                "#!/bin/sh\nexec love \"$(dirname \"$0\")/" .. name .. ".love\" \"$@\"\n")
            write_file(dist_pkg .. "/README.txt",
                "This package does not bundle the LÖVE runtime.\n"
                .. "Install LÖVE 11+ from https://love2d.org and run ./run.sh\n")
        end

        if exists(tgz) then rm_rf(tgz) end
        if not tar_gz_dir(dist_pkg, tgz) then fail("could not create " .. tgz) end
        artifact = tgz

    elseif package_target == "windows" then
        local dist_pkg = dist_root .. "/" .. name .. "-windows"
        local zip_out = dist_root .. "/" .. name .. "-windows.zip"
        if not rm_rf(dist_pkg) then fail("could not clear " .. dist_pkg) end
        if not mkdir_p(dist_pkg) then fail("could not create " .. dist_pkg) end
        if not cp(love_path, dist_pkg .. "/" .. name .. ".love") then
            fail("could not stage .love")
        end

        if love_bin then
            if not directory_exists(love_bin) then
                fail("--love-bin for --target windows must be a directory containing love.exe")
            end
            if not exists(love_bin .. "/love.exe") then
                fail("--love-bin directory must contain love.exe: " .. love_bin)
            end
            if not cp_r_contents(love_bin, dist_pkg) then
                fail("could not copy LÖVE Windows runtime")
            end
            local fused = dist_pkg .. "/" .. name .. ".exe"
            if exists(fused) then rm_rf(fused) end
            if not command_ok("cat " .. quote(dist_pkg .. "/love.exe")
                .. " " .. quote(love_path) .. " > " .. quote(fused)) then
                fail("could not fuse love.exe + .love into " .. fused)
            end
            write_file(dist_pkg .. "/README.txt",
                "Run " .. name .. ".exe to play.\n"
                .. "Requires: same-directory love.exe DLLs (SDL2, OpenAL, etc.) shipped here.\n"
                .. "Alternatively, drag " .. name .. ".love onto love.exe.\n")
        else
            write_file(dist_pkg .. "/README.txt",
                "This package does not bundle the LÖVE runtime.\n"
                .. "Download LÖVE 11+ for Windows from https://love2d.org and\n"
                .. "drag " .. name .. ".love onto love.exe, or pass --love-bin <dir>\n"
                .. "where <dir> contains love.exe and its DLLs.\n")
        end

        if exists(zip_out) then rm_rf(zip_out) end
        if not zip_dir(dist_pkg, zip_out) then fail("could not create " .. zip_out) end
        artifact = zip_out

    elseif package_target == "macos" then
        local dist_pkg = dist_root .. "/" .. name .. "-macos"
        local tgz = dist_root .. "/" .. name .. "-macos.tar.gz"
        if not rm_rf(dist_pkg) then fail("could not clear " .. dist_pkg) end
        if not mkdir_p(dist_pkg) then fail("could not create " .. dist_pkg) end
        if not cp(love_path, dist_pkg .. "/" .. name .. ".love") then
            fail("could not stage .love")
        end

        if love_bin then
            if not directory_exists(love_bin) then
                fail("--love-bin for --target macos must be love.app (directory)")
            end
            if not directory_exists(love_bin .. "/Contents") then
                fail("--love-bin does not look like a .app bundle: " .. love_bin)
            end
            local app_name = name .. ".app"
            if not cp_r(love_bin, dist_pkg .. "/" .. app_name) then
                fail("could not copy love.app")
            end
            local resources = dist_pkg .. "/" .. app_name .. "/Contents/Resources"
            if not directory_exists(resources) then
                fail("love.app is missing Contents/Resources/")
            end
            if not cp(love_path, resources .. "/" .. name .. ".love") then
                fail("could not drop game into .app Resources")
            end
            write_file(dist_pkg .. "/README.txt",
                "macOS .app bundle created: " .. app_name .. "\n"
                .. "Game embedded at Contents/Resources/" .. name .. ".love\n\n"
                .. "For distribution you must:\n"
                .. "  1. codesign --deep --force --sign 'Developer ID Application: ...' " .. app_name .. "\n"
                .. "  2. xcrun notarytool submit " .. name .. ".zip --wait --apple-id ...\n"
                .. "  3. xcrun stapler staple " .. app_name .. "\n"
                .. "See PACKAGING.md for details.\n")
        else
            write_file(dist_pkg .. "/README.txt",
                "This package does not bundle the LÖVE runtime.\n"
                .. "Install LÖVE 11+ for macOS from https://love2d.org, then open "
                .. name .. ".love.\n"
                .. "Or pass --love-bin ~/love.app to produce an unsigned .app bundle.\n")
        end

        if exists(tgz) then rm_rf(tgz) end
        if not tar_gz_dir(dist_pkg, tgz) then fail("could not create " .. tgz) end
        artifact = tgz

    else
        fail("--target must be linux, windows, or macos")
    end

    if artifact and exists(artifact) then
        print("Packaged: " .. artifact)
    else
        fail("package did not produce an artifact")
    end
    os.exit(0)
end

fail("unsupported command " .. action)
