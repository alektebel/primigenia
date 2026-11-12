# cpore — top-level build.
# core/ is the simulation: libc + libm only, no graphics (DESIGN.md Q31, Q50).
CC      ?= cc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra -Wno-unused-parameter -fno-fast-math
CFLAGS  += -Icore/include -D_POSIX_C_SOURCE=200809L
LDLIBS   = -lm
BUILD   := build

CORE_SRC := $(wildcard core/src/*.c)
CORE_OBJ := $(CORE_SRC:%.c=$(BUILD)/%.o)
HDRS     := $(wildcard core/include/cpore/*.h)

.PHONY: all core lib test bench smoke studio clean check-core
all: core $(BUILD)/cpore_test $(BUILD)/cpore_bench

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

test: $(BUILD)/cpore_test check-core
	./$(BUILD)/cpore_test
bench: $(BUILD)/cpore_bench
	./$(BUILD)/cpore_bench
smoke: lib
	python3 bindings/python/smoke_test.py

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

clean:
	rm -rf $(BUILD)
	$(MAKE) -C studio-sdl clean 2>/dev/null || true
