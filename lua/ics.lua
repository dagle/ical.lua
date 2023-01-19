-- TODO
--- [x] We have some, maybe do some more
-- [x] linereader needs to be able to fold
-- [x] produce an ical from a table
-- [ ] verify functions


local function islist(t)
  if type(t) ~= 'table' then
    return false
  end

  local count = 0

  for k, _ in pairs(t) do
    if type(k) == 'number' then
      count = count + 1
    else
      return false
    end
  end

  return count > 0
end

local linereader = {}

function linereader:new(lines)
  local this = {}
  this.lines = lines
  this.linenr = 1
  self.__index = self
  setmetatable(this, self)

  return this
end

local function is_prop(value)
  if type(value) == "table" then
    return value.val ~= nil
  end
  return false
end

local function parse_date(val)
  local t, utc = {}, nil
  t.year, t.month, t.day = val:match("^(%d%d%d%d)(%d%d)(%d%d)")
  t.hour, t.min, t.sec, utc = val:match("T(%d%d)(%d%d)(%d%d)(Z?)")
  t.hour = t.hour or 0
  t.min = t.min or 0
  t.sec = t.sec or 0
  for k, v in pairs(t) do t[k] = tonumber(v) end
  t.utc = utc ~= "" or nil
  return t
end

-- TODO: We need to match the property to a print function
local function serialize_prop(buf, h, t)
  local str = { h }
  for k, v in pairs(t) do
    k = k:lower()
    if k ~= "val" then
      table.insert(str, v)
    end
  end
  local prop = table.concat(str, ";") .. ":" .. t.val
  table.insert(buf, prop)
end

local function serialize(t, buf)
  if type(t) == "table" then
    for k, v in pairs(t) do
      if islist(v) then
        for _, l in ipairs(v) do
          if is_prop(l) then
            serialize_prop(buf, k, l)
          else
            table.insert(buf, "BEGIN" .. ":" .. k)
            serialize(l, buf)
            table.insert(buf, "END" .. ":" .. k)
          end
        end
      elseif type(v) == "table" then
        if is_prop(v) then
          serialize_prop(buf, k, v)
        else
          table.insert(buf, "BEGIN" .. ":" .. k)
          serialize(v, buf)
          table.insert(buf, "END" .. ":" .. k)
        end
      elseif type(v) == "string" then
        table.insert(buf, k .. ":" .. v)
      elseif type(v) == "number" then
        table.insert(buf, k .. ":" .. tostring(v))
      end
    end
  end
end

local function make_ical(t)
  local buf = {}
  serialize(t, buf)
  return table.concat(buf, "\n")
end

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function concat(lastline, line)
  if lastline then
    return lastline .. " " .. trim(line)
  end
  return line
end

local function folded(line)
  return line:match("^%s")
end

local function unevenqoute(line)
  local _, s = line:gsub('"', '')
  return not (s % 2)
end

local function vand(...)
  for _, v in ipairs({ ... }) do
    if not v then
      return false
    end
  end
  return true
end

local function prop_required_once(t, prop)
  return t[prop] ~= nil and type(t[prop]) ~= "table"
end

local function prop_optional_once(t, prop)
end

local function prop_optional_many(t, prop)
  return true
end

local function verify_object_once(t, obj, fun)
  if t[obj] == nil or type(t[obj]) ~= "table" or t[obj][1] == nil then
    return false
  end
  return fun(t[obj])
end

local function verify_object_many(t, obj, fun)
  if t[obj] == nil or type(t[obj]) ~= "table" then
    return false
  end
  if t[obj][1] ~= nil then
    local ret = true
    for _, v in ipairs(t[obj]) do
      ret = ret and fun(v)
    end
    return ret
  end
  return fun(t[obj])
end

local function verify_action(t)
  return vand(
    prop_optional_many(t, "attach"),
    prop_optional_many(t, "attendee"),
    prop_optional_many(t, "categories"),
    prop_optional_once(t, "class"),
    prop_optional_many(t, "comment"),
    prop_optional_many(t, "contact"),
    prop_optional_once(t, "created"),
    prop_optional_once(t, "description"),
    prop_optional_once(t, "dtstamp"),
    prop_optional_once(t, "dtstart"),
    prop_optional_many(t, "exdate"),
    prop_optional_many(t, "exrule"),
    prop_optional_once(t, "last-mod"),
    prop_optional_once(t, "organizer"),
    prop_optional_many(t, "rdate"),
    prop_optional_once(t, "recurid"),
    prop_optional_many(t, "related"),
    prop_optional_many(t, "rrule"),
    prop_optional_many(t, "rsatus"),
    prop_optional_once(t, "seq"),
    prop_optional_once(t, "status"),
    prop_optional_once(t, "summary"),
    prop_optional_once(t, "uid"),
    prop_optional_once(t, "url"),
    prop_optional_many(t, "x-prop")
  )
end

local function verify_valarm(t)
  return vand(
    prop_required_once(t, "action"),
    prop_optional_once(t, "due"),
    prop_optional_once(t, "repeat"),
    prop_required_once(t, "trigger"),
    prop_optional_many(t, "x-prop")
  )
end

local function verify_vevent(t)
  return vand(
    verify_action(t),
    -- dtend,
    -- duration,
    prop_optional_once(t, "completed"),
    prop_optional_once(t, "geo"),
    prop_optional_once(t, "location"),
    prop_optional_once(t, "priority"),
    prop_optional_many(t, "resources"),
    prop_optional_once(t, "transp"),
    verify_object_many(t, "valarm", verify_valarm)
  )
end

local function verify_vtodo(t)
  return vand(
    verify_action(t),
    -- due,
    -- duration,
    prop_optional_once(t, "geo"),
    prop_optional_once(t, "location"),
    verify_object_many(t, "valarm", verify_valarm)
  )
end

local function verify_vjournal(t)
  return verify_action(t)
end

local function verify_vfreebusy(t)
  return vand(
    prop_optional_many(t, "attendee"),
    prop_optional_many(t, "comment"),
    prop_optional_once(t, "contact"),
    prop_optional_once(t, "dtend"),
    prop_optional_once(t, "dtstamp"),
    prop_optional_once(t, "dtstart"),
    prop_optional_once(t, "duration"),
    prop_optional_many(t, "freebusy"),
    prop_optional_once(t, "organizer"),
    prop_optional_many(t, "rstatus"),
    prop_optional_once(t, "uid"),
    prop_optional_once(t, "url"),
    prop_optional_many(t, "x-prop")
  )
end

local function verify_vtimezone(t)
  return vand(
    prop_optional_once(t, "last-mod"),
    prop_required_once(t, "tzid"),
    prop_optional_once(t, "tzurl")
  )
end

local function count_objects(t, ...)
  local counter = 0;
  for _, v in ipairs({ ... }) do
    if t[v] then
      counter = counter + 1
    end
  end
  return counter
end

local function verify(ical)
  return vand(
    count_objects("vevent", "vtodo", "vjournal", "vfreebusy", "vtimezone") < 1,
    prop_optional_once(ical, "calscale"),
    prop_optional_once(ical, "method"),
    prop_required_once(ical, "prodid"),
    prop_required_once(ical, "version"),
    prop_optional_once(ical, "x-prop"),
    verify_object_once(ical, "vevent", verify_vevent),
    verify_object_once(ical, "vtodo", verify_vtodo),
    verify_object_once(ical, "vjournal", verify_vjournal),
    verify_object_once(ical, "vfreebusy", verify_vfreebusy),
    verify_object_once(ical, "vtimezone", verify_vtimezone)
  )
end

local function generator(source, fun)
  local lines = {}
  local lastline
  local qouted = false
  for line in fun(source) do
    if qouted or folded(line) then
      lastline = concat(lastline, line)
    else
      table.insert(lines, lastline)
      lastline = line
    end
    if unevenqoute(line) then
      qouted = not qouted
    end
  end
  table.insert(lines, lastline)
  return linereader:new(lines)
end

local function filereader(file)
  return generator(file, io.lines)
end

local function stringreader(str)
  return generator(str, function(source) return string.gmatch(source, "[^\r\n]+") end)
end

function linereader:skip()
  self.linenr = self.linenr + 1
end

--- @return string|nil, string|nil
function linereader:peek()
  local line = self.lines[self.linenr]
  if not line then
    return nil, nil
  end
  local k, v = line:match("^(.-):(.*)$")
  if not (k and v) then
    error("No key value found")
  end
  return trim(k), trim(v)
end

--- @return string|nil, string|nil
function linereader:read()
  local k, v = self:peek()
  self:skip()
  return k, v
end

function linereader:iterate()
  return function()
    local k, v = self:read()
    return k, v
  end
end

local function insert(entry, key, obj)
  if entry[key] then
    if islist(entry[key]) then
      table.insert(entry[key], obj)
    else
      entry[key] = { entry[key], obj }
    end
  else
    entry[key] = obj
  end
end

--- TODO: don't go over the whole string
local function split(str, delim)
  local pattern = string.format("[^%s]+", delim)
  -- local match = string.find(pattern)
  local parts = {}
  for i in str:gmatch(pattern) do
    table.insert(parts, i)
  end
  return parts[1], parts[2]
end

local function getentry(key, val)
  local entry_name, rest = split(key, ";")
  if rest then
    local ret = {}
    ret.val = val
    for p in rest:gmatch("[^;]+") do
      local prop_name, value = split(p, "=")
      ret[prop_name] = value
    end
    return entry_name, ret
  else
    return entry_name, val
  end
end

local function insert_prop(cal, k, v)
  local key, entry = getentry(k, v)
  insert(cal, key, entry)
end

--- This parser is optimistic,
--- It can parse bad icals
--- You might want to run a verify on the output
local function parse(lr, inval)
  if not inval then
    local k, v = lr:peek()
    if k ~= "BEGIN" or v ~= "VCALENDAR" then
      return nil
    end
  end
  local entry = {}
  for k, v in lr:iterate() do
    if k == "BEGIN" then
      local object = parse(lr, v)
      insert(entry, v, object)
    elseif k == "END" then
      if inval and inval ~= v then
        error("Not matching begin and end")
      end
      return entry
    else
      insert_prop(entry, k, v)
    end
  end
  return entry
end

return {
  parse_date = parse_date,
  parse = parse,
  filereader = filereader,
  stringreader = stringreader,
  make_ical = make_ical,
  verify = verify,
}
