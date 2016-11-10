# Define these choices to set defaults, or define them when calling functions:
# The variable set.chunksize sets the number of words to subdivide each document.
# The variable set.pos sets Mallet to run only on particular parts of speech.
# The variable set.k determines the number of topics to seek.
# Add set.stops to filter out words that sneak through, including proper nouns.
# Finally, set.project sets the default project name while allowing for files of a number of projects to coexist
set.chunksize <- 1000
set.pos <- c("NN")
set.k <- 50
set.stops <- c()
set.project <- "import"
set.stability <- FALSE
set.stability.seed <- 1

get.project <- function(url,projectname){
  download.file(url, destfile = paste(projectname,".csv",sep=""), method="auto")
  write("", file = paste(projectname,".csv",sep=""), append=TRUE)
  set.project <<- projectname
}

# To run:
# 1. load this file
# 2. do.preparation()
# - 2.5 (optional) do.stopwords()
# 3. do.model()
# 4 do.comparison("sex","f","m") 

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
if(!require("scales"))
  install.packages("scales")

# Download files to the project folder
# future variable: download only x texts
makeLocalCopy <- function(url, number, project=set.project) {
  tk.type <- sapply(strsplit(url, split="\\."), tail, 1L)
  if (length(grep("/",tk.type))>0) tk.type <- "html"
  # Be kind to Gutenberg by using its mirrors
  urlsplit <- strsplit(url, split="/")[[1]]
  if (length(grep("gutenberg.org",urlsplit))==1) {
    urlnumber <- grep("[0-9]+",urlsplit)
    urlid <- gsub("[\\.a-z\\-]+","",urlsplit[urlnumber])
    urlid <- unique(urlid)
    urldigits <- strsplit(urlid[1],"")[[1]]
    urldigits.top <- urldigits[1:(length(urldigits)-1)]
    if (length(urlid)>1) {
      urldigits.bottom <- paste(urlid[1],"-8.txt",sep="")
    } else {
      urldigits.bottom <- paste(urlid[1],".txt",sep="")
      }
    urldigits.top <- paste(paste(urldigits.top,collapse="/"),paste(urldigits,collapse=""),sep="/")
    mirrors <- c("http://mirror.csclub.uwaterloo.ca/gutenberg", "http://sailor.gutenberg.lib.md.us", "http://mirrors.xmission.com/gutenberg", "http://gutenberg.pglaf.org", "http://aleph.gutenberg.org", "http://gutenberg.readingroo.ms")
    newurl <- paste(gutenmirrors[gutencounter],urldigits.top,urldigits.bottom,sep="/")
    newurlvector <- c(newurlvector,newurl)
    if (gutencounter>5) {gutencounter <<- 1} else {gutencounter <<- gutencounter + 1}
    url <- newurl
    tk.type <- "txt"
  }
  # Continue to download
  tk.thisfilename <- paste(paste(project,"/texts/",sep=""), number, ".", sep="")
  tk.thisfilename.type <- paste(tk.thisfilename, tk.type, sep="")
  download.file(url, destfile = tk.thisfilename.type)
  # Convert HTML to TXT
  if (!tk.type=="txt") {
    library(XML)
    char.vec <- paste(readLines(tk.thisfilename.type, warn = FALSE), collapse=" ")
    # doc <- htmlTreeParse(char.vec, useInternalNodes = T)
    # text <- unlist(xpathApply(doc, "//p", xmlValue))
    doc <- htmlParse(char.vec, asText = T)
    text <- xpathSApply(doc, "//text()[not(ancestor::script)][not(ancestor::style)][not(ancestor::noscript)][not(ancestor::form)]", xmlValue)
    # toggle above
    txt <- paste(text, collapse="\n")
    write(txt,file=paste(tk.thisfilename, "txt", sep=""),append=FALSE,sep="")
  }
  tk.thisfilename <- paste(tk.thisfilename, "txt", sep="")
  return(tk.thisfilename)
}

makeCleanText <- function(filename, start, end){
  dirtytext <- scan(file=filename, what="character", sep="\n", blank.lines.skip = FALSE)
  if(!is.na(suppressWarnings(as.numeric(start)))) {this.start <- start} else {
    this.start <- if(length(grep(start, dirtytext, ignore.case = TRUE))==0) 0 else grep(start, dirtytext, ignore.case = TRUE)
  }
  if(!is.na(suppressWarnings(as.numeric(end)))){
    if(as.numeric(end)<0){
      end <- length(dirtytext)+as.numeric(end)
    }} else {
      end <- if(length(grep(end, dirtytext, ignore.case = TRUE))==0) length(dirtytext) else grep(end, dirtytext, ignore.case = TRUE)+1
    }
  this.end <- as.numeric(end)-as.numeric(this.start)
  this.start <- as.numeric(this.start)-1
  temp.texts <- paste(unlist(scan(file=filename, what="character", sep="\n", skip=this.start, nlines=this.end)), collapse="\n")
  return(temp.texts)
}

# Divide the texts into equal-sized chunks (from Jockers' Text Analysis with R)
makeFlexTextChunks <- function(tk.doc.text, chunk.size=1000, percentage=TRUE){
  words.regular <- gsub("[^[:alnum:][:space:]']", " ", tk.doc.text)
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
makeFilterTokens <- function(file, pos, entities=F, project=set.project, dir=paste(getwd(), paste("txt", paste(pos,collapse = "-"), sep="-"), sep="/")){
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
  set.pos.index <- paste("(",paste(pos,collapse="|"),")",sep="")
  thisPOSindex <- grep(paste(set.pos.index,"$",sep=""), tags)
  tokenizedAndTagged <- sprintf("%s/%s", txt[POSwords][thisPOSindex], tags[thisPOSindex])
  untokenizedAndTagged <- paste(tokenizedAndTagged, collapse = " ")
  untokenizedAndTagged <- gsub(paste("\\/",set.pos.index,sep=""), "", untokenizedAndTagged)
  pos.savefile <- paste(dir, file, sep="/")
  write(untokenizedAndTagged, file=pos.savefile, append = FALSE, sep="")
}

# This function automates the creation of stoplists. Set entity="person" or "location". Or use do.stopwords().
tk.filter.name <- function(project=set.project, file, kind="person"){
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

makeFilterWords <- function(project=set.project, file){
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
do.preparation <- function(project=set.project, pos=set.pos, chunksize=set.chunksize) {
  if (!file.exists(paste(project, ".csv", sep=""))) {
    stop("Please make sure to specify a CSV file in the working directory.")
  }
  if (!file.exists(project)) {dir.create(file.path(getwd(), project))}
  tk.import <<- read.csv(paste(project,".csv",sep=""), colClasses="character")
  # Load document contents, imputing missing or negative endpoints.
  tk.filenames <- c()
  if (!file.exists(paste(project,"texts",sep="/"))) {dir.create(file.path(getwd(), paste(project,"texts",sep="/")))}
  for (number in 1:nrow(tk.import)) {
    if (!file.exists(paste(project,"texts",paste(number,".txt",sep=""),sep="/"))){
      tk.filenames[number] <- makeLocalCopy(url=tk.import[number,1], number=number, project=project)
    }
  }
  tk.filenames <- paste(project,"texts",paste(1:nrow(tk.import),".txt",sep=""), sep="/")
  tk.texts <- c()
  for (number in 1:nrow(tk.import)) {
    tk.texts[number] <- makeCleanText(filename=tk.filenames[number], start=tk.import[number,2], end=tk.import[number,3])
  }
  tk.chunks <- list()
  # If directory "txt" doesn't exist, write text to files in chunks ~1,000 each
  if (!dir.exists(paste(project, "txt", sep="/"))) {
    dir.create(paste(project,"txt",sep="/"))
    for (number in 1:nrow(tk.import)) {
      tk.chunks[[number]] <- makeFlexTextChunks(tk.texts[number], chunk.size = chunksize, percentage = FALSE)
    }
    for (number in 1:length(tk.chunks)) {
      for (sub in 1:length(tk.chunks[[number]])) {
        filename <- paste(paste(project,"/txt/",sep=""),number,"-",sub,".txt",sep="")
        write(tk.chunks[[number]][sub],file=filename,append=FALSE,sep="")
      }
    }
  }
  # If directory "txt-[POS]" doesn't exist, run makeFilterTokens to strip out all but part of speech
  tk.dir <<- paste(paste(project, "txt-", sep="/"), paste(pos, collapse="-"), sep="")
  if (!dir.exists(tk.dir)) {
    dir.create(file.path(tk.dir))
    library(NLP)
    library(openNLP)
    for (file in list.files(path=paste(project, "txt/", sep="/"))) {
      makeFilterTokens(file=file, pos=pos, dir=tk.dir, entities="both", project=project)
    }
  }
  print("Next, run do.stopwords(), or skip ahead to do.model().")
}

### Run this function to automate stopwords.
# It is time intensive.
do.stopwords <- function(project=set.project){
  for (text in 1:nrow(tk.import)){
    textfile <- paste(text,".txt",sep="")
    makeFilterWords(project=project,file=textfile)
  }
}

# ===== Now it's time to build a model of topics in these documents
# Modified from example_1.R in Neal Audenaert's "Topic Modeling R Tools"

source("functions/lda.R")
source("functions/import.R")

### Run this function to make a topic model of the texts
do.model <- function(project=set.project,k=set.k,pos=set.pos,wordclouds=T,stability=set.stability) {
  # Set data.dir to the directory with data.
  data.dir <- tk.dir
  # Ready the directory for word clouds
  if (!file.exists(paste(set.project,"plots",sep="/"))){
    dir.create(paste(set.project,"plots",sep="/"))
  }
  docs <- loadDocuments(data.dir)# from Audenaert's import.R
  # Compile words to the stop list from a few different places
  if (file.exists(paste(set.project,"entities",sep="/"))) {
    for (file in list.files(paste(set.project,"entities",sep="/"))) {
      thisfile <- paste(set.project,"entities",file,sep="/")
      set.stops <- c(set.stops, readLines(thisfile))
    }
  }
  set.stops <- c(set.stops, readLines("stopwords.txt"))
  set.stops <- unique(tolower(set.stops))
  fileConn <- file(paste(set.project,"tk-stops.txt",sep="/"))
  writeLines(set.stops, fileConn)
  close(fileConn)
  stoplist <<- paste(set.project,"tk-stops.txt",sep="/")
  # Train a document model with topics numbering as much as set.k, ignoring stop words
  model <<- trainSimpleLDAModel(docs, k, stoplist=stoplist)# from Audenaert's example1.R which I've renamed to lda.R
  # Print wordclouds for easy visualization.
  if (wordclouds==T) {
    print("printing topic word clouds")
    plotTopicWordcloud(model, verbose=T, output=paste(set.project,"plots",sep="/"))
  }
  print("preparing results for analysis")
  # Get and clean up the ids and add them alongside the topics
  library(plyr)
  tk.ids <<- gsub("^n|-.*$","", model$documents[,1])
  tk.ids <<- type.convert(tk.ids,numerals="no.loss")
  tk.import.analysis <- cbind(id=1:nrow(tk.import),tk.import[,4:ncol(tk.import)])
  tk.topics <<- cbind(tk.ids, model$docAssignments)
  # Recombine all the chunks for each id by averaging the scores
  mode(tk.topics) <<- "numeric"
  tk.topics <<- ddply(as.data.frame(tk.topics),.(tk.ids),numcolwise(mean))
  colnames(tk.topics)[2:ncol(tk.topics)] <<- paste("Topic", 1:model$K, sep=" ")
  # Calculate number of significant topics per document, using average median score of topics as a threshold
  tk.averagetopicmedian <- mean(apply(tk.topics[,2:ncol(tk.topics)],1,median))
  tk.topicsabovethreshold <- rowSums(tk.topics[,2:ncol(tk.topics)] > tk.averagetopicmedian)
  tk.topics <<- cbind(id=tk.topics[,1], topic.count = tk.topicsabovethreshold, tk.topics[,2:ncol(tk.topics)])
  # rm(tk.topicsabovethreshold,tk.ids)
  # Add data from the import CSV
  tk.topics <<- merge(tk.import.analysis, tk.topics)
  t.start <<- ncol(tk.import.analysis)+2
  t.end <<- ncol(tk.topics)
  # Add useful labels to the topics.
  tk.topwords <<- c()
  for (topic in 1:set.k) {
    tk.topwords[topic] <<- paste(names(model$getTopic(topic)$getWords(5)), collapse=", ")
  }
  attr(tk.topics, "variable.labels")[t.start:t.end] <<- tk.topwords
  # Add filtered views for each additional column, and export to CSV.
  tk.topics.by <<- list()
  tk.dist <<- list()
  for (tk.factor in 2:(t.start-2)){
    factorname <- colnames(tk.topics)[tk.factor]
    tk.topics.by[[factorname]] <<- tk.topics[,c(tk.factor,t.start:t.end)]
    tk.topics.by[[factorname]] <<- ddply(as.data.frame(tk.topics.by[[factorname]]),factorname,numcolwise(mean))
    tempdata <- tk.topics.by[[factorname]]
    tempnames <- tempdata[,1]
    tempdata[,1] <- NULL
    tempdata <- t(tempdata)
    colnames(tempdata) <- tempnames
    rownames(tempdata) <- paste(gsub("Topic ", "", rownames(tempdata)), tk.topwords, sep=". ")
    write.csv(tempdata,file=paste(set.project,"/topics-by-",factorname,".csv",sep=""))
    # Add a special visualization for binary factors.
    if (nrow(tk.topics.by[[factorname]])==2) {
      do.comparison(factorname,tk.topics.by[[factorname]][1,1],tk.topics.by[[factorname]][2,1])
    }
    rm(factorname,tempdata)
  }
  # Export a master CSV file for analysis.
  write.csv(tk.topics, file=paste(set.project,"/topics",paste(set.pos,collapse="-"),".csv",sep=""))
  View(tk.topics)
  tk.topics.subset.begin <- ncol(tk.topics)-set.k+1
  tk.topics.subset <<- tk.topics[,c(2,tk.topics.subset.begin:ncol(tk.topics))]
  # tk.topics.subset[1] <<- with(tk.topics.subset, reorder(tk.topics.subset[1], tk.topics.subset[2])) # might be nice to reorder, if I could get it to work
  tk.topics.subset.m <<- melt(tk.topics.subset)
  tk.topics.subset.m <<- ddply(tk.topics.subset.m, .(variable), transform, rescale = rescale(value))
  tk.topics.subset.m[,2] <<- paste(gsub("Topic ", "", tk.topics.subset.m[,2]), tk.topwords[as.numeric(gsub("Topic ", "", tk.topics.subset.m[,2]))], sep=". ")
  if("year" %in% colnames(tk.topics)){
    years <- c()
    for(text in tk.topics.subset.m[[1]]){
      years <- c(years,as.numeric((subset(tk.topics, tk.topics[[2]]==text, select="year")[[1]])))
    }
    tk.topics.subset.m <<- cbind(tk.topics.subset.m,years)
  }
  heatmap <- ggplot(tk.topics.subset.m, aes_q(x=substitute(reorder(variable, -rescale)), y=as.name(colnames(tk.topics.subset.m[1]))))
  # if("year" %in% colnames(tk.topics)){heatmap <- heatmap + scale_y_discrete(limits=(tk.topics.subset.m[[1]])[order(tk.topics.subset.m$years,tk.topics.subset.m[[1]],decreasing = T)])}
  heatmap <- heatmap + geom_tile(aes(fill = rescale), colour = "white") 
  heatmap <- heatmap + scale_fill_gradient(low = "white", high = "darkmagenta")
  base_size <- 9
  heatmap <- heatmap + theme_grey(base_size=base_size)
  heatmap <- heatmap + labs(x="", y="")
  heatmap <- heatmap + scale_x_discrete(expand = c(0,0))
  heatmap <- heatmap + theme(legend.position="none", axis.ticks=element_blank(), axis.text.x=element_text(size=base_size*0.75, angle=270, hjust = 0, colour="grey50"))
  print(heatmap)
  pdf(paste(set.project,"/heatmap", ".pdf", sep=""))
  print(heatmap)
  dev.off()
  message.last <- "Next, run do.comparison(). Be sure to specify what you would like to compare, in the following format: \n do.comparison(\"sex\",\"f\",\"m\")."
  cat(message.last)
}


### Run this function to look more closely at particular factors.
# With the sample import.csv, try some of the following:
# do.comparison("sex","f","m")
# do.comparison("nationality","american","british")
#
# Note that omitting the third argument compares against the average of the whole corpus:
# do.comparison("title","Tender Buttons")
do.comparison <- function(factorname,compare,compare2=paste("not ",compare,sep=""),limit=set.k,project=set.project){
  library(reshape2)
  library(scales)
  otheraverage <<- t(data.frame(colMeans(subset(tk.topics.by[[factorname]][2:ncol(tk.topics.by[[factorname]])]), factorname!=compare)))
  otheraverage <<- cbind(factorname = paste("not ",compare,sep=""),otheraverage)
  colnames(otheraverage)[1] <<- factorname
  rownames(otheraverage) <<- NULL
  fac.dist <<- tk.topics.by[[factorname]]
  fac.dist <<- rbind(fac.dist,otheraverage)
  topicnames <<- colnames(fac.dist[,2:ncol(fac.dist)])
  melted <<- suppressWarnings(melt(fac.dist, id.vars = factorname, measure.vars=topicnames))
  melted <<- subset(melted,melted[,1] %in% c(compare, compare2))
  colnames(melted) <<- c(factorname, "Topic", "Distribution")
  melted[,2] <<- paste(gsub("Topic ", "", melted[,2]), tk.topwords[as.numeric(gsub("Topic ", "", melted[,2]))], sep=". ")
  melted[,3] <<- sapply(melted[,3], as.numeric)
  tosort <<- c(compare,compare2)
  melted <<- melted[order(match(melted[[factorname]],tosort),melted$Topic),]
  topicavg <<- c()
  for (row in 1:set.k) {topicavg[row] <<- melted[row,3]-melted[row+set.k,3]}
  topicavg <<- c(topicavg,topicavg)
  variancemean <<- paste(round(mean(abs(topicavg))*100,digits=2),"%",sep="")
  variancemax <<- paste(round(max(abs(topicavg))*100,digits=2),"%",sep="")
  melted <<- cbind(melted,topicavg)
  melted <<- melted[order(-topicavg),]
  limiter <<- limit*2
  topicnums <<- set.k*2
  bottomlimit <<- topicnums-limiter+1
  supermelted <<- melted[c(1:limiter),]
  submelted <<- melted[c(bottomlimit:topicnums),]
  glacier <<- rbind(supermelted,submelted)
  library(ggplot2)
  dist <- ggplot(data=glacier, aes_q(x=substitute(reorder(Topic, topicavg)), y=quote(Distribution), fill=as.name(factorname)))
  dist <- dist + geom_bar(data=subset(glacier,glacier[,1]==compare), stat="identity")
  dist <- dist + geom_bar(data=subset(glacier,glacier[,1]==compare2), stat="identity", position="identity", mapping=aes(y=-Distribution))
  dist <- dist + scale_y_continuous(labels=abs)
  dist <- dist + xlab("Topics") + ylab(paste("Average variance: ", variancemean, "; Max variance: ", variancemax, sep="")) + scale_fill_discrete(breaks = c(compare,compare2))
  dist <- dist + coord_flip()
  #dist <- dist + scale_fill_manual(values=c("springgreen","palevioletred1"))
  dist <- dist + geom_point(data=subset(glacier,glacier[,1]==compare2), mapping=aes(y=topicavg), shape=4, show.legend = F)
  print(dist)
  pdf(paste(set.project,"/", compare, " vs ", compare2, ".pdf", sep=""))
  print(dist)
  dev.off()
}

message.1 <- "To start, set the name of your project before initializing preparation. If your project file is named \"shakespeare.csv\", for example, enter the following commands: \n set.project <- \"shakespeare\" \n do.preparation()"

cat(message.1)


# Acknowledgments (to be added to a NOTICES file)
# conversion of HTML to text adapted from Tony Breyal
# https://github.com/tonybreyal/Blog-Reference-Functions/blob/master/R/htmlToText/htmlToText.R
#
# This project includes code derived from Audenaert, "Topic Modeling R Tools"
# https://github.com/audenaert/TopicModelingRTools
