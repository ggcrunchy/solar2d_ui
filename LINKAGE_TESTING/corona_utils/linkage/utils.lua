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
local pairs = pairs

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

--- DOCME
function M.ReadLinks (level, on_entry, on_pair)
	local list, index, entry, sub = level.links, 1

	for i = 1, #list, 2 do
		local item, other = list[i], list[i + 1]

		-- Entry pair: Load the entry via its ID (note that the build and load pre-resolve steps
		-- both involve stuffing the ID into the links) and append it to the entries array. If
		-- there is a per-entry visitor, call it along with its entry index.
		if item == "entry" then
			entry = list[other]

			on_entry(entry, index)

			list[index], index = entry, index + 1

		-- Sublink pair: Get the sublink name.
		elseif item == "sub" then
			sub = other

		-- Other object sublink pair: The saved entry stream is a fat representation, with both
		-- directions represented for each link, i.e. each sublink pair will be encountered twice.
		-- The first time, only "entry" will have been loaded, and should be ignored. On the next
		-- pass, pair the two entries, since both will be loaded.
		elseif index > item then
			on_pair(list, entry, list[item], sub, other)
		end
	end
end

return M