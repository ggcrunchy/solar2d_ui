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
local meta = require("tektite_core.table.meta")

-- Exports --
local M = {}

--
--
--

local function Decorate (what, which)
	return which .. ":" .. tostring(what) -- reasonably unique name
end

local function GetDecoratedInterfaces (env, what, which)
	local ifx_list = env.m_interface_lists[which]
	local interfaces, decorated = ifx_list and ifx_list[what], env.m_decorated or meta.WeakKeyed()

	if decorated[interfaces] then
		return interfaces
	else
		local list

		if interfaces then -- interpreted
			for i = 1, #interfaces do
				list = adaptive.Append(list, Decorate(which, interfaces[i]))
			end
		else
			list = adaptive.Append(nil, Decorate(which, what))
		end

		env.m_decorated, decorated[list] = decorated, true

		if ifx_list then
			ifx_list[what] = list
		else
			env.m_interface_lists[which] = { [what] = list }
		end

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

local function SynthesizeStandardRule (limit, mods, oifx_primary, has_no_links)
	local coarse = ImplementsInterface(oifx_primary, mods and mods.strict)
	local fine = limit and has_no_links or DefFineMatch

	return function(event)
		if coarse(event) then
			return fine(event), "Single-link node already bound" -- n.b. currently only possible failure
		else
			return false, "Incompatible type"
		end
	end
end

local function SingleLinkWildcard (predicate, has_no_links)
	return function(event)
		if has_no_links(event) then
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

local function RestrictedWildcard (predicate, has_no_links)
	local current_ifx

	return function(event)
		if predicate(event) then
			if has_no_links(event) then
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

local function SynthesizeWildcardRule (limit, mods, predicate, has_no_links)
	if limit then
		return SingleLinkWildcard(predicate, has_no_links)
	elseif mods.wildcard == "?" then
		return RestrictedWildcard(predicate, has_no_links)
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

		return SynthesizeWildcardRule(limit, mods, predicate, env.m_has_no_links), Wildcard
	else
		local other = which == "imports" and "exports" or "imports"
		local other_ifxs = GetDecoratedInterfaces(env, what, other) -- ensure existence of complementary interface(s)...
		local iter, state, index = adaptive.IterArray(other_ifxs)
		local _, oifx_primary = iter(state, index) -- ...and iterate once to get the primary one
		local interfaces = GetDecoratedInterfaces(env, what, which)

		if not IgnoredByWildcards(what, mods) then
			interfaces = adaptive.Append(interfaces, Value)
		end

		return SynthesizeStandardRule(limit, mods, oifx_primary, env.m_has_no_links), interfaces
	end
end

local NodeEnvironment = {}

NodeEnvironment.__index = NodeEnvironment

--- DOCME
-- @param what
-- @string which
-- @treturn ?|function|nil X
function NodeEnvironment:GetRule (what, which)
	if type(what) == "function" then -- already a rule, essentially
		return what
	else
		assert(which == "exports" or which == "imports", "Unknown rule type")

		local rule = self.m_rules[which][what]

		if not rule then
			local name, interfaces = {}

			rule, interfaces = MakeRule(self, what, which)

			component.RegisterType{ name = name, interfaces = interfaces }
			component.AddToObject(rule, name)
			component.LockInObject(rule, name)

			self.m_rules[which][what] = rule
		end

		return rule
	end
end

--- DOCME
function NodeEnvironment:GetRuleInfo (rule)
	local rules = self.m_rules

	for what, v in pairs(rules.exports) do
		if v == rule then
			return "exports", what
		end
	end

	for what, v in pairs(rules.imports) do
		if v == rule then
			return "imports", what
		end
	end
end

--- DOCME
-- @string name
-- @treturn string X
function NodeEnvironment:Instantiate (name)
	local counters = self.m_counters or {}
	local id = (counters[name] or 0) + 1
	local instance = ("%s|%i|"):format(name:sub(1, -2), id)

	counters[name], self.m_counters = id, counters

	return instance
end

local function DefHasNoLinks () return true end

local function ListInterpretations (list)
	local out

	if list then
		assert(type(list) == "table", "Non-table interface interpretation list")

		for k, v in pairs(list) do
			out = out or {}
			out[k] = v
		end
	end

	return out
end

---
-- @ptable params
-- @treturn RuleEnvironment X
function M.New (params)
	assert(type(params) == "table", "Non-table params")

	local env, ii_lists, wlist = {
		m_has_no_links = params.has_no_links or DefHasNoLinks,
		m_interface_lists = {},
		m_rules = { exports = {}, imports = {} }
	}, params.interpretation_lists, params.wildcards

	if ii_lists ~= nil then
		assert(type(ii_lists) == "table", "Non-table interface interpretation lists")

		env.m_interface_lists.exports = ListInterpretations(ii_lists.exports) -- these are treated as interpretations...
		env.m_interface_lists.imports = ListInterpretations(ii_lists.imports) -- ...until being decorated
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

	return setmetatable(env, NodeEnvironment)
end

--- DOCME
function M.ValueComponent ()
	return Value
end

--- DOCME
function M.WildcardComponent ()
	return Wildcard
end

return M