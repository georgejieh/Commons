class_name FileMode
extends RefCounted
## The one place that decides whether the file's detectors act (ADR 0022): a build made
## with a release export template acts; a development or debug build, and every tool and
## test, only logs. A controller's FileWatch reads it once, and a test may turn acting on
## for a controller it builds.


## True in a build made with a release export template, where the detectors act.
static func release_build() -> bool:
	return OS.has_feature("template") and not OS.is_debug_build()
