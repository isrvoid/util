ifeq ($(RELEASE), 1)
	DFALGS := -O -release -boundscheck=off
else
	DLFAGS := -debug
endif

BUILDDIR := bin

UNITTESTSRC := src/util/removecomments.d src/util/aspectnames.d

$(BUILDDIR)/unittest: $(UNITTESTSRC)
	@dmd $(DFLAGS) -unittest -main $^ -of$@

$(BUILDDIR)/aspectnames: src/util/aspectnames.d src/util/removecomments.d
	@dmd $(DLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
