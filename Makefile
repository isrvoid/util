ifeq ($(RELEASE), 1)
	DFLAGS := -O -release -boundscheck=off
else
	DFLAGS := -debug -unittest
endif

BUILDDIR := bin

$(BUILDDIR)/aspectid: src/util/aspectid.d src/util/removecomments.d
	@$(DC) $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
