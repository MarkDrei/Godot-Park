extends Node
## Runs every tests/unit/test_*.gd. Exit code 0 = all passed.
## Usage: godot --headless --path . res://tests/test_runner.tscn [-- --filter=name]

func _ready() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	var dir := DirAccess.open("res://tests/unit")
	var files := []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var total := 0
	var failed := 0
	for f: String in files:
		if filter != "" and not f.contains(filter):
			continue
		var script: GDScript = load("res://tests/unit/" + f)
		var tc: TestCase = script.new()
		var t0 := Time.get_ticks_msec()
		tc.before_all()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			tc.current = "%s::%s" % [f, name]
			var before := tc.failures.size()
			var result = tc.call(name)
			if result is Object and result.has_method("is_valid"):
				await result
			if tc.failures.size() > before:
				failed += 1
				for msg in tc.failures.slice(before):
					print("  FAIL ", msg)
			else:
				print("  ok   ", tc.current)
		print("%s done in %d ms" % [f, Time.get_ticks_msec() - t0])
	print("\n%d tests, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 else 0)
