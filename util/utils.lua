-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- author: Collins Huff <ch@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
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
