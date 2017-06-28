latexfile 	= lineval
sections	= abstract.tex introduction.tex methodology.tex results.tex
files		= color.tex macros.tex
data		= data/tree_size.csv data/merge_counts.csv
figures		=

$(latexfile).pdf : $(latexfile).tex $(sections) $(files) $(data) $(figures)
	rubber --pdf $(latexfile)


.PHONY: clean clean-full


clean:
	rubber --clean $(latexfile)

clean-full: clean
	rm -f $(latexfile).synctex $(latexfile).synctex.gz
	rm -f $(latexfile).brf
	rm -f $(latexfile).pdf
