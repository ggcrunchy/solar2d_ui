--- Some useful UI patterns based around table views.

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
local ipairs = ipairs
local rawequal = rawequal

-- Modules --
local file_utils = require("solar2d_utils.file")
local layout = require("solar2d_ui.utils.layout")
local layout_dsl = require("solar2d_ui.utils.layout_dsl")
local meta = require("tektite_core.table.meta")

-- Corona globals --
local display = display
local native = native
local timer = timer

-- Corona modules --
local widget = require("widget")

-- Cached module references --
local _Listbox_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.FileList (group, options)
	local FileList = _Listbox_(group, options)

	--
	local path, base, exts, filter_info, name_only

	if options then
		path = options.path
		base = options.base
		exts = options.exts
		filter_info = options.filter_info
		name_only = not not options.name_only
	end
	-- ^^^ As is, without options it's broken (nothing to watch)... can be salvaged?

	--
	assert(not (filter_info and name_only), "Incompatible options: info filter and name only listings")

	local opts = { base = base, exts = exts, get_contents = not name_only }

	--
	local function GetContents (file)
		return file and file_utils.GetContents(path .. "/" .. file, base)
	end

	--
	local filter, on_lost_selection, on_reload

	if options then
		filter = options.filter
		on_lost_selection = options.on_lost_selection
		on_reload = options.on_reload
	end

	local function Reload ()
		local selection = FileList:GetSelection()

		-- Populate the list, checking what is still around. Perform filtering, if requested.
		local names, alt = file_utils.EnumerateFiles(path, opts)

		if filter then
			local count = 0

			for _, file in ipairs(names) do
				if filter(file, not name_only and GetContents(file) or "", FileList) then
					names[count + 1], count = file, count + 1
				end
			end

			for i = #names, count + 1, -1 do
				names[i] = nil
			end
		end

		FileList:AssignList(names)

		--
		if on_reload then
			alt = on_reload(FileList)
		end

		-- If the selection still exists, scroll the listbox to it. Otherwise, fall back to an
		-- alternate, if possible. Report any dropped selection, if being tracked.
		local offset = FileList:Find(selection)

		if not offset then
			FileList:ClearSelection()

			if selection and on_lost_selection then
				on_lost_selection{ listbox = FileList, selection = selection }
			end

			offset = FileList:Find(alt)
		end

		if offset then
			FileList:scrollToIndex(offset, 0)
			-- ^^^ TODO: scrollToPosition{ y = y }
		end
	end

	--- DOCME
	function FileList:GetContents ()
		return GetContents(self:GetSelection())
	end

	--- DOCME
	function FileList:Init ()
		Reload()
	end

	--
	local watch = file_utils.WatchForFileModification(path, Reload, opts)

	FileList:addEventListener("finalize", function()
		timer.cancel(watch)
	end)

	-- Extra credit: Directory navigation (requires some effort on the file utility side)

	return FileList
end

--
local function GetIndex (index, add_group)
	if index and add_group then
		index = index * 2 - 1

		return (index >= 1 and index < add_group.numChildren) and index
	end
end

--
local function Identity (str)
	return str
end

-- --
local Event = {}

---
local function TouchEvent (func, rect, listbox)
	Event.listbox = listbox

	local get_text, group = listbox.m_get_text, rect.parent

	for i = 1, group.numChildren, 2 do
		if group[i] == rect then
			Event.index, Event.str = (i + 1) / 2, get_text(rect.m_data) or ""

			func(Event)

			break
		end
	end

	Event.listbox, Event.str = nil
end

local function Select (event)
	local phase, rect, func = event.phase, event.target
	local listbox = rect.parent.parent.parent -- rect -> add group -> scroll view -> listbox
	local selection = listbox.m_selection

	--
	if phase == "began" then
		if rect ~= selection then
			if selection then
				selection:setFillColor(1)
			end

			rect:setFillColor(0, 0, 1)

			listbox.m_selection, func = rect, listbox.m_press
		end

	--
	elseif phase == "ended" then
		func = listbox.m_release
	end

	--
	if func then
		TouchEvent(func, rect, listbox)
	end

	-- Fall through, for scroll view
end

local function Append (listbox, str)
	local h = layout.ResolveY(listbox.m_text_rect_height)
	local rect = display.newRect(0, 0, listbox.width, h)
	local text = display.newText(listbox.m_get_text(str), 0, 0, native.systemFont, layout.ResolveY(listbox.m_text_size))

	listbox:insert(rect)
	listbox:insert(text)

	local add_group = listbox.m_add_group or rect.parent

	listbox.m_add_group = add_group

	rect:addEventListener("touch", Select)
	text:setFillColor(0)

	local count = add_group.numChildren / 2

	rect.x, rect.y = listbox.width / 2, (count - .5) * h
	text.anchorX, text.x, text.y = 0, layout.ResolveX(".625%"), rect.y

	rect.m_data = str

	return count
end

-- --
local Listbox = {}

--- DOCME
function Listbox:Append (str)
	return Append(self, str)
end

--- DOCME
function Listbox:AppendList (list)
	for i = 1, #list do
		Append(self, list[i])
	end
end

--- DOCME
function Listbox:AssignList (list)
	self:Clear()
	self:AppendList(list)
end

--- DOCME
function Listbox:Clear ()
	local add_group = self.m_add_group

	self.m_selection = nil

	for i = add_group and add_group.numChildren or 0, 1, -2 do
		local rect, text = add_group[i - 1], add_group[i]

		rect.m_data = nil

		text:removeSelf()
		rect:removeSelf()
	end
end

--- DOCME
function Listbox:Count ()
	local add_group = self.m_add_group

	return .5 * (add_group and add_group.numChildren or 0)
end

--- DOCME
function Listbox:ClearSelection ()
	local selection = self.m_selection

	if selection then
		selection:setFillColor(1)
	end

	self.m_selection = nil
end

--- DOCME
function Listbox:Delete (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	if index then
		local rect, text = add_group[index], add_group[index + 1]

		if rect == self.m_selection then
			self.m_selection = nil
		end

		rect.m_data = nil

		text:removeSelf()
		rect:removeSelf()

		--
		for i = index, add_group.numChildren do
			local item = add_group[i]

			item.y = item.y - 40
		end
	end
end

--- DOCME
function Listbox:Find (str)
	local add_group, get_text = self.m_add_group, self.m_get_text

	for i = 1, (str and add_group) and add_group.numChildren or 0, 2 do
		if get_text(add_group[i].m_data) == str then
			return (i + 1) / 2
		end
	end

	return nil
end

--- DOCME
function Listbox:FindData (data)
	local add_group = self.m_add_group

	for i = 1, (data and add_group) and add_group.numChildren or 0, 2 do
		if rawequal(add_group[i].m_data, data) then
			return (i + 1) / 2
		end
	end

	return nil
end

--- DOCME
function Listbox:FindSelection ()
	return self:Find(self:GetSelection())
end

--- DOCME
function Listbox:ForEach (func, ...)
	local add_group, get_text = self.m_add_group, self.m_get_text

	for i = 1, add_group and add_group.numChildren or 0, 2 do
		local data = add_group[i].m_data

		func(get_text(data), data, ...)
	end
end

--- DOCME
function Listbox:Frame (r, g, b)
	display.remove(self.m_frame)

	local bounds = self.contentBounds
	local w, h = bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin
	local frame = display.newRoundedRect(self.parent, bounds.xMin, bounds.yMin, w, h, layout.ResolveX(".25%"))

	frame:setFillColor(0, 0)
	frame:setStrokeColor(r, g, b)
	frame:translate(w / 2, h / 2)

	frame.strokeWidth = 2

	self.m_frame = frame
end

--- DOCME
function Listbox:GetCount ()
	local add_group = self.m_add_group

	return (add_group and add_group.numChildren or 0) / 2
end

--- DOCME
function Listbox:GetData (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	return index and add_group[index].m_data
end

--- DOCME
function Listbox:GetRect (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	return index and add_group[index]
end

--- DOCME
function Listbox:GetSelection ()
	local selection = self.m_selection
	
	return selection and self.m_get_text(selection.m_data)
end

--- DOCME
function Listbox:GetSelectionData ()
	local selection = self.m_selection

	return selection and selection.m_data
end

--- DOCME
function Listbox:GetString (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	return index and add_group[index + 1]
end

--- DOCME
function Listbox:GetText (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	return index and self.m_get_text(add_group[index].m_data)
end

--- DOCME
function Listbox:Select (index)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	if index then
		Event.phase, Event.target = "began", add_group[index]

		Select(Event)

		Event.phase = "ended"

		Select(Event)
	end
end

--- DOCME
function Listbox:Update (index, data)
	local add_group = self.m_add_group

	index = GetIndex(index, add_group)

	if index then
		if data ~= nil then
			add_group[index].m_data = data
		end

		add_group[index + 1].text = self.m_get_text(add_group[index].m_data)
	end
end

--
local function RemoveFrame (event)
	display.remove(event.target.m_frame)
end

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @ptable options bool hide If true, the listbox starts out hidden.
-- @treturn DisplayObject Listbox object.
-- TODO: Update, reincorporate former Adder docs...
function M.Listbox (group, options)
	local w, h = layout_dsl.EvalDims("37.5%", "31.25%")
	local lopts, x, y = layout_dsl.ProcessWidgetParams(options, { width = w, height = h })

	--
	lopts.horizontalScrollDisabled = true

	local listbox = widget.newScrollView(lopts)

	layout_dsl.PutObjectAt(listbox, x, y)

	group:insert(listbox)

	-- On Render --
	if options and options.get_text then
		local getter = options.get_text

		function listbox.m_get_text (item)
			return getter(item) or item
		end
	else
		listbox.m_get_text = Identity
	end

	--
	listbox.m_press = options and options.press
	listbox.m_release = options and options.release
	listbox.m_text_rect_height = options and options.text_rect_height or "8.3%"
	listbox.m_text_size = options and options.text_size or "5%"

	listbox.isVisible = not (options and options.hide)

	meta.Augment(listbox, Listbox)

	listbox:addEventListener("finalize", RemoveFrame)

	return listbox
end

_Listbox_ = M.Listbox

return M