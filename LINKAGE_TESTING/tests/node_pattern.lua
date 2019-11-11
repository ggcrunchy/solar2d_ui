--- Node pattern unit test.

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
local NP = require("s3_editor.NodePattern")

--
--
--

local np = NP.New()

np:AddExportNode("result", "int")
np:AddImportNode("x", "float")
np:AddImportNode("origin*", "pos")

print(np:Generate("origin*"))
print(np:Generate("origin*"))
print(np:Generate("origin*"))

local another = np:Generate("origin*")

print(another, np:GetTemplate(another))
print("nn|2|", np:GetTemplate("nn*"))
print("x", np:GetTemplate("x"))

print(np:HasNode("result"))
print(np:HasNode("x", "imports"))
print(np:HasNode("origin*", "imports"))
print(np:HasNode("result", "imports"))
print(np:HasNode("duck", "other"))
print(np:HasNode("cluck", "exports"))

local function Iter (patt)
    for k, v in patt:IterNodes() do
        print("GENERAL NODE", k, v)
    end

    for k, v in patt:IterNodes("exports") do
        print("EXPORT NODE", k, v)
    end

    for k, v in patt:IterNodes("imports") do
        print("IMPORT NODE", k, v)
    end

    for k, v in patt:IterTemplateNodes() do
        print("GENERAL TEMPLATE NODE", k, v)
    end

    for k, v in patt:IterNonTemplateNodes() do
        print("GENERAL NON-TEMPLATE NODE", k, v)
    end
end

print("")
print("MIXED PATTERN")

Iter(np)

print("")

local env = np:GetEnvironment()

for k, v in np:IterNodes() do
    print("FIND RULE " .. k .. ":", env:GetRuleInfo(v))
end

print("")

do
    local npe = NP.New()

    npe:AddExportNode("only_export", "int")

    print("EXPORT-ONLY PATTERN")

    Iter(npe)

    print("")
end

do
    local npi = NP.New()

    npi:AddImportNode("only_import", "int")

    print("IMPORT-ONLY PATTERN")

    Iter(npi)

    print("")
end

do
    local np0 = NP.New()

    print("EMPTY PATTERN")

    Iter(np0)

    print("")
end

do
    local env = require("s3_editor.NodeEnvironment").New{
        interface_lists = {
            exports = {
                uint = { "uint", "int" }
            },
            imports = {
                int = { "int", "uint" }
            }
        }
    }
    local npc = NP.New(env) 

    npc:AddImportNode("x", "int")
    npc:AddImportNode("y", "uint")
    npc:AddExportNode("z", "int")
    npc:AddExportNode("w", "uint")

    local rules = {}

    for k, v in npc:IterNodes() do
        rules[k] = v
    end

    print("")

    print("x -> x", rules.x{ target = rules.x })
    print("x -> y", rules.x{ target = rules.y })
    print("x -> z", rules.x{ target = rules.z })
    print("x -> w", rules.x{ target = rules.w })

    print("")

    print("y -> x", rules.y{ target = rules.x })
    print("y -> y", rules.y{ target = rules.y })
    print("y -> z", rules.y{ target = rules.z })
    print("y -> w", rules.y{ target = rules.w })

    print("")

    print("z -> x", rules.z{ target = rules.x })
    print("z -> y", rules.z{ target = rules.y })
    print("z -> z", rules.z{ target = rules.z })
    print("z -> w", rules.z{ target = rules.w })

    print("")

    print("w -> x", rules.w{ target = rules.x })
    print("w -> y", rules.w{ target = rules.y })
    print("w -> z", rules.w{ target = rules.z })
    print("w -> w", rules.w{ target = rules.w })

    print("")
end