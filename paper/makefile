latexfile 	= lineval
files		= abstract.tex introduction.tex color.tex macros.tex references.bib makefile
figures		=

$(latexfile).pdf : $(latexfile).tex $(files) $(figures)
	rubber --pdf $(latexfile)


.PHONY: clean clean-full


clean:
	rubber --clean $(latexfile)

clean-full: clean
	rm -f $(latexfile).synctex $(latexfile).synctex.gz
	rm -f $(latexfile).brf
	rm -f $(latexfile).pdf
