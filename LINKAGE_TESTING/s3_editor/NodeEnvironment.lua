--- TODO!
-- @module NodeEnvironment

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local assert = assert
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local component = require("tektite_core.component")

-- Exports --
local M = {}

--
--
--

local function Mangle (what, which)
	return which .. ":" .. tostring(what) -- reasonably unique name
end

local function GetInterfaces (env, what, which)
	local ifx_list = env.m_interface_lists[which]
	local interfaces = ifx_list and ifx_list[what]

	if type(interfaces) == "number" then -- index?
		return env.m_mangled[interfaces]
	else
		local index, list = #env.m_mangled + 1

		if interfaces then
			for i = 1, #interfaces do
				list = adaptive.Append(list, Mangle(which, interfaces[i]))
			end
		else
			list = adaptive.Append(nil, Mangle(which, what))
		end

		env.m_mangled[index], ifx_list[what] = list, index

		return list
	end
end

local Modifiers = {
	["-"] = "limit", ["+"] = "limit",
	["="] = "strict",
	["!"] = "wildcard", ["?"] = "wildcard"
}

local function ExtractModifiers (what)
	local mods

	for _ = 1, #what do
		local last = what:sub(-1)
		local modifier = Modifiers[last]

		if modifier then
			assert(not (mods and mods[modifier]) or mods[modifier] == last, "Conflicting modifiers")

			mods = mods or {}
			mods[modifier] = last
		else
			break
		end

		what = what:sub(1, -2)
	end

	assert(#what > 0, "Empty rule name")

	return what, mods
end

local Wildcard = {}

local PredicateToInterface

local function ImplementsInterface (ifx, strict)
	if strict then
		return function(event)
			return component.ImplementedByObject(event.target, ifx)
		end
	else
		PredicateToInterface = PredicateToInterface or setmetatable({}, { __mode = "k" })
		
		local function predicate (event)
			return component.ImplementedByObject(event.target, ifx)
				or component.ImplementedByObject(event.target, Wildcard)
		end

		PredicateToInterface[predicate] = ifx

		return predicate
	end
end

local function DefFineMatch () return true end

local function HasNoLinks (event)
	return not event.linker:HasLinks(event.from_id, event.from_name)
end

local function SynthesizeStandardRule (limit, mods, oifx_primary)
	local coarse = ImplementsInterface(oifx_primary, mods and mods.strict)
	local fine = limit and HasNoLinks or DefFineMatch

	return function(event)
		if coarse(event) then
			return fine(event), "Single-link node already bound" -- n.b. currently only possible failure
		else
			return false, "Incompatible type"
		end
	end
end

local function SingleLinkWildcard (predicate)
	return function(event)
		if HasNoLinks(event) then
			return predicate(event), "Type not covered by wildcard"
		else
			return false, "Single-link node already bound"
		end
	end
end

local function MixtureWildcard (predicate)
	return function(event)
		return predicate(event), "Type not covered by wildcard"
	end
end

local function RestrictedWildcard (predicate)
	local current_ifx

	return function(event)
		if predicate(event) then
			if HasNoLinks(event) then
				current_ifx = PredicateToInterface and PredicateToInterface[event.target]

				return true
			else
				return component.ImplementedByObject(event.target, current_ifx),
						"Type incompatible with interface in effect"
			end
		else
			return false, "Type not covered by wildcard"
		end
	end
end

local function SynthesizeWildcardRule (limit, mods, predicate)
	if limit then
		return SingleLinkWildcard(predicate)
	elseif mods.wildcard == "?" then
		return RestrictedWildcard(predicate)
	else
		return MixtureWildcard(predicate)
	end
end

local function IgnoredByWildcards (what, mods)
	return what == "event" or (mods and mods.strict) -- at the moment wildcards only accept values
end

local function ResolveLimit (what, which, mods) -- TODO: more intuitive as "limited"?
	if what == "event"
	or which == "exports" then
		return (mods and mods.limit) == "-"	-- usually fine to export value to multiple recipients,
											-- to broadcast an event,
											-- or for disparate events to lead to another one in common
	else
		return (mods and mods.limit) ~= "+" -- usually only makes sense to import one value
	end
end

local Value = {}

local function MakeRule (env, what, which)
	local mods

	if type(what) == "string" then
		what, mods = ExtractModifiers(what)
	end

	local limit = ResolveLimit(what, which, mods)

	if mods and mods.wildcard then
		local wpreds = assert(env.m_wildcard_predicates, "No wildcard predicates defined")
		local predicate = assert(wpreds[what], "Invalid wildcard predicate")

		return SynthesizeWildcardRule(limit, mods, predicate), Wildcard
	else
		local other = which == "imports" and "exports" or "imports"
		local iter, state, index = adaptive.IterArray(GetInterfaces(env, what, other))
		local _, oifx_primary = iter(state, index) -- iterate once to get primary interface
		local interfaces = GetInterfaces(env, what, which)

		if not IgnoredByWildcards(what, mods) then
			interfaces = adaptive.Append(interfaces, Value)
		end

		return SynthesizeStandardRule(limit, mods, oifx_primary), interfaces
	end
end

function M.GetRule (env, what, which)
	if type(what) == "function" then -- already a rule, essentially
		return what
	else
		local rule_list = env.m_rules[which]
		local rule = rule_list[what]

		if not rule then
			local name, interfaces = {}

			rule, interfaces = MakeRule(env, what, which)

			component.RegisterType{ name = name, interfaces = interfaces }
			component.AddToObject(rule, name)
			component.LockInObject(rule, name)

			rule_list[what] = rule
		end

		return rule
	end
end

--- DOCME
function M.GenerateName (env, name)
	local counters = env.m_counters or {}
	local id = (counters[name] or 0) + 1
	local gend = ("%s|%i|"):format(name:sub(1, -2), id)

	counters[name], env.m_counters = id, counters

	return gend
end

local function ListInterfaces (env, key, ifx_lists)
	local list, out = ifx_lists[key]

	if list ~= nil then
		assert(type(list) == "table", "Non-table interface list")

		for k, v in pairs(list) do
			out = out or {}
			out[k] = v
		end
	end

	env.m_interface_lists[key] = out
end

---
-- @ptable params
-- @treturn RuleEnvironment X
function M.New (params)
	assert(type(params) == "table", "Non-table params")

	local get_linker_and_endpoint = params.get_linker_and_endpoint

	assert(type(get_linker_and_endpoint) == "function", "Non-function getter for linker and endpoint")

	local env, ifx_lists, wlist = {
		m_get_linker_and_endpoint = get_linker_and_endpoint,
		m_rules = {}
	}, params.interface_lists, params.wildcards

	if ifx_lists ~= nil then
		assert(type(ifx_lists) == "table", "Non-table interface lists")

		env.m_interface_lists = {}

		ListInterfaces(env, "exports", ifx_lists)
		ListInterfaces(env, "imports", ifx_lists)
	end

	if wlist ~= nil then
		assert(type(wlist) == "table", "Non-table wildcard list")

		local wpreds

		for k, v in pairs(wlist) do
			assert(type(k) == "string", "Non-string wildcard predicate name")
			assert(type(v) == "function", "Non-function wildcard predicate")

			wpreds = wpreds or {}
			wpreds[k] = v
		end

		env.m_wildcard_predicates = wpreds
	end

	return env
end

--- DOCME
function M.ValueComponent ()
	return Value
end

return M