--!strict

local common = require("./common")
local input = require("./input")
local ui = tern.ui

local MAX_PAGE_BYTES = 1024 * 1024
local PROCESS_CAPTURE_BYTES = 16 * 1024 * 1024
local PAGE_ROWS = 80
local INPUT_ORDER = { "root", "filter", "question" }

type Note = {
	index: number,
	path: string,
	relative: string,
	title: string,
	search: string,
	error: string?,
}

type State = {
	root: input.Field,
	filter: input.Field,
	question: input.Field,
	focus: string,
	active_root: string?,
	notes: { Note },
	by_relative: { [string]: Note },
	matches: { Note },
	page: number,
	selection: string?,
	restore_selection: string?,
	body: string?,
	frontmatter: string?,
	body_error: string?,
	preview_warning: string?,
	generation: number,
	filter_generation: number,
	filtering: boolean,
	loading: boolean,
	phase: string,
	scanned: number,
	excluded: number,
	unreadable: number,
	skipped: number,
	issues: { string },
	issue_count: number,
	scan_error: string?,
	feedback: string?,
	feedback_tone: string,
}

local function clipped(text: string, bytes: number): string
	if #text <= bytes then
		return text
	end
	local boundary = utf8.offset(text, 0, bytes + 1) or (bytes + 1)
	return text:sub(1, boundary - 1) .. "…"
end

local function display(text: string): string
	if utf8.len(text) == nil then
		return "[non-UTF-8 text]"
	end
	return (text:gsub("[%c]", function(character)
		if character == "\n" then
			return "\\n"
		elseif character == "\r" then
			return "\\r"
		elseif character == "\t" then
			return "\\t"
		end
		return string.format("\\x%02X", string.byte(character))
	end))
end

local function error_text(value: any): string
	return clipped(display(tostring(value)), 2048)
end

local function feedback(state: State, text: string, tone: string?)
	state.feedback = text
	state.feedback_tone = tone or "info"
end

local function clear_preview(state: State)
	state.selection = nil
	state.body = nil
	state.frontmatter = nil
	state.body_error = nil
	state.preview_warning = nil
end

local function issue(state: State, text: string)
	state.issue_count += 1
	if #state.issues < 12 then
		table.insert(state.issues, text)
	end
end

-- Frontmatter is displayed verbatim, never interpreted as an incomplete YAML schema.
local function split_page(source: string): (string, string?, string?)
	if source:sub(1, 3) == "\239\187\191" then
		source = source:sub(4)
	end
	local first_end = source:find("\n", 1, true)
	local first = source:sub(1, if first_end then first_end - 1 else #source):gsub("\r$", "")
	if not first:match("^%-%-%-%s*$") then
		return source, nil, nil
	end
	local at = if first_end then first_end + 1 else #source + 1
	while at <= #source do
		local line_end = source:find("\n", at, true)
		local line = source:sub(at, if line_end then line_end - 1 else #source):gsub("\r$", "")
		if line:match("^%-%-%-%s*$") or line:match("^%.%.%.%s*$") then
			local after = if line_end then line_end + 1 else #source + 1
			return source:sub(after), source:sub(1, after - 1), nil
		end
		at = if line_end then line_end + 1 else #source + 1
	end
	return source, nil, "The opening frontmatter delimiter has no closing delimiter; showing an uninterpreted source excerpt."
end

local function page_title(body: string, relative: string): string
	local fence: string? = nil
	for line in (body:sub(1, 65536) .. "\n"):gmatch("(.-)\n") do
		local marker = line:match("^ ? ? ?(```+)") or line:match("^ ? ? ?(~~~+)")
		if marker then
			if fence == nil then
				fence = marker
			elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
				fence = nil
			end
		elseif fence == nil then
			local hashes, heading = line:match("^ ? ? ?(#+)%s+(.+)")
			if hashes and #hashes <= 6 and heading and utf8.len(heading) ~= nil then
				heading = heading:gsub("%s+#+%s*$", ""):gsub("%s+$", "")
				if heading ~= "" then
					return clipped(display(heading), 240)
				end
			end
		end
	end
	local name = relative:match("([^/]+)$") or relative
	local stem = name:sub(1, -4)
	return display(if stem ~= "" then stem else name)
end

local function matches(state: State, note: Note): boolean
	local query = state.filter.text:match("^%s*(.-)%s*$") or ""
	return query == "" or note.search:find(string.lower(query), 1, true) ~= nil
end

local function read_page(note: Note): (string?, string?)
	local ok, value = pcall(tern.fs.read, note.path, MAX_PAGE_BYTES)
	if not ok then
		return nil, error_text(value)
	end
	if utf8.len(value) == nil then
		return nil, "The page is not valid UTF-8."
	end
	return value, nil
end

local function select_note(state: State, note: Note)
	if state.by_relative[note.relative] ~= note or not matches(state, note) then
		clear_preview(state)
		return
	end
	clear_preview(state)
	state.selection = note.relative
	state.restore_selection = nil
	local source, err = read_page(note)
	if not source then
		state.body_error = err or "The page could not be read."
		return
	end
	local body, frontmatter, warning = split_page(source)
	state.body = clipped(body, 4096)
	state.frontmatter = frontmatter
	state.preview_warning = warning
end

local function restore_selection(state: State)
	local relative = state.restore_selection
	if not relative then
		return
	end
	state.restore_selection = nil
	local note = state.by_relative[relative]
	if note and matches(state, note) then
		select_note(state, note)
		for index, candidate in state.matches do
			if candidate == note then
				state.page = math.floor((index - 1) / PAGE_ROWS) + 1
				break
			end
		end
	end
end

-- Filtering and scan work yield between small batches rather than consuming a host call.
local function refilter(state: State, cx: BlockCx)
	state.filter_generation += 1
	local token, generation = state.filter_generation, state.generation
	state.filtering = true
	state.matches = {}
	state.page = 1
	local selected = if state.selection then state.by_relative[state.selection] else nil
	if selected and not matches(state, selected) then
		clear_preview(state)
	end
	local found: { Note } = {}
	local at = 1
	local step: () -> ()
	step = function()
		if token ~= state.filter_generation or generation ~= state.generation then
			return
		end
		local deadline = tern.now() + 12
		local count = 0
		while at <= state.scanned and count < 250 and tern.now() < deadline do
			local note = state.notes[at]
			if matches(state, note) then
				table.insert(found, note)
			end
			at += 1
			count += 1
		end
		if at <= state.scanned then
			tern.timer(1, step)
		else
			state.matches = found
			state.filtering = false
			if not state.loading then
				restore_selection(state)
			end
		end
		cx:render()
	end
	tern.timer(1, step)
end

local function scan_titles(state: State, cx: BlockCx, generation: number)
	local step: () -> ()
	step = function()
		if generation ~= state.generation then
			return
		end
		local deadline = tern.now() + 12
		local count = 0
		while state.scanned < #state.notes and count < 4 and tern.now() < deadline do
			local note = state.notes[state.scanned + 1]
			local source, err = read_page(note)
			if source then
				local body = split_page(source)
				note.title = page_title(body, note.relative)
				note.search = string.lower(note.relative .. "\n" .. note.title)
			else
				local message = err or "The page could not be read."
				note.error = message
				state.unreadable += 1
				issue(state, display(note.relative) .. ": " .. message)
			end
			state.scanned += 1
			count += 1
			if not state.filtering and matches(state, note) then
				table.insert(state.matches, note)
			end
		end
		state.phase = string.format("Reading page titles: %d / %d", state.scanned, #state.notes)
		if state.scanned < #state.notes then
			tern.timer(1, step)
		else
			state.loading = false
			state.phase = ""
			if not state.filtering then
				restore_selection(state)
			end
		end
		cx:render()
	end
	tern.timer(1, step)
end

local function valid_relative(relative: string): boolean
	if relative == "" or relative:sub(1, 1) == "/" or relative:sub(-3) ~= ".md" then
		return false
	end
	for part in relative:gmatch("[^/]+") do
		if part == "." or part == ".." or part == ".git" then
			return false
		end
	end
	return true
end

local function collect_paths(state: State, cx: BlockCx, generation: number, root: string, result: ProcessResult)
	if generation ~= state.generation then
		return
	end
	if result.status ~= 0 or result.timed_out then
		local detail = error_text(result.stderr)
		if detail == "" then
			detail = if result.timed_out then "find timed out." else "find exited with status " .. tostring(result.status) .. "."
		end
		state.scan_error = "Wiki scan failed or was incomplete: " .. detail
	elseif result.stderr ~= "" then
		state.scan_error = "Wiki scan reported: " .. error_text(result.stderr)
	end
	if #result.stdout >= PROCESS_CAPTURE_BYTES then
		issue(state, "The file listing reached Tern's 16 MiB process-output limit; the browser may show only part of this wiki.")
	end
	local prefix = if root == "/" then "/" else root .. "/"
	local output = result.stdout
	local at = 1
	local step: () -> ()
	step = function()
		if generation ~= state.generation then
			return
		end
		local deadline = tern.now() + 12
		local count = 0
		while at <= #output and count < 250 and tern.now() < deadline do
			local last = output:find("\0", at, true)
			if not last then
				state.skipped += 1
				issue(state, "Skipped an incomplete filename at the end of find's output.")
				at = #output + 1
				break
			end
			local path = output:sub(at, last - 1)
			at = last + 1
			count += 1
			if utf8.len(path) == nil then
				state.skipped += 1
				issue(state, "Skipped a filename that is not valid UTF-8.")
			elseif path:sub(1, #prefix) ~= prefix then
				state.skipped += 1
				issue(state, "Skipped an unexpected path outside the enumerated wiki root.")
			else
				local relative = path:sub(#prefix + 1)
				local basename = string.lower(relative:match("([^/]+)$") or relative)
				if basename == "index.md" or basename == "log.md" then
					state.excluded += 1
				elseif valid_relative(relative) and not state.by_relative[relative] then
					local title = page_title("", relative)
					local note: Note = {
						index = #state.notes + 1,
						path = path,
						relative = relative,
						title = title,
						search = string.lower(relative .. "\n" .. title),
						error = nil,
					}
					state.by_relative[relative] = note
					table.insert(state.notes, note)
				else
					state.skipped += 1
					issue(state, "Skipped an invalid or duplicate page path: " .. display(relative))
				end
			end
		end
		state.phase = "Enumerating pages: " .. tostring(#state.notes)
		if at <= #output then
			tern.timer(1, step)
		else
			output = ""
			scan_titles(state, cx, generation)
		end
		cx:render()
	end
	tern.timer(1, step)
end

local function reset_scan(state: State)
	state.generation += 1
	state.filter_generation += 1
	state.active_root = nil
	state.notes = {}
	state.by_relative = {}
	state.matches = {}
	state.page = 1
	state.filtering = false
	state.loading = false
	state.phase = ""
	state.scanned = 0
	state.excluded = 0
	state.unreadable = 0
	state.skipped = 0
	state.issues = {}
	state.issue_count = 0
	state.scan_error = nil
	clear_preview(state)
end

local function refresh(state: State, cx: BlockCx)
	local wanted = state.selection or state.restore_selection
	reset_scan(state)
	state.restore_selection = wanted
	state.feedback = nil
	local root, err = common.normalize_root(state.root.text)
	if not root then
		state.restore_selection = nil
		state.scan_error = err or "Enter an absolute wiki path."
		cx:render()
		return
	end
	if tern.runtime.os ~= "linux" and tern.runtime.os ~= "macos" then
		state.scan_error = "Wiki browsing requires the Linux or macOS find utility. Research and Ask remain available."
		cx:render()
		return
	end
	state.active_root = root
	state.loading = true
	state.phase = "Finding Markdown pages…"
	local generation = state.generation
	-- A trailing slash makes a file supplied as the root fail as a non-directory.
	-- -H permits an explicit root symlink, never descendant symlink traversal.
	local scan_root = if root == "/" then "/" else root .. "/"
	local ok, failure = pcall(function()
		tern.process.run({ "find", "-H", scan_root, "-type", "d", "-name", ".git", "-prune", "-o", "-type", "f", "-name", "*.md", "-print0" }, { timeout_ms = 30000 }, function(result: ProcessResult)
			collect_paths(state, cx, generation, root, result)
		end)
	end)
	if not ok then
		state.loading = false
		state.phase = ""
		state.restore_selection = nil
		state.scan_error = "Cannot start the read-only wiki scan: " .. error_text(failure)
	end
	cx:render()
end

local function focus(state: State, field: string, cx: BlockCx)
	state.focus = field
	cx:frame({ { "focus", "main." .. field } })
end

local function selected_note(state: State): Note?
	local root = common.normalize_root(state.root.text)
	if root == nil or root ~= state.active_root or state.selection == nil then
		return nil
	end
	local note = state.by_relative[state.selection]
	return if note and matches(state, note) then note else nil
end

local function dispatch(state: State, operation: string, cx: BlockCx)
	local root, err = common.normalize_root(state.root.text)
	if not root then
		feedback(state, err or "Enter a wiki root.", "error")
		return
	end
	local text = state.question.text
	if operation == "use" then
		local note = selected_note(state)
		if not note then
			feedback(state, "Select an enumerated wiki page first.", "error")
			return
		end
		-- Recheck the bounded regular-file read before handing a page to a model.
		local source, read_error = read_page(note)
		if not source then
			state.body = nil
			state.frontmatter = nil
			state.body_error = read_error
			feedback(state, "The selected page is unreadable; no chat was requested.", "error")
			return
		end
		text = note.relative
	elseif text:match("^%s*$") then
		feedback(state, "Enter a research topic or question first.", "error")
		focus(state, "question", cx)
		return
	end
	local ok, failure = pcall(function()
		cx:open(common.action_url(operation, root, text))
	end)
	if ok then
		local label = if operation == "research" then "Research and write" elseif operation == "ask" then "Read-only wiki question" else "Chat with selected note"
		feedback(state, label .. " requested in an agent pane. This browser has not written any wiki files.")
	else
		feedback(state, "Could not request the wiki action: " .. error_text(failure), "error")
	end
end

local function open_selected(state: State, cx: BlockCx)
	local note = selected_note(state)
	if not note then
		feedback(state, "Select an enumerated wiki page first.", "error")
		return
	end
	local source, err = read_page(note)
	if not source then
		state.body = nil
		state.frontmatter = nil
		state.body_error = err
		feedback(state, "The selected page is unreadable; it was not opened.", "error")
		return
	end
	local ok, failure = pcall(function()
		cx:open(note.path)
	end)
	feedback(state, if ok then "Requested the selected page in the editor." else "Could not open the page: " .. error_text(failure), if ok then "info" else "error")
end

local function keyed(node: Node, key: string): Node
	local props: { [string]: any } = node.p or {}
	props.key = key
	node.p = props
	return node
end

local function button(label: string, action: string, role: string, available: boolean?): Node
	return ui.el("button", {
		key = action,
		role = role,
		aria = label,
		actions = { click = action },
	}, { ui.badge(label, if available == false then "muted" else "accent") })
end

local function field_node(field: input.Field, name: string, label: string, multiline: boolean): Node
	return ui.node(if multiline then "editor" else "input", {
		key = name,
		role = "wiki-" .. name,
		aria = label,
		text = field.text,
		cursor = input.utf16(field.text, field.cursor),
		anchor = if field.anchor ~= nil then input.utf16(field.text, field.anchor) else nil,
		placeholder = label,
		maxLines = if multiline then 6 else nil,
	})
end

local function view(state: State, _cx: BlockCx): BlockView
	local selected = selected_note(state)
	local children: { Node } = {
		keyed(ui.text(ui.span("Wiki", "strong")), "heading"),
		keyed(ui.text("Wiki root (Enter to refresh)"), "root-label"),
		field_node(state.root, "root", "Wiki root", false),
		keyed(ui.text("Filter by title or relative path"), "filter-label"),
		field_node(state.filter, "filter", "Filter title or path", false),
		keyed(ui.text("Research topic or wiki question · Enter: research and write · Shift+Enter: newline · Tab: next field"), "question-label"),
		field_node(state.question, "question", "Research topic or wiki question", true),
		keyed(ui.row({
			button("Research and write", "research", "wiki-research"),
			button("Ask wiki", "ask", "wiki-ask"),
			button("Refresh", "refresh", "wiki-refresh"),
		}), "actions"),
		keyed(ui.row({
			button("Open selected in editor", "open", "wiki-open", selected ~= nil),
			button("Chat with selected note", "use", "wiki-use", selected ~= nil),
		}), "note-actions"),
		keyed(ui.text(ui.span("Browsing never writes notes. Ask has read-only tools. Research writes notes; Chat with selected note loads context into a normal omp chat. No model runs until you request one.", "muted")), "policy"),
	}
	if state.feedback then
		table.insert(children, keyed(ui.text(ui.span(state.feedback, state.feedback_tone)), "feedback"))
	end
	if state.scan_error then
		table.insert(children, keyed(ui.text(ui.span(state.scan_error, "error")), "scan-error"))
	end
	if state.loading then
		table.insert(children, keyed(ui.progress(nil, state.phase), "loading"))
	elseif state.active_root == nil and state.scan_error == nil then
		table.insert(children, keyed(ui.text(ui.span("Root changed. Press Refresh or Enter in Wiki root to read this location. Missing roots are never created by the browser.", "muted")), "root-changed"))
	end
	if state.filtering then
		table.insert(children, keyed(ui.text(ui.span("Filtering pages…", "muted")), "filtering"))
	end
	local pages = math.max(1, math.ceil(#state.matches / PAGE_ROWS))
	local page = math.clamp(state.page, 1, pages)
	local first = (page - 1) * PAGE_ROWS + 1
	local last = math.min(first + PAGE_ROWS - 1, #state.matches)
	local rows: { Node } = {}
	for index = first, last do
		local note = state.matches[index]
		table.insert(rows, ui.node("item", {
			key = "n" .. tostring(note.index),
			label = note.title,
			detail = display(note.relative),
			value = if note.error then "unreadable" else nil,
			tone = if note.error then "warning" else nil,
		}))
	end
	local empty = if state.loading then "Pages appear as their titles are read…" elseif state.scan_error and #state.notes == 0 then "No readable listing was returned. See the scan error above." elseif #state.notes == 0 then "No note pages found. index.md and log.md are navigation/history, not notes. The browser does not create files." else "No pages match this title/path filter."
	table.insert(children, keyed(ui.text(string.format("%d matching / %d discovered · %d navigation/history excluded · %d unreadable · %d skipped", #state.matches, #state.notes, state.excluded, state.unreadable, state.skipped)), "counts"))
	table.insert(children, ui.node("list", {
		key = "notes",
		role = "wiki-notes",
		aria = "Wiki note pages",
		selected = if selected then "main.notes.n" .. tostring(selected.index) else nil,
		filter = state.filter.text,
		empty = empty,
		max = { lines = 10 },
	}, rows))
	if pages > 1 then
		table.insert(children, keyed(ui.row({
			button("Previous pages", "previous", "wiki-previous", page > 1),
			ui.text(string.format("Page %d / %d", page, pages)),
			button("Next pages", "next", "wiki-next", page < pages),
		}), "pagination"))
	end
	if state.issue_count > 0 then
		local details: { Node } = {}
		for _, text in state.issues do
			table.insert(details, ui.text(text))
		end
		if state.issue_count > #state.issues then
			table.insert(details, ui.text(tostring(state.issue_count - #state.issues) .. " additional scan issues; unreadable pages are also marked in the list."))
		end
		local issues = keyed(ui.section("Scan issues (" .. tostring(state.issue_count) .. ")", details), "issues")
		local issue_props: { [string]: any } = issues.p or {}
		issue_props.collapsible = true
		issue_props.collapsed = true
		issues.p = issue_props
		table.insert(children, issues)
	end
	if selected then
		table.insert(children, keyed(ui.rule(display(selected.relative)), "selected-path"))
		table.insert(children, keyed(ui.text(ui.span("Plain source excerpt. Open selected in editor (or double-click the page) for the full native reader with correctly resolved links.", "muted")), "preview-help"))
		if state.body_error then
			table.insert(children, keyed(ui.text(ui.span("Could not read this page: " .. state.body_error .. " (regular UTF-8 files up to 1 MiB only).", "error")), "body-error"))
		else
			if state.preview_warning then
				table.insert(children, keyed(ui.text(ui.span(state.preview_warning, "warning")), "preview-warning"))
			end
			if state.frontmatter then
				local raw = keyed(ui.section("Raw frontmatter (unparsed reference data)", { ui.code(state.frontmatter, "yaml") }), "frontmatter")
				local raw_props: { [string]: any } = raw.p or {}
				raw_props.collapsible = true
				raw_props.collapsed = true
				raw.p = raw_props
				table.insert(children, raw)
			end
			local body = keyed(if state.body and state.body ~= "" then ui.code(state.body) else ui.text(ui.span("This page has no Markdown body.", "muted")), "body")
			local body_props: { [string]: any } = body.p or {}
			body_props.role = "wiki-body"
			body.p = body_props
			table.insert(children, body)
		end
	else
		table.insert(children, keyed(ui.text(ui.span("Select a page for a plain excerpt; double-click it or use Open selected in editor for the full native reader. Refresh rereads the source; there is no background filesystem polling.", "muted")), "no-selection"))
	end
	return { main = ui.col(children) }
end

local function key(state: State, pressed: Key, cx: BlockCx): boolean?
	if pressed.name == "tab" then
		local at = table.find(INPUT_ORDER, state.focus) or (if pressed.shift then 1 else #INPUT_ORDER)
		local next_index = ((at - 1 + (if pressed.shift then -1 else 1)) % #INPUT_ORDER) + 1
		focus(state, INPUT_ORDER[next_index], cx)
		return true
	elseif state.focus == "notes" then
		if pressed.name == "enter" then
			open_selected(state, cx)
		elseif pressed.name == "up" or pressed.name == "down" then
			local current = if state.selection then state.by_relative[state.selection] else nil
			local at = if current then table.find(state.matches, current) or 1 else 1
			local next_index = math.clamp(at + (if pressed.name == "up" then -1 else 1), 1, math.max(1, #state.matches))
			local note = state.matches[next_index]
			if note then
				select_note(state, note)
				state.page = math.floor((next_index - 1) / PAGE_ROWS) + 1
			end
		else
			return false
		end
		return true
	elseif pressed.name == "enter" and state.focus == "question" and not pressed.shift then
		dispatch(state, "research", cx)
		return true
	elseif pressed.name == "enter" and state.focus == "root" then
		refresh(state, cx)
		return true
	elseif pressed.name == "enter" and state.focus == "filter" then
		if state.matches[1] then
			select_note(state, state.matches[1])
		end
		focus(state, "question", cx)
		return true
	end
	local field = if state.focus == "root" then state.root elseif state.focus == "filter" then state.filter else state.question
	local handled, changed, err = input.key(field, pressed, state.focus == "question")
	if err then
		feedback(state, err, "error")
	end
	if changed then
		state.feedback = nil
		if state.focus == "root" then
			reset_scan(state)
			state.restore_selection = nil
		elseif state.focus == "filter" then
			refilter(state, cx)
		end
	end
	return handled
end

local function event(state: State, ev: UiEvent, cx: BlockCx)
	if ev.ev == "focus" then
		for _, name in INPUT_ORDER do
			if ev.id == "main." .. name then
				focus(state, name, cx)
				return
			end
		end
	elseif (ev.ev == "select" or ev.ev == "activate") and ev.id == "main.notes" and type(ev.item) == "string" then
		local index = tonumber(ev.item:match("^main%.notes%.n(%d+)$"))
		local note = if index then state.notes[index] else nil
		if note and index and index <= state.scanned and matches(state, note) then
			select_note(state, note)
			focus(state, "notes", cx)
			if ev.ev == "activate" then
				open_selected(state, cx)
			end
		end
	elseif ev.ev == "action" then
		if ev.act == "research" or ev.act == "ask" or ev.act == "use" then
			dispatch(state, ev.act, cx)
		elseif ev.act == "refresh" then
			refresh(state, cx)
		elseif ev.act == "open" then
			open_selected(state, cx)
		elseif ev.act == "previous" then
			state.page = math.max(1, state.page - 1)
		elseif ev.act == "next" then
			state.page = math.min(math.max(1, math.ceil(#state.matches / PAGE_ROWS)), state.page + 1)
		end
	end
end

local definition: BlockDef<State> = {
	init = function(cx, args, saved)
		local values = if type(saved) == "table" then saved else {}
		local saved_root = if type(values.root) == "string" then common.normalize_root(values.root) else nil
		local root = if saved_root then values.root elseif type(args[1]) == "string" and args[1] ~= "" then args[1] else common.default_root()
		local state: State = {
			root = input.new(root),
			filter = input.new(if type(values.filter) == "string" then values.filter else ""),
			question = input.new(if type(values.question) == "string" then values.question else ""),
			focus = "question",
			active_root = nil,
			notes = {},
			by_relative = {},
			matches = {},
			page = 1,
			selection = nil,
			restore_selection = if type(values.selection) == "string" then values.selection else nil,
			body = nil,
			frontmatter = nil,
			body_error = nil,
			preview_warning = nil,
			generation = 0,
			filter_generation = 0,
			filtering = false,
			loading = true,
			phase = "Preparing the read-only wiki browser…",
			scanned = 0,
			excluded = 0,
			unreadable = 0,
			skipped = 0,
			issues = {},
			issue_count = 0,
			scan_error = nil,
			feedback = nil,
			feedback_tone = "info",
		}
		-- The fields must exist before the raw focus operation is applied.
		tern.timer(0, function()
			focus(state, "question", cx)
			refresh(state, cx)
		end)
		return state
	end,
	view = view,
	title = function(_state)
		return "Wiki"
	end,
	key = key,
	event = event,
	save = function(state)
		return {
			root = state.root.text,
			filter = state.filter.text,
			question = state.question.text,
			selection = state.selection or state.restore_selection,
		}
	end,
}

tern.block.define("browser", definition)
