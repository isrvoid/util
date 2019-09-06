ifeq ($(RELEASE), 1)
	DFLAGS := -O -release -boundscheck=off
else
	DFLAGS := -debug
endif

BUILDDIR := bin

UNITTESTSRC := src/util/removecomments.d src/util/aspectnames.d

$(BUILDDIR)/unittest: $(UNITTESTSRC)
	@dmd $(DFLAGS) -unittest -main $^ -of$@

$(BUILDDIR)/aspectnames: src/util/aspectnames.d src/util/removecomments.d
	@dmd $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
