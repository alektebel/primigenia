# cpore — top-level build.
# core/ is the simulation: libc + libm only, no graphics (DESIGN.md Q31, Q50).
CC      ?= cc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra -Wno-unused-parameter -fno-fast-math
override CFLAGS += -Icore/include -D_POSIX_C_SOURCE=200809L
# Determinism (DESIGN.md Q24, G25/P2): no fused multiply-add contraction anywhere.
override CFLAGS += -fno-fast-math -ffp-contract=off
LDLIBS   = -lm
BUILD   := build

CORE_SRC := $(wildcard core/src/*.c)
CORE_OBJ := $(CORE_SRC:%.c=$(BUILD)/%.o)
HDRS     := $(wildcard core/include/cpore/*.h)

.PHONY: all core lib test bench tourney smoke studio blender blender-mcp-setup blender-mcp-smoke blender-sample-parts clean check-core serve play check
all: $(BUILD)/world_cli core $(BUILD)/cpore_test $(BUILD)/cpore_bench $(BUILD)/combat_test $(BUILD)/combat_tourney

core: $(BUILD)/libcpore.a $(BUILD)/libcpore.so
lib: $(BUILD)/libcpore.so

$(BUILD)/%.o: %.c $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -fPIC -c $< -o $@

$(BUILD)/libcpore.a: $(CORE_OBJ)
	ar rcs $@ $^
$(BUILD)/libcpore.so: $(CORE_OBJ)
	$(CC) -shared -o $@ $^ $(LDLIBS)

$(BUILD)/cpore_test: tests/test_core.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
$(BUILD)/steer_test: tests/test_steer.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
$(BUILD)/cpore_bench: apps/bench.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

# Combat (P2): bots and the duel runner live in apps/ and are shared by the tests and the tourney.
$(BUILD)/apps/combat_bots.o: apps/combat_bots.c apps/combat_bots.h $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -fPIC -Iapps -c $< -o $@
$(BUILD)/combat_test: tests/test_combat.c core/src/combat.c apps/combat_bots.h $(BUILD)/apps/combat_bots.o $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -DCP_COMBAT_TEST -Iapps $< core/src/combat.c $(BUILD)/apps/combat_bots.o $(BUILD)/libcpore.a -o $@ $(LDLIBS)
$(BUILD)/combat_tourney: apps/combat_tourney.c apps/combat_bots.h $(BUILD)/apps/combat_bots.o $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -Iapps $< $(BUILD)/apps/combat_bots.o $(BUILD)/libcpore.a -o $@ $(LDLIBS)

$(BUILD)/combat_tourney_test: tests/test_combat_tourney.c apps/combat_tourney.c apps/combat_bots.h $(BUILD)/apps/combat_bots.o $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -Iapps $< $(BUILD)/apps/combat_bots.o $(BUILD)/libcpore.a -o $@ $(LDLIBS)

$(BUILD)/combat_golden: tests/combat_golden.c apps/combat_bots.h $(BUILD)/apps/combat_bots.o $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -Iapps $< $(BUILD)/apps/combat_bots.o $(BUILD)/libcpore.a -o $@ $(LDLIBS)

# Correctness regressions. Balance acceptance is a separate measured gate:
# run make tourney as well before claiming P2 acceptance.
test: $(BUILD)/parts_nest_test $(BUILD)/plan_test $(BUILD)/social_test $(BUILD)/world_cli $(BUILD)/world_test $(BUILD)/terrain_test $(BUILD)/cpore_test $(BUILD)/combat_test $(BUILD)/combat_tourney_test $(BUILD)/combat_golden check-core $(BUILD)/nav_test $(BUILD)/steer_test $(BUILD)/routes_test secrets-test
	nice -n 10 ./$(BUILD)/terrain_test
	./$(BUILD)/world_test
	./$(BUILD)/social_test
	nice -n 10 ./$(BUILD)/nav_test
	./$(BUILD)/steer_test
	@for g in world-1 world-42 world-987654321 world-debug-42 world-field-1; do ./$(BUILD)/world_cli --replay tests/golden/$$g.log | diff -q - tests/golden/$$g.hashes >/dev/null || { echo "world_cli replay of $$g differs from its .hashes"; exit 1; }; done; echo "world_cli replays match the golden hashes"
	@sed "s/ 5ef8636377460348/ 5ef8636377460345/" tests/golden/world-field-1.log > $(BUILD)/world-field-bad.log; ! ./$(BUILD)/world_cli --replay $(BUILD)/world-field-bad.log 2>$(BUILD)/world-field-bad.err >/dev/null && grep -q "terrain hash mismatch" $(BUILD)/world-field-bad.err && echo "a field log with an edited hash is refused"
	python3 tests/test_terrain_metrics.py
	./$(BUILD)/cpore_test
	./$(BUILD)/combat_test
	./$(BUILD)/moves_recipes_test
	./$(BUILD)/parts_nest_test
	./$(BUILD)/plan_test
	./$(BUILD)/combat_tourney_test
	python3 tests/test_combat_golden.py ./$(BUILD)/combat_golden
	python3 tools/routes/fixtures.py --check
	@failed=0; for seed in 1 7 42; do nice -n 10 ./$(BUILD)/routes_test $$seed || failed=1; done; test $$failed -eq 0
tourney: $(BUILD)/combat_tourney
	./$(BUILD)/combat_tourney
bench: $(BUILD)/cpore_bench
	./$(BUILD)/cpore_bench
smoke: lib $(BUILD)/world_cli
	python3 bindings/python/smoke_test.py
	python3 bindings/python/world_smoke.py
	python3 bindings/python/lineage_smoke.py
	python3 bindings/python/social_smoke.py
	python3 bindings/python/parts_nest_smoke.py
	python3 bindings/python/moves_recipes_smoke.py

# The core may only depend on libc/libm: fail if any core object pulls in more.
check-core: $(BUILD)/libcpore.so
	@! ldd $(BUILD)/libcpore.so | grep -v -E 'linux-vdso|libc\.so|libm\.so|ld-linux' | grep -q '=>' \
	  || (echo "core links something beyond libc/libm"; exit 1)
	@! grep -l -E '#include *[<"](SDL|GL|epoxy|X11)' core/src/*.c core/include/cpore/*.h \
	  || (echo "core includes a graphics header"; exit 1)
	@echo "core: libc + libm only"

# Transitional: the SDL creature studio until it moves to web/ (DESIGN.md Q49).
studio:
	$(MAKE) -C studio-sdl

blender-mcp-setup:
	npm ci --prefix tools/blender-mcp

blender:
	CPORE_PROJECT_ROOT=$(CURDIR) blender --python tools/blender-mcp/addon.py

blender-mcp-smoke:
	npm --prefix tools/blender-mcp run smoke

blender-sample-parts:
	blender --background --python tools/blender-mcp/sample_parts.py

clean:
	rm -rf $(BUILD)
	$(MAKE) -C studio-sdl clean 2>/dev/null || true

# P3a: Emscripten stays optional; native `make test` never invokes it.
# Run each recipe in bash so an installed SDK can supply emcc when absent on PATH.
WASM_SRC := core/src/combat.c core/src/rng.c apps/combat_bots.c
WASM_FLAGS := -O2 -std=c99 -Wall -Wextra -fno-fast-math -ffp-contract=off -Icore/include -Iapps
EMCC_RUN = bash -c 'if ! command -v emcc >/dev/null 2>&1; then \
  if test -f "$$HOME/emsdk/emsdk_env.sh"; then source "$$HOME/emsdk/emsdk_env.sh" >/dev/null 2>&1; fi; \
  fi; command -v emcc >/dev/null 2>&1 || { echo "Emscripten not found: put emcc on PATH or install ~/emsdk/emsdk_env.sh" >&2; exit 1; }; exec emcc "$$@"' --
WASM_EXPORTS := '[_cb_layout,_cb_setup,_cb_reset,_cb_order,_cb_step,_cb_tick,_cb_count,_cb_states,_cb_event_count,_cb_events,_cb_hash,_cb_preview,_cb_bot_init,_cb_bot_decide]'

.PHONY: wasm wasm-parity
wasm: $(BUILD)/wasm/cpore_combat.mjs $(BUILD)/wasm/cpore_combat.wasm
$(BUILD)/wasm/cpore_combat.mjs $(BUILD)/wasm/cpore_combat.wasm &: $(WASM_SRC) apps/wasm_api.c apps/combat_bots.h $(HDRS) Makefile
	@mkdir -p $(dir $@)
	$(EMCC_RUN) $(WASM_FLAGS) $(WASM_SRC) apps/wasm_api.c --no-entry -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=web,node -sEXPORTED_FUNCTIONS=$(WASM_EXPORTS) -sEXPORTED_RUNTIME_METHODS=HEAP8,HEAPU8,HEAPU32 -o $(BUILD)/wasm/cpore_combat.mjs
$(BUILD)/wasm/%.cjs $(BUILD)/wasm/%.wasm &: tests/%.c $(WASM_SRC) apps/combat_bots.h $(HDRS) Makefile
	@mkdir -p $(dir $@)
	$(EMCC_RUN) $(WASM_FLAGS) $< $(WASM_SRC) -sENVIRONMENT=node -sNODERAWFS=1 -o $(BUILD)/wasm/$*.cjs
$(BUILD)/combat_parity: tests/combat_parity.c apps/combat_bots.h $(BUILD)/apps/combat_bots.o $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -Iapps $< $(BUILD)/apps/combat_bots.o $(BUILD)/libcpore.a -o $@ $(LDLIBS)
wasm-parity: $(BUILD)/wasm/combat_golden.cjs $(BUILD)/wasm/combat_golden.wasm $(BUILD)/wasm/combat_parity.cjs $(BUILD)/wasm/combat_parity.wasm $(BUILD)/combat_parity
	nice -n 10 python3 tests/test_wasm_parity.py

.PHONY: wasm-test
wasm-test: wasm wasm-parity
	nice -n 10 node tests/test_wasm_combat.mjs

# P3b: serve the repo root on port 8765 before the browser acceptance targets.
# CPORE_STAGE_URL may select a private server; CPORE_STAGE_EVIDENCE redirects artifacts.
# Playwright must already be available (e.g. through NODE_PATH); no install step.
.PHONY: stage stage-test studio-test
stage:
	python3 tools/stage/build_stage.py
stage-test: wasm $(BUILD)/combat_parity stage
	python3 tests/test_stage_build.py
	nice -n 10 node tests/test_stage_sim.mjs
	nice -n 10 node tests/stage_winnability.mjs
	nice -n 10 node tests/stage_play.cjs
	nice -n 10 node tests/stage_polish.cjs
studio-test:
	nice -n 10 python3 tests/check_studio_glbs.py
	nice -n 10 node tests/test_growth.cjs
	nice -n 10 node tests/test_studio_genome.cjs
	@mkdir -p $(BUILD)/studio-tests
	CPORE_ARTIFACT_DIR=$(BUILD)/studio-tests nice -n 10 node tests/studio_interaction.cjs
	CPORE_ARTIFACT_DIR=$(BUILD)/studio-tests nice -n 10 node tests/studio_touch.cjs
	G48_TEST_OUTPUT=$(BUILD)/studio-tests/g48-tests.json nice -n 10 node tests/studio_procedural_parts.cjs

# W11: native smoke remains small; 1024 guarantees and parity are opt-in.
TERRAIN_SRC := core/src/terrain.c core/src/rng.c
$(BUILD)/terrain_cli: apps/terrain_cli.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
$(BUILD)/terrain_test: tests/test_terrain.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
.PHONY: terrain-test
# Never regenerate committed goldens during tests.
terrain-test: $(BUILD)/terrain_test $(BUILD)/terrain_cli
	nice -n 10 ./$(BUILD)/terrain_test --heavy

TERRAIN_EXPORTS := '[_ct_config,_ct_deltas,_ct_features,_ct_rivers,_ct_river,_ct_material,_ct_cave_count,_ct_caves,_ct_volcano,_ct_generate,_ct_map,_ct_hash,_ct_version,_ct_size]'
wasm: $(BUILD)/wasm/cpore_terrain.mjs $(BUILD)/wasm/cpore_terrain.wasm
$(BUILD)/wasm/cpore_terrain.mjs $(BUILD)/wasm/cpore_terrain.wasm &: $(TERRAIN_SRC) apps/terrain_wasm_api.c $(HDRS) Makefile
	@mkdir -p $(dir $@)
	$(EMCC_RUN) $(WASM_FLAGS) $(TERRAIN_SRC) apps/terrain_wasm_api.c --no-entry -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=web,worker,node -sINITIAL_MEMORY=50331648 -sEXPORTED_FUNCTIONS=$(TERRAIN_EXPORTS) -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPU32,HEAPU8 -o $(BUILD)/wasm/cpore_terrain.mjs
.PHONY: terrain-parity
terrain-parity: $(BUILD)/terrain_cli $(BUILD)/wasm/cpore_terrain.mjs $(BUILD)/wasm/cpore_terrain.wasm
	nice -n 10 node tests/test_wasm_terrain.mjs
terrain-test: terrain-parity
wasm-test: terrain-parity

.PHONY: terrain-metrics
terrain-metrics: $(BUILD)/terrain_cli
	nice -n 10 python3 tools/terrain/metrics.py --cli $(BUILD)/terrain_cli --n 1024 --seeds 1,7,42,99,1234,31337 --workdir $(BUILD)/terrain --json $(BUILD)/terrain/metrics.json --check
terrain-test: terrain-metrics

# G56: world simulation (the cell-stage world.c retains its historical name).
$(BUILD)/libcpore.a $(BUILD)/libcpore.so: $(BUILD)/apps/combat_bots.o
$(BUILD)/world_test: tests/test_world.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
WORLD_SRC := $(CORE_SRC) apps/combat_bots.c
WORLD_EXPORTS := '[_cw_version,_cw_config,_cw_profile,_cw_spawn,_cw_obstacle,_cw_reset,_cw_height,_cw_ground,_cw_step,_cw_hash,_cw_meta,_cw_entities,_cw_orders,_cw_observe,_cb_layout,_cb_tick,_cb_count,_cb_states,_cb_event_count,_cb_events,_cb_hash,_cb_preview]'
wasm: $(BUILD)/wasm/cpore_world.mjs $(BUILD)/wasm/cpore_world.wasm
$(BUILD)/wasm/cpore_world.mjs $(BUILD)/wasm/cpore_world.wasm &: $(WORLD_SRC) apps/world_wasm_api.c apps/wasm_api.c apps/combat_bots.h $(HDRS) Makefile
	@mkdir -p $(dir $@)
	$(EMCC_RUN) $(WASM_FLAGS) -sINITIAL_MEMORY=134217728 -sSTACK_SIZE=8388608 -sALLOW_MEMORY_GROWTH=1 $(WORLD_SRC) apps/world_wasm_api.c --no-entry -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=web,node -sEXPORTED_FUNCTIONS=$(WORLD_EXPORTS) -sEXPORTED_RUNTIME_METHODS=HEAP8,HEAPU8,HEAPU32,UTF8ToString -o $(BUILD)/wasm/cpore_world.mjs
$(BUILD)/world_cli: apps/world_cli.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
world-test: $(BUILD)/world_test $(BUILD)/world_cli wasm
	nice -n 10 ./$(BUILD)/world_test
	nice -n 10 node tests/test_wasm_world.mjs
wasm-test: world-test
stage-test: $(BUILD)/world_cli

.PHONY: world-test world-coverage
world-coverage: $(BUILD)/libcpore.a
	@mkdir -p $(BUILD)/world-coverage
	python3 -c 'from pathlib import Path; [p.unlink() for p in Path("$(BUILD)/world-coverage").glob("*.gcda")]'
	nice -n 10 $(CC) $(CFLAGS) -O0 --coverage -c $(CURDIR)/core/src/stage_world.c -o $(BUILD)/world-coverage/stage_world.o
	nice -n 10 $(CC) $(CFLAGS) -O0 --coverage tests/test_world.c $(BUILD)/world-coverage/stage_world.o $(BUILD)/libcpore.a -o $(BUILD)/world-coverage/unit $(LDLIBS)
	nice -n 10 $(CC) $(CFLAGS) -O0 --coverage apps/world_cli.c $(BUILD)/world-coverage/stage_world.o $(BUILD)/libcpore.a -o $(BUILD)/world-coverage/cli $(LDLIBS)
	nice -n 10 ./$(BUILD)/world-coverage/unit
	@for seed in 1 42 987654321; do nice -n 10 ./$(BUILD)/world-coverage/cli --replay tests/golden/world-$$seed.log >/dev/null || exit 1; done
	cd $(BUILD)/world-coverage && gcov -b -c stage_world.gcno

# ── convenience targets ──────────────────────────────────────────────
SERVE_PORT ?= 8765

.PHONY: serve
serve:
	python3 -m http.server 8090 --bind 127.0.0.1

.PHONY: play
play:
	@echo "Open these URLs in your browser:"
	@echo "  http://127.0.0.1:8090/web/studio/"
	@echo "  http://127.0.0.1:8090/web/stage/"
	@echo "  http://127.0.0.1:8090/web/terrain-lab/"

# Helper that runs a recipe, guaranteeing the background server dies.
#  $1 = port to check
define start_server
	@_pid=0; \
	if _p=$$(python3 -c 'import socket; s=socket.socket(); s.settimeout(0.5); r=s.connect_ex(("127.0.0.1",$1)); s.close(); print(r)' 2>/dev/null) && [ "$$_p" = "0" ]; then \
	  echo "Port $1 already in use — skipping server (tests that need it will fail)"; \
	else \
	  python3 -m http.server $1 --bind 127.0.0.1 >/dev/null 2>&1 & _pid=$$!; \
	  echo "Started http server on port $1 (PID $$_pid)"; \
	fi; \
	echo "$$_pid"
endef

# Full verification pipeline: C tests → WASM → terrain → studio → stage (browser).
# Runs with nice -n 10; stops the server afterwards even on failure.
.PHONY: check
check:
	@echo "=== make check ==="
	@echo ""
	@echo "--- preflight: playwright? ---"
	@if [ ! -d "$$(echo $(NODE_PATH) 2>/dev/null)/playwright" ] && \
	   ! python3 -c 'import playwright' 2>/dev/null && \
	   ! node -e 'require("playwright")' 2>/dev/null; then \
	  echo "ERROR: playwright not found in NODE_PATH."; \
	  echo "  export NODE_PATH=/path/to/node_modules"; \
	  echo "  (or install playwright first)"; \
	  exit 1; \
	fi
	@echo ""
	@echo "--- 1/5 make test (C unit tests) ---"
	@nice -n 10 make test
	@echo ""
	@echo "--- 2/5 make wasm-test (WASM parity + browser test) ---"
	@nice -n 10 make wasm-test
	@echo ""
	@echo "--- 3/5 make terrain-test (terrain + WASM) ---"
	@nice -n 10 make terrain-test
	@echo ""
	@echo "--- 4-5/5 make studio-test + make stage-test (browser; one shared server on $(SERVE_PORT)) ---"
	@mkdir -p $(BUILD)/studio-tests
	@set -e; _pid=""; \
	if python3 -c 'import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(("127.0.0.1",$(SERVE_PORT)))==0 else 1)'; then \
	  echo "Port $(SERVE_PORT) already serving; reusing it"; \
	else \
	  setsid python3 -m http.server $(SERVE_PORT) --bind 127.0.0.1 >$(BUILD)/check-server.log 2>&1 & _pid=$$!; \
	  for i in $$(seq 50); do python3 -c 'import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(("127.0.0.1",$(SERVE_PORT)))==0 else 1)' && break; sleep 0.2; done; \
	  echo "Started http server on port $(SERVE_PORT) (PID $$_pid)"; \
	fi; \
	trap '[ -n "$$_pid" ] && kill $$_pid 2>/dev/null || true' EXIT; \
	nice -n 10 $(MAKE) studio-test; \
	nice -n 10 $(MAKE) stage-test
	@echo "=== make check done ==="

# ---- Godot desktop frontend (G76). Dependencies live outside the repository. ----
GODOT ?= godot
GODOT_CPP ?= /home/diego/Desarrollo/cpore-wt/_agent/godot-cpp
SCONS ?= /home/diego/Desarrollo/cpore-wt/_agent/godot-venv/bin/scons
GODOT_JOBS ?= 4
GODOT_TARGET ?= template_debug
.PHONY: godot godot-test godot-render-test godot-evidence
godot: $(BUILD)/libcpore.a
	GODOT_CPP=$(GODOT_CPP) nice -n 10 $(SCONS) -C godot/extension -j$(GODOT_JOBS) \
	  target=$(GODOT_TARGET) build_profile=$(CURDIR)/godot/extension/build_profile.json
	@mkdir -p godot/.godot
	@test -s godot/.godot/extension_list.cfg || echo 'res://cpore.gdextension' > godot/.godot/extension_list.cfg
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import
godot-test: godot $(BUILD)/terrain_cli $(BUILD)/world_cli
	nice -n 10 timeout 900 $(GODOT) --headless --path godot --script res://game/tests/run_m0_tests.gd
godot-render-test: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/render_tests.gd
godot-evidence: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/m0_evidence.gd -- $(CURDIR)/docs/evidence/godot/m0
# Godot UI + audio headless tests (M3).
godot-ui-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://tests/ui_test.gd
.PHONY: godot-ui-test
# The stage picker (main menu), headless; the second run checks that --play skips the menu.
.PHONY: godot-menu-test godot-menu-evidence
godot-menu-test:
	nice -n 10 timeout 300 $(GODOT) --headless --path godot --script res://game/tests/test_menu.gd
	nice -n 10 timeout 300 $(GODOT) --headless --path godot --script res://game/tests/test_menu.gd -- --play
godot-menu-evidence:
	@mkdir -p docs/evidence/godot/stage-menu
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/menu_evidence.gd -- $(CURDIR)/docs/evidence/godot/stage-menu
# The cell stage (godot/cell): play it, and its headless sim tests.
.PHONY: godot-cell godot-cell-test godot-cell-evidence
godot-cell:
	$(GODOT) --path godot -- --cell
godot-cell-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://cell/tests/cell_test.gd
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://cell/tests/cell_ui_test.gd
godot-cell-evidence:
	@mkdir -p docs/evidence/godot/cell
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a $(GODOT) --rendering-driver opengl3 --path godot --script res://cell/tests/cell_evidence.gd -- $(CURDIR)/docs/evidence/godot/cell
# DT0 dev tools (PLAN-devtools): headless unit tests, evidence screenshots, agent socket test.
.PHONY: godot-devtools-test godot-devtools-evidence godot-agent-test
godot-devtools-test: godot
	nice -n 10 timeout 600 $(GODOT) --headless --fixed-fps 60 --path godot --script res://devtools/tests/run_devtools_tests.gd
godot-devtools-evidence: godot
	@mkdir -p docs/evidence/godot/devtools
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 \
	  --resolution 1280x720 --path godot --script res://devtools/tests/evidence.gd -- $(CURDIR)/docs/evidence/godot/devtools
godot-heights-test: godot
	@mkdir -p docs/evidence/godot/heights
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://game/tests/test_heights.gd -- $(CURDIR)/docs/evidence/godot/heights
.PHONY: godot-heights-test
godot-agent-test: godot
	nice -n 10 timeout 300 python3 godot/devtools/agent/test_agent.py --godot $(GODOT)
# G76 M2: Godot studio headless tests, then the web validator cross-check on what Godot wrote.
.PHONY: godot-studio-test
godot-studio-test:
	@mkdir -p $(BUILD)/studio-godot
	nice -n 10 timeout 600 $(GODOT) --headless --path godot/studio --script res://tests/test_studio.gd
	node godot/studio/tests/node_check.js
# Creator direct manipulation (wheel scale, joints, spine arrows, actuator ring), real view, real input path.
.PHONY: godot-studio-ix-test godot-studio-ix-evidence
godot-studio-ix-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://studio/tests/test_interaction.gd
godot-studio-ix-evidence:
	@mkdir -p docs/evidence/godot/creator-ix
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 30 --resolution 1280x720 --path godot \
	  --script res://studio/tests/ix_evidence.gd -- $(CURDIR)/docs/evidence/godot/creator-ix
# Godot creature module (M1a, godot/creature). Headless tests; the import step
# refreshes Godot's class_name cache. Evidence renders use software GL only.
.PHONY: godot-creature-test godot-creature-evidence
godot-creature-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import >/dev/null 2>&1 || true
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://creature/tests/test_creature.gd
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://creature/tests/test_realism.gd
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://creature/tests/test_radial.gd
# Radial body plans (docs/godot/CREATURE-RADIAL.md): per-species views, gait strips, lineup, island habitats, bilateral guard.
.PHONY: godot-radial-evidence
godot-radial-evidence:
	@mkdir -p docs/evidence/godot/radial
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 xvfb-run -a $(GODOT) --rendering-driver opengl3 --path godot --script res://creature/tools/radial_evidence.gd -- $(CURDIR)/docs/evidence/godot/radial
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 --path godot --script res://game/tests/radial_island_evidence.gd -- $(CURDIR)/docs/evidence/godot/radial
	nice -n 10 $(GODOT) --headless --path godot --script res://creature/tools/mesh_hashes.gd 2>&1 | grep -v "^WARN\|   at:" | tee docs/evidence/godot/radial/bilateral_unchanged.txt
godot-creature-evidence:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import >/dev/null 2>&1 || true
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 --path godot --script res://creature/tools/render_evidence.gd
# Opt-in high-quality renderer tier (Forward+ / Vulkan: SSAO, SSIL, soft shadows, TAA; docs/godot/CREATURE-REALISM.md).
# Needs a Vulkan GPU, so run it on the desktop; the default tier stays GL Compatibility. Studio = the game's creator screen.
.PHONY: godot-play-hq godot-creature-realism-shots
godot-play-hq: godot
	$(GODOT) --rendering-method forward_plus --rendering-driver vulkan --path godot
# Before/after JPGs of the four pilot creatures (software GL; CPORE_REALISM=0 gives the old look). Usage: make godot-creature-realism-shots TAG=after
godot-creature-realism-shots:
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 --path godot \
	  --script res://creature/tools/realism_shots.gd -- $(CURDIR)/docs/evidence/godot/creature-realism $(or $(TAG),after)
.PHONY: godot-loco-test
godot-loco-test:
	cd godot && timeout 300 nice -n 10 timeout 600 $(GODOT) --headless --path . --script locomotion/test/run_tests.gd

# The whole game, headless: main -> menu -> Play -> encounter, rig contract, studio -> save -> Play (godot/game/tests/play_test.gd).
.PHONY: godot-play-test godot-wire-evidence
QUALITY ?=
godot-play-test: godot
	nice -n 10 timeout 900 $(GODOT) --headless --fixed-fps 60 --path godot --script res://game/tests/play_test.gd $(if $(QUALITY),-- $(QUALITY),)
godot-wire-evidence: godot
	@mkdir -p docs/evidence/godot/wire
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1200 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/wire_evidence.gd -- $(CURDIR)/docs/evidence/godot/wire

# CAMERA-ZOOM s4 evidence: the z = 0..1 strip and frame times on the real island (software GL).
.PHONY: godot-camera-evidence
godot-camera-evidence: godot
	@mkdir -p docs/evidence/godot/camera
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --resolution 1280x720 --path godot \
	  --script res://game/tests/camera_evidence.gd -- $(CURDIR)/docs/evidence/godot/camera

# Rock and terrain material (docs/godot/PLAN-rock.md). Evidence frames use software GL; the benchmark does NOT: the owner
# runs it on the real GPU (make godot-rock-bench TIER=auto). Read it as mean/p95 frame ms per view (docs/godot/ROCK.md).
.PHONY: godot-rock-evidence godot-rock-bench godot-rock-stretch-test
ROCK_OUT ?= $(CURDIR)/docs/evidence/godot/rock/after
TIER ?= auto
ROCK_VIEWS ?= chase,mid,far,cliff_lit,cliff_shade
ROCK_GRASS ?= 60000
ROCK_MASKS ?= masks
godot-rock-evidence: godot
	@mkdir -p $(ROCK_OUT)
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/rock_evidence.gd -- $(ROCK_OUT) $(ROCK_VIEWS) $(ROCK_GRASS) $(ROCK_MASKS)
godot-rock-bench: godot
	@mkdir -p $(CURDIR)/docs/evidence/godot/rock
	nice -n 5 timeout 1800 $(GODOT) --path godot --resolution 1920x1080 --script res://game/tests/bench_terrain.gd -- $(CURDIR)/docs/evidence/godot/rock $(TIER)
# Same benchmark under llvmpipe, only for a relative new/old ratio (a few frames; never a GPU number).
.PHONY: godot-rock-bench-sw
godot-rock-bench-sw: godot
	@mkdir -p $(ROCK_OUT)
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --resolution 1280x720 --path godot \
	  --script res://game/tests/bench_terrain.gd -- $(ROCK_OUT) $(TIER) 40 10 60000
# Terrain v5 (visual erosion, docs/TERRAIN.md): generator timings and memory (CPU), look frames (8 views + 4 close-ups, software GL) and the GPU
# benchmark the owner runs on the RTX (make godot-terrain-bench TIER=high; windowed, vsync off; writes docs/evidence/godot/terrain-v5/bench-*.json).
.PHONY: godot-visual-bench godot-terrain-look godot-terrain-bench
# v5's frames stay in terrain-v5/after (the "before" of the photographic materials, docs/godot/ROCK.md).
LOOK_OUT ?= $(CURDIR)/docs/evidence/godot/terrain-photo/after
BENCH_OUT ?= $(CURDIR)/docs/evidence/godot/terrain-photo
LOOK_VIEWS ?= cliff_lit,cliff_shade,ridge,scree,valley,coast,far,river,mid,close_gully,close_scree,close_cliff,close_bank,close_cave
godot-visual-bench: godot
	@mkdir -p docs/evidence/godot/terrain-v5
	nice -n 10 timeout 900 $(GODOT) --headless --path godot --script res://game/tests/bench_visual.gd -- 1 $(CURDIR)/docs/evidence/godot/terrain-v5/bench-visual-gen.json
godot-terrain-look: godot
	@mkdir -p $(LOOK_OUT)
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1700 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/look_evidence.gd -- $(LOOK_OUT) $(LOOK_VIEWS)
godot-terrain-bench: godot
	@mkdir -p $(BENCH_OUT)
	nice -n 5 timeout 1800 $(GODOT) --path godot --resolution 1920x1080 --script res://game/tests/bench_terrain.gd -- $(BENCH_OUT) $(TIER)
# The same benchmark under llvmpipe (a few frames, a relative ratio against another checkout's run, never a GPU number).
.PHONY: godot-terrain-bench-sw
godot-terrain-bench-sw: godot
	@mkdir -p $(BENCH_OUT)
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --resolution 1280x720 --path godot \
	  --script res://game/tests/bench_terrain.gd -- $(BENCH_OUT) $(TIER) 40 10 60000
# The stretch, sign and strata tests, once per quality tier (low, medium, high).
godot-rock-stretch-test: godot
	for t in low medium high; do \
	  LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --path godot \
	    --script res://game/tests/rock_stretch_test.gd -- $$t || exit 1; \
	done

# PLAN-feel: how the creature feels to steer (C motion rule + the real Godot pipeline), writes docs/evidence/godot/feel/measurements.json.
.PHONY: godot-feel-test godot-feel-evidence
godot-feel-test: godot
	nice -n 10 timeout 600 $(GODOT) --headless --fixed-fps 60 --path godot --script res://game/tests/feel_test.gd -- $(CURDIR)/docs/evidence/godot/feel
godot-feel-evidence: godot
	@mkdir -p docs/evidence/godot/feel
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 --path godot \
	  --script res://game/tests/feel_evidence.gd -- $(CURDIR)/docs/evidence/godot/feel

# Procedural action animation (G77, godot/actions): headless tests with a scripted feed (no GDExtension needed).
.PHONY: godot-actions-test godot-actions-evidence
godot-actions-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import >/dev/null 2>&1 || true
	cd godot && nice -n 10 timeout 900 $(GODOT) --headless --path . --script actions/test/run_tests.gd
godot-actions-evidence:
	@mkdir -p docs/evidence/godot/actions
	cd godot && LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1200 xvfb-run -a $(GODOT) --rendering-driver opengl3 --resolution 1280x720 --path . \
	  --script actions/test/capture.gd -- out=$(CURDIR)/docs/evidence/godot/actions $(ARGS)

# C1-nav: GO pathfinding on the generated island (20 seeded far targets, planner timing, determinism).
$(BUILD)/nav_test: tests/test_nav.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -O2 $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
.PHONY: nav-test
nav-test: $(BUILD)/nav_test
	nice -n 10 ./$(BUILD)/nav_test

# A21 evidence: the hotbar and the loadout panel (software GL).
.PHONY: godot-loadout-evidence
godot-loadout-evidence: godot
	@mkdir -p docs/evidence/godot/loadout
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 \
	  --resolution 1280x720 --path godot --script res://game/tests/loadout_evidence.gd -- $(CURDIR)/docs/evidence/godot/loadout

# ---- lore (docs/LORE-FORMAT.md, tools/lore/README.md) ----
.PHONY: lore-check lore-refcheck
lore-check:
	python3 -m unittest discover tools/lore/tests
	python3 tools/lore/validate.py
	python3 tools/lore/render.py
	git diff --exit-code -- docs/creatures docs/lore
	@if git status --porcelain docs/creatures docs/lore | grep -q '^??'; then echo "untracked rendered docs: git add them"; exit 1; fi
lore-refcheck:
	python3 tools/lore/refcheck.py

$(BUILD)/lineage_test: tests/test_lineage_ledger.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
test: lineage-test
.PHONY: lineage-test
lineage-test: $(BUILD)/lineage_test $(BUILD)/lineage_evolution_test $(BUILD)/lineage_social_test
	./$(BUILD)/lineage_social_test
	./$(BUILD)/lineage_test
	./$(BUILD)/lineage_evolution_test
$(BUILD)/lineage_evolution_test: tests/test_lineage_evolution.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

$(BUILD)/lineage_social_test: tests/test_lineage_social.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

$(BUILD)/creature_types_test: tests/test_creature_types.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
test: creature-types-test
.PHONY: creature-types-test
creature-types-test: $(BUILD)/creature_types_test
	./$(BUILD)/creature_types_test

.PHONY: godot-lineage-test godot-lineage-evidence
godot-lineage-test: godot
	nice -n 10 timeout 60 $(GODOT) --headless --path godot --check-only --script res://game/tests/lineage_test.gd
	nice -n 10 timeout 120 $(GODOT) --headless --path godot --script res://game/tests/lineage_test.gd
	nice -n 10 timeout 60 $(GODOT) --headless --path godot --check-only --script res://game/tests/lineage_island_test.gd
	nice -n 10 timeout 180 $(GODOT) --headless --path godot --script res://game/tests/lineage_island_test.gd
godot-lineage-evidence: godot
	nice -n 10 timeout 60 $(GODOT) --headless --path godot --check-only --script res://game/tests/lineage_test.gd
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/lineage_test.gd -- --evidence
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/lineage_island_test.gd -- --evidence
# C2 social layer (core/src/stage_social.c)
$(BUILD)/social_test: tests/test_social.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

# The diegetic UI (docs/godot/UI-DIEGETIC.md, PLAN-ui-diegetic.md). Render test of the ground marks (software GL), then one capture per mockup state (JPG).
.PHONY: godot-ground-marks-render-test
godot-ground-marks-render-test: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/render_ground_marks.gd
.PHONY: godot-ui-diegetic-evidence
godot-ui-diegetic-evidence: godot
	@mkdir -p docs/evidence/godot/ui-diegetic
	for run in "move_marker,idle,selected,befriend,combat,carcass,low_health,menu,loadout,keys,minimap midday" \
	  "befriend dawn" "combat evening" "sheet midday"; do \
	  LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" \
	    $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	    --script res://tests/ui_diegetic_evidence.gd -- $(CURDIR)/docs/evidence/godot/ui-diegetic $$run || exit 1; \
	done

# C2 social loop through the real island and UI (software GL). Evidence strip: make godot-social-evidence
.PHONY: godot-social-test godot-social-evidence
godot-social-test: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/social_flow.gd
# Ten simulated minutes on the real island through the real input path (software GL under xvfb); a strip of JPG frames
# goes to docs/evidence/godot/soak/. Wall time is 15-25 minutes on a loaded machine. Script errors fail the target.
.PHONY: godot-soak
godot-soak: godot
	@mkdir -p docs/evidence/godot/soak
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/island_soak.gd -- $(CURDIR)/docs/evidence/godot/soak $(or $(MINUTES),10) 2>&1 | tee /tmp/godot-soak.log; \
	  ! grep -q "SCRIPT ERROR" /tmp/godot-soak.log && grep -q "^soak: .* 0 failures" /tmp/godot-soak.log
godot-social-evidence: godot
	@mkdir -p docs/evidence/godot/social
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/social_flow.gd -- $(CURDIR)/docs/evidence/godot/social

.PHONY: godot-zoo-evidence
godot-zoo-evidence: godot
	@mkdir -p docs/evidence/godot/steering
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --resolution 1280x720 --path godot \
	  --script res://devtools/tests/zoo_evidence.gd -- $(CURDIR)/docs/evidence/godot/steering

$(BUILD)/plan_test: tests/test_plan.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

$(BUILD)/parts_nest_test: tests/test_parts_nest.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)

.PHONY: godot-parts-nest-test
godot-parts-nest-test:
	$(GODOT) --headless --path godot --check-only --script res://game/tests/parts_nest_test.gd
	$(GODOT) --headless --path godot --script res://game/tests/parts_nest_test.gd
# C1 curated round trips, actual steering and deterministic trajectory replay.
$(BUILD)/routes_test: tests/test_routes.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
.PHONY: routes-test
routes-test: $(BUILD)/routes_test
	python3 tools/routes/fixtures.py --check
	@failed=0; for seed in 1 7 42; do nice -n 10 ./$(BUILD)/routes_test $$seed || failed=1; done; test $$failed -eq 0
.PHONY: godot-route-events-test
godot-route-events-test: godot
	nice -n 10 timeout 120 $(GODOT) --headless --path godot --script res://game/tests/test_route_events.gd

$(BUILD)/moves_recipes_test: tests/test_moves_recipes.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) -DCP_COMBAT_TEST $< core/src/combat.c $(BUILD)/libcpore.a -o $@ $(LDLIBS)
test: $(BUILD)/moves_recipes_test

.PHONY: godot-moves-recipes-test
godot-moves-recipes-test:
	$(GODOT) --headless --path godot --check-only --script res://game/tests/moves_recipes_test.gd
	$(GODOT) --headless --path godot --script res://game/tests/moves_recipes_test.gd

# C2 secrets: meteor shards, hidden cave chamber, day/night, Acechalunas and Babosa (tests/test_secrets.c)
$(BUILD)/secrets_test: tests/test_secrets.c $(HDRS) $(BUILD)/libcpore.a
	$(CC) $(CFLAGS) $< $(BUILD)/libcpore.a -o $@ $(LDLIBS)
.PHONY: secrets-test
secrets-test: $(BUILD)/secrets_test
	nice -n 10 ./$(BUILD)/secrets_test flat
	@failed=0; for seed in 1 7 42; do nice -n 10 ./$(BUILD)/secrets_test $$seed || failed=1; done; test $$failed -eq 0

# The field journal (G38, godot/ui/journal_*.gd): every section and spread, ES and EN, plus overflow cases (software GL, JPG).
# Small laptop: make godot-journal-evidence RES=1024x600 SUFFIX=_1024x600
.PHONY: godot-journal-evidence
godot-journal-evidence: godot
	@mkdir -p docs/evidence/godot/journal
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 $(or $(RES),1280x720)x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution $(or $(RES),1280x720) --path godot \
	  --script res://game/tests/journal_evidence.gd -- $(CURDIR)/docs/evidence/godot/journal $(SUFFIX)

# Nest overlay layout, Esc and the end-of-lineage overlay at small-laptop sizes (software GL, JPG).
.PHONY: godot-journal-nest-evidence
godot-journal-nest-evidence: godot
	@mkdir -p docs/evidence/godot/journal/nest
	for cfg in "1280 720 es" "1024 600 es" "1024 600 en"; do set -- $$cfg; \
	  LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 $$1x$$2x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution $$1x$$2 --path godot \
	    --script res://game/tests/journal_nest_evidence.gd -- $(CURDIR)/docs/evidence/godot/journal/nest $$3 _$$1x$$2_$$3 || exit 1; done
