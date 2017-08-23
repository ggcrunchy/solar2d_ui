--- Functionality for dialog sections.

-- TODO: Skin

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
local abs = math.abs
local assert = assert
local pairs = pairs

-- Corona globals --
local transition = transition
local timer = timer

-- Exports --
local M = {}

-- How many items so far?
local function ItemCount (dialog)
	return dialog:ItemGroup().numChildren
end

--- DOCME
-- @treturn SectionHandle H
function M:BeginSection ()
	assert(not self.m_sealed, "Cannot begin section in sealed dialog")

	self:InitProperties()

	-- Create a new section, and a new list if necessary. Until the dialog is sealed, the list
	-- doubles as a stack which is used to build the section hierarchy; the section is pushed
	-- onto the stack, and if another is below it, that becomes its parent. As for the list
	-- proper, the section is "pushed" onto it, but at a negative index.
	local section, list = {
		m_is_open = true, m_from = ItemCount(self) + 1
	}, self.m_list or { stack = 0 }
	local si, n = list.stack, #list

	if si < 0 then
		section.m_parent = n
	end

	self.m_list, list[si - 1], list[n + 1], list.stack = list, section, section, si - 1

	return section
end

-- Helper to apply an operation (recursively) to a dialog section
local function Apply (handle, op, igroup)
	if handle.m_is_open then
		local index, to, si = handle.m_from, handle.m_to, 1

		while index <= to do
			-- Perform the operation on each entry, stopping if a new subsection begins.
			local sub = handle[si]
			local up_to = sub and sub.m_from - 1 or to

			while index <= up_to do
				op(igroup[index])

				index = index + 1
			end

			-- If a subsection was encountered, apply the operation on it recursively.
			-- Update the subsection index and move the entry index past it.
			if sub then
				Apply(sub, op, igroup)

				si, index = si + 1, sub.m_to + 1
			end
		end
	end
end

-- Are all of this subsection's parents open?
local function AreParentsOpen (handle, list)
	repeat
		handle = list[handle.m_parent]
	until not (handle and handle.m_is_open)

	return not handle
end

-- --
local FadeOutParams = {
	alpha = .3, time = 150,

	onComplete = function(object)
		object.isVisible = false
	end
}

-- --
local DoImmediately

--
local function To (object, params)
	if DoImmediately then
		local delta = params.delta

		for k, v in pairs(params) do
			if k ~= "time" and k ~= "delay" and k ~= "onComplete" then
				object[k] = delta and (object[k] + v) or v
			end

			if params.onComplete then
				params.onComplete(object)
			end
		end
	else
		transition.to(object, params)
	end
end

-- Hides an element, which may be a spacer
local function Hide (item)
	if item.m_collapsed ~= nil then
		item.m_collapsed = true
	else
		item.alpha = 1

		To(item, FadeOutParams)
	end
end

-- Visiblity predicate that accounts for spacers
local function IsVisible (item)
	return item.isVisible or item.m_collapsed == false
end

-- --
local MoveParams = { delta = true }

--
local function Move (item, field, delta)
	local time = abs(delta) -- adjust time...

	MoveParams.time, MoveParams[field] = 120, delta

	To(item, MoveParams)

	MoveParams[field] = nil
end

-- Separation distances between objects and dialog edges --
local XSep = 5 -- TODO: Skin this

--
local function Reflow (line, igroup)
	local x, is_open = XSep

	for i = line.first_item, line.last_item do
		local item = igroup[i]

		if IsVisible(item) then -- can this even be a spacer?
			Move(item, "x", x - item.x)

			x, is_open = x + item.m_addx, true
		end
	end

	return is_open
end

-- Helper to prevent further sections from being added to the dialog
local function Seal (dialog)
	local list = assert(dialog.m_list, "No sections to operate on")
	
	assert(list.stack == 0, "Sections still pending")

	if not dialog.m_sealed then
		dialog:EndLine()

		dialog.m_sealed = true
	end
end

-- Helper to move a range of items
local function MoveItems (igroup, from, to, dy)
	for i = from, dy ~= 0 and to or 0 do
		local item = igroup[i]

		if item.isVisible then
			Move(item, "y", dy)
		else
			item.y = item.y + dy
		end
	end
end

--- DOCME
-- @tparam SectionHandle handle
function M:Collapse (handle)
	Seal(self)

	if handle.m_is_open then
		local igroup, from, to = self:ItemGroup(), handle.m_from, handle.m_to
		local parents_open = AreParentsOpen(handle, self.m_list)
		local dy, line1, line2 = 0

		-- The following only matters when the items are visible anyway, and can be deferred,
		-- so it will be wasted effort if a parent is closed. Otherwise, proceed.
		if parents_open then
			local lines, item1, item2 = self.m_lines, igroup[from], igroup[to]

			line1, line2 = lines[item1.m_line], lines[item2.m_line]

			-- The section begins with a "partial" line, i.e. the right-hand side of the first
			-- line, and likewise ends with another, viz. the left-hand side of the last line.
			-- However, these may constitute the whole (visible) line, so we must check here.
			local any1, any2

			for i = line1.first_item, from - 1 do
				any1 = any1 or IsVisible(igroup[i])
			end

			for i = to + 1, line2.last_item do
				any2 = any2 or IsVisible(igroup[i])
			end

			-- Accumulate the heights of the interior lines. These can be assumed to be "whole",
			-- but we must check whether they were not already collapsed; if not, collapse them.
			for i = item1.m_line + 1, item2.m_line - 1 do
				local line = lines[i]

				if line.is_open then
					dy, line.is_open = dy + line.h, false
				end
			end

			-- If either of the "partial" lines were actually the entire visible part, subsume the
			-- line into the collapsed lines, accumulating the height if the line was not already
			-- collapsed, and remove the line from further consideration. As a special case, when
			-- the first and last lines are the same, check both sides; for "further consideration"
			-- purposes, this is treated as a "last line" case.
			if line1 == line2 then
				any2, line1 = any1 or any2
			elseif not any1 then
				dy, line1.is_open, line1 = dy + (line1.is_open and line1.h or 0), false
			end

			if not any2 then
				dy, line2.is_open, line2 = dy + (line2.is_open and line2.h or 0), false
			end
		end

		-- Hide all items in the collapsed region.
		Apply(handle, Hide, igroup)

		-- As above, the following only matters if the objects will be visible.
		if parents_open then
			-- Reflow the first and last lines, if still being considered. If there is a last
			-- line, ensure that we don't start moving items up until the following line.
			if line1 then
				Reflow(line1, igroup)
			end

			if line2 then
				Reflow(line2, igroup)

				to = line2.last_item
			end

			-- Move up all items in the lines following the collapsed section.
			MoveItems(igroup, to + 1, igroup.numChildren, -dy)
		end

		handle.m_is_open = false
	end
end

--- DOCME
function M:EndSection ()
	-- Pull the section off the stack.
	local list = assert(self.m_list, "No sections begun")
	local section = assert(list[list.stack], "Empty section stack")

	list.stack = list.stack + 1

	-- Assign the last-added item as the section's end boundary.
	section.m_to = ItemCount(self)

	-- If this is a subsection, add it to its parent's list.
	local parent = self.m_list[section.m_parent]

	if parent then
		parent[#parent + 1] = section
	end
end

-- --
local FadeInParams = { alpha = 1, time = 150 }

-- Shows an element, which may be a spacer
local function Show (item)
	if item.m_collapsed ~= nil then
		item.m_collapsed = false
	else
		item.alpha, item.isVisible = .3, true

		To(item, FadeInParams)
	end
end

--- DOCME
-- @tparam SectionHandle handle
function M:Expand (handle)
	Seal(self)

	if not handle.m_is_open then
		handle.m_is_open = true

		if AreParentsOpen(handle, self.m_list) then
			local igroup = self:ItemGroup()

			--
			Apply(handle, Show, igroup)

			--
			local lines, to, dy = self.m_lines, igroup[handle.m_to].m_line, 0

			for i = igroup[handle.m_from].m_line, to do
				local line = lines[i]
				local is_open = Reflow(line, igroup)

				if is_open and not line.is_open then
					line.is_open, dy = true, dy + line.h
				end
			end

			--
			MoveItems(igroup, lines[to].last_item + 1, igroup.numChildren, dy)
		end
	end
end

--- DOCME
-- @tparam SectionHandle to_expand
-- @tparam SectionHandle to_collapse
function M:FlipTwoStates (to_expand, to_collapse)
	Seal(self)

	-- One of the operations cannot be performed: attempt the other.
	if to_expand.m_is_open then
		self:Collapse(to_collapse)
	elseif not to_collapse.m_is_open then
		self:Expand(to_expand)

	-- Both operations are on the same section, and would cancel out: no-op. Otherwise, expand
	-- and then collapse the sections, interspersing a delay to let the transitions catch up.
	elseif to_expand ~= to_collapse then
		self:Expand(to_expand)

		FadeOutParams.delay, MoveParams.delay = 200, 200

		self:Collapse(to_collapse)

		FadeOutParams.delay, MoveParams.delay = nil
	end
end

--- DOCME
-- @tparam SectionHandle handle
-- @param name
-- @bool use_false
function M:SetStateFromValue (handle, name, use_false)
	if not self:GetValue(name) ~= not use_false then
		self:Expand(handle)
	else
		self:Collapse(handle)
	end
end

--- DOCME
-- @tparam SectionHandle handle
-- @param name
-- @bool use_false
function M:SetStateFromValue_Watch (handle, name, use_false)
	--
	DoImmediately = true

	self:SetStateFromValue(handle, name, use_false)

	DoImmediately = false

	--
	local list = self.m_watch_sections

	if not list then
		list = {}

		self.m_watch_sections = list
		self.m_watch_sections_timer = timer.performWithDelay(30, function()
			for i = 1, #list, 3 do
				self:SetStateFromValue(list[i], list[i + 1], list[i + 2])
			end
		end, 0)

		self:addEventListener("finalize", function(event)
			timer.cancel(event.target.m_watch_sections_timer)
		end)
	end

	--
	list[#list + 1] = handle
	list[#list + 1] = name
	list[#list + 1] = use_false or false
end

-- Export the module.
return M