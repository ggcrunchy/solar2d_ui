--- TODO

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
local getmetatable = getmetatable
local pairs = pairs
local setmetatable = setmetatable

-- Modules --
local common = require("s3_editor.Common") -- urgh...
local strings = require("tektite_core.var.strings")
local utils = require("corona_utils.linkage.utils")

-- Cached module references --
local _SaveValuesIntoEntry_

-- Exports --
local M = {}

--
--
--

local function GatherLabel (name, labels)
	local label = common.GetLabel(name)
	-- local label = env:GetLabel(name)

	if label then
		labels = labels or {}
		labels[name] = label
	end

	return labels
end

local EntryPairTag = utils.EntryPairTag()

local function GetEntry (new, ids_to_entries, ids_to_indices, id)
	local entry = ids_to_entries[id]

	if entry.uid then
		new[#new + 1] = EntryPairTag
		new[#new + 1] = entry.uid

		local n = ids_to_indices.n + 1

		ids_to_indices[id], ids_to_indices.n, entry.uid = n, n 
	end
end

local AttachmentPairTag = utils.AttachmentPairTag()

--- DOCME
function M.ResolveLinks_Save (links, ids_to_entries)
	local new, ids_to_indices, labels

	links:ForEachLink(function(link)
		new, ids_to_indices = new or {}, ids_to_indices or { n = 0 }

		local id1, aname1, id2, aname2 = link:GetLinkedPairs()

		GetEntry(new, ids_to_entries, ids_to_indices, id1)
		GetEntry(new, ids_to_entries, ids_to_indices, id2)

		new[#new + 1] = AttachmentPairTag
		new[#new + 1] = aname1
		new[#new + 1] = ids_to_indices[id2]
		new[#new + 1] = aname2

		labels = GatherLabel(aname1, labels)
		labels = GatherLabel(aname2, labels)
	end)

	return new, labels
end

--- DOCME
function M.SaveGroupOfValues (values_group, links, list, building)
	local target = {}
	local saved = { entries = target, version = 1 }

	for k, values in pairs(values_group) do
		target[k], list = _SaveValuesIntoEntry_(values, {}, links, list, building)
	end

	return saved
end

local SaveEvent = { name = "save" }

--- DOCME
function M.SaveValuesIntoEntry (values, entry, links, list, building)
--	utils.EnumDefs(mod, values)

	-- Does this values blob have any links? If so, make note of it in the blob itself and
	-- add some tracking information in the links list.
	local rep = common.GetRepFromValues(values)
	-- local id = env:GetIdentifierFromValues(values)

	if links:HasAnyLinks(rep) and not values.uid then
	-- if HasAny(id) then
		list, values.uid = list or {}, strings.NewName()
		list[#list + 1] = rep
		-- list[#list + 1] = id
	end

	-- Copy the values into the editor state, alert any listeners, and add defaults as necessary.
	for k, v in pairs(values) do
		entry[k] = v
	end

	SaveEvent.entry, SaveEvent.values = entry, values

	values:dispatchEvent(SaveEvent)

	SaveEvent.entry, SaveEvent.values = nil

	if building then
		setmetatable(entry, getmetatable(values))
	end

--	utils.AssignDefs(entry)

	-- dispatch for positions, instances?
	entry.positions, entry.instances = common.GetPositions(rep), common.GetInstances(rep, "copy")
	-- entry.positions, entry.instances = env:GetPositions(id), env:GetGeneratedNames(id, "copy")

	return entry, list
end

-- ^^^ TODO: what would it take to use this to save / restore via undo?

_SaveValuesIntoEntry_ = M.SaveValuesIntoEntry

return M