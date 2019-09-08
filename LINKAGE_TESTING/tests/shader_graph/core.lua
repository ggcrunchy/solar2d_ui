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
local boxes = require("tests.shader_graph.boxes")
local cluster_basics = require("tests.shader_graph.cluster_basics")
local drag = require("corona_ui.utils.drag")
local nc = require("corona_ui.patterns.node_cluster")
local nl = require("tests.shader_graph.node_layout")
local ns = require("tests.shader_graph.node_state")

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

ns.AddHardToWildcardEntries{ "float", "vec2", "vec3", "vec4", wildcard_type = "vector" }

local NC

local Drag = drag.MakeTouch_Parent{
    offset_by_object = true,

    on_post_move = function(group, _)
        for i = 1, group.numChildren do
            local item = group[i]

            if item.bound_bit then -- nodes will have this member
                nc.PutInUpdateList(item) -- any curves will need to track node movement
            end
        end

        NC:Update()
    end
}

local function Rect (title)
    local group = display.newGroup()

    group.next_bit = 1

	display.newText(group, title, 0, 0, native.systemFontBold)

    return group
end

nl.SetEdgeWidth(5)
nl.SetMiddleWidth(20)
nl.SetSeparation(7)

local function Place_Direct (item, what, value) -- place objects exactly where we say
	item[what] = value
end

local OwnerID = 1

local function CommitRect (group, x, y)
	group.fully_bound, group.next_bit = group.next_bit - 1
    group.bound = 0 -- when = fully_bound, all nodes are connected

	local w, h = nl.GetDimensions(group)
    local back = display.newRoundedRect(group, x, y, w, h, 12)

    back:addEventListener("touch", Drag)
    back:setFillColor(.7)
    back:toBack()

	nl.HideItemDuringVisits(back)
	nl.SetPlaceFunc(Place_Direct)

	group.back = back -- back should be in element 1, but keep a ref just in case

	nl.VisitGroup(group, nl.PlaceItems, back)

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

local function Place_MightTransition (item, what, value) -- set objects' final destinations, preferring a transition
														-- but opting for direct placement when not worth the hassle
	local cur = item[what]
	local diff = cur - value

	if math.abs(diff) >= 3 then -- enough to be worth transitioning?
		ToUpdate = ToUpdate or {}
		ToUpdate[item] = (ToUpdate[item] or 0) + 1 -- how many properties need waiting on?
		item.to_update, ResizeParams[what] = ToUpdate, value

		transition.to(item, ResizeParams)

		ResizeParams[what] = nil
	elseif diff ~= 0 then -- at least needs an update?
		Place_Direct(item, what, value)
	end
end

local can_connect, connect = boxes.MakeClusterFuncs(function(parent)
	local back, w, h = parent.back, nl.GetDimensions(parent)

	nl.SetPlaceFunc(Place_MightTransition)

	local bw, bh = back.width, back.height	-- the back object will be used as a guide to launch the others'
											-- transitions, so temporarily swap out its dimensions with the
											-- final results and do those calculations, then restore them

	back.width, back.height = w, h

	nl.VisitGroup(parent, nl.PlaceItems, back)

	back.width, back.height = bw, bh

	Place_MightTransition(back.path, "width", w) -- we want to transition the scale of the back object, but only
	Place_MightTransition(back.path, "height", h) -- when necessary, so (directly) reuse the "might" logic

	if ToUpdate then
		local to_update = ToUpdate

		timer.performWithDelay(35, function(event)
			local any

			for object, count in pairs(to_update) do
				if count == 0 then -- all properties done?
					to_update[object], object.to_update = nil
				else
					any = true -- TODO: is this in the right place?
				end

				nc.PutInUpdateList(object)
			end

			if any then -- at least one property updated?
				NC:Update()
			else
				timer.cancel(event.source)
			end
		end, 0)
	end

	ToUpdate = nil
end)

NC = cluster_basics.NewCluster{ can_connect = can_connect, connect = connect, get_color = StandardColor }

local function Circle (group, width, radius, ...)
	local circle = display.newCircle(group, 0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

-- "vector" -> set as wildcard type, use AllowT
-- "vector|float" -> use different rule, use AllowTOrFloat
-- other -> at the moment, as above (e.g. bvector, ivector), else hard type (float, sampler, etc.)

local function NewNode (group, what, name, payload_type, how)
	if how == "sync" then
		nl.SetSyncPoint(group)
	end

	local object = Circle(group, 3, 7, StandardColor(what))
	local anchor = (what == "lhs" or what == "delete") and 0 or 1

	if what == "delete" then
		object:setFillColor(1, 0, 0)
		object:setStrokeColor(.7, 0, 0)

		nl.SetSide(object, "lhs")
	else
		NC:AddNode(object, OwnerID, what)

-- TODO: at the moment all vectors but needs some generalization
		local tstr, wildcard_type = "?", ns.WildcardType(object.parent)

		if payload_type == "fv" then
			assert(wildcard_type == nil or wildcard_type == "vector", "Group already has other wildcard type")

			ns.SetNonResolvingHardType(object, "float")
		elseif payload_type == "?v" then
			assert(wildcard_type == nil or wildcard_type == "vector", "Group already has other wildcard type")

			ns.SetWildcardType(object.parent, "vector")
		else
			ns.SetHardType(object, assert(payload_type, "Expected type"))

			tstr = payload_type
		end

		nl.SetExtraTrailingItemsCount(object, 2)
		nl.SetSide(object, what)

		object.bound_bit = group.next_bit
		group.next_bit = 2 * group.next_bit

		local text = display.newText(group, name, 0, 0, native.systemFont, 24)

		text.anchorX = anchor

		local ttext = display.newText(group, tstr, 0, 0, native.systemFont, 24)

		if tstr ~= "?" then
			ttext:setFillColor(1, 0, 1)
		else
			ttext:setFillColor(1, 1, 0)

			ttext.needs_resolving = true
		end

		ttext.anchorX = anchor
	end

	object.anchorX = anchor
end

-- TEMP!
RR=Rect
NN=NewNode
CR=CommitRect
-- /TEMP!

require("tests.shader_graph.add_menu")