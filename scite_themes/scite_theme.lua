local _sf = string.format
local _printf = function(...) print(_sf(...)) end

local yaml_map = {
	scheme = 'scheme-name',
	author = 'scheme-author',
	base00 = 'back',
	base01 = 'lnback',
	base02 = 'whitespace',
	base03 = 'comment',
	base04 = 'lnfore',
	base05 = 'fore',
	base06 = 'operator',
	base07 = 'highlight',
	base08 = 'variable',
	base09 = 'number',
	base0A = 'class',
	base0B = 'string',
	base0C = 'support',
	base0D = 'function',
	base0E = 'keyword',
	base0F = 'embed',
}

local yaml_parse = function(path)
	local key, value
	local vars = {}
	for line in io.lines(path) do
		key, value = string.match(line, '^%s*([%w]+)%s*:%s*"([^"]-)"')
		key = key and yaml_map[key]
		if key ~= nil then
			vars[key] = value
		end
	end
	for id, k in pairs(yaml_map) do
		if vars[k] == nil then 
		_printf('missing value %s in %s', id, path) return end
	end
	return vars
end

local json_map = {
	name = 'scheme-name',
	author = 'scheme-author',
	background = 'back',
	line_highlight = 'lnback',
	invisibles = 'whitespace',
	comment = 'comment',
	docblock = 'lnfore',
	foreground = 'fore',
	caret = 'operator',
	selection_foreground = 'highlight',
	fifth = 'variable',
	number = 'number',
	second = 'class',
	string = 'string',
	first = 'support',
	third = 'function',
	fourth = 'keyword',
	brackets = 'embed',
}

local json_parse = function(path)
	local key, value
	local vars = {}
	for line in io.lines(path) do
		key, value = string.match(line, '^%s*"([%w_]+)"%s*:%s*"#?([^"]-)"')
		--print(key, value)
		key = key and json_map[key]
		if key ~= nil then
			vars[key] = value
		end
	end
	for id, k in pairs(json_map) do
		if vars[k] == nil then 
		_printf('missing value %s in %s', id, path) return end
	end
	vars['whitespace'] = vars['lnback']
	return vars
end

local clamp = function(x, min, max)
	if x > max then return max end
	if x < min then return min end
	return x
end

-- {r, g, b}:[0, 255]
local to_hsl = function(r, g, b)
	--[[
	r, g, b = clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)
	--]]
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

-- h:[0, 6] s:[0, 1] l:[0,1]
local to_rgb = function(h, s, l)
	--[[
	h, s, l = h % 6, clamp(s, 0, 1), clamp(l, 0, 1)
	--]]
	if s == 0 then l = l * 255 return l,l,l end
	local c
	if l > 0.5 then c = (2 - 2 * l) * s
	else c = (2 * l) * s end
	local m = l - c / 2
	
	local r, g, b
	if     h < 1 then b, r, g = 0, c, c * h
	elseif h < 2 then b, g, r = 0, c, c * (2 - h)
	elseif h < 3 then r, g, b = 0, c, c * (h - 2)
	elseif h < 4 then r, b, g = 0, c, c * (4 - h)
	elseif h < 5 then g, b, r = 0, c, c * (h - 4)
	else              g, r, b = 0, c, c * (6 - h)
	end
	r, g, b = (r + m) * 255, (g + m) * 255, (b + m) * 255
	return r, g, b
end


local dim_list = {'operator', 'comment', 'variable', 'number', 'class',
	'string','support', 'function', 'keyword', 'embed'}

-- add inactive (dim) colors
-- use back/fore based lightness and reduce sat.
local key_error = 'Error parsing value for key: '
local add_dim_vars = function(t, fill)
	local r, g, b = string.match(t['back'], '#?(%x%x)(%x%x)(%x%x)')
	if r == nil then print(key_error .. 'back') return end
	r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	local h, s, l = to_hsl(r, g, b)

	r, g, b = string.match(t['fore'], '#?(%x%x)(%x%x)(%x%x)')
	if r == nil then print(key_error .. 'fore') return end
	r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	local H, S, L = to_hsl(r, g, b)
	
	if fill then
		t['lnback'] = _sf('%02x%02x%02x', to_rgb(h, s, l + 0.2 * (L - l)))
		t['whitespace'] = _sf('%02x%02x%02x', to_rgb(h, s, l + 0.4 * (L - l)))
		t['comment'] = _sf('%02x%02x%02x', to_rgb(H, S, l + 0.6 * (L - l)))
		t['lnfore'] = _sf('%02x%02x%02x', to_rgb(H, S, l + 0.8 * (L - l)))
	end
	
	l = l + 0.4 * (L - l)
	r, g, b = to_rgb(h, s * 0.4, l)
	t['fore-dim'] = _sf('%02x%02x%02x', r, g, b)
	
	local key
	for i, v in ipairs(dim_list) do
		key = v
		r, g, b = string.match(t[v], '#?(%x%x)(%x%x)(%x%x)')
		if r == nil then print(key_error .. v) return end
		r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
		h, s = to_hsl(r, g, b)
		r, g, b = to_rgb(h, s * 0.4, l)
		t[v..'-dim'] = _sf('%02x%02x%02x', r, g, b)
	end
end

local isfile = function(fname)
	local f = io.open(fname, 'r')
	if f then io.close(f) return true end
	return false
end

local locate_scheme = function(pdir, name)
	--pdir = pdir .. '/'
	if isfile(pdir .. name) then return name end
	
	local search = {'%s.yaml', 'base16/%s', 'base16/%s.yaml',
		'%s.json', 'daylerees/%s', 'daylerees/%s.json'}
	
	local s
	for i, fmt in ipairs(search) do
		s = _sf(fmt, name)
		if isfile(pdir .. s) then return s end
	end
end


local apply_scheme = function(name)
	local theme_dir = props['ext.lua.theme_dir']
	local schemes_dir = theme_dir .. '/schemes/'
	local props_dir = theme_dir .. '/props/'
	
	local scheme_path = locate_scheme(schemes_dir, name)
	if not scheme_path then
		_printf('File "%s" cannot be found', name)
		return
	end
	
	name = scheme_path
	scheme_path = schemes_dir .. scheme_path
	
	local vars
	local filetype = scheme_path:sub(-5)
	if filetype == '.yaml' then
		vars = yaml_parse(scheme_path)
	elseif filetype == '.json' then
		vars = json_parse(scheme_path)
	else
		_printf('Filetype "%s" is not supported', filetype)
		return
	end

	add_dim_vars(vars)

	local mf = function(key)
		local kv = vars[key]
		if kv ~= nil then
			--print(key, kv)
			return kv
		end
		-- TODO: scripted colors (like brighter desat'd) and memoize
		_printf('Key "%s" is unknown', key)
	end

	local filler
	local key, value
	local line_no = 0
	local list = dofile(theme_dir .. '/prop_list.lua')
	local template_path
	for i, v in ipairs(list) do
		template_path = props_dir .. v
		for line in io.lines(template_path) do
			line_no = line_no + 1
			filler = (line:match('%S') == nil) or (line:match('^%s*#') ~= nil)
			if not filler then
				key, value = string.match(line, '^%s*([%w_.%-*]+)%s*=%s*([%w%p]*)')
				if key then
					props[key] = value:gsub('{{([%w%-]+)}}', mf)
				else
					_printf('ignoring line %i: %s', line_no, line)
				end
			end
		end
	end
	--_printf('Using theme "%s" by "%s"', vars['scheme-name'], vars['scheme-author'])
	props['ext.lua.theme_now'] = name
end

-- Change to the fixed theme defined in user properties file
function change_theme()
	local name = props['ext.lua.theme']:lower():gsub(' ','-'):gsub('[,]','')
	apply_scheme(name)
	_printf('Using "%s"', props['ext.lua.theme_now'])
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
		list_cur = 1
	end
	list_cur = 1 + ((list_cur + step - 1) % list_len)
	name = list[list_cur]
	apply_scheme(name)
	_printf('Using "%s" %i/%i', props['ext.lua.theme_now'], list_cur, list_len)
end

function next_theme()
	cycle_theme(1)
end

function prev_theme()
	cycle_theme(-1)
end

if props then
	change_theme()
end
