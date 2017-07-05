latexfile 	= lineval
sections	= abstract.tex introduction.tex methodology.tex results.tex discussion.tex
files		= color.tex macros.tex
data		= data/tree_size.csv data/merge_counts.csv
figures		=
misc 		= makefile
output		= output/

# Phony Targets

.PHONY: all clean clean-full
all: $(output) $(output)$(latexfile).pdf

clean:
	rubber --clean $(latexfile)

clean-full: clean
	rm -f $(latexfile).synctex $(latexfile).synctex.gz
	rm -f $(latexfile).brf
	rm -f $(output)$(latexfile).pdf

# Primary targets

$(output)$(latexfile).pdf : $(latexfile).tex $(sections) $(files) $(data) $(figures) $(misc)
	rubber  --pdf $(latexfile)
	mv $(latexfile).pdf output/$(latexfile).pdf

$(output):
	mkdir -p $(output)
