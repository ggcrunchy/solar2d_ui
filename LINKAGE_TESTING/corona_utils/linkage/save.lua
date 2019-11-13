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
local pairs = pairs

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
function M.SaveGroupOfValues (level, what, mod, view)
	local target = {}

	level[what] = { entries = target, version = 1 }

	local values = view:GetValues()

	for k, v in pairs(values) do
		target[k] = _SaveValuesIntoEntry_(level, mod, v, {})
	end
end

local function HasAny (rep) -- id
	local links = common.GetLinks() -- env:GetLinks()
	local tag = links:GetTag(rep) -- Type(id)

	if tag then
		local f, s, v0, reclaim = links:GetTagDatabase():Sublinks(tag, "no_templates")

		for _, sub in f, s, v0 do
			if links:HasLinks(rep, sub) then
			-- if links:HasLinks(id, sub) then
				reclaim()

				return true
			end
		end
	end
end

--- DOCME
function M.SaveValuesIntoEntry (level, mod, values, entry)
	utils.EnumDefs(mod, values)

	-- Does this values blob have any links? If so, make note of it in the blob itself and
	-- add some tracking information in the links list.
	local rep = common.GetRepFromValues(values)
	-- local id = env:GetIdentifierFromValues(values)

	if HasAny(rep) then
	-- if HasAny(id) then
		local list = level.links or {}

		if not list[rep] then -- see note below
		-- if not list[id] then
			values.uid = strings.NewName()

			list[#list + 1] = rep
			-- list[#list + 1] = id
			list[rep] = #list -- TODO: as id, might mix with list... maybe negate or stringify?
		end

		level.links = list
	end

	-- Copy the values into the editor state, alert any listeners, and add defaults as necessary.
	for k, v in pairs(values) do
		entry[k] = v
	end

	utils.EditorEvent(mod, "save", level, entry, values)
	-- entry:SendMessage(...)

	utils.AssignDefs(entry)

	entry.positions, entry.instances = common.GetPositions(rep), common.GetInstances(rep, "copy")
	-- entry.positions, entry.instances = env:GetPositions(id), env:GetGeneratedNames(id, "copy")

	return entry
end

-- ^^^ TODO: what would it take to use this to save / restore via undo?

_SaveValuesIntoEntry_ = M.SaveValuesIntoEntry

return M