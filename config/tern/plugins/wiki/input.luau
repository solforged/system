--!strict

-- Cursor positions here are UTF-8 byte boundaries; only surface props use UTF-16.
export type Field = {
	text: string,
	cursor: number,
	anchor: number?,
}

local input = {}

function input.new(text: string): Field
	return { text = text, cursor = #text, anchor = nil }
end

function input.utf16(text: string, boundary: number): number
	local units = 0
	for at, point in utf8.codes(text) do
		if at > boundary then
			break
		end
		units += if point > 0xFFFF then 2 else 1
	end
	return units
end

local function previous(text: string, cursor: number): number
	if cursor == 0 then
		return 0
	end
	return (utf8.offset(text, -1, cursor + 1) or 1) - 1
end

local function following(text: string, cursor: number): number
	if cursor == #text then
		return cursor
	end
	return (utf8.offset(text, 2, cursor + 1) or (#text + 1)) - 1
end

local function replace(field: Field, text: string)
	local anchor = field.anchor or field.cursor
	local first, last = math.min(anchor, field.cursor), math.max(anchor, field.cursor)
	field.text = field.text:sub(1, first) .. text .. field.text:sub(last + 1)
	field.cursor = first + #text
	field.anchor = nil
end

local function move(field: Field, cursor: number, selecting: boolean)
	if selecting then
		field.anchor = field.anchor or field.cursor
	else
		field.anchor = nil
	end
	field.cursor = cursor
end

-- Returns handled, text-changed, and a user-facing error for invalid pasted bytes.
function input.key(field: Field, key: Key, multiline: boolean): (boolean, boolean, string?)
	local before = field.text
	local command = key.ctrl or key.meta
	if command and key.name == "a" then
		field.anchor, field.cursor = 0, #field.text
	elseif key.name == "left" or key.name == "right" then
		local cursor: number
		if not key.shift and field.anchor ~= nil and field.anchor ~= field.cursor then
			cursor = if key.name == "left" then math.min(field.anchor, field.cursor) else math.max(field.anchor, field.cursor)
		else
			cursor = if key.name == "left" then previous(field.text, field.cursor) else following(field.text, field.cursor)
		end
		move(field, cursor, key.shift)
	elseif key.name == "home" or key.name == "begin" then
		local cursor = if command then 0 else (field.text:sub(1, field.cursor):match(".*()\n") or 0)
		move(field, cursor, key.shift)
	elseif key.name == "end" then
		local newline = field.text:find("\n", field.cursor + 1, true)
		move(field, if command then #field.text else ((newline or (#field.text + 1)) - 1), key.shift)
	elseif key.name == "backspace" or key.name == "delete" then
		if field.anchor == nil or field.anchor == field.cursor then
			field.anchor = if key.name == "backspace" then previous(field.text, field.cursor) else following(field.text, field.cursor)
		end
		replace(field, "")
	elseif key.name == "enter" and multiline then
		replace(field, "\n")
	elseif key.text and (key.name == "paste" or not command) then
		local text = key.text
		if utf8.len(text) == nil then
			return true, false, "The pasted text is not valid UTF-8."
		end
		text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
		if not multiline then
			text = text:gsub("\n", " ")
		end
		replace(field, text)
	else
		return false, false, nil
	end
	return true, field.text ~= before, nil
end

return input
