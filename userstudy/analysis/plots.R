#!/usr/bin/Rscript
# Jul 01, 2017
# Evan Wilde
library(RSQLite)
library(fitdistrplus)

pdf("figures/results.pdf", width=17, height=12)
par(mfrow=c(3, 7))

colorScheme <- c("#3366CC", "#DC3912", "#FF9900", "#109618", "#990099", "#3B3EAC")
colorSchemeTrans <- c("#3366CC99", "#DC391299", "#FF990099", "#10961899", "#99009999", "#3B3EAC99")
con <- dbConnect(drv=dbDriver('SQLite'), dbname='data/data.db')

query_response_correct <- "
SELECT question, 'Correct' AS result, tools.name AS tool FROM summarize
JOIN outcomes ON summarize.outcome = outcomes.id
JOIN tools ON summarize.tool = tools.id
WHERE summarize.outcome = 1
UNION ALL
SELECT question, 'Incorrect' AS result, tools.name AS tool FROM summarize
JOIN outcomes ON summarize.outcome = outcomes.id
JOIN tools ON summarize.tool = tools.id
WHERE summarize.outcome != 1
"
data <- dbGetQuery(con, query_response_correct)
questions <- sort(unique(data$question))

for (question in questions) {
  d <- data[(data$question == question),]
  counts <- table(d$tool, d$result)
  barplot(counts, legend=rownames(counts), beside=TRUE,
          ylim=c(0,25),
          main=paste(c('T', question + 1), sep='', collapse=''),
          col=colorSchemeTrans[1:2],
          border=colorScheme[1:2])
}


accuracy_query <- "
SELECT lt.question AS question,
lt.distance AS lindist,
gt.distance AS gitdist,
(gt.distance - lt.distance) AS 'diff'
FROM
(SELECT user, question, distance FROM summarize WHERE tool = 1) AS lt
JOIN
(SELECT user, question, distance FROM summarize WHERE tool = 2) AS gt
ON
lt.user = gt.user AND
lt.question = gt.question
WHERE
diff IS NOT null;
"

data <- dbGetQuery(con, accuracy_query)
eps <- 0.000001

for (q in questions) {
  d <- data[(data$question == q),]

  if (length(unlist(d)) == 0) {
    plot.new()
  } else {
  boxplot(data.frame(d$gitdist, d$lindist),
          names=list('Gitk', 'Linvis'),
          col=colorSchemeTrans)
  }
}


time_query <- "
SELECT lt.cid AS cid, lt.question AS question,
lt.time AS lintime,
gt.time AS gittime,
(gt.time - lt.time) AS 'diff' FROM
(SELECT user, cid, question, time FROM summarize WHERE tool = 1) AS lt
JOIN
(SELECT user, cid, question, time FROM summarize WHERE tool = 2) AS gt
ON
lt.user = gt.user AND
lt.question = gt.question AND
lt.cid = gt.cid;
"

data <- dbGetQuery(con, time_query)
eps <- 0.000001

for (q in questions) {
  d <- data[(data$question == q),]
  boxplot(data.frame(d$gittime, d$lintime), names=list('Gitk', 'Linvis'),
          ylab='Time (seconds)',
          col=colorSchemeTrans)
}



dbDisconnect(con)
