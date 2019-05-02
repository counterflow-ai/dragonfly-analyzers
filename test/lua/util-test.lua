-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- Author: Collins Huff <ch@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

require 'analyzer/utils'


local test_table = {hello = {world = ''},
                    test = 'value',
                    foo = {bar = {baz = 'value'}} 
                   }

-- fields present
function test_field_present()
    assert(check_field(test_table, 'test'))
end

function test_field_present_nested()
    assert(check_field(test_table, 'hello.world'))
end

function test_field_not_present()
    assert(check_field(test_table, 'quux') == false)
end

function test_field_not_present_nested()
    assert(check_field(test_table, 'foo.bar.baz.quux') == false)
end

-- fields equal specific value
function test_field_equals()
    assert(check_field(test_table, 'test', 'value'))
end

function test_field_equals_nested()
    assert(check_field(test_table, 'hello.world', ''))
end

function test_field_not_equals_not_present()
    assert(check_field(test_table, 'quux', 'v') == false)
end

function test_field_not_equals_present()
    assert(check_field(test_table, 'hello.world', 'v') == false)
end

function test_field_equals_not_present_nested()
    assert(check_field(test_table, 'foo.bar.baz.quux', 'v') == false)
end

-- field equals one of multiple options
function test_field_equals_multiple()
    assert(check_field(test_table, 'test', {'eulav','value'}))
end

function test_field_not_equals_multiple()
    assert(check_field(test_table, 'test', {'eulav','laveu','valuess'}) == false)
end

function test_field_equals_multiple_nested()
    assert(check_field(test_table, 'hello.world', {'','value'}))
end

function test_field_not_equals_multiple_nested()
    assert(check_field(test_table, 'hello.world', {'v1','v2',v3}) == false)
end

function test_field_equals_multiple_not_present()
    assert(check_field(test_table, 'quux', {'v1','v2','v3'}) == false)
end

-- test multiple fields
function test_fields_true()
    test_fields = {'hello.world',
                   ['test'] = 'value',
                   ['foo.bar.baz'] = {'valuess', 'eulav', 'value'},}
    assert(check_fields(test_table, test_fields))
end

function test_fields_false_not_present()
    test_fields = {'hello.world',
                   ['test'] = 'value',
                   ['foo.bar.baz'] = 'value',
                   ['quux'] = 'value',}
    assert(check_fields(test_table, test_fields) == false)
end

function test_fields_false_not_equals()
    test_fields = {'hello.world',
                   ['test'] = 'eulav',
                   ['foo.bar.baz'] = 'value',}
    assert(check_fields(test_table, test_fields) == false)
end

function test_fields_false_not_equals_multiple()
    test_fields = {'hello.world',
                   ['test'] = 'value',
                   ['foo.bar.baz'] = {'eulav','lavue','valuee'}}
    assert(check_fields(test_table, test_fields) == false)
end


test_field_present()
test_field_not_present()
test_field_not_present_nested()

test_field_equals()
test_field_equals_nested()
test_field_not_equals_not_present()
test_field_not_equals_present()
test_field_equals_not_present_nested()

test_field_equals_multiple()
test_field_not_equals_multiple()
test_field_equals_multiple_nested()
test_field_not_equals_multiple_nested()
test_field_equals_multiple_not_present()

test_fields_false_not_present()
test_fields_false_not_equals()
test_fields_false_not_equals_multiple()
test_fields_true()

print("PASS")
