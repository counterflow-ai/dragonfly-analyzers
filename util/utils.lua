-- ----------------------------------------------
-- Copyright 2018, CounterFlow AI, Inc. 
-- 
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following 
-- conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
--    in the documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products 
--    derived from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
-- BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
-- SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
-- OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- author: Collins Huff <ch@counterflowai.com>
-- ----------------------------------------------

-- ----------------------------------------------
-- Common Utility Functions
-- ----------------------------------------------
--

-- https://gist.github.com/ripter/4270799
-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            tprint(v, indent+1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))		
        else
            print(formatting .. v)
        end
    end
end

function check_fields(eve, field_values)
    local result = false
    for k,v in pairs(field_values) do
        if type(k) == 'number' then
            result = check_field(eve, v)
            if not result then return false end
        else
            result = check_field(eve, k, v)
            if not result then return false end
        end
    end
    return true
end

function check_field(eve, field, value) 
    local cur_table = eve
    for f in string.gmatch(field, "[^%.]+") do
        if f ~= nil and f ~= '' then
            cur_table = cur_table[f]
        end
        if not cur_table then return false end
    end

    local value_in_table = cur_table

    if not value then 
        return true 
    elseif type(value) == 'table' then
        local found = false
        for _,possible_value in ipairs(value) do
            if value_in_table == possible_value then
                found = true
                break
            end
        end
        return found
    else
        return (value == value_in_table)
    end
end
