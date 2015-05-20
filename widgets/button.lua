--- Button UI elements.
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
local floor = math.floor
local type = type

-- Modules --
local colors = require("corona_ui.utils.color")
local geom2d_preds = require("tektite_core.geom2d.predicates")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local skins = require("corona_ui.utils.skin")

-- Corona globals --
local display = display
local system = system
local timer = timer

-- Imports --
local GetColor = colors.GetColor

-- Cached module references --
local _Button_XY_

-- Exports --
local M = {}

-- Cleans up a button's timer, if present
local function ClearTimer (button)
	local update = button.m_update

	if update then
		timer.cancel(update)

		button.m_update = nil
	end
end

-- Do timeouts when a button is touched
local function DoTimeouts (button)
	button.m_since = system.getTimer()
	button.m_update = timer.performWithDelay(20, function(event)
		if button.parent and button.m_is_touched then
			if button.m_inside then
				local since, timeout = button.m_since, button.m_timeout

				-- Do the button logic as many times as the timer elapsed. Use this opportunity to flag
				-- that the button is now doing timeouts.
				local nlapses = floor((event.time - since) / timeout)

				for _ = 1, nlapses do
					button.m_doing_timeouts = true

					button:m_func()
				end

				button.m_since = since + nlapses * timeout

			-- Reset the timer if the touch strays outside the button.
			else
				button.m_since = event.time
			end

		-- Stop timeouts once the button is released.
		else
			ClearTimer(button)
		end
	end, 0)
end

-- Helper to set stage focus
local function SetFocus (target)
	display.getCurrentStage():setFocus(target)
end

-- Touch listener
local function OnTouch (event)
	local button = event.target
	local skin = button.m_skin
	local mode = "button_held"

	-- On(began): make the button the main focus and set some flags
	if event.phase == "began" then
		SetFocus(button)

		button.m_doing_timeouts = false
		button.m_inside = true
		button.m_is_touched = true

		-- If a timer is available, reset it and start watching for timeouts.
		if button.m_timeout then
			DoTimeouts(button)
		end

	-- Guard against moves onto the button during touches.
	elseif not button.m_is_touched then
		return true
	else
		-- Check whether the touch is inside the button.
		local bx, by = button:localToContent(0, 0)

		button.m_inside = geom2d_preds.PointInBox(event.x, event.y, bx - button.width / 2, by - button.height / 2, button.contentWidth, button.contentHeight)

		-- On(ended) / On(cancelled): release focus and restore appearance
		-- If the button was doing timeouts, do nothing. Otherwise, if it was dropped
		-- while the touch is inside, do the button logic.
		if event.phase == "ended" or event.phase == "cancelled" then
			ClearTimer(button)
			SetFocus(nil)

			if not button.m_doing_timeouts and event.phase == "ended" and button.m_inside then
				button.m_func(button.parent)
			end

			button.m_is_touched = false

			mode = "button_normal"

		-- Otherwise, if the touch strayed outside, make the appearance reflect that.
		elseif not button.m_inside then
			mode = "button_touch"
		end
	end

	-- Set the button's appearance in a type-appropriate manner.
	local choice = skin[mode]

	if skin.button_type == "image" or skin.button_type == "rounded_rect" then
		button:setFillColor(GetColor(choice))
	elseif skin.button_type == "sprite" then
		button:setFrame(choice)
	end

	return true
end

-- Factory functions for button types --
local Factories = {}

-- Image button
function Factories.image (bgroup, skin)
	local button = display.newImage(bgroup, skin.button_image)

	button:setFillColor(GetColor(skin.button_normal))

	return button
end

-- Rounded rect button
function Factories.rounded_rect (bgroup, skin, w, h)
	local button = display.newRoundedRect(bgroup, 0, 0, w, h, layout.ResolveX(skin.button_corner))

	button.strokeWidth = skin.button_borderwidth

	button:setFillColor(GetColor(skin.button_normal))
	button:setStrokeColor(GetColor(skin.button_bordercolor))

	return button
end

-- Sprite button
function Factories.sprite (bgroup, skin)
	local button = display.newSprite(skin.button_sprite) -- TODO: This still doesn't match up with the API

	bgroup:insert(button)

	return button
end

-- Cleans up button resources
local function Cleanup (event)
	ClearTimer(event.target)
end

-- REINTEGRATE:
-- @param[opt] skin Name of button's skin.
-- @string[opt=""] text Button text.
-- @see corona_ui.utils.skin.GetSkin

--- DOCME
-- @pgroup group Group to which button will be inserted.
-- @tparam number|dsl_dimension w Width. (Ignored for some types.)
-- @tparam number|dsl_dimension h Height. (Ignored for some types.)
-- @callable func Logic for this button, called on drop or timeout.
-- @tparam string|table|nil[opt=""] opts
-- @treturn DisplayGroup Child #1: the button; Child #2: the text.
function M.Button (group, w, h, func, opts)
	return _Button_XY_(group, 0, 0, w, h, func, opts)
end

--- Creates a new button.
-- @pgroup group Group to which button will be inserted.
-- @tparam number|dsl_coordinate x Position in _group_.
-- @tparam number|dsl_coordinate y Position in _group_.
-- @tparam number|dsl_dimension w Width. (Ignored for some types.)
-- @tparam number|dsl_dimension h Height. (Ignored for some types.)
-- @callable func Logic for this button, called on drop or timeout.
-- @tparam string|table|nil[opt=""] opts
-- @treturn DisplayGroup Child #1: the button; Child #2: the text.
function M.Button_XY (group, x, y, w, h, func, opts)
	--
	local skin, text

	if type(opts) == "string" then
		text = opts
	elseif opts then
		skin = opts.skin
		text = opts.text
	end

	skin = skins.GetSkin(skin)

	-- Build a new group. The button and string will be relative to this group.
	local Button = display.newGroup()

	Button.anchorChildren = true

	-- Add the button and (partially centered) text, in that order, to the group.
	w, h = layout_dsl.EvalDims(w, h)

	local button = Factories[skin.button_type](Button, skin, w, h)
	local str_cont = display.newContainer(w, h)

	Button:insert(str_cont)

	local string = display.newText(str_cont, text or "", 0, 0, skin.button_font, layout.ResolveY(skin.button_textsize))

	string:setFillColor(GetColor(skin.button_textcolor))

	-- Apply any properties to the button.
	button.rotation = skin.button_angle or 0
	button.xScale = skin.button_xscale or 1
	button.yScale = skin.button_yscale or 1

	-- Add the group to the parent at the requested position, with any formatting.
	layout_dsl.PutObjectAt(Button, x, y)

	group:insert(Button)

	-- Install common button logic.
	button:addEventListener("touch", OnTouch)
	button:addEventListener("finalize", Cleanup)

	-- Assign custom button state.
	button.m_func = func
	button.m_skin = skin

	--- Getter.
	-- @treturn string Button text.
	function Button:GetText ()
		return string.text
	end

	--- Setter.
	-- @string text
	function Button:SetText (text)
		string.text = text
	end

	--- Setter.
	-- @function Button:SetTimeout
	-- @tparam ?|number|nil timeout A value &gt; 0. When the button is held, its function is
	-- called each time this duration passes. If absent, any such timeout is removed.
	function Button:SetTimeout (timeout)
		if timeout then
			button.m_since, button.m_timeout = system.getTimer(), timeout
		else
			ClearTimer(button)

			button.m_timeout = nil
		end
	end

	-- Assign any timeout.
	Button:SetTimeout(skin.button_timeout)

	-- Provide the button.
	return Button
end

-- Main button skin --
skins.AddToDefaultSkin("button", {
	borderwidth = 2,
	bordercolor = "red",
	normal = "blue",
	held = "red",
	touch = "green",
	corner = "1.5%",
	font = "PeacerfulDay",
	textcolor = "white",
	textsize = "6.875%",
	type = "rounded_rect"
})

-- Add some button-specific skins.
skins.RegisterSkin("rscroll", {
	normal = { 0, .5, 1 },
	held = { 1, .25, 0 },
	touch = { 0, 1, .5 },
	image = "corona_ui/assets/Arrow.png",
	type = "image",
	timeout = 150,
	_prefix_ = "button"
})

skins.RegisterSkin("lscroll", {
	xscale = -1,
	_prefix_ = "PARENT"
}, "rscroll")

-- Cache module members.
_Button_XY_ = M.Button_XY

-- Export the module.
return M