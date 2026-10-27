--!strict

export type Request = {
	operation: string,
	root: string,
	text: string,
}

local common = {}
local scheme = "tern-wiki:"

function common.normalize_root(value: string): (string?, string?)
	local root = value:match("^%s*(.-)%s*$") or ""
	if root == "~" or root:sub(1, 2) == "~/" then
		local home = tern.getenv("HOME") or tern.getenv("USERPROFILE")
		if not home or home == "" then
			return nil, "The home directory is unavailable; enter an absolute wiki path."
		end
		root = home .. root:sub(2)
	end
	if tern.runtime.os == "windows" then
		root = root:gsub("\\", "/")
	end
	if root:find("%z") or root:find("[\r\n]") then
		return nil, "The wiki path cannot contain NUL or newline characters."
	end
	if root:sub(1, 1) ~= "/" and not root:match("^%a:/") then
		return nil, "Enter an absolute wiki path or a path beginning with ~/."
	end
	if root:match("^/+$") then
		root = "/"
	elseif not root:match("^%a:/$") then
		root = root:gsub("/+$", "")
	end
	return root, nil
end

function common.default_root(): string
	local root, err = common.normalize_root(tern.getenv("TERN_WIKI_ROOT") or "~/wiki")
	if not root then
		error(err)
	end
	return root
end

function common.action_url(operation: string, root: string, text: string): string
	local payload = tern.json.encode({ operation = operation, root = root, text = text })
	local encoded = payload:gsub("([^%w._~-])", function(byte)
		return string.format("%%%02X", string.byte(byte))
	end)
	return scheme .. encoded
end

function common.decode_action(url: string): (Request?, string?)
	if url:sub(1, #scheme) ~= scheme then
		return nil, nil
	end
	local encoded = url:sub(#scheme + 1)
	local at = 1
	while at <= #encoded do
		if encoded:sub(at, at) == "%" then
			if not encoded:sub(at + 1, at + 2):match("^%x%x$") then
				return nil, "The wiki action contains invalid URL encoding."
			end
			at += 3
		else
			at += 1
		end
	end
	local decoded = encoded:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) :: number)
	end)
	local ok, value = pcall(tern.json.decode, decoded)
	if not ok or type(value) ~= "table" then
		return nil, "The wiki action is not a valid request."
	end
	if value.operation ~= "research" and value.operation ~= "ask" and value.operation ~= "use" then
		return nil, "The wiki action is unknown."
	end
	if type(value.root) ~= "string" or type(value.text) ~= "string" or value.text:match("^%s*$") then
		return nil, "Select a wiki and provide a question or page."
	end
	local root, err = common.normalize_root(value.root)
	if not root then
		return nil, err
	end
	local request: Request = { operation = value.operation, root = root, text = value.text }
	return request, nil
end

return common
