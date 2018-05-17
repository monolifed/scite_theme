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

local clamp = function(x, min, max)
	if x > max then return max end
	if x < min   then return min end
	return x
end


local to_hsl = function(r, g, b)
	r, g, b = r / 255, g / 255, b / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	if max == min then return 0, 0, min end
	
	local l = max + min
	local d = max - min
	local s
	if l > 1 then s = d / (2 - l)
	else s = d / l end
	l = l / 2
	if max == r then
		h = (g - b) / d
		if g < b then h = h + 6 end
	elseif max == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end
	return h, s, l
end

local to_rgb = function(h, s, l)
	if s == 0 then l = l * 255 return l,l,l end
	local c
	if l > 0.5 then c = (2 - 2 * l) * s
	else c = (2 * l) * s end
	m = l - c / 2
	local x = h % 2
	local r, g, b
	if     h < 1 then b, r, g = 0, c, c * x
	elseif h < 2 then b, g, r = 0, c, c * (2 - x)
	elseif h < 3 then r, g, b = 0, c, c * x
	elseif h < 4 then r, b, g = 0, c, c * (2 - x)
	elseif h < 5 then g, b, r = 0, c, c * x
	else			  g, r, b = 0, c, c * (2 - x)
	end
	r, g, b = (r + m) * 255, (g + m) * 255, (b + m) * 255
	return r,g,b
end

-- add scheme-name, scheme-author and base00-hex - base0F-hex
local add_std_vars = function(t, key, value)
	if key == 'scheme' then
		t['scheme-name'] = value
		return
	end
	if key == 'author' then
		t['scheme-author'] = value
		return
	end
	t[key..'-hex'] = value
end

-- add base08-dim - base0F-dim (inactive colors)
-- use base03(comment) lightness and reduce sat.
local add_dim_vars = function(t)
	local r, g, b = string.match(t['base03-hex'], '#?(%x%x)(%x%x)(%x%x)')
	if r == nil then print('error - base03 value') return end
	r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	local h, s, l = to_hsl(r, g, b)
	
	local key
	for i = 8, 15 do
		key = _sf('base0%X', i)
		r, g, b = string.match(t[key..'-hex'], '#?(%x%x)(%x%x)(%x%x)')
		if r == nil then print('error - ' .. key .. ' value') return end
		r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
		h, s = to_hsl(r, g, b)
		r, g, b = to_rgb(h, clamp(s * 0.4, 0, 1), l)
		t[key..'-dim'] = _sf('%02x%02x%02x', r, g, b)
	end
end

local load_scheme = function(dir, name)
	local path = _sf('%s/%s.yaml', dir, name)
	print(_sf('* Loading file %s', path))
	
	local key, value
	local vars = {}
	for line in io.lines(path) do
		key, value = string.match(line, '^%s*([%w]+)%s*:%s*"([^"]-)"')
		if key and valid_yaml[key] then
			add_std_vars(vars, key, value)
		end
	end
	add_dim_vars(vars, key, value)
	print(_sf('* Scheme Name:   %s\n* Scheme Author: %s', vars['scheme-name'], vars['scheme-author']))
	return vars
end

local apply_scheme = function(dir, name)
	local vars = load_scheme(dir..'/schemes', name)
	local path = _sf('%s/merged.properties', dir)
	local filler
	local key, value
	local line_no = 0
	local f = function(key)
		local aa = vars[key]
		if aa ~= nil then
			return aa
		end
		-- scripted colors (like brighter desat'd) and memoize
		print(_sf('Key %s is unknown', key))
	end
	for line in io.lines(path) do
		line_no = line_no + 1
		filler = (line:match('%S') == nil) or (line:match('^%s*#') ~= nil)
		if not filler then
			key, value = string.match(line, '^%s*([%w_.%-*]+)%s*=%s*([%w%p]*)')
			if key then
				props[key] = value:gsub('{{([%w%-]+)}}', f)
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
	if param[1] == 'test' then
		print('test')
		return
	end
	print('unknown parameter ' .. param[1])
end
