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
test: $(BUILD)/world_test $(BUILD)/terrain_test $(BUILD)/cpore_test $(BUILD)/combat_test $(BUILD)/combat_tourney_test $(BUILD)/combat_golden check-core
	nice -n 10 ./$(BUILD)/terrain_test
	./$(BUILD)/world_test
	python3 tests/test_terrain_metrics.py
	./$(BUILD)/cpore_test
	./$(BUILD)/combat_test
	./$(BUILD)/combat_tourney_test
	python3 tests/test_combat_golden.py ./$(BUILD)/combat_golden
tourney: $(BUILD)/combat_tourney
	./$(BUILD)/combat_tourney
bench: $(BUILD)/cpore_bench
	./$(BUILD)/cpore_bench
smoke: lib $(BUILD)/world_cli
	python3 bindings/python/smoke_test.py
	python3 bindings/python/world_smoke.py

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
	nice -n 10 node tests/test_stage_camera.mjs
	nice -n 10 node tests/test_stage_boot.mjs
	nice -n 10 node tests/stage_winnability.mjs
	nice -n 10 node tests/stage_play.cjs
	nice -n 10 node tests/stage_polish.cjs
	nice -n 10 node tests/stage_camera.cjs
.PHONY: stage-firefox-test
stage-firefox-test: wasm stage
	nice -n 10 python3 tests/stage_firefox.py
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

TERRAIN_EXPORTS := '[_ct_config,_ct_deltas,_ct_features,_ct_material,_ct_cave_count,_ct_caves,_ct_volcano,_ct_generate,_ct_map,_ct_hash,_ct_version,_ct_size]'
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
WORLD_SRC := core/src/stage_world.c $(WASM_SRC)
WORLD_EXPORTS := '[_cw_version,_cw_config,_cw_profile,_cw_spawn,_cw_obstacle,_cw_reset,_cw_height,_cw_ground,_cw_step,_cw_hash,_cw_meta,_cw_entities,_cw_orders,_cw_observe,_cb_layout,_cb_tick,_cb_count,_cb_states,_cb_event_count,_cb_events,_cb_hash,_cb_preview]'
wasm: $(BUILD)/wasm/cpore_world.mjs $(BUILD)/wasm/cpore_world.wasm
$(BUILD)/wasm/cpore_world.mjs $(BUILD)/wasm/cpore_world.wasm &: $(WORLD_SRC) apps/world_wasm_api.c apps/wasm_api.c apps/combat_bots.h $(HDRS) Makefile
	@mkdir -p $(dir $@)
	$(EMCC_RUN) $(WASM_FLAGS) $(WORLD_SRC) apps/world_wasm_api.c --no-entry -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=web,node -sEXPORTED_FUNCTIONS=$(WORLD_EXPORTS) -sEXPORTED_RUNTIME_METHODS=HEAP8,HEAPU8,HEAPU32,UTF8ToString -o $(BUILD)/wasm/cpore_world.mjs
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
