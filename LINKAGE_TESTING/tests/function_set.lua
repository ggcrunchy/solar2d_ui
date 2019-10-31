--- Function set unit test.

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
local FS = require("s3_editor.FunctionSet")

--
--
--

do
	local fs = FS.New("F1", {
		a = function(o)
			print("a! " .. tostring(o))
		end,

		b = function(o)
			print("b! " .. tostring(o))
		end
	})

	print("RAW")

	fs.a("aa")
	fs.b(3456)

	print("")

	fs.__index = fs

	local o1, o2 = setmetatable({}, fs), setmetatable({}, fs)

	print("METHOD")

	o1:a()
	o2:a()
	o1:b()
	o2:b()

	print("")
end

do
	local fs = FS.New("F2", {
		c = function()
			print("c! " .. FS.GetState("F2").info)
		end
	}, {
		state = function(name)
			print("GET STATE", name)

			return { info = 5 }
		end
	})

	print("RAW WITH STATE")

	fs.c()

	print("")
end

do
	local fs = FS.New("F3", {}, {
		init = function(_, def)
			print("INIT")

			function def.d ()
				print("d!")
			end
		end
	})

	print("RAW WITH INIT")

	fs.d()

	print("")
end

do
	FS.New("F4", {
		e = function()
			print("e!")
		end
	})
	
	local fs = FS.New("F5", {
		e = function()
			print("e2!")
		end
	}, { prototype = "F4" })

	print("RAW WITH INHERITANCE (AFTER)")

	fs.e()

	print("")
end

do
	local fs = FS.New("F6", {}, {
		prototype = "F4",

		before = {
			e = function()
				print("e0!")
			end
		}
	})

	print("RAW WITH INHERITANCE (BEFORE)")

	fs.e()

	print("")
end

do
	local fs = FS.New("F7", {
		e = function()
			print("e again!")
		end
	}, { prototype = "F6" })

	print("RAW WITH INHERITED SEQUENCE (AFTER)")

	fs.e()

	print("")
end

do
	FS.New("F8", {
		e = function()
			print("e, suppressed!")
		end,

		f = function()
			print("f!")
		end
	})

	local fs = FS.New("F9", {
		f = function()
			print("f again!")
		end
	}, {
		prototype = "F8",

		instead = {
			e = function()
				print("e for real")
			end
		}
	})
		

	print("RAW WITH INHERITED SEQUENCE AND REPLACEMENT (AFTER)")

	fs.e()
	fs.f()

	print("")
end