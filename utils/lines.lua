--- Line utilities.

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
local sqrt = math.sqrt

-- Modules --
local array_funcs = require("tektite_core.array.funcs")
local curves = require("tektite_core.number.curves")
local color = require("solar2d_ui.utils.color")
local line_ex = require("solar2d_ui.utils.line_ex")

-- Solar2D globals --
local display = display
local timer = timer

-- Exports --
local M = {}

--
--
--

-- Number of segments in a curve --
local CurveCount = 15

-- Maximum use-a-straight-line distance --
local LineDist = 40

-- Active lines --
local Lines = {}

-- A curve function with nice properties
local function CurveXY (x, y, dx, dy, index)
	local xt = index / CurveCount
	local yt = curves.Perlin(xt)

	return x + dx * xt, y + dy * yt
end

-- "Has position changed?" helper; will ALWAYS be true on first call
local function Diff (a, b, eps)
	return not b or abs(a - b) > (eps or .5)
end

-- Default keep: always
local function NoKeep () return true end

-- Helper to initialize / update line knots
local function UpdateKnot (knot, x1, y1, x2, y2)
	local x, y = CurveXY(x1, y1, x2 - x1, y2 - y1, CurveCount / 2)

	knot.x, knot.y = knot.parent:contentToLocal(x, y)
end

-- Update body
local function UpdateLines (event)
	if #Lines == 0 then
		Lines.is_running = false

		timer.cancel(event.source)

		-- okay to fall through
	end

	for i = #Lines, 1, -1 do
		local line = Lines[i]
		local p1, p2, group = line.p1, line.p2, line.group

		-- If one or both of the endpoints was removed, or the keep condition fails, remove
		-- the line. Since order is unimportant (and we are iterating backwards), backfill
		-- its slot with another line.
		if not (display.isValid(p1) and display.isValid(p2) and line.keep(p1, p2, line.knot)) then
			if display.isValid(group) then -- TODO: just a synonym for display.remove()?
				group:removeSelf()
			end

			array_funcs.Backfill(Lines, i)

		-- Otherwise, if one or both endpoints have changed, rebuild the line. 
		else
			local p1x, p1y = p1:localToContent(0, 0)
			local p2x, p2y = p2:localToContent(0, 0)

			if Diff(p1x, line.p1x) or Diff(p1y, line.p1y) or Diff(p2x, line.p2y) or Diff(p2y, line.p2y) then
				for i = group.numChildren, 1, -1 do
					group:remove(i)
				end

				local dx, dy = p2x - p1x, p2y - p1y
				local len = sqrt(dx^2 + dy^2)

				-- There are at least two points in the curve: we use a single segment
				-- if the endpoints are close or nearly horizontal / vertical to each
				-- other. Otherwise, we use a full curve and subdivide the interval.
				local second = 1

				if len < LineDist or not (Diff(p1x, p2x, 25) and Diff(p1y, p2y, 25)) then
					second = CurveCount
				end

				-- Build up the curve, starting with the first point.
				local seg = line_ex.NewLine(group, p1x, p1y)

				seg:setStrokeColor(color.GetColor(line.color))

				seg.strokeWidth = line.width

				-- Add the second through n-th points.
				for i = second, CurveCount do
					seg:append(CurveXY(p1x, p1y, dx, dy, i))
				end

				-- If the line has a knot, recenter it.
				if line.knot then
					UpdateKnot(line.knot, p1x, p1y, p2x, p2y)
				end

				-- Update state used to track dirty endpoints.
				line.p1x, line.p1y = p1x, p1y
				line.p2x, line.p2y = p2x, p2y
			end

			-- Update visibility of line components.
			local is_visible = p1.isVisible and p2.isVisible

			group.isVisible = is_visible

			if line.knot then
				line.knot.isVisible = is_visible
			end
		end
	end
end

--- Creates a line that tracks between _p1_ and _p2_. This line becomes a curve when these
-- endpoints are somewhat separated.
-- @pobject p1 Endpoint #1.
-- @pobject p2 Endpoint #2.
-- @ptable[opt] options Line options. Fields:
--
-- * **color**: Line color. If absent, white.
-- * **keep**: **callable** If provided, called with _p1_, _p2_, and _options_.**knot** as
-- arguments. On a false result, the line will be removed. By default, lines are always kept.
-- * **into**: **DisplayGroup** If provided, the line (and knot, if available), are inserted
-- into this group. Otherwise, they go onto the stage.
-- * **knot**: **DisplayObject** Optional object to maintain on top of the line.
-- * **width**: Line width, q.v. **display.newLine**. If absent, a default is used.
function M.LineBetween (p1, p2, options)
	if not Lines.is_running then
		Lines.is_running = true

		timer.performWithDelay(20, UpdateLines, 0)
	end

	local group = display.newGroup()
	local into, keep, knot, color, width

	if options then
		into = options.into
		keep = options.keep
		knot = options.knot
		color = options.color
		width = options.width
	end

	into = into or display.getCurrentStage()

	into:insert(group)

	if knot then
		into:insert(knot)

		local x1, y1 = p1:localToContent(0, 0)
		local x2, y2 = p2:localToContent(0, 0)

		UpdateKnot(knot, x1, y1, x2, y2)
	end

	Lines[#Lines + 1] = {
		p1 = p1, p2 = p2, group = group,
		keep = keep or NoKeep, knot = knot,
		color = color or "white", width = width or 2
	}
end

return M