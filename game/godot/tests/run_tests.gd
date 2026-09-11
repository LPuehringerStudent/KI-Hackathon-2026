extends SceneTree
## Headless test runner:
##   godot --headless --path game/godot -s res://tests/run_tests.gd
## Runs every test_* method of every res://tests/test_*.gd suite
## (suites extend base_test.gd). Exits 1 if anything fails.
## To add tests, drop a new test_<module>.gd file here — no runner edits needed.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: Script = load(TEST_DIR + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s — could not load suite (parse error?)" % file)
			continue
		var suite: Object = script.new()
		for method: Dictionary in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			suite.failures.clear()
			suite.call(test_name)
			if suite.failures.is_empty():
				passed += 1
				print("PASS %s :: %s" % [file, test_name])
			else:
				failed += 1
				for message: String in suite.failures:
					print("FAIL %s :: %s — %s" % [file, test_name, message])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
