--- A collection of linkable nodes and the operations pertinent to their connections.
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

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local lines = require("corona_ui.utils.lines")
local meta = require("tektite_core.table.meta")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Cached module references --
local _Break_
local _Connect_
local _GetNodeInfo_
local _SetNodeInfo_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.Break (knot)
	display.remove(knot)

	if knot then
		knot.m_broken = true
	end
end

--- DOCME
-- @callable on_break
-- @treturn function F
function M.BreakTouchFunc (on_break)
	return touch.TouchHelperFunc(function()
		-- ??
	end, nil, function(_, knot)
		on_break(knot)

		_Break_(knot)
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

	keep = function(_, _, knot)
		return not knot.m_broken
	end
}

-- Options for soft link lines --
local SoftLineOpts = { color = { .4, .4, .4, 1 } }

--- DOCME
function M.Connect (object1, object2, touch, ngroup, kgroup)
	local opts, knot

	if touch then
		knot = Circle(3, 16, 1, 0, 0, .5)

		kgroup:insert(knot)

		knot:addEventListener("touch", touch)
		knot:setStrokeColor(0, .75)

		opts = LineOpts
	else
		opts = SoftLineOpts
	end

-- ^^ SKIN?
	opts.into, opts.knot = ngroup, knot

	lines.LineBetween(object1, object2, opts)

	opts.into, opts.knot = nil

	return knot
end

--- DOCME
function M.GetLinkInfo (item)
	return item.m_owner_id, not item.m_is_lhs
end

-- --
local NodeGroup = {}

-- Highlights / de-highlights a node
local function Highlight (node, is_over)
	if node then
		node:setStrokeColor(is_over and 1 or 0, 1, 0)
-- ^^ COLOR
	end
end

-- Is the point inside the node object?
local function InNode (node, x, y)
	local npath, lx, ly = node.path, node:localToContent(0, 0)
	local radius, w = npath.radius

	if w or not radius then
		local h = npath.height

		radius = (w and h) and (w + h) / 4 or 25
	end

	radius = radius + 5 -- accept slightly outside inputs

	return (x - lx)^2 + (y - ly)^2 < radius^2
end

--
local function MayPair (item, id, is_rhs)
	return item.m_is_lhs == is_rhs and id ~= item.m_owner_id
end

-- Enumerate all opposite typed links in other states that contain the point
local function EnumOpposites (ng, node, x, y)
	local id, is_rhs = _GetNodeInfo_(node)
	local over

	for _, item in ipairs(ng.m_items) do
		if MayPair(item, id, is_rhs) and InNode(item, x, y) then
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
local function UpdateOver (ng, node, x, y)
	-- Was the point over any objects? It may be over multiple overlapping links, so we
	-- arbitrarily prefer the one with lowest ID.
	local over = EnumOpposites(ng, node, x, y)

	if over then
		sort(over, IDComp)

		over = over[1]
	end

	-- Update was-over / is-over node highlights.
	Highlight(ng.m_over, false)
	Highlight(over, true)

	ng.m_over = over
end

-- Hides or shows nodes that a given node does not target
local function HideNonTargets (ng, node, how)
	local emphasize, show_or_hide = ng.m_emphasize, ng.m_show_or_hide

	if emphasize then
		local id, is_rhs = _GetNodeInfo_(node)

		for _, item in ipairs(ng.m_items) do
			emphasize(item, how, node, item.m_is_lhs == is_rhs, id ~= item.m_owner_id)
		end
	end

	if show_or_hide then
		local id, is_rhs = _GetNodeInfo_(node)

		for _, item in ipairs(ng.m_items) do
			if not MayPair(item, id, is_rhs) then
				show_or_hide(item, how)
			end
		end
	end
end

-- --
local Group = meta.FullyWeak()

-- Options for a temporary line --
local LineOptsMaybe = { color = { 1, .25, .25, .75 } }

-- Node touch listener
local NodeTouch = touch.TouchHelperFunc(function(event, node)
	local ng = Group[node]

	--
	display.remove(ng.m_temp)

	local temp = ng.m_can_touch(node) and ng.m_make_temp()

	ng.m_temp = temp

	if temp then
		if temp.parent then
			ng:insert(temp)

			temp:toFront()
		end

		temp.x, temp.y = ng:contentToLocal(event.x, event.y)

		--
		local candidates, gather, items = ng.m_candidates, ng.m_gather, ng.m_items

		if gather then
			gather(items, event, node)

			local wi = 1

			for _, item in ipairs(items) do
				if candidates[item] then
					items[wi], wi = item, wi + 1
				end
			end

			for i = #items, wi, -1 do
				items[i] = nil
			end
		end

		--
		LineOptsMaybe.into = ng.m_lines

		lines.LineBetween(node, temp, LineOptsMaybe)

		LineOptsMaybe.into = nil

		-- The node currently hovered over --
		HideNonTargets(ng, node, "began")
		UpdateOver(ng, node, event.x, event.y)
	end
end, function(event, node)
	local ng = Group[node]
	local temp = ng.m_temp

	if temp then
		temp.x, temp.y = ng:contentToLocal(event.x, event.y)

		UpdateOver(ng, node, event.x, event.y)
	end
end, function(_, node)
	local ng = Group[node]
	local temp = ng.m_temp

	if temp then
		local over, knot = ng.m_over

		--
		if over then
			Highlight(over, false)

			if ng.m_can_touch(over) then
				knot = ng:ConnectObjects(node, over)
			end
		end

		--
		if temp.parent then
			temp:removeSelf()
		end

		--
		HideNonTargets(ng, node, knot and "ended" or "cancelled")

		ng.m_over, ng.m_temp = nil

		--
		if ng.m_gather then
			local items = ng.m_items

			for i = #items, 1, -1 do
				items[i] = nil
			end
		end
	end
end)

--
local function NewNodeObject (is_lhs)
	local r, b = .125, 1

	if is_lhs then
		r, b = b, r
	end

	return Circle(4, 25, r, .125, b, .75)
	-- ^^ SKIN??
end

--- DOCME
-- @int owner_id
-- @string what Either **"lhs"** or **"rhs"**, indicating that the node is on the left- or
-- right-hand side, respectively.
-- @pobject object
-- @treturn pobject O
function NodeGroup:AddNode (owner_id, what, object)
	assert(what == "lhs" or what == "rhs", "Invalid node")

	local is_lhs = what == "lhs"

	object = object or NewNodeObject(is_lhs)

	object:addEventListener("touch", NodeTouch)

	--
	if self.m_gather then
		self.m_candidates[object] = true
	else
		local items = self.m_items

		items[#items + 1] = object
	end

	Group[object] = self

	--
	_SetNodeInfo_(object, owner_id, is_lhs)

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
	item:removeEventListener("touch", NodeTouch)

	item.m_is_lhs, item.m_owner_id = nil
end

--- DOCME
function NodeGroup:Clear ()
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
	WipeGroup(self.m_knots)
end

--- DOCME
function NodeGroup:ConnectObjects (obj1, obj2)
	local knot

	if self.m_can_link(obj1, obj2) then
		knot = _Connect_(obj1, obj2, self.m_touch, self:GetGroups())

		self:m_connect(obj1, obj2, knot)
	end

	return knot
end

--- DOCME
function NodeGroup:GetGroups ()
	return self.m_lines, self.m_knots
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
function M.NodeGroup (group, on_connect, on_touch, options)
	local ngroup = display.newGroup()

	group:insert(ngroup)

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
	ngroup.m_can_link = can_link or DefCanTouch
	ngroup.m_can_touch = can_touch or DefCanTouch
	ngroup.m_connect = on_connect
	ngroup.m_emphasize = emphasize
	ngroup.m_gather = gather
	ngroup.m_items = {}
	ngroup.m_knots = display.newGroup()
	ngroup.m_lines = display.newGroup()
	ngroup.m_make_temp = make_temp or DefMakeTemp
	ngroup.m_show_or_hide = show_or_hide
	ngroup.m_touch = on_touch

	if gather then
		ngroup.m_candidates = {}
	end

	--
	ngroup:insert(ngroup.m_lines)
	ngroup:insert(ngroup.m_knots)

	meta.Augment(ngroup, NodeGroup)

	return ngroup
end

--- DOCME
function M.SetNodeInfo (object, owner_id, is_lhs)
	object.m_is_lhs = not not is_lhs
	object.m_owner_id = owner_id
end

_Break_ = M.Break
_Connect_ = M.Connect
_GetNodeInfo_ = M.GetNodeInfo
_SetNodeInfo_ = M.SetNodeInfo

return M