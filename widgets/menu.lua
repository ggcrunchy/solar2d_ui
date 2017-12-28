--- Menu UI elements.
--
-- @todo Document skin...

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
local type = type

-- Modules --
local array_index = require("tektite_core.array.index")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local meta = require("tektite_core.table.meta")
local table_funcs = require("tektite_core.table.funcs")

-- Corona globals --
local display = display
local native = native
local system = system
local transition = transition

-- Cached module references --
local _Menu_

-- Exports --
local M = {}

--
--
--

local function Heading (menu, index)
	return menu[index][1]
end

local function DataFromHeading (heading)
	local tindex, iindex = heading.m_text_index, heading.m_image_index
	local data_index = tindex or iindex -- see 'into' in PopulateEntry()

	return heading.parent[data_index], heading, tindex, iindex
end

local function HeadingData (menu, index)
	return DataFromHeading(Heading(menu, index))
end

local ImageFill, OnItemChangeEvent = { type = "image" }, {}

local function PlaceImage (image, object, pos, str, margin)
	if pos == "left" then
		layout.LeftAlignWith(image, object, margin)
	elseif pos == "right" then
		layout.RightAlignWith(image, object, -margin)
	elseif str then
		layout.PutLeftOf(image, str, -margin)
	else
		image.x = object.x
	end

	image.y = object.y
end

local function UpdateText (str, event)
	local new_text = event.text

	if new_text then
		str.text = event.visual_text or new_text
	end

	str.isVisible = new_text ~= nil
end

local function UpdateImage (image, event, heading, str)
	local filename = event.filename

	if filename then
		image.fill, ImageFill.filename, ImageFill.baseDir = ImageFill, event.filename, event.baseDir

		PlaceImage(image, heading, event.pos, str, image.m_margin)
	end

	image.isVisible = filename ~= nil
end

local function SetHeading (event)
	local menu = event.target
	local data, heading, tindex, iindex = HeadingData(menu, event.column)
	local old_text, old_id, new_text, new_id = data.m_text, data.m_id, event.text, event.id

	if old_text ~= new_text or old_id ~= new_id then
		data.m_text, data.m_id, data.m_filename, data.m_dir = new_text, new_id, event.filename, event.baseDir

		if tindex then
			UpdateText(data, event)
		end

		if iindex then
			UpdateImage(data.parent[iindex], event, heading, tindex and data)
		end

		OnItemChangeEvent.name = "item_change"
		OnItemChangeEvent.target = menu
		OnItemChangeEvent.old_text, OnItemChangeEvent.text = old_text, new_text
		OnItemChangeEvent.old_id, OnItemChangeEvent.id = old_id, new_id

		menu:dispatchEvent(OnItemChangeEvent)
	end
end

local function FindData (bar, index)
	local bgroup, cur = bar.parent, 1

	for i = bar.m_offset + 1, bgroup.numChildren do
		local item = bgroup[i]

		if item.m_text or item.m_id then
			if cur == index then
				return item
			else
				cur = cur + 1
			end
		end
	end

	assert(false, "Data not found") -- should never get here if implementation is correct
end

local MenuItemEvent = {}

local function SendMenuItemEvent (menu, packet, column)
	MenuItemEvent.name, MenuItemEvent.target = "menu_item", menu
	MenuItemEvent.id, MenuItemEvent.text, MenuItemEvent.visual_text = packet.m_id
	MenuItemEvent.filename, MenuItemEvent.baseDir = packet.m_filename, packet.m_dir
	MenuItemEvent.column, MenuItemEvent.pos = column, packet.m_pos

	local text = packet.m_text

	if text then
		MenuItemEvent.text = text

		if menu.m_get_text then
			local vtext = menu.m_get_text(text)

			if vtext ~= text then
				MenuItemEvent.visual_text = text
			end
		end
	end

	menu:dispatchEvent(MenuItemEvent)

	MenuItemEvent.target = nil
end

--- DOCME
function M.Dropdown (params)
	local column = assert(params.column, "Expected column")

	assert(type(column) == "table", "Column must be table")
	assert(#column > 0, "Table entries required")

	params = table_funcs.Copy(params)
	params.columns, params.is_dropdown = { "", column }, true

	local dropdown = _Menu_(params)

	local choice = params.choice

	if choice then
		dropdown:Select(choice)
	else
		local packet = FindData(Heading(dropdown, 1).m_dropdown.m_bar, 1)

		SendMenuItemEvent(dropdown, packet, 1)
	end

	return dropdown
end

local function Type (column)
	local ctype = type(column)

	assert(ctype == "table" or ctype == "string", "Bad column type")

	if ctype == "string" then
		return "entry"
	elseif #column == 0 then
		assert(column.text == nil or type(column.text) == "string", "Non-string text")
		assert(column.filename == nil or type(column.filename) == "string", "Non-string filename")
		assert(column.id == nil or type(column.id) == "number", "Non-number ID")
		assert(column.text or column.filename, "Entry has neither text nor an image")

		local pos = column.position

		if pos then
			assert(pos == nil or pos == "left" or pos == "right", "Invalid image position")
		end

		return "entry"
	else
		return "column"
	end
end

local function CheckColumns (columns)
	assert(columns, "Missing columns")

	local prev_type

	for _, column in ipairs(columns) do
		local ctype = Type(column)

		if ctype == "column" then
			assert(prev_type == "entry", "Columns must follow heading entry")

			for _, v in ipairs(column) do
				assert(Type(v) == "entry", "Invalid column entry")
			end
		end

		prev_type = ctype
	end

	return columns
end

local FadeParams = {
	time = 150,

	onComplete = function(object)
		object.m_can_touch = true
	end
}

local function Fade (object, alpha)
	object.m_can_touch, FadeParams.alpha = false, alpha

	return transition.to(object, FadeParams)
end

local function MenuFromHeading (heading)
	return heading.parent.parent
end

local function InHeading (heading, x, y)
	local menu = MenuFromHeading(heading)

	for i = 1, menu.numChildren do
		local item = Heading(menu, i)
		local ibounds = item.contentBounds

		if x >= ibounds.xMin and x <= ibounds.xMax and y >= ibounds.yMin and y <= ibounds.yMax then
			if item == heading then
				return "this"
			else
				return item
			end
		end
	end
end

local function ReleaseHeading (heading)
	heading:setFillColor(.6)
end

local function Close (dropdown, new)
	transition.cancel(dropdown.m_fading)

	dropdown.m_can_touch, dropdown.m_fading = false

	Fade(dropdown.parent, 0)
	ReleaseHeading(dropdown.m_bar.m_heading)

	display.getCurrentStage():setFocus(new)
end

local function TouchHeading (heading)
	heading:setFillColor(.2)

	local dropdown = heading.m_dropdown

	if dropdown then
		dropdown.m_fading = Fade(dropdown.parent, 1)

		display:getCurrentStage():setFocus(dropdown)
	else
		display:getCurrentStage():setFocus(heading)
	end
end

local function DropdownTouch (event)
	local dropdown, phase = event.target, event.phase
	local end_phase = phase == "ended" or phase == "cancelled" 

	if not (dropdown.parent.m_can_touch or end_phase) then
		return
	end

	local bar = dropdown.m_bar

	if phase == "moved" then
		local bounds, x, y = dropdown.contentBounds, event.x, event.y
		local xinside = x >= bounds.xMin and x <= bounds.xMax
		local yinside = y >= bounds.yMin and y <= bounds.yMax
		local heading, _, topy = bar.m_heading, dropdown:contentToLocal(0, y)
		local index = array_index.FitToSlot(topy, -dropdown.height / 2, bar.height)

		if yinside then
			layout.PutBelow(bar, heading, (index - 1) * bar.height)
		end

		local how = yinside and "show"

		if xinside and yinside then
			bar.m_index = index
		else
			how, bar.m_index = how or InHeading(heading, x, y)
		end

		bar.isVisible = how == "show"

		if how and how ~= "show" and how ~= "this" then
			Close(dropdown, how)
			TouchHeading(how)
		end
	elseif end_phase then
		if bar.m_index then
			local heading = bar.m_heading

			SendMenuItemEvent(MenuFromHeading(heading), FindData(bar, bar.m_index), heading.m_column)

			bar.m_index = nil
		end

		bar.isVisible = false

		Close(dropdown)
	end

	return true
end

local function HeadingTouch (event)
	local heading, phase = event.target, event.phase

	if phase == "began" then
		TouchHeading(heading)
	elseif phase == "moved" then
		local how = InHeading(heading, event.x, event.y)

		if how and how ~= "this" then
			ReleaseHeading(heading)
			TouchHeading(how)
		end
	elseif phase == "ended" or phase == "cancelled" then
		ReleaseHeading(heading)

		display.getCurrentStage():setFocus(nil)

		if InHeading(heading, event.x, event.y) == "this" then
			SendMenuItemEvent(MenuFromHeading(heading), DataFromHeading(heading), heading.m_column)
		end
	end

	return true
end

local Menu = {}

--- DOCME
function Menu:addEventListener (name, listener)
	self.m_dispatcher = self.m_dispatcher or system.newEventDispatcher()

	self.m_dispatcher:addEventListener(name, listener)
end

--- DOCME
function Menu:dispatchEvent (event)
	assert(not self.m_broken, "Menu not whole")

	if self.m_dispatcher then
		self.m_dispatcher:dispatchEvent(event)
	end
end

--- DOCME
function Menu:GetHeadingCenterY ()
	local heading = Heading(self, 1)
	local _, y = self.parent:contentToLocal(heading:localToContent(0, 0))

	return y
end

--- DOCME
function Menu:GetHeadingHeight ()
	return Heading(self, 1).height
end

--- DOCME
function Menu:GetSelection (index)
	assert(not self.m_broken, "Menu not whole")
	assert(index == nil or type(index) == "number", "Invalid index")

	index = index or 1

	assert(self[index], "Index out of bounds")

	local data = HeadingData(self, index)

	return data.m_text, data.m_id, data.m_filename, data.m_dir
end

--- DOCME
function Menu:RelocateDropdowns (into)
	assert(not self.m_broken, "Menu not whole")
	assert(not self.m_relocated, "Dropdowns already relocated")

	for i = 1, self.numChildren do
		local cgroup = self[i]

		if cgroup.m_has_dropdown then
			local bgroup = cgroup[cgroup.numChildren]
			local x, y = bgroup:localToContent(0, 0)

			into:insert(bgroup)

			bgroup.x, bgroup.y = into:contentToLocal(x, y)
		end
	end

	self.m_relocated = true
end

--- DOCME
function Menu:removeEventListener (name, listener)
	if self.m_dispatcher then
		self.m_dispatcher:removeEventListener(name, listener)
	end
end

--- DOCME
function Menu:RestoreDropdowns (stash)
	assert(self.m_broken, "Menu already whole")

	local headings_only = stash.m_headings_only

	for i = self.numChildren, 1, -1 do
		if not (headings_only and headings_only[i]) then
			self[i]:insert(stash[stash.numChildren])
		end
	end

	self.m_broken = false
end

-- --
local SelectPacket = {}

local function FindSelection (menu, name_or_id)
	for i = 1, menu.numChildren do
		local bar = Heading(menu, i).m_dropdown.m_bar
		local bgroup = bar.parent

		for j = bar.m_offset + 1, bgroup.numChildren do
			local item = bgroup[j]

			if item.m_id == name_or_id or item.m_text == name_or_id then
				return item, i
			end
		end
	end
end

--- DOCME
function Menu:Select (name_or_id)
	assert(not self.m_broken, "Menu not whole")

	local ni_type = type(name_or_id)

	assert(ni_type == "string" or ni_type == "number", "Expected string name or number ID")

	local packet, column = FindSelection(self, name_or_id)

	if not packet then
		packet = SelectPacket

		if ni_type == "string" then
			packet.m_text, packet.m_id = name_or_id
		else
			packet.m_id, packet.m_text = name_or_id
		end
	end

	SendMenuItemEvent(self, packet, column or 1)
end

--- DOCME
function Menu:StashDropdowns ()
	assert(not self.m_broken, "Already stashed")
	assert(not self.m_relocated, "Dropdowns have been relocated")

	local stash, headings_only = display.newGroup()

	for i = 1, self.numChildren do
		local cgroup = self[i]

		if cgroup.m_has_dropdown then
			stash:insert(cgroup[cgroup.numChildren])
		else
			headings_only = headings_only or {}
			headings_only[i] = true
		end
	end

	self.m_broken, stash.isVisible, stash.m_headings_only = true, false, headings_only

	return stash
end

local function DefGetText (text) return text end

local function EnsureText (object, font, size, is_dropdown, is_heading)
	local heading = is_heading and object or object.m_heading
	local cgroup = heading.parent

	-- If we just added the heading, we already have our text. Otherwise, if this is the
	-- first text entry in a dropdown, the heading must be ready to represent it, so get
	-- a text object ready to go. This is irrelevant for non-dropdowns.
	if is_dropdown and not (is_heading or heading.m_text_index) then
		display.newText(cgroup, "", heading.x, heading.y, font, size).isVisible = false
	end

	-- Make the heading aware of any text.
	if is_dropdown or is_heading then
		heading.m_text_index = heading.m_text_index or cgroup.numChildren
	end
end

local function EnsureImage (object, iw, ih, margin, is_dropdown, is_heading)
	local heading = is_heading and object or object.m_heading
	local cgroup, image = heading.parent

	-- If this is a dropdown, the heading must be ready to represent the image, so get a rect
	-- ready to go, to be assigned a bitmap fill. This might be the heading itself, in which
	-- case it should already be visible. This is irrelevant for non-dropdowns that use image
	-- display objects instead.
	if is_dropdown and not heading.m_image_index then
		image = display.newRect(cgroup, 0, 0, iw, ih)
		image.m_margin, image.isVisible = margin, is_heading
	end

	-- Make the heading aware of any image.
	if is_dropdown or is_heading then
		heading.m_image_index = heading.m_image_index or cgroup.numChildren
	end

	return image
end

local function PopulateEntry (column, group, object, get_text, font, size, iw, ih, margin, is_dropdown, is_heading)
	local into, str, filename, dir, id, text, pos

	if type(column) == "string" then
		text = column
	else
		text, filename, dir, id, pos = column.text, column.filename, column.baseDir, column.id, column.position
	end

	if text then
		str = display.newText(group, get_text(text), object.x, object.y, font, size)
		str.m_text, into = text, str

		EnsureText(object, font, size, is_dropdown, is_heading)
	end

	if filename then
		local image = EnsureImage(object, iw, ih, margin, is_dropdown, is_heading)

		if image and is_heading then
			image.fill, ImageFill.filename, ImageFill.baseDir = ImageFill, filename, dir
		else
			if image then -- not heading, so object is bar
				PlaceImage(image, object.m_heading, pos, str, margin)
			end

			if dir then
				image = display.newImageRect(group, filename, dir, iw, ih)
			else
				image = display.newImageRect(group, filename, iw, ih)
			end
		end

		PlaceImage(image, object, pos, str, margin)

		into = into or image -- consolidate all data in one object
		into.m_filename, into.m_dir, into.m_id, into.m_pos = filename, dir, id, pos
	end
end

--- DOCME
function M.Menu (params)
	local menu = display.newGroup()

	if params.group then
		params.group:insert(menu)
	end

	local columns = CheckColumns(params.columns)
	local column_width, heading_height = layout_dsl.EvalDims(params.column_width or 100, params.heading_height or 30)
	local _, bar_height = layout_dsl.EvalDims(nil, params.bar_height or heading_height)
	local iw, ih = layout_dsl.EvalDims(params.image_width or 24, params.image_height or 24)
	local font, size = params.font or native.systemFont, params.size or 16
	local x, y, margin, cgroup, heading = .5 * column_width, .5 * heading_height, layout.ResolveX(params.margin or 5)
	local ci, get_text, is_dropdown = 1, params.get_text or DefGetText, params.is_dropdown

	menu.m_get_text = get_text

	for _, column in ipairs(columns) do
		if type(column) == "string" or #column == 0 then
			cgroup = display.newGroup()
			heading = display.newRect(cgroup, x, y, column_width, heading_height)
			heading.m_column = ci

			ReleaseHeading(heading) -- set fill color
			PopulateEntry(column, cgroup, heading, get_text, font, size, iw, ih, margin, is_dropdown, true)

			heading:addEventListener("touch", HeadingTouch)
			menu:insert(cgroup)

			ci, x = ci + 1, x + column_width
		else
			local bgroup = display.newGroup()

			cgroup.m_has_dropdown = true

			local dropdown = display.newRect(bgroup, heading.x, 0, column_width, #column * bar_height)
			local bar = display.newRect(bgroup, heading.x, 0, column_width, bar_height)
			local prev = heading

			heading.m_dropdown, dropdown.m_bar, bar.m_heading = dropdown, bar, heading

			layout.PutBelow(dropdown, heading)

			bar.m_offset = bgroup.numChildren

			for _, entry in ipairs(column) do
				layout.PutBelow(bar, prev)

				PopulateEntry(entry, bgroup, bar, get_text, font, size, iw, ih, margin, is_dropdown)

				prev = layout.Below(bar)
			end

			cgroup:insert(bgroup) -- add here to ensure as last element

			dropdown:addEventListener("touch", DropdownTouch)
			dropdown:setFillColor(0, 0, .3)
			bar:setFillColor(0, .7, 0)

			bgroup.alpha, bar.isVisible = 0, false
		end
	end

	if params.left then
		layout.LeftAlignWith(menu, params.left)
	elseif params.x then
		layout.CenterAtX(menu, params.x)
	end

	if params.top then
		layout.TopAlignWith(menu, params.top)
	elseif params.y then
		layout.CenterAtY(menu, params.y)
	end

	meta.Augment(menu, Menu)

	if is_dropdown then
		menu:addEventListener("menu_item", SetHeading)
	end

	return menu
end

-- Cache module members.
_Menu_ = M.Menu

-- Export the module.
return M