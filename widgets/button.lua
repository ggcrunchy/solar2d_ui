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
local type = type

-- Modules --
local colors = require("solar2d_ui.utils.color")
local layout = require("solar2d_ui.utils.layout")
local layout_dsl = require("solar2d_ui.utils.layout_dsl")
local meta = require("tektite_core.table.meta")
local skins = require("solar2d_ui.utils.skin")
local touch = require("solar2d_ui.utils.touch")

-- Corona globals --
local display = display
local timer = timer

-- Imports --
local GetColor = colors.GetColor

-- Cached module references --
local _Button_XY_

-- Exports --
local M = {}

--
--
--

local function ClearTimer (button)
	local update = button.m_update

	if update then
		timer.cancel(update)

		button.m_update = nil
	end
end

local function DoTimeouts (button)
	button.m_update = timer.performWithDelay(button.m_timeout, function()
		if display.isValid(button) and touch.IsTouched(button) then
			if button.m_inside then
				button.m_func(button.parent)

				button.m_doing_timeouts = true
			end
		else
			ClearTimer(button)
		end
	end, 0)
end

--
local function Draw (button, mode)
	local skin = button.m_skin
	local choice = skin[mode]

	if skin.button_type == "image" or skin.button_type == "rounded_rect" then
		button:setFillColor(GetColor(choice))
	elseif skin.button_type == "sprite" then
		button:setFrame(choice)
	end
end

-- Touch listener
local OnTouch = touch.TouchHelperFunc(function(_, button)
	button.m_doing_timeouts, button.m_inside = false, true

	if button.m_timeout then
		DoTimeouts(button)
	end

	Draw(button, "button_held")
end, function(event, button)
	button.m_inside = touch.Inside(event, button)

	Draw(button, button.m_inside and "button_held" or "button_touch")
end, function(event, button)
	ClearTimer(button)

	if not button.m_doing_timeouts and event.phase == "ended" and button.m_inside then
		button.m_func(button.parent)
	end

	button.m_inside = false

	Draw(button, "button_normal")
end)

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
	local which = h < 20 and "button_short_corner" or "button_corner"
	local button = display.newRoundedRect(bgroup, 0, 0, w, h, layout.ResolveX(skin[which]))

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
-- @see solar2d_ui.utils.skin.GetSkin

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

-- --
local Button = {}

--- Getter.
-- @treturn string Button text.
function Button:GetText ()
	return self.m_string.text
end

--- Setter.
-- @string text
function Button:SetText (text)
	self.m_string.text = text
end

--- Setter.
-- @function Button:SetTimeout
-- @tparam ?|number|nil timeout A value &gt; 0. When the button is held, its function is
-- called each time an auxiliary timer fires. If absent, any such timeout is removed.
function Button:SetTimeout (timeout)
	local button = self.m_button

	if not timeout then
		ClearTimer(button)
	end

	button.m_timeout = timeout or nil
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
	local bgroup = display.newGroup()

	bgroup.anchorChildren = true

	-- Add the button and (partially centered) text, in that order, to the group.
	w, h = layout_dsl.EvalDims(w, h)

	local button = Factories[skin.button_type](bgroup, skin, w, h)
	local str_cont = display.newContainer(w, h)

	bgroup:insert(str_cont)

	local string = display.newText(str_cont, text or "", 0, 0, skin.button_font, layout.ResolveY(skin.button_textsize))

	string:setFillColor(GetColor(skin.button_textcolor))

	-- Apply any properties to the button.
	button.rotation = skin.button_angle or 0
	button.xScale = skin.button_xscale or 1
	button.yScale = skin.button_yscale or 1

	-- Add the group to the parent at the requested position, with any formatting.
	layout_dsl.PutObjectAt(bgroup, x, y)

	group:insert(bgroup)

	-- Install common button logic.
	button:addEventListener("touch", OnTouch)
	button:addEventListener("finalize", Cleanup)

	-- Assign custom button state.
	button.m_func = func
	button.m_skin = skin

	--
	bgroup.m_button, bgroup.m_string = button, string

	meta.Augment(bgroup, Button)

	-- Assign any timeout.
	bgroup:SetTimeout(skin.button_timeout)

	-- Provide the button.
	return bgroup
end

-- Main button skin --
skins.AddToDefaultSkin("button", {
	borderwidth = 2,
	bordercolor = "red",
	normal = "blue",
	held = "red",
	touch = "green",
	corner = "1.5%",
	short_corner = ".75%",
	font = "PeacerfulDay",
	textcolor = "white",
	textsize = "6.875%",
	type = "rounded_rect"
})

skins.RegisterSkin("small_text_button", {
	textsize = "3%",
	_prefix_ = "button"
})

_Button_XY_ = M.Button_XY

return M