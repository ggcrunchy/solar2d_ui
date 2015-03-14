--- 2D grid UI elements.
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
local ceil = math.ceil
local floor = math.floor
local remove = table.remove

-- Modules --
local array_index = require("tektite_core.array.index")
local bresenham = require("iterator_ops.grid.bresenham")
local colors = require("corona_ui.utils.color")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local range = require("tektite_core.number.range")
local skins = require("corona_ui.utils.skin")
local stencil = require("iterator_ops.grid.stencil")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Helper to get the per-cell dimensions
local function GetCellDims (back)
	return back.width / back.m_ncols, back.height / back.m_nrows
end

-- Gets a position's (non-offset) cell
local function Cell (back, x, y)
	local gx, gy = back:contentToLocal(x, y)
	local dw, dh = GetCellDims(back)
	local col = array_index.FitToSlot(gx, -back.width / 2, dw)
	local row = array_index.FitToSlot(gy, -back.height / 2, dh)

	return col, row
end

-- Event to dispatch --
local Event = {}

-- Dispatch events to grid
local function Dispatch (back, col, row, x, y, context, is_first)
	local grid = back.parent.parent

	Event.name = "cell"
	Event.target = grid
	Event.col, Event.x = col, floor(x)
	Event.row, Event.y = row, floor(y)
	Event.context = context
	Event.is_first = is_first

	grid:dispatchEvent(Event)
end

-- Helper to get the in-cell offsets
local function GetLocalOffsets (back)
	return -back.m_cx, -back.m_cy
end

-- Touch listener
local Touch = touch.TouchHelperFunc(function(event, back)
	local coff, roff = back.m_coffset, back.m_roffset
	local col, row = Cell(back, event.x, event.y)
	local context, cx, cy = event.context, GetLocalOffsets(back)
	local ncols, nrows = back.m_ncols, back.m_nrows
	local dw, dh = GetCellDims(back)

	-- Fit the new coordinate to a stencil-based swath of cells. During moves, the previous and
	-- new coordinates may not be adjacent, so line-based traversal is performed to approximate
	-- the intermediate coordinates.
	local began, f, s, v = event.phase == "began"

	if began then
		f, s, v = stencil.StencilIter(back.m_stencil, col, row)
	else
		f, s, v = stencil.StencilIter_FromTo(back.m_stencil, back.m_col, back.m_row, col, row, true)
	end

	for c, r in f, s, v do
		if c >= 1 and c <= ncols and r >= 1 and r <= nrows then
			local cres, rres = c + coff, r + roff

			Dispatch(back, cres, rres, (cres + cx) * dw, (rres + cy) * dh, context, began)
		end
	end

	-- Commit the new previous coordinates.
	back.m_col, back.m_row, Event.target = col, row
end, "began")

-- Common line add logic
local function AddGridLine (group, skin, x1, y1, x2, y2)
	local line = display.newLine(group, x1, y1, x2, y2)

	line.strokeWidth = skin.grid_linewidth

	line:setStrokeColor(colors.GetColor(skin.grid_linecolor))
end

-- Cache of simulated touch events --
local Events = {}

-- Common logic for beginning a simulated touch...
local function BeginTouch (back, x, y)
	local event = remove(Events) or { name = "touch", id = "ignore_me" }

	event.target, event.x, event.y = back, x, y
	event.phase = "began"
	event.context = back.parent.m_context

	Touch(event)

	return event
end

-- ...end logic...
local function EndTouch (event)
	event.phase = "ended"

	Touch(event)

	Events[#Events + 1], event.context, event.target = event
end

-- ...and move logic
local function MoveTouch (event, x, y)
	event.x, event.y = x, y
	event.phase = "moved"

	Touch(event)
end

-- --
local DefStencil = stencil.NewStencil{ 0, 0 }

--- Creates a new two-dimensional grid, with background and lines enabled.
--
-- A **"cell"** event is exposed via the **addEventListener** and **removeEventListener**
-- methods, with reference to the grid itself under the **target** key. This event is
-- dispatched when the grid receives a touch or is dragged into a new cell, or manually by
-- calling @{Grid:TouchCell} or @{Grid:TouchXY}. The **x**, **y**, **col**, and **row** keys
-- hold the x- and y-coordinates (cf. @{Grid:SetCentering}) and cell coordinates. The
-- **is\_first** key will be **true** on the initial touch, and **false** while dragging. A
-- **context** key is also present during manually triggered events.
-- @pgroup group Group to which grid will be inserted.
-- @number x Position in _group_.
-- @number y Position in _group_.
-- @number w Width.
-- @number h Height.
-- @uint cols Number of visible / touchable columns...
-- @uint rows ...and rows.
-- @ptable opts[opt] TODO: Skin, etc.
-- @treturn DisplayObject Grid widget. 
-- @see corona_ui.utils.skin.GetSkin
function M.Grid (group, x, y, w, h, cols, rows, opts)
	local skin = skins.GetSkin(opts and opts.skin)

	--
	local Grid = display.newGroup()

	group:insert(Grid)

	-- Begin with a container which will hold the background and canvas.
	w, h = layout_dsl.EvalDims(w, h)

	if opts and opts.round_up then
		w, h = ceil(w / cols) * cols, ceil(h / rows) * rows
	end

	local cgroup = display.newContainer(w, h)

	Grid:insert(cgroup, true)

-- TODO: Does the background get anything out of being contained?
	-- Put a background and canvas into the container and line everything up.
	local canvas = display.newGroup()
	local back = display.newRect(0, 0, w, h)
	local halfw, halfh = floor(w / 2), floor(h / 2)

	cgroup:insert(back, true)
	cgroup:translate(halfw, halfh)
	cgroup:insert(canvas, true)
	canvas:translate(-halfw, -halfh)

	-- Add touch support and assign some properties.
	back:addEventListener("touch", Touch)
	back:setFillColor(colors.GetColor(skin.grid_backcolor))

	back.m_ncols, back.m_cx, back.m_coffset = cols, .5, 0
	back.m_nrows, back.m_cy, back.m_roffset = rows, .5, 0

	-- Handle input trapping in the absence of a background.
	if skin.grid_trapinput then
		back.isHitTestable = true
	end

	-- Add lines above the container.
	local lines, xf, yf = display.newGroup(), w - 1, h - 1

	Grid:insert(lines)
-- TODO: The boundary lines fatten the group up slightly (perhaps if stroke alignment is ever added...)
	-- Add vertical lines...
	local xoff, dw = 0, w / cols

	for _ = 1, cols do
		local cx = floor(xoff)

		AddGridLine(lines, skin, cx, 0, cx, yf)

		xoff = xoff + dw
	end

	AddGridLine(lines, skin, xf, 0, xf, yf)

	-- ...and horizontal ones.
	local yoff, dh = 0, h / rows

	for _ = 1, rows do
		local cy = floor(yoff)

		AddGridLine(lines, skin, 0, cy, xf, cy)

		yoff = yoff + dh
	end

	AddGridLine(lines, skin, 0, yf, xf, yf)

	--- Getter.
	-- @treturn DisplayGroup Canvas group, to be populated and translated by the user.
	function Grid:GetCanvas ()
		return canvas
	end

	--- Getter.
	-- @treturn uint Number of columns...
	-- @treturn uint ...and rows.
	function Grid:GetCellDims ()
		return GetCellDims(back)
	end

	--- Getter.
	-- @treturn uint Column offset.
	-- @see SetColOffset
	function Grid:GetColOffset ()
		return back.m_coffset
	end

	--- Getter.
	-- @treturn uint Row offset.
	-- @see SetRowOffset
	function Grid:GetRowOffset ()
		return back.m_roffset
	end

	--- Assigns cell-relative centering, which determine how **x** and **y** are calculated in a
	-- **"cell"** listener (analagous to Corona's anchor points).
	--
	-- Values are clamped to [0, 1].
	-- @number x Horizontal centering: 0 = left side of cell, 1 = right side...
	-- @number y ...and vertical: 0 = top of cell, 1 = bottom.
	function Grid:SetCentering (x, y)
		back.m_cx = 1 - range.ClampIn(x, 0, 1)
		back.m_cy = 1 - range.ClampIn(y, 0, 1)
	end

	--- Setter.
	--
	-- **N.B.** The offset only affects the grid for touch purposes. The user is responsible
	-- for translating the canvas.
-- TODO: Add some support for this?
	-- @uint[opt=0] coffset Column offset.
	-- @see GetColOffset
	function Grid:SetColOffset (coffset)
		back.m_coffset = coffset or 0
	end

	--- Setter.
	-- @param context Context to assign to grid, or **nil** to clear it.
	-- @see Grid:TouchCell, Grid:TouchXY
	function Grid:SetContext (context)
		self.m_context = context
	end

	--- Setter.
	--
	-- **N.B.** The offset only affects the grid for touch purposes. The user is responsible
	-- for translating the canvas.
	-- @uint[opt=0] roffset Row offset.
	-- @see GetRowOffset
	function Grid:SetRowOffset (roffset)
		back.m_roffset = roffset or 0
	end

	--- DOCME
	-- @tparam ?|array|Stencil|nil arr X
	function Grid:SetStencil (arr)
		back.m_stencil = arr and stencil.NewStencil(arr) or DefStencil
	end

	--- Setter.
	-- @bool show Show a background behind the cells?
	function Grid:ShowBack (show)
		back.isVisible = show
	end

	--- Setter.
	-- @bool show Show lines between the cells?
	function Grid:ShowLines (show)
		lines.isVisible = show
	end

	--- Manually performs a touch (or drag) on the grid.
	--
	-- This will trigger the grid's current touch behavior. Any in-progress touch state is
	-- preserved during this call, e.g. it may be called from a **"cell"** listener.
	--
	-- A **"cell"** listener is dispatched as per normal touch, with the grid as **target**; the
	-- **context** key will also contain whatever was last assigned by @{Grid:SetContext}.
	--
	-- **N.B.** Columns and rows are absolute, i.e. the offsets assigned by @{Grid:SetColOffset}
	-- and @{Grid:SetRowOffset} are not taken into account.
	-- @uint col Initial touch column...
	-- @uint row ...and row.
	-- @uint cto Final column... (If absent, _col_.)
	-- @uint rto ...and row. (Ditto for _row_.)
	function Grid:TouchCell (col, row, cto, rto)
		local scol, srow, x, y = self.m_col, self.m_row, back:localToContent(-.5 * back.width, -.5 * back.height)
		local dc, dr, dw, dh = back.m_coffset + .5, back.m_roffset + .5, GetCellDims(back)
		local event = BeginTouch(back, x + (col - dc) * dw, y + (row - dr) * dh)

		cto, rto = cto or col, rto or row

		if col ~= cto or row ~= rto then
			MoveTouch(event, x + (cto - dc) * dw, y + (rto - dr) * dh)
		end

		EndTouch(event)

		self.m_col, self.m_row = scol, srow
	end

	--- Variant of @{Grid:TouchCell} that uses content x- and y-coordinates.
	--
	-- Since this is meant to simulate a touch, the offsets assigned by @{Grid:SetColOffset} and
	-- @{Grid:SetRowOffset} are respected. Also, _xto_ and _yto_ are clamped to the grid.
	-- @number x Initial touch x-coordinate.
	-- @number y ...and y-coordinate.
	-- @number[opt=x] xto Final x...
	-- @number[opt=y] yto ...and y.
	function Grid:TouchXY (x, y, xto, yto)
		local scol, srow = self.m_col, self.m_row
		local event = BeginTouch(back, x, y)

		xto, yto = xto or x, yto or y

		if x ~= xto or y ~= yto then
			MoveTouch(event, xto, yto)
		end

		EndTouch(event)

		self.m_col, self.m_row = scol, srow
	end

	-- Apply a default stencil and move the grid into position.
	Grid:SetStencil(nil)

	layout_dsl.PutObjectAt(Grid, x, y)

	-- Provide the grid.
	return Grid
end

-- Main grid skin --
skins.AddToDefaultSkin("grid", {
	backcolor = { .375, .75 },
	linecolor = "white",
	linewidth = 2,
	trapinput = true
})

-- Export the module.
return M