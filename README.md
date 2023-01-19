# ical.lua
A parser and producer for the ical format.
The parser isn't strict, but you can verify the output

The parser has no time localization for that you have to bring your own
code. I want to keep the lib small. Here is an example in lua to convert
value to local time etc (using luatz).

``` lua
local get_tz = require("luatz").get_tz
local function make_local_entry(t, tz_name)
  local tzinfo = get_tz(tz_name)
  local ts = os.time(t)
  local tt = tzinfo:find_current(ts)
  return tt.abbr .. ":" .. ts
end

local function local_time(t, tz_name)
  tz_name = tz_name or (t.utc and "UTC")
  local tzinfo = get_tz(tz_name)
  local utc = tzinfo:utctime(os.time(t))
  local localtz = get_tz()
  local lt = localtz:localize(utc)
  return lt
end
```
