--- Node group test.

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

local drag = require("corona_ui.utils.drag")
local nc = require("corona_ui.patterns.node_cluster")

local BackGroup = nil -- display.newGroup()

local KnotObjects = {}

local function WithKnot (event)
	local knot, t = KnotObjects[event.id], event.t

	if t < .2 then
		t = .05 + .95 * t / .2
	elseif t > .8 then
		t = 1 - .95 * (t - .8) / .2
	else
		t = 1
	end

	knot.x, knot.y, knot.alpha = event.x, event.y, t^2
end

local KnotID = 0

local Count = 5

local Shift = .375

local FadeParams = {
	alpha = .15, time = 200,

	onComplete = display.remove
}

local function EvictAndFadeObject (curve)
	local object = curve:EvictDisplayObject()

	if object then -- object might not exist when curve endpoints overlap, etc.
		transition.to(object, FadeParams)
	end
end

local function FadeAndDie (curve)
	local knot = KnotObjects[curve.knot_id]

	KnotObjects[curve.knot_id] = false

	transition.to(knot, FadeParams)

	EvictAndFadeObject(curve)
end

local function StandardColor (what)
	local r, b = .125, 1

	if what == "lhs" then
		r, b = b, r
	end

	return r, .125, b, .75
end

local BlendParams = { time = 150 }

local function Blend (paint, r, g, b, a)
	BlendParams.r, BlendParams.g, BlendParams.b, BlendParams.a = r, g, b, a

	transition.to(paint, BlendParams)
end

local function BlendRGB (paint, r, g, b) -- redundant but explicit
	Blend(paint, r, g, b, nil)
end

local function BlendA (paint, a)
	Blend(paint, nil, nil, nil, a)
end

local NC = nc.New{
	connect = function(how, a, b, curve)
		if how == "connect" then -- n.b. display object does NOT exist yet...
			curve:SetKnotFunc(WithKnot)

			local knots = {}

			if KnotID == 0 then
				KnotID = Count + 1

				for i = 1, Count do
					knots[#knots + 1] = { id = i, s = i / Count }
					KnotObjects[i] = display.newCircle(0, 0, 10)
				end

				timer.performWithDelay(100, function(event)
					curve:SetShift((event.time / 1000) * Shift)
					nc.PutInUpdateList(a)
					nc.GetCluster(a):Update()
				end, 0)
			else
				KnotID = KnotID + 1
				KnotObjects[KnotID] = display.newCircle(0, 0, 10)

				knots[1] = { id = KnotID, s = .5 }

				KnotObjects[KnotID]:addEventListener("touch", function(event)
					if event.phase == "ended" then
						nc.DisconnectObjects(a, b)
					end

					return true
				end)
			end

			curve:SetKnots(knots)
			curve:SetStrokeWidth(3)

			curve.knot_id = KnotID

			-- TODO: see if this is robust against exclusive links, so doing a disconnect from here

		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie
			FadeAndDie(curve)
		end
	end,

	emphasize = function(how, item, arg)
		if how == "began" then -- arg: table, with node, owners_differ, sides_differ, touch_id
			if arg.owners_differ and arg.sides_differ then -- viable candidate?
				BlendRGB(item.fill, 1, 0, 1)
			elseif item == arg.node then -- self
				BlendRGB(arg.node.stroke, 1, 0, 1)
			else -- anything else
				if arg.owners_differ then
					BlendRGB(item.fill, 0, 0, 0)
				else
					BlendA(item.fill, .25)
				end
			end
		elseif how == "ended" then -- ditto
			Blend(arg.node.stroke, 0, 1, 0, 1)
			Blend(item.fill, StandardColor(nc.GetSide(item)))
		elseif how == "highlight" then -- arg: begin?
			Blend(item.stroke, arg and 1 or 0, 1, 0, 1)
		end
	end,

	with_temp_curve = function(how, curve)
		if how == "began" then -- n.b. display object does NOT exist yet...
			curve:SetStrokeColor(1, .25, .25, .75)
			curve:SetStrokeWidth(5)
		elseif how ~= "connected" then  -- as with connection curves, we usually have a display object now
										-- if connected, we just instantly disappear, to be replaced? (TODO: might be more elegant if
										-- we coordinate a transition between widths, of course)  
			EvictAndFadeObject(curve)
		end
	end,

	line_group = BackGroup
}

local cx, cy = display.contentCenterX, display.contentCenterY

local function AuxRect (group, minx, miny, maxx, maxy, a, ...)
    if a then
        local bounds = a.contentBounds

        group:insert(a)

        minx = math.min(bounds.xMin, minx)
        miny = math.min(bounds.yMin, miny)
        maxx = math.max(bounds.xMax, maxx)
        maxy = math.max(bounds.yMax, maxy)
        
        minx, miny, maxx, maxy = AuxRect(group, minx, miny, maxx, maxy, ...)
    end

    return minx, miny, maxx, maxy
end

local Drag = drag.MakeTouch_Parent{
    offset_by_object = true,

    on_post_move = function(group, back)
        for i = 1, group.numChildren do
            local item = group[i]

            if item ~= back then
                nc.PutInUpdateList(item)
            end
        end

        NC:Update()
    end
}

local function Rect (...)
    local group = display.newGroup()
    local minx, miny, maxx, maxy = AuxRect(group, 1 / 0, 1 / 0, -1 / 0, -1 / 0, ...)
    local w, h = maxx - minx + 10, maxy - miny + 10
    local back = display.newRect(group, (minx + maxx) / 2, (miny + maxy) / 2, w, h)

    back:addEventListener("touch", Drag)
    back:setFillColor(.7)
    back:toBack()
end

local function Circle (width, radius, ...)
	local circle = display.newCircle(0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

local function NewNode (owner_id, what)
	local object = Circle(4, 25, StandardColor(what))

	NC:AddNode(object, owner_id, what)

	return object
end


local a = NewNode(1, "lhs")
local b = NewNode(1, "lhs")
local c = NewNode(1, "rhs")

a.x, a.y = cx - 50, cy - 100
b.x, b.y = cx - 50, cy - 50
c.x, c.y = cx + 50, cx - 75

Rect(a, b, c)

local d = NewNode(2, "lhs")

d.x, d.y = cx + 120, cy - 150

Rect(d)

local e = NewNode(3, "lhs")

e.x, e.y = cx + 120, cy + 150

Rect(e)

local f = NewNode(4, "lhs")
local g = NewNode(4, "rhs")

f.x, f.y = cx - 175, cy + 50
g.x, g.y = cx - 100, cy + 50

Rect(f, g)