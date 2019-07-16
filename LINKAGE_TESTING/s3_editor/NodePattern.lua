--- TODO!
-- @module NodePattern

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
local next = next
local pairs = pairs
local rawequal = rawequal
local rawget = rawget
local setmetatable = setmetatable
local tostring = tostring
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local component = require("tektite_core.component")

-- Cached module references --
local _NewEnvironment_

-- Exports --
local M = {}

--
--
--

local Value = {}

---
-- @ptable event Event containing a **target** member, as supplied by a "can link?" query.
-- @treturn boolean Is the target a "value" as defined by node patterns?
function M.ImplementsValue (event)
	return component.ImplementedByObject(event.target, Value)
end

local function Mangle (what, which)
	return "IFX:" .. which .. ":" .. type(what) .. ":" .. tostring(what) -- reasonably unique name
end
-- ^^ TODO: is this important any more? now that a different RemoveDups() technique is used by component interfaces, maybe not?
-- what WAS `which` meant to be??
-- anyhow, if possible, just use `what` as is, or a new table etc.

local function GetInterfaces (env, what, which)
	local ifx_list = env.m_interface_lists[which]
	local interfaces = ifx_list and ifx_list[what]

	if type(interfaces) == "number" then -- index?
		return env.m_mangled[interfaces]
	else
		local index, list = #env.m_mangled + 1

		if interfaces then
			for i = 1, #interfaces do
				list = adaptive.Append(list, Mangle(interfaces[i]))
			end
		else
			list = adaptive.Append(nil, Mangle(what))
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

local function ImplementsInterface (ifx, strict)
	if strict then
		return function(event)
			return component.ImplementedByObject(event.target, ifx)
		end
	else
		return function(event)
			if rawequal(event, Value) then -- TODO: fragile? cf. RestrictedWildcard
				return ifx
			elseif component.ImplementedByObject(event.target, ifx) then
				return true
			else
				return component.ImplementedByObject(event.target, Wildcard)
			end
		end
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
				current_ifx = event.target(Value) -- TODO: fragile? cf. ImplementsInterface

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
	return what == "func" or (mods and mods.strict) -- at the moment wildcards only accept values
end

local function ResolveLimit (what, which, mods) -- TODO: more intuitive as "limited"?
	if what == "func" -- import an event that calls func, or call func that exports event (TODO: more intuitive as "event"?)
	or which == "exports" then
		return (mods and mods.limit) == "-"	-- usually fine to export value to multiple recipients,
											-- to broadcast an event,
											-- or to make a func callable from disparate events
	else
		return (mods and mods.limit) ~= "+" -- usually only makes sense to import one value
	end
end

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

local function GetRule (env, what, which)
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

local function AddNode (env, name, key, what)
	local elist, ilist = env.m_export_nodes, env.m_import_nodes

	assert(not (elist and elist[name]), "Name already used in exports list")
	assert(not (ilist and ilist[name]), "Name already used in imports list")

	local list = env[key] or {}

	env[key], list[name] = GetRule(env, what, key == "m_export_nodes" and "exports" or "imports")
end

local NodePattern = {}

NodePattern.__index = NodePattern

local Environments = {}

--- Add an export node to the pattern.
-- @param name Node name, expected to be unique among both exports and imports.
--
-- String-type names that end in **"*"** are interpreted as templates and may be cloned via
-- @{NodePattern:Generate}, useful for effecting certain variable length patterns.
-- @param what What sort of node this will be.
--
-- If this is a string, it may also end with some combination of options: **"-"** or **"+"**
-- (but not both), **"="**, and **"?"** or **"!"** (but not both). Once read, these will be
-- peeled off and the shortened string used as _what_.
--
-- Three kinds of node are currently available: functions, values, and wildcards.
--
-- Functions are denoted by _what_ being **"func"** and will only match fellow functions.
--
-- Values are subtyped by _what_ and will typically give themselves the interface generated
-- from _what_ and the node's list, e.g. something like `interface = NameFrom(what, "exports")`,
-- although this can be changed on a case-by-case basis in the interface lists, cf.
-- @{NewEnvironment}. A value node will match the interface in the opposite list, e.g.
-- `opposite = NameFrom(what, "imports")` with respect to the previous example.
--
-- By default, values will also have a "this is a value" interface, making them visible
-- to @{ImplementsValue}, and also try to match wildcards. The strict modifier (**"="** from
-- above) will let them opt out of this policy.
--
-- When a **"?"** or **"!"** modifier is present, _what_ is the name of a wildcard predicate, cf.
-- @{NewEnvironment}, which will be used to try matching values. In the mixture case (**"!"**),
-- the value need only satisfy the predicate; otherwise, once one link has been established,
-- any further matches must also implement its "primary interface", cf. @{NewEnvironment}.
--
-- The remaining modifiers determine whether the node should be limited to one link (**"-"**)
-- or unlimited (**"+"**). The former is the default for value import nodes and the latter
-- for everything else.
-- @see NodePattern:AddImportNode
function NodePattern:AddExportNode (name, what)
	AddNode(Environments[self.m_env_id], name, "m_export_nodes", what)
end

--- Add an import node to the pattern.
-- @param name As per @{NodePattern:AddExportNode}, but for the imports list.
-- @param what Ditto.
function NodePattern:AddImportNode (name, what)
	AddNode(Environments[self.m_env_id], name, "m_import_nodes", what)
end

local function IsTemplate (name)
	return type(name) == "string" and name:sub(-1) == "*"
end

--- DOCME
-- @param name
-- @treturn ?|string|nil
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:GetTemplate
function NodePattern:Generate (name)
	if IsTemplate(name) then
		local elist, ilist = self.m_export_nodes, self.m_import_nodes
		local rule = (elist and elist[name]) or (ilist and ilist[name])

		if rule then
			local counters = Environments[self.m_env_id].m_counters
			local id = (counters[name] or 0) + 1
			local gend = ("%s|%i|"):format(name:sub(1, -2), id)

			counters[name] = id

			return gend, rule
		end
	end

	return nil
end

--- DOCME
-- @param name
-- @treturn ?|string|nil
-- @see NodePattern:Generate
function NodePattern:GetTemplate (name)
	local pi = type(name) == "string" and name:find("|")
	local template = pi and name:sub(1, pi - 1) .. "*"
	local elist, ilist = self.m_export_nodes, self.m_import_nodes

	return ((elist and elist[template]) or (ilist and ilist[template])) and template
end

local function AuxIterBoth (NG, name)
	local ilist = NG.m_import_nodes

	if not rawget(ilist, name) then -- nil or in export list?
		local k, v = next(NG.m_export_nodes, name)

		if k == nil then -- switch from export to import list?
			return next(ilist, nil)
		else
			return k, v
		end
	else
		return next(ilist, nil)
	end
end

local function DefIter () end

local function IterBoth (NG)
	local elist, ilist = NG.m_export_nodes, NG.m_import_nodes

	if elist and ilist then
		return AuxIterBoth, NG, nil
	elseif elist or ilist then
		return adaptive.IterSet(elist or ilist)
	else
		return DefIter
	end
end

local function GetNodeList (NP, how)
	return NP[how == "exports" and "m_export_nodes" or "m_import_nodes"]
end

---
-- @param name
-- @string[opt] how
-- @treturn boolean X
function NodePattern:HasNode (name, how)
	if how == "exports" or how == "imports" then
		local list = GetNodeList(self, how)

		return (list and list[name]) ~= nil
	else
		local elist, ilist = self.m_export_nodes, self.m_import_nodes

		return ((elist and elist[name]) or (ilist and ilist[name])) ~= nil
	end
end

--- Iterate over a set of the nodes thus far added to the pattern.
-- @string[opt] how If this is **"exports"** or **"imports"**, iteration will be restricted
-- to the corresponding subset of nodes. Otherwise, all nodes are iterated.
-- @return Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNonTemplateNodes, NodePattern:IterTemplateNodes
function NodePattern:IterNodes (how)
	if how == "exports" or how == "imports" then
		return adaptive.IterSet(GetNodeList(self, how))
	else
		return IterBoth(self)
	end
end

--- Variant of @{NodePattern:IterNodes} that only considers non-template nodes.
-- @string[opt] how As per @{NodePattern:IterNodes}.
-- @treturn Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNodes, NodePattern:IterTemplateNodes
function NodePattern:IterNonTemplateNodes (how)
	local list = {}

	for k, v in self:IterNodes(how) do
		if not IsTemplate(k) then
			list[k] = v
		end
	end

	return pairs(list)
end

--- Variant of @{NodePattern:IterNodes} that only considers template nodes.
-- @string[opt] how As per @{NodePattern:IterNodes}.
-- @treturn Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNodes, NodePattern:IterNonTemplateNodes
function NodePattern:IterTemplateNodes (how)
	local list = {}

	for k, v in self:IterNodes(how) do
		if IsTemplate(k) then
			list[k] = v
		end
	end

	return pairs(list)
end

local DefEnvID

--- DOCME
-- @param[opt] env_id If present, an ID as returned by @{NewEnvironment}, indicating the
-- environment to use. Otherwise, the default environment is chosen.
-- @treturn NodePattern Node pattern.
function M.New (env_id)
	if env_id == nil then
		DefEnvID = DefEnvID or _NewEnvironment_{}
		env_id = DefEnvID
	else
		assert(Environments[env_id], "Invalid environment ID")
	end

	return setmetatable({ m_env_id = env_id }, NodePattern)
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

--- Create an environment used to share behaviors among node patterns.
-- @ptable params
-- @return ID Lookup ID for this environment.
function M.NewEnvironment (params)
	assert(type(params) == "table", "Non-table params")

	local env, ifx_lists, wlist = {}, params.interface_lists, params.wildcards

	if ifx_lists ~= nil then
		assert(type(ifx_lists) == "table", "Non-table interface lists")
	
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

	local id = {}

	Environments[id], env.m_counters = env, {}

	return id
end

_NewEnvironment_ = M.NewEnvironment

return M