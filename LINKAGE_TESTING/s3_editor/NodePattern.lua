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
local rawget = rawget
local setmetatable = setmetatable
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local node_environment = require("s3_editor.NodeEnvironment")

-- Exports --
local M = {}

--
--
--

local Environments = {}

local function AddNode (id, name, key, what)
	local env = Environments[id]
	local elist, ilist = env.m_export_nodes, env.m_import_nodes

	assert(not (elist and elist[name]), "Name already used in exports list")
	assert(not (ilist and ilist[name]), "Name already used in imports list")

	local list = env[key] or {}

	env[key], list[name] = env:GetRule(what, key == "m_export_nodes" and "exports" or "imports")
end

local NodePattern = {}

NodePattern.__index = NodePattern

--- Add an export node to the pattern.
-- @param name Node name, expected to be unique among both exports and imports.
--
-- String-type names that end in **"*"** are interpreted as templates and may be cloned via
-- @{NodePattern:Generate}, useful for effecting certain dynamic patterns.
-- @param what What sort of node this will be.
--
-- If this is a string, it may also end with some combination of options: **"-"** or **"+"**
-- (but not both), **"="**, and **"?"** or **"!"** (but not both). Once read, these will be
-- peeled off and the shortened string used as _what_.
--
-- Three kinds of node are currently available: functions, values, and wildcards.
--
-- Functions are denoted by _what_ being **"event"** and will only match fellow events.
--
-- Values are subtyped by _what_ and will typically give themselves the interface derived
-- from _what_ and the node's list, e.g. something like `interface = NameFrom(what, "exports")`,
-- although this can be changed on a case-by-case basis in the interface lists, cf.
-- @{NodeEnvironment:New}. The node in question will match the interface `opposite = NameFrom(what, "imports")`.
-- A _what_ of **"bool"**, for instance, might have interface **"exports:bool"** and match
-- against **"imports:bool"**.
--
-- By default, values also receive a "this is a value" interface, making them visible
-- to @{ImplementsValue}, and also try to match wildcards. The strict modifier (**"="** from
-- above) will let them opt out of this policy.
--
-- When a **"?"** or **"!"** modifier is present, _what_ is the name of a wildcard predicate,
-- cf. @{NodeEnvironment:New}, that will be used to try to match values. In the mixture case
-- (**"!"**), the value need only satisfy the predicate; otherwise, once one link has been
-- established, any further matches must also implement its "primary interface".
--
-- The remaining modifiers determine whether the node should be limited to one link (**"-"**)
-- or unlimited (**"+"**). The former is the default for value import nodes and the latter
-- for everything else.
-- @see NodePattern:AddImportNode
function NodePattern:AddExportNode (name, what)
	AddNode(self.m_env_id, name, "m_export_nodes", what)
end

--- Add an import node to the pattern.
-- @param name As per @{NodePattern:AddExportNode}, but for the imports list.
-- @param what Ditto.
function NodePattern:AddImportNode (name, what)
	AddNode(self.m_env_id, name, "m_import_nodes", what)
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
			return Environments[self.m_env_id]:Instantiate(name), rule
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

local function AuxIterBoth (NP, name)
	local ilist = NP.m_import_nodes

	if not rawget(ilist, name) then -- nil or in export list?
		local k, v = next(NP.m_export_nodes, name)

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

local function IterBoth (NP)
	local elist, ilist = NP.m_export_nodes, NP.m_import_nodes

	if elist and ilist then
		return AuxIterBoth, NP, nil
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
		DefEnvID = DefEnvID or node_environment.New{ get_linker_and_endpoint = nil }
		env_id = DefEnvID
	else
		assert(Environments[env_id], "Invalid environment ID")
	end

	return setmetatable({ m_env_id = env_id }, NodePattern)
end

return M