# Define these choices to set defaults, or define them when calling functions:
# The variable ldak.chunksize sets the number of words to subdivide each document.
# The variable ldak.pos sets Mallet to run only on particular parts of speech.
# The variable ldak.k determines the number of topics to seek.
# Add ldak.stops to filter out words that sneak through, including proper nouns.
# Finally, ldak.project sets the default project name while allowing for files of a number of projects to coexist
ldak.chunksize <- 1000
ldak.pos <- c("NN")
ldak.k <- 45
ldak.stops <- c()
ldak.project <- "import"

# To run:
# 1. load this file
# 2. ldak.make.ready()
# - 2.5 (optional) ldak.make.stopwords
# 3. ldak.make.model()
# 4. ldak.make.analysis()
# - 4.5 (optional) ldak.make.distribution("sex","f","m")

# necessary to avoid hitting any one gutenberg mirror too hard
gutencounter <- sample(1:6, 1)
newurlvector <- c()

# Default k variable set by number of texts?

# Set up and install some required packages
if(!require("XML"))
  install.packages("XML")
if(!require("NLP"))
  install.packages("NLP")
if(!require("openNLP"))
  install.packages("openNLP")
if(!require("plyr"))
  install.packages("plyr")
if(!require("ggplot2"))
  install.packages("ggplot2")
if(!require("reshape2"))
  install.packages("reshape2")

# Start by reading the CSV
if (!file.exists("import.csv")){
  stop("Please make sure to have an import.csv file in the working directory.")
}
ldak.import <- read.csv(paste(ldak.project,".csv",sep=""), colClasses=c(url="character", start.line="character", end.line="character", title="character", year="numeric"))

# Download files to the project folder
# optional variable: download only x texts
makeLocalCopy <- function(url, number, project=ldak.project) {
  ldak.type <- sapply(strsplit(url, split="\\."), tail, 1L)
  # Be kind to Gutenberg by using its mirrors
  urlsplit <- strsplit(url, split="/")[[1]]
  if (length(grep("gutenberg.org",urlsplit))==1) {
    urlnumber <- grep("[0-9]+",urlsplit)
    urlid <- gsub("[\\.a-z\\-]+","",urlsplit[urlnumber])
    stopifnot(length(unique(urlid))==1)
    urlid <- unique(urlid)
    urldigits <- strsplit(urlid,"")[[1]]
    urldigits.top <- urldigits[1:(length(urldigits)-1)]
    urldigits.top <- paste(urldigits.top,collapse="/")
    gutenmirrors <- c("http://mirror.csclub.uwaterloo.ca/gutenberg", "http://sailor.gutenberg.lib.md.us", "http://mirrors.xmission.com/gutenberg", "http://gutenberg.pglaf.org", "http://aleph.gutenberg.org", "http://gutenberg.readingroo.ms")
    newurl <- paste(gutenmirrors[gutencounter],urldigits.top,urlid,paste(urlid,"txt",sep="."),sep="/")
    newurlvector <- c(newurlvector,newurl)
    if (gutencounter>5) {gutencounter <- 1} else {gutencounter <- gutencounter + 1}
    url <- newurl
    ldak.type <- "txt"
  }
  # Continue to download
  ldak.thisfilename <- paste(paste(project,"/texts/",sep=""), number, ".", sep="")
  ldak.thisfilename.type <- paste(ldak.thisfilename, ldak.type, sep="")
  download.file(url, destfile = ldak.thisfilename.type, method="auto")
  # Convert HTML to TXT
  if (!ldak.type=="txt") {
    library(XML)
    char.vec <- paste(readLines(ldak.thisfilename.type, warn = FALSE), collapse=" ")
    doc <- htmlTreeParse(char.vec, useInternalNodes = T)
    text <- unlist(xpathApply(doc, "//p", xmlValue))
    txt <- paste(text, collapse="\n")
    write(txt,file=paste(ldak.thisfilename, "txt", sep=""),append=FALSE,sep="")
  }
  ldak.thisfilename <- paste(ldak.thisfilename, "txt", sep="")
  return(ldak.thisfilename)
}

makeCleanText <- function(filename, start, end){
  dirtytext <- scan(file=filename, what="character", sep="\n", blank.lines.skip = FALSE)
  if(!is.na(suppressWarnings(as.numeric(start)))){} else {
    start <- if(length(grep(start, dirtytext, ignore.case = TRUE))==0) 0 else grep(start, dirtytext, ignore.case = TRUE)
  }
  if(!is.na(suppressWarnings(as.numeric(end)))){
    if(as.numeric(end)<0){
      end <- length(dirtytext)+as.numeric(end)
    }} else {
      end <- if(length(grep(end, dirtytext, ignore.case = TRUE))==0) length(dirtytext) else grep(end, dirtytext, ignore.case = TRUE)+1
    }
  end <- as.numeric(end)-as.numeric(start)
  start <- as.numeric(start)-1
  temp.texts <- paste(unlist(scan(file=filename, what="character", sep="\n", skip=start, nlines=end)), collapse="\n")
  return(temp.texts)
}

# Divide the texts into equal-sized chunks (from Jockers' Text Analysis with R)
makeFlexTextChunks <- function(ldak.doc.text, chunk.size=1000, percentage=TRUE){
  words.regular <- gsub("[^[:alnum:][:space:]']", " ", ldak.doc.text)
  words.l <- strsplit(words.regular, "\\s+")
  word.v <- unlist(words.l)
  x <- seq_along(word.v)
  if(length(word.v) <= chunk.size) {
    chunks.l <- split(word.v, ceiling(x/chunk.size))
  }
  else {
    if(percentage){
      max.length <- length(word.v)/chunk.size
      chunks.l <- split(word.v, ceiling(x/max.length))
    }
    else {
      chunks.l <- split(word.v, ceiling(x/chunk.size))
      if(length(chunks.l[[length(chunks.l)]]) <= chunk.size/2){
        chunks.l[[length(chunks.l)-1]] <- c(chunks.l[[length(chunks.l)-1]], chunks.l[[length(chunks.l)]])
        chunks.l[[length(chunks.l)]] <- NULL
      }
    }
  }
  chunks.l <- lapply(chunks.l, paste, collapse=" ")
  chunks.df <- do.call(rbind, chunks.l)
}

# For finding named entities (proper nouns) for filtering, via https://rpubs.com/lmullen/nlp-chapter
makeEntities <- function(doc, kind) {
  s <- doc$content
  a <- annotations(doc)[[1]]
  if(hasArg(kind)) {
    k <- sapply(a$features, `[[`, "kind")
    s[a[k == kind]]
  } else {
    s[a[a$type == "entity"]]
  }
}

# Filter out everything but given part(s) of speech, via http://stackoverflow.com/questions/30995232/how-to-use-opennlp-to-get-pos-tags-in-r
makeFilterTokens <- function(file, pos, entities=F, project=ldak.project, dir=paste(getwd(), paste("txt", paste(pos,collapse = "-"), sep="-"), sep="/")){
  startfile <- paste(paste(project, "txt/", sep="/"),file,sep="")
  txt <- as.String(readLines(startfile))
  if (!entities==T) {
    if(!require("openNLPmodels.en")) {
      install.packages("openNLPmodels.en",repos = "http://datacube.wu.ac.at/",type = "source")
    }}
  library(NLP)
  library(openNLP)
  wordAnnotation <- NLP::annotate(txt, list(Maxent_Sent_Token_Annotator(), Maxent_Word_Token_Annotator()))
  POSAnnotation <- NLP::annotate(txt, Maxent_POS_Tag_Annotator(), wordAnnotation)
  POSwords <- subset(POSAnnotation, type == "word")
  tags <- sapply(POSwords$features, '[[', "POS")
  ldak.pos.index <- paste("(",paste(pos,collapse="|"),")",sep="")
  thisPOSindex <- grep(paste(ldak.pos.index,"$",sep=""), tags)
  tokenizedAndTagged <- sprintf("%s/%s", txt[POSwords][thisPOSindex], tags[thisPOSindex])
  untokenizedAndTagged <- paste(tokenizedAndTagged, collapse = " ")
  untokenizedAndTagged <- gsub(paste("\\/",ldak.pos.index,sep=""), "", untokenizedAndTagged)
  pos.savefile <- paste(dir, file, sep="/")
  write(untokenizedAndTagged, file=pos.savefile, append = FALSE, sep="")
}

# This function automates the creation of stoplists. Set entity="person" or "location". Or use ldak.make.stopwords().
ldak.filter.name <- function(project=ldak.project, file, kind="person"){
  if (!file.exists(paste(project,"entities",sep="/"))) {dir.create(paste(project, "entities", sep="/"))}
  if (!file.exists(paste(project,"/entities/",kind,"-",file))) {
    startfile <- paste(paste(project, "texts/", sep="/"),file,sep="")
    txt <- as.String(readLines(startfile))
    wordfilter <- NLP::annotate(txt, list(Maxent_Sent_Token_Annotator(), Maxent_Word_Token_Annotator(), Maxent_Entity_Annotator(kind = kind)))
    simple_doc <- AnnotatedPlainTextDocument(txt, wordfilter)
    filterwords <- unlist(makeEntities(simple_doc, kind=kind))
    filterwords <- gsub("\\s+"," ",filterwords)
    filterwords <- unique(gsub("^\\s+|\\s+$", "", filterwords))
    write(filterwords,file=paste(project,"/entities/",kind,"-",file,sep=""),append=FALSE,sep="")
  }
}

makeFilterWords <- function(project=ldak.project, file){
  if (!file.exists(paste(project,"entities",sep="/"))) {dir.create(paste(project, "entities", sep="/"))}
  if (!file.exists(paste(project,"/entities/","both-",file))) {
    startfile <- paste(paste(project, "texts/", sep="/"),file,sep="")
    txt <- as.String(readLines(startfile))
    filterperson <- Maxent_Entity_Annotator(kind = "person")
    filterplace <- Maxent_Entity_Annotator(kind = "location")
    wordfilter <- NLP::annotate(txt, list(Maxent_Sent_Token_Annotator(), Maxent_Word_Token_Annotator(), filterperson, filterplace))
    simple_doc <- AnnotatedPlainTextDocument(txt, wordfilter)
    filterwords <- unlist(makeEntities(simple_doc))
    filterwords <- gsub("\\s+"," ",filterwords)
    filterwords <- unique(gsub("^\\s+|\\s+$", "", filterwords))
    write(filterwords,file=paste(project,"/entities/","both-",file,sep=""),append=FALSE,sep="")
  }
}

### Run this function to download and prepare texts.
ldak.make.ready <- function(project=ldak.project, pos=ldak.pos, chunksize=ldak.chunksize) {
  if (!file.exists(paste(project, ".csv", sep=""))) {
    stop("Please make sure to specify a CSV file in the working directory.")
  }
  if (!file.exists(project)) {dir.create(file.path(getwd(), project))}
  ldak.import <<- read.csv(paste(project,".csv",sep=""), colClasses=c(url="character", start.line="character", end.line="character", title="character", year="numeric"))
  # Load document contents, imputing missing or negative endpoints.
  if (!file.exists(paste(project,"texts",sep="/"))) {
    ldak.filenames <- c()
    dir.create(file.path(getwd(), paste(project,"texts",sep="/")))
    for (number in 1:nrow(ldak.import)) {
      ldak.filenames[number] <- makeLocalCopy(url=ldak.import[number,1], number=number, project=project)
    }
  } else {ldak.filenames <- paste(project,"texts",paste(1:nrow(ldak.import),".txt",sep=""), sep="/")}
  ldak.texts <- c()
  for (number in 1:nrow(ldak.import)) {
    ldak.texts[number] <- makeCleanText(filename=ldak.filenames[number], start=ldak.import[number,2], end=ldak.import[number,3])
  }
  ldak.chunks <- list()
  # If directory "txt" doesn't exist, write text to files in chunks ~1,000 each
  if (!dir.exists(paste(project, "txt", sep="/"))) {
    dir.create(paste(project,"txt",sep="/"))
    for (number in 1:nrow(ldak.import)) {
      ldak.chunks[[number]] <- makeFlexTextChunks(ldak.texts[number], chunk.size = chunksize, percentage = FALSE)
    }
    for (number in 1:length(ldak.chunks)) {
      for (sub in 1:length(ldak.chunks[[number]])) {
        filename <- paste(paste(project,"/txt/",sep=""),number,"-",sub,".txt",sep="")
        write(ldak.chunks[[number]][sub],file=filename,append=FALSE,sep="")
      }
    }
  }
  # If directory "txt-[POS]" doesn't exist, run makeFilterTokens to strip out all but part of speech
  ldak.dir <<- paste(paste(project, "txt-", sep="/"), paste(pos, collapse="-"), sep="")
  if (!dir.exists(ldak.dir)) {
    dir.create(file.path(ldak.dir))
    library(NLP)
    library(openNLP)
    for (file in list.files(path=paste(project, "txt/", sep="/"))) {
      makeFilterTokens(file=file, pos=pos, dir=ldak.dir, entities="both", project=project)
    }
  }
}

### Run this function to automate stopwords.
# It is *very* time intensive.
ldak.make.stopwords <- function(project=ldak.project){
  for (text in 1:nrow(ldak.import)){
    textfile <- paste(text,".txt",sep="")
    makeFilterWords(project=project,file=textfile)
  }
}

# ===== Now it's time to build a model of topics in these documents
# Modified from example_1.R in Neal Audenaert's "Topic Modeling R Tools"

source("functions/lda.R")
source("functions/import.R")

### Run this function to make a topic model of the texts
ldak.make.model <- function(project=ldak.project,k=ldak.k,pos=ldak.pos) {
  # Set data.dir to the directory with data.
  data.dir <- ldak.dir
  # Ready the directory for word clouds
  if (!file.exists(paste(ldak.project,"plots",sep="/"))){
    dir.create(paste(ldak.project,"plots",sep="/"))
  }
  docs <- loadDocuments(data.dir)# from Audenaert's import.R
  # Compile words to the stop list from a few different places
  if (file.exists(paste(ldak.project,"entities",sep="/"))) {
    for (file in list.files(paste(ldak.project,"entities",sep="/"))) {
      thisfile <- paste(ldak.project,"entities",file,sep="/")
      ldak.stops <- c(ldak.stops, readLines(thisfile))
    }
  }
  ldak.stops <- c(ldak.stops, readLines("stop-words/stop-words_english_2_en.txt"))
  ldak.stops <- unique(ldak.stops)
  fileConn <- file(paste(ldak.project,"ldak-stops.txt",sep="/"))
  writeLines(ldak.stops, fileConn)
  close(fileConn)
  stoplist <- paste(ldak.project,"ldak-stops.txt",sep="/")
  # Train a document model with topics numbering as much as ldak.k, ignoring stop words
  model <<- trainSimpleLDAModel(docs, k, stoplist=stoplist)# from Audenaert's example1.R which I've renamed to lda.R
  # Print wordclouds for easy visualization.
  print("printing topic word clouds")
  plotTopicWordcloud(model, verbose=T, output=paste(ldak.project,"plots",sep="/"))
}


### Run this funcion to present results in a useful format
ldak.make.analysis <- function(project=ldak.project){
  # Get and clean up the ids and add them alongside the topics
  library(plyr)
  ldak.ids <- gsub("^n|-.*$","", model$documents[,1])
  ldak.ids <- type.convert(ldak.ids,numerals="no.loss")
  ldak.import <- cbind(id=1:nrow(ldak.import),ldak.import[,4:ncol(ldak.import)])
  ldak.topics <- cbind(ldak.ids, model$docAssignments)
  # Recombine all the chunks for each id by averaging the scores
  mode(ldak.topics) <- "numeric"
  ldak.topics <- ddply(as.data.frame(ldak.topics),.(ldak.ids),numcolwise(mean))
  colnames(ldak.topics)[2:ncol(ldak.topics)] <- paste("Topic", 1:model$K, sep=" ")
  # Calculate number of significant topics per document, using average median score of topics as a threshold
  ldak.averagetopicmedian <- mean(apply(ldak.topics[,2:ncol(ldak.topics)],1,median))
  ldak.topicsabovethreshold <- rowSums(ldak.topics[,2:ncol(ldak.topics)] > ldak.averagetopicmedian)
  ldak.topics <- cbind(id=ldak.topics[,1], topic.count = ldak.topicsabovethreshold, ldak.topics[,2:ncol(ldak.topics)])
  rm(ldak.topicsabovethreshold,ldak.ids)
  # Add data from the import CSV
  ldak.topics <- merge(ldak.import, ldak.topics)
  t.start <- ncol(ldak.import)+2
  t.end <- ncol(ldak.topics)
  # Add useful labels to the topics.
  ldak.topwords <<- c()
  for (topic in 1:ldak.k) {
    ldak.topwords[topic] <<- paste(names(model$getTopic(topic)$getWords(4)), collapse=", ")
  }
  attr(ldak.topics, "variable.labels")[t.start:t.end] <- ldak.topwords
  # Add filtered views for each additional column, and export to CSV.
  ldak.topics.by <<- list()
  ldak.dist <<- list()
  for (ldak.factor in 2:(t.start-2)){
    factorname <- colnames(ldak.topics)[ldak.factor]
    ldak.topics.by[[factorname]] <<- ldak.topics[,c(ldak.factor,t.start:t.end)]
    ldak.topics.by[[factorname]] <<- ddply(as.data.frame(ldak.topics.by[[factorname]]),factorname,numcolwise(mean))
    tempdata <- ldak.topics.by[[factorname]]
    tempnames <- tempdata[,1]
    tempdata[,1] <- NULL
    tempdata <- t(tempdata)
    colnames(tempdata) <- tempnames
    rownames(tempdata) <- paste(gsub("Topic ", "", rownames(tempdata)), ldak.topwords, sep=". ")
    write.csv(tempdata,file=paste(ldak.project,"/topics-by-",factorname,".csv",sep=""))
    # Add a special visualization for binary factors.
    if (nrow(ldak.topics.by[[factorname]])==2) {
      library(reshape2)
      topicnames <<- colnames(ldak.topics.by[[factorname]][,2:ncol(ldak.topics.by[[factorname]])])
      melted <<- melt(ldak.topics.by[[factorname]], id.vars = factorname, measure.vars=topicnames)
      colnames(melted) <<- c(factorname, "Topic", "Distribution")
      melted [,2] <<- paste(gsub("Topic ", "", melted[,2]), ldak.topwords[as.numeric(gsub("Topic ", "", melted[,2]))], sep=". ")
      melted <<- melted[order(melted[[factorname]],melted$Topic),]
      topicavg <<- c()
      for (row in 1:ldak.k) {topicavg[row] <<- melted[row,3]-melted[row+ldak.k,3]}
      topicavg <<- c(topicavg,topicavg)
      melted <<- cbind(melted,topicavg)
      library(ggplot2)
      dist <- ggplot(data=melted, aes_q(x=substitute(reorder(Topic, topicavg)), y=quote(Distribution), fill=as.name(factorname)))
      dist <- dist + geom_bar(data=subset(melted,melted[,1]==ldak.topics.by[[factorname]][1,1]), stat="identity")
      dist <- dist + geom_bar(data=subset(melted,melted[,1]==ldak.topics.by[[factorname]][2,1]), stat="identity", position="identity", mapping=aes(y=-Distribution))
      dist <- dist + scale_y_continuous(labels=abs)
      dist <- dist + xlab("Topics")
      dist <- dist + coord_flip()
      dist <- dist + geom_point(data=subset(melted,melted[,1]==ldak.topics.by[[factorname]][2,1]), mapping=aes(y=topicavg), shape=4, show.legend = F)
      ldak.dist[[factorname]] <<- dist
      print(dist)
      pdf(paste(ldak.project,"/distribution-", factorname, ".pdf", sep=""))
      print(dist)
      dev.off()
      # rm(melted,topicavg,topicnames)
    }
    rm(factorname,tempdata)
  }
  # Export a master CSV file for analysis.
  write.csv(ldak.topics, file=paste(ldak.project,"/topics",paste(ldak.pos,collapse="-"),".csv",sep=""))
  View(ldak.topics)
}


### Run this function to look more closely at particular factors.
# With the sample import.csv, try some of the following:
# ldak.make.distribution("sex","f","m")
# ldak.make.distribution("nationality","american","british")
#
# Note that omitting the third argument compares against the average of the whole corpus:
# ldak.make.distribution("title","Tender Buttons")
ldak.make.distribution <- function(factorname,compare,compare2="average",project=ldak.project){
  library(reshape2)
  average <<- t(data.frame(colMeans(ldak.topics.by[[factorname]][2:ncol(ldak.topics.by[[factorname]])])))
  average <<- cbind(factorname = "average",average)
  colnames(average)[1] <<- factorname
  rownames(average) <<- NULL
  fac.dist <<- ldak.topics.by[[factorname]]
  fac.dist <<- rbind(fac.dist,average)
  topicnames <<- colnames(fac.dist[,2:ncol(fac.dist)])
  melted <<- melt(fac.dist, id.vars = factorname, measure.vars=topicnames)
  melted <<- subset(melted,melted[,1] %in% c(compare, compare2))
  colnames(melted) <<- c(factorname, "Topic", "Distribution")
  melted[,2] <<- paste(gsub("Topic ", "", melted[,2]), ldak.topwords[as.numeric(gsub("Topic ", "", melted[,2]))], sep=". ")
  melted[,3] <<- sapply(melted[,3], function(x) as.numeric(levels(x))[x])
  tosort <- c(compare,compare2)
  melted <<- melted[order(match(melted[[factorname]],tosort),melted$Topic),]
  topicavg <<- c()
  for (row in 1:ldak.k) {topicavg[row] <<- melted[row,3]-melted[row+ldak.k,3]}
  topicavg <<- c(topicavg,topicavg)
  melted <<- cbind(melted,topicavg)
  library(ggplot2)
  dist <- ggplot(data=melted, aes_q(x=substitute(reorder(Topic, topicavg)), y=quote(Distribution), fill=as.name(factorname)))
  dist <- dist + geom_bar(data=subset(melted,melted[,1]==compare), stat="identity")
  dist <- dist + geom_bar(data=subset(melted,melted[,1]==compare2), stat="identity", position="identity", mapping=aes(y=-Distribution))
  dist <- dist + scale_y_continuous(labels=abs)
  dist <- dist + xlab("Topics") + scale_fill_discrete(breaks = c(compare,compare2))
  dist <- dist + coord_flip()
  dist <- dist + geom_point(data=subset(melted,melted[,1]==compare2), mapping=aes(y=topicavg), shape=4, show.legend = F)
  print(dist)
}

# Acknowledgments (to be added to a NOTICES file)
# conversion of HTML to text adapted from Tony Breyal
# https://github.com/tonybreyal/Blog-Reference-Functions/blob/master/R/htmlToText/htmlToText.R
#
# This project includes code derived from Audenaert, "Topic Modeling R Tools"
# https://github.com/audenaert/TopicModelingRTools