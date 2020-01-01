--- Object used to plot a curve between two points.

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
local setmetatable = setmetatable
local remove = table.remove
local sort = table.sort
local sqrt = math.sqrt
local type = type

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

local KnotLayouts = {}

local function ValidateArcLength (s)
	assert(type(s) == "number", "Invalid arc length")

	return s
end

--- DOCME
function M.CreateKnotLayout (name, knots)
	assert(not KnotLayouts[name], "Another layout with this name already exists")
	assert(type(knots) == "table", "Invalid knots table")

	local layout = {}

	for i = 1, #knots do
		local knot = knots[i]

		if type(knot) == "table" then
			layout[#layout + 1] = { id = knot.id, s = ValidateArcLength(knot.s) }
		else
			layout[#layout + 1] = ValidateArcLength(knot)
		end
	end

	KnotLayouts[name] = layout
end

local Knots = {}

local KnotStash = {}

local function SortByArcLength (a, b)
    return a.s < b.s
end

local function GatherKnots (knots, shift, wrap)
    local n = 0

	if type(knots) == "string" then
		knots = assert(KnotLayouts[knots], "Invalid layout name")
	end

    for i = 1, #(knots or "") do
        local from, id, s = knots[i]

        if type(from) == "table" then
            id, s = from.id, from.s
        else -- interpret number as arc length
            s = from
        end

        s = s + shift

        if wrap then
            s = s % 1
        end

        if s >= 0 and s <= 1 then
            local to = Knots[n + 1] or remove(KnotStash) or {}

            Knots[n + 1], to.id, to.s, n = to, id, s, n + 1
        end
    end

    for i = #Knots, n + 1, -1 do
        KnotStash[#KnotStash + 1], Knots[i] = Knots[i]
    end

    sort(Knots, SortByArcLength)

    return n
end

local function CallMethod (method, x1, y1, dx, dy, t)
    return method(x1, y1, dx, dy, t)
end

local Distances = {}

local function CallMethodAndRememberDistance (method, x1, y1, dx, dy, t)
    local n, x, y = Distances.n, method(x1, y1, dx, dy, t)
	local distance = Distances[n + 1] or {}

	distance.s = sqrt((x - Distances.prev_x)^2 + (y - Distances.prev_y)^2)
    distance.t = t

    Distances[n + 1], Distances.n, Distances.prev_x, Distances.prev_y = distance, n + 1, x, y

    return x, y
end

local KnotEvent = {}

local function CurveLength ()
	local extent = 0

	for i = 1, Distances.n do
		extent = extent + Distances[i].s
	end

	return extent
end

local function VisitKnots (func, n, method, x1, y1, dx, dy)
    local extent, index, scale = CurveLength(), 0, 1 -- scale = 1 accounts for knots at s = 0
    local sprev, tprev, snext, tnext = 0, 0, 0, 0 -- initialize prevs for s = 0 case, nexts for fixup in first knot after that

    for i = 1, n do
        local knot = Knots[i]
        local s = knot.s * extent

        if s > snext then
			while s > snext do
				sprev, tprev, index = snext, tnext, index + 1
				snext, tnext = snext + Distances[index].s, Distances[index].t
			end

            scale = (tnext - tprev) / (snext - sprev)
        end

		local t = tprev + scale * (s - sprev)

        KnotEvent.id, KnotEvent.t = knot.id, t
		KnotEvent.x, KnotEvent.y = method(x1, y1, dx, dy, t)

        func(KnotEvent)
    end
end

local function GetSecondPointIndex (plotter, dx, dy, len_sq, segment_count)
	local ns = plotter.m_nearly_straight

	if len_sq < plotter.m_curve_after_squared or (abs(dx) < ns and abs(dy) < ns) then -- close or straight enough for single segment?
		return segment_count
	else
		return 1
	end
end

local function Plot (plotter, x1, y1, x2, y2, opts)
    local nknots, call, group = 0, CallMethod

    if opts then
        group = opts.group

        if opts.knot_func then
            nknots = GatherKnots(opts.knots, opts.shift or 0, plotter.m_wrap_knots)

            if nknots > 0 then
                call, Distances.n, Distances.prev_x, Distances.prev_y = CallMethodAndRememberDistance, 0, x1, y1
            end
        end
    end

    local dx, dy = x2 - x1, y2 - y1
    local len_sq, curve = dx^2 + dy^2

    if len_sq > plotter.m_minimum_separation_squared then
        local nsegments = plotter.m_segment_count
		local second = GetSecondPointIndex(plotter, dx, dy, len_sq, nsegments)
        local method = plotter.m_curve_method

		group = group or plotter.m_group or display.getCurrentStage()

		x1, y1 = group:contentToLocal(x1, y1) -- TODO: probably need to adjust dx, dy too

        curve = display.newLine(group, x1, y1, call(method, x1, y1, dx, dy, second / nsegments))

        for i = second + 1, nsegments do
            curve:append(call(method, x1, y1, dx, dy, i / nsegments))
        end

        if nknots > 0 then
            VisitKnots(opts.knot_func, nknots, method, x1, y1, dx, dy)
        end
    end

    return curve
end

local CurvePlotter = {}

CurvePlotter.__index = CurvePlotter

--- DOCME
function CurvePlotter:BetweenObjects (object1, object2, opts)
    local x1, y1 = object1:localToContent(0, 0)
    local x2, y2 = object2:localToContent(0, 0)

    return Plot(self, x1, y1, x2, y2, opts)
end

--- DOCME
function CurvePlotter:BetweenPoints (x1, y1, x2, y2, opts)
     if opts then
        local p1_group, p2_group = opts.p1_group, opts.p2_group

        if p1_group then
            x1, y1 = p1_group:localToContent(x1, y1)
        end

        if p2_group then
            x2, y2 = p2_group:localToContent(x2, y2)
        end
    end

    return Plot(self, x1, y1, x2, y2, opts)
end

--- DOCME
function CurvePlotter:FromObjectToPoint (object, x, y, opts)
    local x2, y2, x1, y1 = x, y, object:localToContent(0, 0)

    if opts then
        local point_group = opts.point_group

        if point_group then
            x2, y2 = point_group:localToContent(x2, y2)
        end

        if opts.point_to_object then
            x1, y1, x2, y2 = x2, y2, x1, y1
        end
    end

    return Plot(self, x1, y1, x2, y2, opts)
end

local CurveAfterDistance = 40

local MinimumSeparation = 2

local NearlyStraight = 25

local SegmentCount = 15

local function Perlin (t)
	return t^3 * (t * (t * 6 - 15) + 10)
end

local function DefCurve (x, y, dx, dy, t)
	return x + dx * t, y + dy * Perlin(t)
end

--- DOCME
function M.New (opts)
    local plotter, ca, cm, ms, ns, sc = {}

    if opts then
        ca = opts.curve_after
        cm = opts.curve_method
        ms = opts.minimum_separation
        ns = opts.nearly_straight
        sc = opts.segment_count

		plotter.m_group = opts.line_group
        plotter.m_wrap_knots = not opts.no_knot_wrapping
    end

    plotter.m_curve_after_squared = (ca or CurveAfterDistance)^2
    plotter.m_curve_method = cm or DefCurve
    plotter.m_minimum_separation_squared = (ms or MinimumSeparation)^2
    plotter.m_nearly_straight = ns or NearlyStraight
    plotter.m_segment_count = sc or SegmentCount

    return setmetatable(plotter, CurvePlotter)
end

return M