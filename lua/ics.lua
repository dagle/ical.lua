-- TODO 
-- [ ] convert keys to lower case (why?)
-- [ ] convert properties from strings (when possible)
-- [ ] read from string/etc
-- [x] linereader needs to be able to fold
-- [ ] produce an ical from a table
-- [ ] verify functions
local linereader = {}

function linereader:new(lines)
	local this = {}
	this.lines = lines
	this.linenr = 1
	self.__index = self
	setmetatable(this, self)

	return this
end

local function make_vevent(t, buf)
end

local function make_vtodo(t, buf)
end

local function make_vjournal(t, buf)
end

local function make_vfreebusy(t, buf)
end

local function make_vtimezone(t, buf)
end

local function make_ical(t, id)
	local strtbl = {}
	table.insert(strtbl, "BEGIN:VCALENDAR")
	table.insert(strtbl, "VERSION:2.0")
	table.insert(strtbl, "PRODID:" .. id)
	if t["vevent"] then
		make_vevent(t, strtbl)
	end
	if t["vtodo"] then
		make_vtodo(t, strtbl)
	end
	if t["vjournal"] then
		make_vjournal(t, strtbl)
	end
	if t["vfreebusy"] then
		make_vfreebusy(t, strtbl)
	end
	if t["vtimezone"] then
		make_vtimezone(t, strtbl)
	end
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
	local _, s = line:gsub('"','')
	return not (s % 2)
end

local function vand(...)
	for _, v in ipairs({...}) do
		if not v then
			return false
		end
	end
	return true
end

local function prop_required_once(t, prop)
	return t[prop] ~= nil and type(t[prop]) ~= "table"
end

-- local function prop_required_many(t, prop)
-- end

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
	for _, v in ipairs({...}) do
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

local function filereader(file)
	local lines = {}
	local lastline
	local qouted = false
	for line in io.lines(file) do
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

local function stringreader(str)
	local lines = {}
	local lastline
	local qouted = false
	for line in str:gmatch("[^\r\n]") do
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

local function parse_date(val)
	-- TODO handle utc
	local t, utc = {}, nil
	t.year, t.month, t.day = val:match("^(%d%d%d%d)(%d%d)(%d%d)")
	t.hour, t.min, t.sec, utc = val:match("T(%d%d)(%d%d)(%d%d)(Z?)")
	t.hour = t.hour or 0
	t.min = t.min or 0
	t.sec = t.sec or 0
	for k,v in pairs(t) do t[k] = tonumber(v) end
	return os.time(t)
end

local function parse_dates(v)
	if v:find(",") then
		local values = {}
		for l in v:gmatch("[^,]+") do
			table.insert(values, parse_date(l))
		end
		return values
	end
	return parse_date(v)
end

local proptable = {
	action = nil,
	attach = nil,
	attendee = nil,
	calscale = nil,
	categories = nil,
	class = nil,
	comment = nil,
	completed = nil,
	contact = nil,
	created = nil,
	description = nil,
	DTEND = parse_dates,
	DTSTAMP = parse_dates,
	DTSTART = parse_dates,
	due = nil,
	duration = nil,
	exdate = nil,
	exrule = nil,
	freebusy = nil,
	geo = nil,
	["last-mod"] = nil,
	location = nil,
	method = nil,
	organizer = nil,
	percent = nil,
	priority = nil,
	prodid = nil,
	rdate = nil,
	recurid = nil,
	related = nil,
	["repeat"] = nil,
	resources = nil,
	rrule = nil,
	rstatus = nil,
	seq = nil,
	status = nil,
	summary = nil,
	tranp = nil,
	trigger = nil,
	tzld = nil,
	tzname = nil,
	tzoffsetfrom = nil,
	tzoffsetto = nil,
	tzurl = nil,
	uid = nil,
	url = nil,
	version = nil,
	["x-prop"] = nil,
}

local function parse_value(k, v)
	if proptable[k] then
		return proptable[k](v)
	end
	return v
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
	local k,v = line:match("^(.-):(.*)$")
	if not (k and v) then
		error("No key value found")
	end
	-- local value = parse_value(k, v)
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
		if type(entry[key]) == "table" then
			table.insert(entry[key], obj)
		else
			entry[key] = {entry[key], obj}
		end
	else
		entry[key] = obj
	end
end

--- TODO don't go over the whole string
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
	local parsed_val = parse_value(entry_name, val)
	if rest then
		local ret = {}
		ret.val = parsed_val
		ret.params = {}
		for p in rest:gmatch("[^;]+") do
			local prop_name, value = split(p, "=")
			ret.params[prop_name] = value
		end
		return entry_name, ret
	else
		return entry_name, parsed_val
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

local function test(file)
	local lr = filereader(file)
	local ical = parse(lr, nil)
	return ical
end

return {
	parse = parse,
	filereader = filereader,
	stringreader = stringreader,
	make_ical = make_ical,
	verify = verify,
}
