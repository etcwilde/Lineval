latexfile 	= lineval
files		= abstract.tex introduction.tex color.tex macros.tex generalization.tex userstudy.tex references.bib makefile
data		= data/tree_size.csv
figures		=

$(latexfile).pdf : $(latexfile).tex $(files) $(data) $(figures)
	rubber --pdf $(latexfile)


.PHONY: clean clean-full


clean:
	rubber --clean $(latexfile)

clean-full: clean
	rm -f $(latexfile).synctex $(latexfile).synctex.gz
	rm -f $(latexfile).brf
	rm -f $(latexfile).pdf
