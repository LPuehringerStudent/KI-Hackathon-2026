extends RefCounted
## Base for suites run by run_tests.gd. Use check() instead of assert():
## assert() aborts the run, check() records the failure and keeps going.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
