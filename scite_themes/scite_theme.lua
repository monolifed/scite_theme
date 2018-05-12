local _sf = string.format

local valid_yaml = {
	scheme = '"([^"]-)"', -- Title
	author = '"([^"]-)"', -- Author
	base00 = '(%x%x%x%x%x%x)', -- Default Background
	base01 = '(%x%x%x%x%x%x)', -- Lighter Background (Used for status bars)
	base02 = '(%x%x%x%x%x%x)', -- Selection Background
	base03 = '(%x%x%x%x%x%x)', -- Comments, Invisibles, Line Highlighting
	base04 = '(%x%x%x%x%x%x)', -- Dark Foreground (Used for status bars)
	base05 = '(%x%x%x%x%x%x)', -- Default Foreground, Caret, Delimiters, Operators
	base06 = '(%x%x%x%x%x%x)', -- Light Foreground (Not often used)
	base07 = '(%x%x%x%x%x%x)', -- Light Background (Not often used)
	base08 = '(%x%x%x%x%x%x)', -- Variables, XML Tags, Markup Link Text, Markup Lists, Diff Delete
	base09 = '(%x%x%x%x%x%x)', -- Integers, Boolean, Constants, XML Attributes, Markup Link Url
	base0A = '(%x%x%x%x%x%x)', -- Classes, Markup Bold, Search Text Background
	base0B = '(%x%x%x%x%x%x)', -- Strings, Inherited Class, Markup Code, Diff Inserted
	base0C = '(%x%x%x%x%x%x)', -- Support, Regular Expressions, Escape Characters, Markup Quotes
	base0D = '(%x%x%x%x%x%x)', -- Functions, Methods, Attribute IDs, Headings
	base0E = '(%x%x%x%x%x%x)', -- Keywords, Storage, Selector, Markup Italic, Diff Changed
	base0F = '(%x%x%x%x%x%x)', -- Deprecated, Opening/Closing Embedded Language Tags e.g. <?php ?>
}

-- generate base0[0-F]-(hex|(hex|rgb|dec)-(r|g|b)) o_O
local add_color_vars = function(t, name, colorstr)
	local r, g, b = string.match(colorstr, '#?(%x%x)(%x%x)(%x%x)')
	t[name..'-hex'] = colorstr
	t[name..'-hex-r'], t[name..'-hex-g'], t[name..'-hex-b'] = r, g, b
	r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	t[name..'-rgb-r'], t[name..'-rgb-g'], t[name..'-rgb-b'] = r, g, b
	t[name..'-dec-r'], t[name..'-dec-g'], t[name..'-dec-b'] = r / 255, g / 255, b / 255

	--[=[
	-- calculate disabled color
	local L = 0.2989 * r + 0.5870 * g + 0.1140 * b
	local m = 0.4
	r = r + m * (L - r)
	g = g + m * (L - g)
	b = b + m * (L - b)
	t[name..'-des-hex'] = _sf('%02x%02x%02x', r, g, b)
	--]=]
end

local load_scheme = function(dir, name)
	local path = _sf('%s/%s.yaml', dir, name)
	print(_sf('* Loading file %s', path))
	
	local key, value
	local vars = {}
	for line in io.lines(path) do
		key, value = string.match(line, '^([%w]+)%s*:%s*"([^"]-)"')
		if key and valid_yaml[key] then
			vars[key] = value;
		end
	end
	vars['scheme-name']   = vars['scheme']
	vars['scheme-author'] = vars['author']
	vars['scheme-slug']   = _sf('base16-%s.properties', name)
	for i = 0, 15 do
		key = _sf('base0%X', i)
		value = vars[key]
		add_color_vars(vars, key, value)
		--print(string.format('base0%X', i))
	end
	--print(scheme['base01-hex'])
	print(_sf('* Scheme Name:   %s\n* Scheme Author: %s', vars['scheme-name'], vars['scheme-author']))
	return vars
end

local apply_scheme = function(dir, name)
	local vars = load_scheme(dir..'/schemes', name)
	local path = _sf('%s/merged.properties', dir)
	local filler
	local key, value
	local line_no = 0
	for line in io.lines(path) do
		line_no = line_no + 1
		filler = (line:match('%S') == nil) or (line:match('^%s*#') ~= nil)
		if not filler then
			key, value = string.match(line, '^([%w_.%-*]+)%s*=%s*([%w%p]*)')
			if key then
				props[key] = value:gsub('{{([%w%-]+)}}', vars)
			else
				print(_sf('ignoring line %i: %s', line_no, line))
			end
		end
	end
end

-- Change to the fixed theme defined in user properties file
function change_theme()
	local dir = props['ext.lua.theme_dir']
	local name = props['ext.lua.theme']:lower():gsub(' ','-')
	props['ext.lua.theme_now'] = name
	--print(theme_name)
	apply_scheme(dir, name)
	print('* [Done]')
end

-- Change to the next theme (resets to the fixed one after restart)
function cycle_theme(step)
	local dir = props['ext.lua.theme_dir']
	local name = props['ext.lua.theme_now']
	local list = dofile(dir..'/scheme_list.lua')
	local list_len = #list
	local list_cur = 0
	for i, v in ipairs(list) do
		if v == name then
			list_cur = i
			break
		end
	end
	if list_cur == 0 then
		return
	end
	list_cur = 1 + ((list_cur + step - 1) % list_len)
	name = list[list_cur]
	props['ext.lua.theme_now'] = name
	apply_scheme(dir, name)
	print(_sf("* [Done %i/%i %s]", list_cur, list_len, name))
end

function next_theme()
	cycle_theme(1)
end

function prev_theme()
	cycle_theme(-1)
end

-- Used from the command line as:
-- lua scite_theme.lua genprop
local merge_props = function()
	local sep = string.rep('#####', 10) .. '\n'
	local append_file = function(f, unit, title)
		if not title then title = unit end
		f:write(sep)
		f:write(_sf('# [%s]\n', title))
		f:write(sep)
		f:write('\n')
		for line in io.lines(unit) do
			f:write(line)
			f:write('\n')
		end
		f:write('\n\n')
		--f:write(sep)
	end
	
	local path = 'merged.properties'
	local merged = io.open(path,'w')
	local list = dofile('prop_list.lua')
	for i, v in ipairs(list) do
		append_file(merged, 'props/' .. v, v)
	end
	merged:close()
end

if props then
	change_theme()
else
	local param = table.pack(...)
	if #param == 0 then
		print('No parameter given')
		return
	end
	
	if param[1] == 'genprop' then
		merge_props()
		return
	end
	print('unknown parameter ' .. param[1])
end