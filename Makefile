ifeq ($(RELEASE), 1)
	DFALGS := -O -release -boundscheck=off
else
	DLFAGS := -debug
endif


BUILDDIR := bin
SRCDIR := src

UNITTESTSRC := $(SRCDIR)/util/removecomments.d

$(BUILDDIR)/unittest: $(UNITTESTSRC)
	@dmd $(DFLAGS) -unittest -main $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
