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

-- Modules --
local file_utils = require("corona_utils.file")
local layout_dsl = require("corona_ui.utils.layout_dsl")

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
local function TouchEvent (func, rect, listbox, get_text)
	Event.listbox = listbox

	local group = rect.parent

	for i = 1, group.numChildren, 2 do
		if group[i] == rect then
			Event.index, Event.str = (i + 1) / 2, get_text(rect.m_data) or ""

			func(Event)

			break
		end
	end

	Event.listbox, Event.str = nil
end

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @ptable options bool hide If true, the listbox starts out hidden.
-- @treturn DisplayObject Listbox object.
-- TODO: Update, reincorporate former Adder docs...
function M.Listbox (group, options)
	local lopts, x, y = layout_dsl.ProcessWidgetParams(options, { width = 300, height = 150 })

	-- On Render --
	local get_text = Identity

	if options and options.get_text then
		local getter = options.get_text

		function get_text (item)
			return getter(item) or item
		end
	end

	--
	lopts.horizontalScrollDisabled = true

	local Listbox = widget.newScrollView(lopts)

	layout_dsl.PutObjectAt(Listbox, x, y)

	group:insert(Listbox)

	--
	local press, release, selection = options and options.press, options and options.release

	local function Select (event)
		local phase, rect, func = event.phase, event.target

		--
		if phase == "began" then
			if rect ~= selection then
				if selection then
					selection:setFillColor(1)
				end

				rect:setFillColor(0, 0, 1)

				selection, func = rect, press
			end

		--
		elseif phase == "ended" then
			func = release
		end

		--
		if func then
			TouchEvent(func, rect, Listbox, get_text)
		end

		-- Fall through, for scroll view
	end

	--
	local AddGroup

	local function Append (str)
		local rect = display.newRect(0, 0, Listbox.width, 40)
		local text = display.newText(get_text(str), 0, 0, native.systemFont, 24)

		Listbox:insert(rect)
		Listbox:insert(text)

		AddGroup = AddGroup or rect.parent

		rect:addEventListener("touch", Select)
		text:setFillColor(0)

		local count = AddGroup.numChildren / 2

		rect.x, rect.y = Listbox.width / 2, (count - .5) * 40
		text.anchorX, text.x, text.y = 0, 5, rect.y

		rect.m_data = str

		return count
	end

	--- DOCME
	function Listbox:Append (str)
		return Append(str)
	end

	--- DOCME
	function Listbox:AppendList (list)
		for i = 1, #list do
			Append(list[i])
		end
	end

	--- DOCME
	function Listbox:AssignList (list)
		self:Clear()
		self:AppendList(list)
	end

	--- DOCME
	function Listbox:Clear ()
		selection = nil

		for i = AddGroup and AddGroup.numChildren or 0, 1, -2 do
			local rect, text = AddGroup[i - 1], AddGroup[i]

			rect.m_data = nil

			text:removeSelf()
			rect:removeSelf()
		end
	end

	--- DOCME
	function Listbox:ClearSelection ()
		if selection then
			selection:setFillColor(1)
		end

		selection = nil
	end

	--- DOCME
	function Listbox:Delete (index)
		index = GetIndex(index, AddGroup)

		if index then
			local rect, text = AddGroup[index], AddGroup[index + 1]

			if rect == selection then
				selection = nil
			end

			rect.m_data = nil

			text:removeSelf()
			rect:removeSelf()

			--
			for i = index, AddGroup.numChildren do
				local item = AddGroup[i]

				item.y = item.y - 40
			end
		end
	end

	--- DOCME
	function Listbox:Find (str)
		for i = 1, (str and AddGroup) and AddGroup.numChildren or 0, 2 do
			if get_text(AddGroup[i].m_data) == str then
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
		for i = 1, AddGroup and AddGroup.numChildren or 0, 2 do
			local data = AddGroup[i].m_data

			func(get_text(data), data, ...)
		end
	end

	--- DOCME
	function Listbox:GetCount ()
		return (AddGroup and AddGroup.numChildren or 0) / 2
	end

	--- DOCME
	function Listbox:GetData (index)
		index = GetIndex(index, AddGroup)

		return index and AddGroup[index].m_data
	end

	--- DOCME
	function Listbox:GetRect (index)
		index = GetIndex(index, AddGroup)

		return index and AddGroup[index]
	end

	--- DOCME
	function Listbox:GetSelection ()
		return selection and get_text(selection.m_data)
	end

	--- DOCME
	function Listbox:GetString (index)
		index = GetIndex(index)

		return index and AddGroup[index + 1]
	end

	--- DOCME
	function Listbox:GetText (index)
		index = GetIndex(index, AddGroup)

		return index and get_text(AddGroup[index].m_data)
	end

	--- DOCME
	function Listbox:Update (index, data)
		index = GetIndex(index, AddGroup)

		if index then
			if data ~= nil then
				AddGroup[index].m_data = data
			end

			AddGroup[index + 1].text = get_text(AddGroup[index].m_data)
		end
	end

	--
	Listbox.isVisible = not (options and options.hide)

	return Listbox
end

-- Cache module references.
_Listbox_ = M.Listbox

-- Export the module.
return M