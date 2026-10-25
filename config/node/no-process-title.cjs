// macOS 27 aborts node on the second process.title assignment: libuv's
// uv__set_process_title calls LaunchServices _LSApplicationCheckIn, which
// abort()s on re-check-in. npm sets its title twice during startup, so every
// `npm` invocation past argument parsing dies with SIGABRT. Keep the title in
// JS so libuv is never called.
let current = process.title;
Object.defineProperty(process, "title", {
	configurable: true,
	enumerable: true,
	get: () => current,
	set: value => {
		current = String(value);
	},
});
