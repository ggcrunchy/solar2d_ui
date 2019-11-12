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
local component = require("tektite_core.component")
local NE = require("s3_editor.NodeEnvironment")
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
    local env = NE.New{
        interpretation_lists = {
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
    npc:AddExportNode("did", "event")
    npc:AddImportNode("fire", "event")

    -- TODO: wildcards, restricted

    local rules, value = {}, NE.ValueComponent()

    for k, v in npc:IterNodes() do
        rules[k] = v

        local which, what = env:GetRuleInfo(v)

        print("INTERFACES FOR RULE: " .. k .. "(" .. which .. " " .. what .. ")")
        print("")

        for i, ifx in ipairs(component.GetInterfacesForObject(v)) do
            local str = ifx == value and "value" or tostring(ifx)

            if i == 1 then
                print("  PRIMARY: " .. str)
            else
                print("  SECONDARY: " .. str)
            end
        end

        print("")
    end

    print("")

    print("x -> x", rules.x{ target = rules.x })
    print("x -> y", rules.x{ target = rules.y })
    print("x -> z", rules.x{ target = rules.z })
    print("x -> w", rules.x{ target = rules.w })
    print("x -> did", rules.x{ target = rules.did })
    print("x -> fire", rules.x{ target = rules.fire })

    print("")

    print("y -> x", rules.y{ target = rules.x })
    print("y -> y", rules.y{ target = rules.y })
    print("y -> z", rules.y{ target = rules.z })
    print("y -> w", rules.y{ target = rules.w })
    print("y -> did", rules.y{ target = rules.did })
    print("y -> fire", rules.y{ target = rules.fire })

    print("")

    print("z -> x", rules.z{ target = rules.x })
    print("z -> y", rules.z{ target = rules.y })
    print("z -> z", rules.z{ target = rules.z })
    print("z -> w", rules.z{ target = rules.w })
    print("z -> did", rules.z{ target = rules.did })
    print("z -> fire", rules.z{ target = rules.fire })

    print("")

    print("w -> x", rules.w{ target = rules.x })
    print("w -> y", rules.w{ target = rules.y })
    print("w -> z", rules.w{ target = rules.z })
    print("w -> w", rules.w{ target = rules.w })
    print("w -> did", rules.w{ target = rules.did })
    print("w -> fire", rules.w{ target = rules.fire })

    print("")

    print("did -> x", rules.did{ target = rules.x })
    print("did -> y", rules.did{ target = rules.y })
    print("did -> z", rules.did{ target = rules.z })
    print("did -> w", rules.did{ target = rules.w })
    print("did -> did", rules.did{ target = rules.did })
    print("did -> fire", rules.did{ target = rules.fire })

    print("")

    print("fire -> x", rules.fire{ target = rules.x })
    print("fire -> y", rules.fire{ target = rules.y })
    print("fire -> z", rules.fire{ target = rules.z })
    print("fire -> w", rules.fire{ target = rules.w })
    print("fire -> did", rules.fire{ target = rules.did })
    print("fire -> fire", rules.fire{ target = rules.fire })

    print("")
end