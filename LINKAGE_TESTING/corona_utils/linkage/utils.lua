--- DOCME

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
local type = type

-- Exports --
local M = {}

--
--
--

-- Default values for the type being saved or loaded --
-- TODO: How much work would it be to install some prefab logic?
local Defs

--- DOCME
function M.AssignDefs (item)
	for k, v in pairs(Defs) do
		if item[k] == nil then
			item[k] = v
		end
	end
end

-- Current module and value type being saved or loaded --
local Mod, ValueType

--- DOCME
function M.EditorEvent (mod, what, level, entry, values)
	mod.EditorEvent(ValueType, what, level, entry, values)
end

--- DOCME
function M.EnumDefs (mod, value)
	if Mod ~= mod or ValueType ~= value.type then
		Mod, ValueType = mod, value.type

		Defs = { name = "", type = ValueType }

		mod.EditorEvent(ValueType, "enum_defs", Defs)
	end
end

local AttachmentPairTag, EntryPairTag = "pair>attachment", "pair>entry"

--- DOCME
function M.AttachmentPairTag ()
	return AttachmentPairTag
end

--- DOCME
function M.EntryPairTag ()
	return EntryPairTag
end

local function DefCallback () end

--- DOCME
function M.VisitLinks (list, params)
	assert(type(params) == "table", "Invalid params")

	local ids_to_entries, visited_list = params.ids_to_entries or list, params.visited_list or list
	local visit_entry, resolve_pair = params.visit_entry or DefCallback, params.resolve_pair or DefCallback
	local index, entry, aname = 1

	for i = 1, #list, 2 do
		local a, b = list[i], list[i + 1]

		if a == EntryPairTag then -- b: entry ID
			entry = ids_to_entries[b]

			visit_entry(entry, index)

			visited_list[index], index = entry, index + 1 -- n.b. since we read two entries at a time but write
														  -- at most one, we may safely use list as visited_list

		elseif a == AttachmentPairTag then -- b: attachment point name
			aname = b

		elseif index > a then -- a: index of other entry; b: attachment name of other entry
							  -- n.b. for simplicity, (index #1, name #1) and (index #2, name #2) are each
							  -- represented; the pair is resolved after both entries have been visited
			resolve_pair(entry, aname, visited_list[a], b)
			-- TODO: list used as list[entry] for "prep_link" lookups by builds; dispatchable
			-- entries should serve just as well, and make the process more obvious.
		end
	end
end

return M