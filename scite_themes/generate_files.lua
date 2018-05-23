#! /usr/bin/env luajit

-- creates scheme_list.lua and merged.properties
local cmd =
[[find schemes/ -type f -printf '%P\n' -name '*.json' -o -name '*.yaml'|sort]]
local gen_scheme_list_lua = function()
	local f = io.open('scheme_list.lua', 'w')
	f:write('-- This is an auto-generated file\n')
	f:write('return {\n')
    local pfile = io.popen(cmd)
    for filename in pfile:lines() do
        f:write("\t'" .. filename .. "',\n")
    end
    pfile:close()
	f:write('}\n')
    f:close()
end

local gen_merged_properties = function()
	local sep = string.rep('#####', 10) .. '\n'
	local append_file = function(f, unit, title)
		if not title then title = unit end
		f:write(sep)
		f:write('# [' .. title .. ']\n')
		f:write(sep)
		f:write('\n')
		for line in io.lines(unit) do
			f:write(line)
			f:write('\n')
		end
		f:write('\n\n')
		--f:write(sep)
	end
	
	local merged = io.open('merged.properties','w')
	local list = dofile('prop_list.lua')
	for i, v in ipairs(list) do
		append_file(merged, 'props/' .. v, v)
	end
	merged:close()
end

gen_scheme_list_lua()
gen_merged_properties()