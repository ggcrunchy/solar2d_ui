--- Shader graph proof-of-concept, entry point.

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

-- Modules --
local cluster_basics = require("tests.shader_graph.cluster_basics")
local drag = require("corona_ui.utils.drag")
local nc = require("corona_ui.patterns.node_cluster")

--
--
--

local function StandardColor (what)
	if what == "delete" then
		return 1, 0, 0, 1
	end

	local r, b = .125, 1

	if what == "lhs" then
		r, b = b, r
	end

	return r, .125, b, .75
end

local Connected = {}

local function BreakOldConnection (node)
	node.parent.resolved_was = node.parent.resolved -- breaking might indicate that we should de-resolve; however, the incoming connection
													-- could force us to immediately re-resolve, so save the current state to check afterward

	-- n.b. at moment all nodes are exclusive
	local _, n = nc.GetConnectedObjects(node, Connected)

	for i = 1, n do -- n = 0 or 1
		nc.DisconnectObjects(node, Connected[i])

		Connected[i] = false
	end
end

local function ExtractOldResolved (parent)
	local was = parent.resolved_was

	parent.resolved_was = nil

	return was
end

local function RelevantToResolve (node)
	return not node.hard_type
end

local function ResolvePending (parent)
	return parent.resolved_was ~= nil
end

local Resize

local function Decay (parent)
	for i = 1, parent.numChildren do
		local item = parent[i]

		if item.needs_resolving then
			item:setFillColor(1, 0, 1)

			item.text = "?"
		end
	end

	parent.resolved_type = nil

	Resize(parent)
end

local function ScourConnectedNodes (parent, func, arg)
	for i = 1, parent.numChildren do
		local _, n = nc.GetConnectedObjects(parent[i], Connected)

		for j = 1, n do
			local cnode = Connected[j]

			Connected[j] = false

			func(cnode, arg)
		end
	end
end

local Branch1, Branch2 = {}, {}

local PropagateDecay

local function AuxPropagateDecay (cnode, branch)
	local cparent = cnode.parent

	if branch.exploring and branch[cparent] == nil then -- ignore cut nodes' elements
		if RelevantToResolve(cnode) then
			branch[cparent] = true

			PropagateDecay(cparent, branch)
		else -- found a hard node, so kill this branch
			for k in pairs(branch) do -- includes 'exploring'
				branch[k] = nil
			end
		end
	end
end

function PropagateDecay (parent, branch)
	ScourConnectedNodes(parent, AuxPropagateDecay, branch)
end

local function TryToDecay (node, parent, branch)
	if RelevantToResolve(node) then
		parent.resolved = parent.resolved - node.bound_bit

		if parent.resolved == 0 and not ResolvePending(parent) then
			Decay(parent)
			PropagateDecay(parent, branch)
		end
	end
end

local function Resolve (parent, rtype)
	parent.resolved_type = rtype

	for i = 1, parent.numChildren do
		local item = parent[i]

		if item.needs_resolving then
			item:setFillColor(1, 1, 0)

			item.text = rtype
		end
	end

	Resize(parent)
end

local function ResolvedType (node)
	return node.hard_type or node.parent.resolved_type
end

local TryToResolve

local function PropagateResolve (cnode, rtype)
	if not ResolvedType(cnode) then
		cnode.resolve = rtype

		TryToResolve(cnode, cnode.parent)
	end
end

function TryToResolve (node, parent)
	local was = ExtractOldResolved(parent) or 0

	if RelevantToResolve(node) then
		local rtype = node.resolve

		if rtype then
			parent.resolved, node.resolve = parent.resolved + node.bound_bit

			if was == 0 then
				Resolve(parent, rtype)
				ScourConnectedNodes(parent, PropagateResolve, rtype)
			end
		end
	end

	if parent.resolved == 0 and was > 0 then
		Decay(parent)
	end
end

local HardToWildcard = { float = "vector", --[[ <- this one's iffy ]] vec2 = "vector", vec3 = "vector", vec4 = "vector" }

local function WildcardType (node)
	return node.parent.wildcard_type
end

local function TYPE (node)
	local hard_type = node.hard_type

	if hard_type then
		return HardToWildcard[hard_type]
	else
		return WildcardType(node)
	end
end

local function PurgeBranch (branch)
	if branch.exploring then
		branch.exploring = nil

		for parent, exists in pairs(branch) do
			if exists then
				Decay(parent)
			end
		end
	end
end

function DUMP_INFO ()
	local stage = display.getCurrentStage()
	for i = 1, stage.numChildren do
		local p = stage[i]
		if p.numChildren and p.numChildren >= 2 and p[2].text then
			print("ELEMENT:", p[2].text)

			for j = 3, p.numChildren do
				local _, n = nc.GetConnectedObjects(p[j], Connected)

				if n > 0 then
					print("NODE: ", p[j + 1].text)
					print("INFO: ", NODE_INFO(p[j]))

					for k = 1, n do
						print("CONNECTED TO: ", NODE_INFO(Connected[k]))
					end

					print("")
				end
			end

			print("")
		end
	end
end

local NC = cluster_basics.NewCluster{
	can_connect = function(a, b)
		local compatible = TYPE(a) == TYPE(b) -- e.g. restrict to vectors, matrices, etc.
		local how1, what1 = a:rule(b, compatible)
		local how2, what2 = b:rule(a, compatible)

		if how1 and how2 then
			if how1 == "resolve" then
				a.resolve = what1
			elseif how2 == "resolve" then
				b.resolve = what2
			end

			return true
		end
	end,

	connect = function(how, a, b, _)
		local aparent, bparent = a.parent, b.parent

		if how == "connect" then -- n.b. display object does NOT exist yet...
			BreakOldConnection(a)
			BreakOldConnection(b)

			aparent.bound, bparent.bound = aparent.bound + a.bound_bit, bparent.bound + b.bound_bit

			TryToResolve(a, aparent)
			TryToResolve(b, bparent)
		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
			aparent.bound, bparent.bound = aparent.bound - a.bound_bit, bparent.bound - b.bound_bit

			Branch1.exploring, Branch1[bparent] = true, false
			Branch2.exploring, Branch2[aparent] = true, false

			TryToDecay(a, aparent, Branch1)
			TryToDecay(b, bparent, Branch2)

			PurgeBranch(Branch1)
			PurgeBranch(Branch2)
			DUMP_INFO()
		end
	end,

	get_color = StandardColor
}

local Drag = drag.MakeTouch_Parent{
    offset_by_object = true,

    on_post_move = function(group, _)
        for i = 1, group.numChildren do
            local item = group[i]

            if item.bound_bit then
                nc.PutInUpdateList(item)
            end
        end

        NC:Update()
    end
}

local OwnerID = 1

local function Rect (title, wildcard_type)
    local group = display.newGroup()

    group.next_bit, group.wildcard_type = 1, wildcard_type

	display.newText(group, title, 0, 0, native.systemFontBold)

    return group
end

local Middle = 20

local Separation = 7

local Edge = 5

local function VisitGroup (group, func, arg)
	local index, n = 1, group.numChildren

	repeat
		local item, extra = group[index]

		if not item.put then -- skip back
			extra = func(item, arg, group, index)
		end

		index = index + 1 + (extra or 0)
	until index > n
end

local Dimensions = {}

local function AuxGetDimensions (item, dims, group, index)
	local side = item.side

	if side then
		local extra = item.extra or 0
		local w, h, y = extra * Separation, 0

		for i = 0, extra do
			local elem = group[index + i]
	
			w, h = w + elem.contentWidth, math.max(h, elem.contentHeight)
		end

		if side == "lhs" then
			dims.left, y = math.max(dims.left, w), dims.left_y
			dims.left_y = dims.left_y + h + Separation
		else
			dims.right, y = math.max(dims.right, w), dims.right_y
			dims.right_y = dims.right_y + h + Separation
		end

		local mid = y + h / 2

		for i = 0, extra do
			group[index + i].y_offset = mid
		end

		return extra
	else
		dims.center = math.max(dims.center, item.contentWidth)
		item.y_offset = dims.center_y + item.contentHeight / 2
		dims.center_y = dims.center_y + item.contentHeight + Separation
		dims.left_y, dims.right_y = dims.center_y, dims.center_y
	end
end

local function PlaceItems (item, back, group, index)
	local put, side, x, y = back.put, item.side, back.x, back.y - back.height / 2

	if side then
		local extra, offset, half = item.extra, Edge, back.width / 2

		for i = 0, extra or 0 do
			item = group[index + i]

			if side == "lhs" then
				put(item, "x", x - half + offset)
			else
				put(item, "x", x + half - offset)
			end

			put(item, "y", y + item.y_offset)

			offset = offset + item.contentWidth + Separation
		end

		return extra
	else
		put(item, "x", x)
		put(item, "y", y + item.y_offset)
	end
end

local function PutDirect (item, what, value)
	item[what] = value
end

local function GetDimensions (group)
	Dimensions.center, Dimensions.left, Dimensions.right = 0, 0, 0
	Dimensions.left_y, Dimensions.right_y, Dimensions.center_y = Edge, Edge, Edge

	VisitGroup(group, AuxGetDimensions, Dimensions)

	local w = Dimensions.center

	if Dimensions.left > 0 and Dimensions.right > 0 then -- on each side?
		w = math.max(2 * math.max(Dimensions.left, Dimensions.right) + Middle, w)
	elseif Dimensions.left + Dimensions.right > 0 then -- one side only
		w = math.max(w, Dimensions.left, Dimensions.right)
	end

	w = w + 2 * Edge

	local h = math.max(Dimensions.center_y, Dimensions.left_y, Dimensions.right_y) - Separation -- account for last item added

    return w, h + Edge -- height already includes one Edge from starting offsets
end

local function CommitRect (group, x, y)
	group.fully_bound, group.next_bit = group.next_bit - 1
    group.bound = 0 -- when = fully_bound, all nodes are connected
	group.resolved = 0 -- if non-0, wildcard has been resolved; likewise de-resolved on decay to 0, but see proviso in BreakOldConnections()

	local w, h = GetDimensions(group)
    local back = display.newRoundedRect(group, x, y, w, h, 12)

    back:addEventListener("touch", Drag)
    back:setFillColor(.7)
    back:toBack()

	back.put, group.back = PutDirect, back -- back should be in element 1, but keep a ref just in case

	VisitGroup(group, PlaceItems, back)

    OwnerID = OwnerID + 1
end

local ToUpdate

local ResizeParams = {
	onComplete = function(object)
		local to_update = object.to_update

		if to_update then
			object.to_update[object] = object.to_update[object] - 1
		end
	end, time = 150
}

local function PutMightTransition (item, what, value)
	local cur = item[what]
	local diff = cur - value

	if diff ~= 0 then
		ToUpdate = ToUpdate or {}
		ToUpdate[item] = ToUpdate[item] or 0

		if math.abs(diff) < 3 then
			PutDirect(item, what, value)
		else
			ToUpdate[item] = ToUpdate[item] + 1
			item.to_update, ResizeParams[what] = ToUpdate, value

			transition.to(item, ResizeParams)

			ResizeParams[what] = nil
		end
	end
end

function Resize (parent)
	local w, h = GetDimensions(parent)
	local back = parent.back

	PutMightTransition(back.path, "width", w)
	PutMightTransition(back.path, "height", h)

	back.put = PutMightTransition
local bw, bh = back.width, back.height
back.width,back.height = w, h
	VisitGroup(parent, PlaceItems, back)
back.width,back.height = bw, bh
	if ToUpdate then
		if ToUpdate then
			local to_update = ToUpdate

			timer.performWithDelay(35, function(event)
				local any

				for object, count in pairs(to_update) do
					if count == 0 then
						to_update[object], object.to_update = nil
					else
						any = true
					end

					nc.PutInUpdateList(object)
				end

				if any then
					NC:Update()
				else
					timer.cancel(event.source)
				end
			end, 0)
		end

		ToUpdate = nil
	end
end
-- ^^^ ARGH, this is actually tough :/

local function Circle (group, width, radius, ...)
	local circle = display.newCircle(group, 0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

-- "vector" -> set as wildcard type, use AllowT
-- "vector|float" -> use different rule, use AllowTOrFloat
-- other -> at the moment, as above (e.g. bvector, ivector), else hard type (float, sampler, etc.)

local function Hard (node, other)
	local resolved = ResolvedType(other)

	if resolved == nil then
		return HardToWildcard[node.hard_type] == WildcardType(other)
	else
		return node.hard_type == resolved
	end
end

local function AllowT (node, other, compatible)
	if compatible then
		local resolved1, resolved2 = ResolvedType(node), ResolvedType(other)

		if resolved1 == resolved2 then -- both resolved or wild
			return true
		elseif resolved1 == nil then
			return "resolve", resolved2
		else
			return resolved2 == nil -- given other chance to resolve
		end
	end
end

local function AllowFloatOrT (node, other)
	if ResolvedType(other) == "float" then
		return true
	else
		return AllowT(node, other)
	end
end

local function NewNode (group, what, name, how)
	local object = Circle(group, 3, 7, StandardColor(what))
	local anchor = (what == "lhs" or what == "delete") and 0 or 1

	if what ~= "delete" then
		NC:AddNode(object, OwnerID, what)

-- TODO: at the moment all vectors but needs some generalization
		local tstr = "?"

		if how == "fv" then
			assert(object.parent.wildcard_type == nil or object.parent.wildcard_type == "vector", "Group already has other wildcard type")

			object.parent.wildcard_type = "vector"
			object.rule = AllowFloatOrT
		elseif how == "?v" then
			assert(object.parent.wildcard_type == nil or object.parent.wildcard_type == "vector", "Group already has other wildcard type")

			object.parent.wildcard_type = "vector"
			object.rule = AllowT
		else
			object.hard_type = assert(how, "Expected type")
			object.rule = Hard

			tstr = object.hard_type
		end

		object.side = what

		object.bound_bit = group.next_bit
		group.next_bit = 2 * group.next_bit

		object.extra = 2

		local text = display.newText(group, name, 0, 0, native.systemFont, 24)

		object.anchorX, text.anchorX = anchor, anchor

		local ttext = display.newText(group, tstr, 0, 0, native.systemFont, 24)

		if tstr ~= "?" then
			ttext:setFillColor(1, 0, 1)
		else
			ttext:setFillColor(1, 1, 0)

			ttext.needs_resolving = true
		end

		ttext.anchorX = anchor
	end
end

-- TEMP!
RR=Rect
NN=NewNode
CR=CommitRect
-- /TEMP!

require("tests.shader_graph.add_menu")