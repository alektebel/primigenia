extends RefCounted
## Opt-in, main-thread, exclusive script buckets. Nested work is subtracted from its caller.
static var enabled := false
static var totals: Dictionary = {}
static var calls: Dictionary = {}
static var _stack: Array = []

static func begin() -> void:
	_stack.append([Time.get_ticks_usec(), 0])

static func end(key: StringName) -> void:
	var scope: Array = _stack.pop_back()
	var elapsed: int = Time.get_ticks_usec() - int(scope[0])
	totals[key] = int(totals.get(key, 0)) + elapsed - int(scope[1])
	calls[key] = int(calls.get(key, 0)) + 1
	if not _stack.is_empty():
		_stack.back()[1] += elapsed

static func clear() -> void:
	totals.clear()
	calls.clear()
