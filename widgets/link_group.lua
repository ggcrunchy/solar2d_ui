--- Nodes for building links.
--
-- @todo Skins?

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

-- Exports --
local M = {}

-- Standard library imports --
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local lines = require("corona_ui.utils.lines")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Cached module references --
local _Break_
local _Connect_
local _GetLinkInfo_

--- DOCME
function M.Break (node)
	display.remove(node)

	if node then
		node.m_broken = true
	end
end

--- DOCME
-- @callable on_break
-- @treturn function F
function M.BreakTouchFunc (on_break)
	return touch.TouchHelperFunc(function()
		-- ??
	end, nil, function(_, node)
		on_break(node)

		_Break_(node)
	end)
end

--
local function Circle (width, radius, ...)
	local circle = display.newCircle(0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

-- Options for established lines --
local LineOpts = {
	color = { 1, 1, 1, 1 },

	keep = function(_, _, node)
		return not node.m_broken
	end
}

--- DOCME
function M.Connect (object1, object2, touch, lgroup, ngroup)
	local node = Circle(3, 16, 1, 0, 0, .5)

	ngroup:insert(node)

	node:addEventListener("touch", touch)
	node:setStrokeColor(0, .75)
-- ^^ SKIN?
	LineOpts.into = lgroup
	LineOpts.node = node

	lines.LineBetween(object1, object2, LineOpts)

	LineOpts.into, LineOpts.node = nil

	return node
end

--- DOCME
function M.GetLinkInfo (item)
	return item.m_owner_id, not item.m_is_target
end

-- --
local LinkGroup = {}

-- Highlights / de-highlights a link
local function Highlight (link, is_over)
	if link then
		link:setStrokeColor(is_over and 1 or 0, 1, 0)
-- ^^ COLOR
	end
end

-- Is the point inside the link object?
local function InLink (link, x, y)
	local lpath, lx, ly = link.path, link:localToContent(0, 0)
	local radius, w = lpath.radius

	if w or not radius then
		local h = lpath.height

		radius = (w and h) and (w + h) / 4 or 25
	end

	return (x - lx)^2 + (y - ly)^2 < radius^2
end

--
local function MayPair (item, id, is_source)
	return item.m_is_target == is_source and id ~= item.m_owner_id
end

-- Enumerate all opposite typed links in other states that contain the point
local function EnumOpposites (lg, link, x, y)
	local id, is_source = _GetLinkInfo_(link)
	local over

	for _, item in ipairs(lg.m_items) do
		if MayPair(item, id, is_source) and InLink(item, x, y) then
			over = over or {}

			over[#over + 1] = item
		end
	end

	return over
end

-- Compares objects by group ID
local function IDComp (a, b)
	return a.m_owner_id < b.m_owner_id
end

-- Updates the hovered-over link
local function UpdateOver (lg, link, x, y)
	-- Was the point over any objects? It may be over multiple overlapping links, so we
	-- arbitrarily prefer the one with lowest ID.
	local over = EnumOpposites(lg, link, x, y)

	if over then
		sort(over, IDComp)

		over = over[1]
	end

	-- Update was-over / is-over link highlights.
	Highlight(lg.m_over, false)
	Highlight(over, true)

	lg.m_over = over
end

-- Hides or shows links that a given link does not target
local function HideNonTargets (lg, link, how)
	local emphasize, show_or_hide = lg.m_emphasize, lg.m_show_or_hide

	if emphasize then
		local id, is_source = _GetLinkInfo_(link)

		for _, item in ipairs(lg.m_items) do
			emphasize(item, how, item.m_is_target == is_source, id ~= item.m_owner_id)
		end
	end

	if show_or_hide then
		local id, is_source = _GetLinkInfo_(link)

		for _, item in ipairs(lg.m_items) do
			if not MayPair(item, id, is_source) then
				show_or_hide(item, how)
			end
		end
	end
end

-- --
local Group = setmetatable({}, { __mode = "kv" }) -- todo: sparse array?

-- Options for a temporary line --
local LineOptsMaybe = { color = { 1, .25, .25, .75 } }

-- Link touch listener
local LinkTouch = touch.TouchHelperFunc(function(event, link)
	local lg = Group[link]

	--
	display.remove(lg.m_temp)

	local temp = lg.m_can_touch(link) and lg.m_make_temp()

	lg.m_temp = temp

	if temp then
		if temp.parent then
			lg:insert(temp)

			temp:toFront()
		end

		temp.x, temp.y = lg:contentToLocal(event.x, event.y)

		--
		local candidates, gather, items = lg.m_candidates, lg.m_gather, lg.m_items

		if gather then
			gather(items, event, link)

			local wi = 1

			for i, item in ipairs(items) do
				if candidates[item] then
					items[wi], wi = item, wi + 1
				end
			end

			for i = #items, wi, -1 do
				items[i] = nil
			end
		end

		--
		LineOptsMaybe.into = lg.m_lines

		lines.LineBetween(link, temp, LineOptsMaybe)

		LineOptsMaybe.into = nil

		-- -- The link currently hovered over --
		HideNonTargets(lg, link, "began")
		UpdateOver(lg, link, event.x, event.y)
	end
end, function(event, link)
	local lg = Group[link]
	local temp = lg.m_temp

	if temp then
		temp.x, temp.y = lg:contentToLocal(event.x, event.y)

		UpdateOver(lg, link, event.x, event.y)
	end
end, function(event, link)
	local lg = Group[link]
	local temp = lg.m_temp

	if temp then
		local over, node = lg.m_over

		--
		if over then
			Highlight(over, false)

			if lg.m_can_touch(over) then
				node = lg:ConnectObjects(link, over)
			end
		end

		--
		if temp.parent then
			temp:removeSelf()
		end

		--
		HideNonTargets(lg, link, node and "ended" or "cancelled")

		lg.m_over, lg.m_temp = nil

		--
		if lg.m_gather then
			local items = lg.m_items

			for i = #items, 1, -1 do
				items[i] = nil
			end
		end
	end
end)

--
local function NewLinkObject (is_target)
	local r, b = .125, 1

	if is_target then
		r, b = b, r
	end

	return Circle(4, 25, r, .125, b, .75)
	-- ^^ SKIN??
end

--- DOCME
-- @int owner_id
-- @bool is_target
-- @pobject object
-- @treturn pobject O
function LinkGroup:AddLink (owner_id, is_target, object)
	object = object or NewLinkObject(is_target)

	object:addEventListener("touch", LinkTouch)

	--
	if self.m_gather then
		self.m_candidates[object] = true
	else
		local items = self.m_items

		items[#items + 1] = object
	end

	Group[object] = self

	--
	object.m_is_target = not not is_target
	object.m_owner_id = owner_id

	Highlight(object, false)

	return object
end

--
local function WipeGroup (group)
	for i = group.numChildren, 1, -1 do
		group[i]:removeSelf()
	end
end

--
local function RemoveItem (item)
	item:removeEventListener("touch", LinkTouch)

	item.m_is_target, item.m_owner_id = nil
end

--- DOCME
function LinkGroup:Clear ()
	if self.m_gather then
		for item in pairs(self.m_candidates) do
			RemoveItem(item)
		end

		self.m_candidates = {}
	else
		for _, item in ipairs(self.m_items) do
			RemoveItem(item)
		end
	end

	--
	self.m_items = {}

	WipeGroup(self.m_lines)
	WipeGroup(self.m_nodes)
end

--- DOCME
function LinkGroup:ConnectObjects (obj1, obj2)
	local node

	if self.m_can_link(obj1, obj2) then
		node = _Connect_(obj1, obj2, self.m_touch, self:GetGroups())

		self:m_connect(obj1, obj2, node)
	end

	return node
end

--- DOCME
function LinkGroup:GetGroups ()
	return self.m_lines, self.m_nodes
end

--
local function DefCanTouch () return true end

--
local function DefMakeTemp ()
	return Circle(2, 5, 1, .125)
end

--- DOCME
-- @pgroup group
-- @callable on_connect
-- @callable on_touch
-- @ptable options
-- @treturn pgroup G
function M.LinkGroup (group, on_connect, on_touch, options)
	local lgroup = display.newGroup()

	group:insert(lgroup)

	--
	local can_link, can_touch, emphasize, gather, make_temp, show_or_hide

	if options then
		can_link = options.can_link
		can_touch = options.can_touch
		emphasize = options.emphasize
		gather = options.gather
		make_temp = options.make_temp
		show_or_hide = options.show_or_hide
	end

	--
	lgroup.m_can_link = can_link or DefCanTouch
	lgroup.m_can_touch = can_touch or DefCanTouch
	lgroup.m_connect = on_connect
	lgroup.m_emphasize = emphasize
	lgroup.m_gather = gather
	lgroup.m_items = {}
	lgroup.m_lines = display.newGroup()
	lgroup.m_make_temp = make_temp or DefMakeTemp
	lgroup.m_nodes = display.newGroup()
	lgroup.m_show_or_hide = show_or_hide
	lgroup.m_touch = on_touch

	if gather then
		lgroup.m_candidates = {}
	end

	--
	lgroup:insert(lgroup.m_lines)
	lgroup:insert(lgroup.m_nodes)

	--
	for k, v in pairs(LinkGroup) do
		lgroup[k] = v
	end

	return lgroup
end

-- Cache module members.
_Break_ = M.Break
_Connect_ = M.Connect
_GetLinkInfo_ = M.GetLinkInfo

-- Export the module.
return M