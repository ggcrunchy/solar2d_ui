--- Checkbox UI elements.
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

-- Modules --
local colors = require("corona_ui.utils.color")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local meta = require("tektite_core.table.meta")
local skins = require("corona_ui.utils.skin")
local var_preds = require("tektite_core.var.predicates")

-- Corona globals --
local display = display

-- Cached module references --
local _Checkbox_XY_

-- Exports --
local M = {}

-- Sets the check state and performs any follow-up action
local function Check (box, mark, check)
	mark.isVisible = check

	if box.m_func then
		box:m_func(check)
	end
end

-- Checked -> unchecked, or vice versa
local function Toggle (box)
	local mark = box[2]

	Check(box, mark, not mark.isVisible)
end

-- Checkbox touch listener
local function CheckTouch (event)
	if event.phase == "ended" then
		Toggle(event.target.parent)
	end

	return true
end

-- --
local Checkbox = {}

--- Sets the checkbox state to checked or unchecked.
--
-- The follow-up logic is performed even if the check state does not change.
-- @bool check If true, check; otherwise, uncheck.
function Checkbox:Check (check)
	Check(self, self.m_image, not not check)
end

--- Predicate.
-- @treturn boolean The checkbox is checked?
function Checkbox:IsChecked ()
	return self.m_image.isVisible
end

--- Toggles the checkbox state, checked &rarr; unchecked (or vice versa).
function Checkbox:ToggleCheck ()
	Toggle(self)
end

--- DOCME
function M.Checkbox (group, w, h, opts)
	return _Checkbox_XY_(group, 0, 0, w, h, opts)
end

-- Creates a new checkbox.
-- @pgroup group Group to which the checkbox will be inserted.
-- @param[opt] skin Name of checkbox's skin.
-- @number x Position in _group_.
-- @number y Position in _group_.
-- @number w Width.
-- @number h Height.
-- @callable[opt] func If present, called as `func(is_checked)`, after a check or uncheck.
-- @treturn DisplayGroup Child #1: the box; Child #2: the check mark.
-- @see corona_ui.utils.skin.GetSkin
function M.Checkbox_XY (group, x, y, w, h, opts)
	--
	local skin, func

	if var_preds.IsCallable(opts) then
		func = opts
	elseif opts then
		func = opts.func
		skin = opts.skin
	end

	skin = skins.GetSkin(skin)

	-- Build a new group. Add follow-up logic, if available.
	local checkbox = display.newGroup()

	checkbox.anchorChildren = true

	checkbox.m_func = func

	-- Add the box itself.
	w, h = layout_dsl.EvalDims(w, h)

	local rect = display.newRoundedRect(checkbox, 0, 0, w, h, layout.ResolveX(skin.checkbox_radius))

	rect:addEventListener("touch", CheckTouch)
	rect:setFillColor(colors.GetColor(skin.checkbox_backcolor))
	rect:setStrokeColor(colors.GetColor(skin.checkbox_bordercolor))

	rect.strokeWidth = skin.checkbox_borderwidth

	-- Add the check image.
	checkbox.m_image = display.newImageRect(checkbox, skin.checkbox_image, w, h)

	checkbox.m_image.isVisible = false

	-- Add the group to the parent at the requested position, with any formatting.
	layout_dsl.PutObjectAt(checkbox, x, y)

	group:insert(checkbox)

	-- Provide the checkbox.
	meta.Augment(checkbox, Checkbox)

	return checkbox
end

-- Main checkbox skin --
skins.AddToDefaultSkin("checkbox", {
	backcolor = "white",
	bordercolor = { .5, 0, .5 },
	borderwidth = 4,
	image = "corona_ui/assets/Check.png",
	radius = "1.5%"
})

-- Cache module members.
_Checkbox_XY_ = M.Checkbox_XY

-- Export the module.
return M