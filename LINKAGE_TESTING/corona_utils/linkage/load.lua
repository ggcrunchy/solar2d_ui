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
local assert = assert
local pairs = pairs

-- Modules --
local common = require("s3_editor.Common") -- urgh...
local utils = require("corona_utils.linkage.utils")

-- Cached module references --
local _LoadValuesFromEntry_

-- Exports --
local M = {}

--
--
--

local function NoOp () end

--- DOCME
function M.LoadGroupOfValues (into, level, what, before, before_loop, after_loop, after)
	local values = assert(before(into), "No values supplied")

	level[what].version = nil

	before_loop, after_loop = before_loop or NoOp, after_loop or NoOp

	for k, entry in pairs(level[what].entries) do
		before_loop(k, entry)

		_LoadValuesFromEntry_(level, values[k], entry --[[ argh ]])

		after_loop()
	end

	;(after or NoOp)()
end

local EnumDefsEvent = {}

local LoadEvent = { name = "load" }

--- DOCME
function M.LoadValuesFromEntry (values, entry, links, list, labels)
	EnumDefsEvent.name = "enum_defs"

	values:dispatchEvent(EnumDefsEvent)

	EnumDefsEvent.name = nil

	-- If the entry will be involved in links, stash its rep so that it gets picked up (as
	-- "entry") by ReadLinks() during resolution.
	local rep = common.GetRepFromValues(values)
	-- local id = env:GetIdentitfierFromValues(values)

	if entry.uid then
		list[entry.uid] = rep
	end

	--
	local resolved
	local tag_db, tag = links:GetTagDatabase(), links:GetTag(rep)

	for i = 1, #(entry.instances or "") do
	-- for i = 1, #(entry.generated_names or "") do
		local name = entry.instances[i]
		-- local name = entry.generated_names[i]

		resolved = resolved or {}
		resolved[name] = tag_db:ReplaceSingleInstance(tag, name)
		-- resolved[name] = ???:ReplaceSingleGeneratedName(name)

		common.AddInstance(rep, resolved[name])
		-- env:AddGeneratedName(id, resolved[name])
		common.SetLabel(resolved[name], labels and labels[name])
		-- env:SetLabel(...)
	end

	-- Restore any positions.
	common.SetPositions(rep, entry.positions)
	-- env:SetPositions(id, entry.positions)

	entry.positions = nil

	-- Copy the editor state into the values, alert any listeners, and add defaults as necessary.
	entry.instances = nil
	-- env.generated_names = nil

	for k, v in pairs(entry) do
		values[k] = v
	end

	LoadEvent.entry, LoadEvent.values = entry, values

	values:dispatchEvent(LoadEvent)

	LoadEvent.entry, LoadEvent.values = nil

	for k, v in pairs(EnumDefsEvent) do
		if values[k] ~= nil then
			values[k] = v
		end

		EnumDefsEvent[k] = nil
	end
end

-- ^^ TODO: Can this be made useful with Undo?

--- DOCME
function M.ResolveLinks_Load (list, links, resolved)
	if list then
		utils.VisitLinks(list, {
			resolve_pair = function(id1, aname1, id2, aname2)
				-- The attachment names might have been generated from templates. Since these are
				-- based on some internal state (such as counters starting from 0) they are given
				-- new names for consistency with the current session.
				aname1 = resolved and resolved[aname1] or aname1 -- n.b. might fall through
				aname2 = resolved and resolved[aname2] or aname2 -- ditto

				links:LinkPairs(id1, aname1, id2, aname2)
			end
		})
	end
end

_LoadValuesFromEntry_ = M.LoadValuesFromEntry

return M