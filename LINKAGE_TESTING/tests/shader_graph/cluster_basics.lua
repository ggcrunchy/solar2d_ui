--- Some cluster setup and theming logic.

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
local nc = require("corona_ui.patterns.node_cluster")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

--
--
--

local KnotObjects = {}

local function WithKnot (event)
	local knot = KnotObjects[event.id]

	knot.x, knot.y = event.x, event.y
end

local KnotID = 0

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

--- DOCME
function M.NewCluster (params)
    local kgroup, lgroup = display.newGroup(), display.newGroup()

	params.back_group:insert(lgroup)
	params.back_group:insert(kgroup)

	local connect, get_color = params.connect, params.get_color

    return nc.New{
        can_connect = params.can_connect,

        connect = function(how, a, b, curve)
            if how == "connect" then -- n.b. display object does NOT exist yet...
                curve:SetKnotFunc(WithKnot)

                local knots, ko = {}, display.newCircle(kgroup, 0, 0, 7)

                KnotID = KnotID + 1
                KnotObjects[KnotID], knots[1] = ko, { id = KnotID, s = .5 }

                ko:addEventListener("touch", function(event)
                    if event.phase == "ended" then
                        nc.DisconnectObjects(a, b)
                    end

                    return true
                end)
				ko:setFillColor(0, 0, .7)
				ko:setStrokeColor(0, 0, .5)

				ko.strokeWidth = 1

                curve:SetKnots(knots)
				curve:SetStrokeColor(1, .75)
                curve:SetStrokeWidth(2)

                curve.knot_id = KnotID
            elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
                FadeAndDie(curve)
            end

            connect(how, a, b, curve)
        end,

        emphasize = function(how, item, arg)
            if how == "began" then -- arg: { node, owners_differ, sides_differ, touch_id }
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
                Blend(item.fill, get_color(nc.GetSide(item)))
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

        line_group = lgroup--bgroup
    }
end

return M