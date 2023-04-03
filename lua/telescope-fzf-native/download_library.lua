local uv = vim.loop
local plugin_path = string.sub(debug.getinfo(1).source, 2, #"//lua/telescope-fzf-native/download_library.lua" * -1)
local releases_url = "https://github.com/airtonix/telescope-fzf-native.nvim/releases/download"


local get_valid_compiler = function(platform)
  if platform == "windows" then
    return "cc"
  elseif platform == "macos" then
    return "gcc"
  elseif platform == "linux" then
    return "gcc"
  end
end

local spawn = function(cmd, on_exit)
  local stdout = uv.new_pipe()

  local buffer = ""

  local real_cmd = table.remove(cmd, 1)

  uv.spawn(real_cmd, {
    args = cmd,
    stdio = { nil, stdout },
    verbatim = true,
  }, function()
    stdout:read_stop()
    if type(on_exit) == "function" then
      on_exit(buffer)
    end
  end)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      buffer = buffer .. data
    end
  end)
end

--
-- Given a platform, compiler and version; download
-- the appropriate binary from our releases on github.
--
-- Ensures the expected 'build' directory exists before
-- downloading.
--
-- Reminder:
--
-- The filenames to download are defined as a side effect of the
-- matrix build names in `.github/actions/compile-unix/action.yml` and
-- `.github/actions/compile-windows/action.yml`, then also due to how
-- `.github/actions/prepare-artifacts/action.yml` downloads the artifacts
-- before uploading as releases.
--
-- The filename pattern is generally:
--
--   mac and linux: {github-runner-osname}-{compiler}/libfzf.so
--   windows: {github-runner-osname}-{compiler}/libfzf.dll
--
-- Files in a github release are required to be unique per filename, so we
-- mutate the above downloaded artifacts into:
--
--   {github-runner-osname}-{compiler}-libfzf.{type}
--
-- This downloader then can pick the right binary and save it the users
-- local disk as `libfzf.so` or `libfzf.dll`
--
return function(options)
  options = options or {}
  local platform = options.platform or jit.os
  local arch = options.arch or jit.arch
  local compiler = options.compiler or get_valid_compiler(platform)
  local version = options.version or "dev"

  local path_separator = (platform == "windows") and "\\" or "/"
  local build_path = table.concat({ plugin_path, "build" }, path_separator)
  local download_file = nil
  local binary_file = nil

  if platform == "windows" then
    download_file = string.format("win32-%s-libfzf.dll", compiler)
    binary_file = "libfzf.dll"
  end

  if platform == "linux" then
    download_file = string.format("linux-%s-libfzf.so", compiler)
    binary_file = "libfzf.so"
  end

  if platform == "macos" then
    download_file = string.format("macos-%s-libfzf.so", compiler)
    binary_file = "libfzf.so"
  end

  -- Ensure the Build directory exists
  uv.fs_mkdir(build_path, 511)

  local source = table.concat({ releases_url, version, download_file }, "/")
  local target = table.concat({ build_path, binary_file }, path_separator)

  print("downloading", source, "to", target)

  -- Curl the download
  spawn {
    "curl",
    "-L",
    source,
    "-o",
    target,
  }
end
