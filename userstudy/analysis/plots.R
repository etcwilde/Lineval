#!/usr/bin/Rscript
# Jul 01, 2017
# Evan Wilde
library(RSQLite)
library(fitdistrplus)

pdf("figures/results.pdf", width=17, height=12)
par(mfrow=c(3, 7), mai=c(0.4, 0.3, 0.3, 0.2))
print(par('mai'))

colorScheme <- c("#3366CC", "#DC3912", "#FF9900", "#109618", "#990099", "#3B3EAC")
colorSchemeTrans <- c("#3366CC99", "#DC391299", "#FF990099", "#10961899", "#99009999", "#3B3EAC99")
con <- dbConnect(drv=dbDriver('SQLite'), dbname='data/data.db')

correctness_ignore <- c(4, 8)
timing_ignore <- c(6)

# Aggregated Correctness

query_response_correct <- "
SELECT question, cid, 'Correct' AS result, tools.name AS tool FROM summarize
JOIN outcomes ON summarize.outcome = outcomes.id
JOIN tools ON summarize.tool = tools.id
WHERE summarize.outcome = 1
UNION ALL
SELECT question, cid, 'Incorrect' AS result, tools.name AS tool FROM summarize
JOIN outcomes ON summarize.outcome = outcomes.id
JOIN tools ON summarize.tool = tools.id
WHERE summarize.outcome != 1
"
data <- dbGetQuery(con, query_response_correct)
questions <- sort(unique(data$question))
cids <- sort(unique(data$cid))


for (question in questions) {
  if (question %in% correctness_ignore) {
    print(paste(c("Skipping T", question+1), collapse=''))
    plot.new()
    title(main=paste(c('T', question + 1), collapse=''))
    next
  }
  d <- data[(data$question == question),]
  counts <- table(d$tool, d$result)
  barplot(counts, legend=rownames(counts), beside=TRUE,
          ylim=c(0,25),
          main=paste(c('T', question + 1), sep='', collapse=''),
          col=colorSchemeTrans[1:2],
          border=colorScheme[1:2])
}

# Aggregated Accuracy

accuracy_query <- "
SELECT lt.question AS question,
lt.cid,
lt.distance AS lindist,
gt.distance AS gitdist,
(gt.distance - lt.distance) AS 'diff'
FROM
(SELECT user, cid, question, distance FROM summarize WHERE tool = 1) AS lt
JOIN
(SELECT user, cid, question, distance FROM summarize WHERE tool = 2) AS gt
ON
lt.user = gt.user AND
lt.question = gt.question AND
lt.cid = gt.cid
WHERE
diff IS NOT null;
"

data <- dbGetQuery(con, accuracy_query)
maxdist <- max(max(data$lindist), max(data$gitdist))
eps <- 0.000001

for (q in questions) {
  d <- data[(data$question == q),]

  if (length(unlist(d)) == 0) {
    plot.new()
  } else {
  boxplot(data.frame(d$gitdist, d$lindist),
          names=list('Gitk', 'Linvis'),
          ylim=c(0, maxdist),
          col=colorSchemeTrans)
  }
}

# Aggregated Time

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
maxtime <- max(max(data$gittime), max(data$lintime))
print(maxtime)
eps <- 0.000001

for (q in questions) {

  if (q %in% timing_ignore) {
    print(paste(c("Skipping T", q+1), collapse=''))
    plot.new()
    next
  }

  d <- data[(data$question == q),]
  boxplot(data.frame(d$gittime, d$lintime), names=list('Gitk', 'Linvis'),
          ylab='Time (seconds)',
          ylim=c(0,maxtime),
          col=colorSchemeTrans)
}


# Unaggregated Correctness

data <- dbGetQuery(con, query_response_correct)
for (q in correctness_ignore) {
  pdf(paste(c("figures/correctness/", q+1, '.pdf'), collapse=''))
  par(mfrow=c(1, 2))
  for (c in cids) {
    d <- data[(data$question == q & data$cid == c),]
    counts <- table(d$tool, d$result)
    barplot(counts, legend=rownames(counts), beside=TRUE,
          ylim=c(0,13),
          main=paste(c('Commit', c ), sep='', collapse=' '),
          col=colorSchemeTrans[1:2],
          border=colorScheme[1:2])
  }
}

# Unaggregated Timing
data <- dbGetQuery(con, time_query)
for (q in timing_ignore) {
  pdf(paste(c("figures/time/", q+1, '.pdf'), collapse=''))
  par(mfrow=c(1, 2))
  for (c in cids) {
    d <- data[(data$question == q & data$cid == c),]
    boxplot(data.frame(d$gittime, d$lintime), names=list('Gitk', 'Linvis'),
          ylab='Time (seconds)',
          ylim=c(0,maxtime),
          main=paste(c("Commit", c), sep='', collapse=' '),
          col=colorSchemeTrans)
  }
}


dbDisconnect(con)
