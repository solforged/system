--!strict

local common = require("./common")
local workflow = require("./workflow")
local action_limit = 128 * 1024

local function attempt(cx: WindowCx, title: string, action: () -> ()): ()
	local ok, err = pcall(action :: (() -> any))
	if not ok then
		cx:toast("error", title, tostring(err))
	end
end

tern.command({
	id = "open",
	title = "Open wiki",
	run = function(cx: WindowCx)
		attempt(cx, "Could not open Wiki", function()
			workflow.require_local(cx, nil)
			local pane = cx:new_block("wiki.browser", { common.default_root() }, "tab")
			if not pane then
				error("No ready Wiki browser block is installed on the current local host.", 0)
			end
		end)
	end,
})

tern.command({
	id = "capture",
	title = "Capture focused omp chat as a note",
	run = function(cx: WindowCx)
		attempt(cx, "Could not capture the focused omp chat", function()
			workflow.capture(cx)
		end)
	end,
})

tern.route.link(function(link: LinkRequest, cx: WindowCx): RouteDecision?
	if link.url:sub(1, #"tern-wiki:") ~= "tern-wiki:" then
		return nil
	end
	attempt(cx, "Could not start Wiki chat", function()
		if #link.url > action_limit then
			error("The wiki action is too large; shorten the question or selected path.", 0)
		end
		local request, err = common.decode_action(link.url)
		if not request then
			error(err or "The wiki action is malformed.", 0)
		end
		workflow.request(cx, request, link.pane)
	end)
	return { handled = true }
end)
