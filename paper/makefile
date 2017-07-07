latexfile 	= linvis
figures		=
$(latexfile).pdf : $(figures) $(latexfile).tex citations.bib
	rubber --pdf $(latexfile)


.PHONY: clean proper baseline

clean:
	rubber --clean $(latexfile)
	rm -f new.tex

proper:
	rubber --clean $(latexfile)
	rm -f $(latexfile).synctex $(latexfile).synctex.gz $(latexfile).pdf
	rm -f $(latexfile).brf
	rm -f new.tex

baseline: old.tex

diff.tex : old.tex new.tex
	latexdiff old.tex new.tex | perl -pe 's/^\\drafttrue//' > diff.tex

new.tex : $(latexfile).tex macros.tex
	latexpand --expand-bbl $(latexfile).bbl $(latexfile).tex > new.tex

diff.pdf: diff.tex
	pdflatex diff.tex

old.tex: 
	latexpand --expand-bbl $(latexfile).bbl $(latexfile).tex > old.tex

