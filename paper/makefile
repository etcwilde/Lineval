latexfile 	= lineval
sections	= abstract.tex introduction.tex methodology.tex results.tex discussion.tex
files		= color.tex macros.tex
data		= data/tree_size.csv data/merge_counts.csv
figures		= figures/userstudy/correctness/question-3.pdf figures/userstudy/timing/q3.pdf figures/userstudy/accuracy/q3.pdf
misc 		= makefile

$(latexfile).pdf : $(latexfile).tex $(sections) $(files) $(data) $(figures) $(misc)
	rubber --pdf $(latexfile)


.PHONY: clean clean-full


clean:
	rubber --clean $(latexfile)

clean-full: clean
	rm -f $(latexfile).synctex $(latexfile).synctex.gz
	rm -f $(latexfile).brf
	rm -f $(latexfile).pdf
