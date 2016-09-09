# Define these choices:
# The variable ldak.chunksize sets the number of words to subdivide each document.
# The variable ldak.pos sets Mallet to run only on particular parts of speech.
# The variable ldak.k determines the number of topics to seek.
ldak.chunksize <- 1000
ldak.pos <- c("NN")
ldak.k <- 45

# Start by reading the CSV
if (!file.exists("import.csv")){
  stop("Please make sure to have an import.csv file in the working directory.")
}
ldak.import <- read.csv("import.csv", colClasses=c(url="character", start.line="character", end.line="character", title="character", year="numeric"))

# Download the files as text into a new directory
ldak.types <- sapply(strsplit(ldak.import[["url"]], split="\\."), tail, 1L)
if (!file.exists("texts")) {
  ldak.filenames <- c()
  dir.create(file.path(getwd(), "texts"))
  for (number in 1:nrow(ldak.import)){
    ldak.thisfilename <- paste("texts/", number, ".", sep="")
    ldak.thisfilename.type <- paste(ldak.thisfilename, ldak.types[number], sep="")
    download.file(ldak.import[number,1], destfile = ldak.thisfilename.type, method="auto")
    if (!ldak.types[number]=="txt") {
      library(XML)
      char.vec <- paste(readLines(ldak.thisfilename.type, warn = FALSE), collapse=" ")
      doc <- htmlParse(char.vec, asText = T)
      text <- xpathSApply(doc, "//text()[not(ancestor::script)][not(ancestor::style)][not(ancestor::noscript)][not(ancestor::form)]", xmlValue)
      txt <- paste(text, collapse="\n")
      write(txt,file=paste(ldak.thisfilename, "txt", sep="."),append=FALSE,sep="")
      rm(char.vec,doc,text,txt)
    }
    ldak.thisfilename <- paste(ldak.thisfilename, "txt", sep="")
    ldak.filenames <- c(ldak.filenames,ldak.thisfilename)
  }
  rm(ldak.thisfilename,ldak.thisfilename.type,number,ldak.types)
}

# Load document contents, imputing missing or negative endpoints
ldak.texts <- c()
for (number in 1:nrow(ldak.import)){
  temp.list <- list()
  filename <- ldak.filenames[number]
  temp.text <- scan(file=filename, what="character", sep="\n", blank.lines.skip = FALSE)
  if(!is.na(suppressWarnings(as.numeric(ldak.import[number,2])))){} else {
    ldak.import[number,2] <- if(length(grep(ldak.import[number,2], temp.text, ignore.case = TRUE))==0) 0 else grep(ldak.import[number,2], temp.text, ignore.case = TRUE)
  }
  if(!is.na(suppressWarnings(as.numeric(ldak.import[number,3])))){
    if(as.numeric(ldak.import[number,3])<0){
      ldak.import[number,3] <- length(temp.text)+as.numeric(ldak.import[number,3])
  }} else {
      ldak.import[number,3] <- if(length(grep(ldak.import[number,3], temp.text, ignore.case = TRUE))==0) length(temp.text) else grep(ldak.import[number,3], temp.text, ignore.case = TRUE)+1
  }
  # if(is.null(ldak.import[number,3])){
  #   temp.text <- scan(file=filename, what="character", sep="\n", blank.lines.skip = FALSE)
  #   ldak.import[number,3] <- if(length(grep("end of the project gutenberg ebook", temp.text, ignore.case = TRUE))==0) length(temp.text) else grep("end of the project gutenberg ebook", temp.text, ignore.case = TRUE)
  # }
  start <- as.numeric(ldak.import[number,2])-1
  end <- as.numeric(ldak.import[number,3])-as.numeric(ldak.import[number,2])
  temp.list <- scan(file=filename, what="character", sep="\n", skip=start, nlines=end)
  ldak.texts[number] <- paste(unlist(temp.list), collapse = " \n")
}
rm(filename,temp.list,start,end,number)

# Chunk the text (from Jockers' Text Analysis with R)
makeFlexTextChunks <- function(ldak.doc.text, chunk.size=1000, percentage=TRUE){
  words.lower <- tolower(ldak.doc.text)
  words.lower <- gsub("[^[:alnum:][:space:]']", " ", words.lower)
  words.l <- strsplit(words.lower, "\\s+")
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

ldak.chunks <- list()
for (number in 1:nrow(ldak.import)) {
  ldak.chunks[[number]] <- makeFlexTextChunks(ldak.texts[number], chunk.size = ldak.chunksize, percentage = FALSE)
}

# If "txt" dir doesn't exist, write text to files in chunks ~1,000 each
if (!dir.exists("txt")) {
  dir.create(file.path(getwd(), "txt"))
  for (number in 1:length(ldak.chunks)) {
    for (sub in 1:length(ldak.chunks[[number]])) {
      filename <- paste("txt/",number,"-",sub,".txt",sep="")
      write(ldak.chunks[[number]][sub],file=filename,append=FALSE,sep="")
    }
  }
  rm(number,sub)
}
rm(ldak.chunks,ldak.texts)

## Strip out everything but the common nouns, but only if dir doesn't exist
# via http://stackoverflow.com/questions/30995232/how-to-use-opennlp-to-get-pos-tags-in-r
ldak.dir <- paste("txt-",paste(ldak.pos,collapse="-"),sep="")
if (!dir.exists(ldak.dir)) {
  dir.create(file.path(getwd(), ldak.dir))
  library(NLP) 
  library(openNLP)
  noun.startdir <- "txt/"
  noun.enddir <- paste(ldak.dir,"/",sep="")
  noun.files <- list.files(path=noun.startdir)
  for (noun.file in noun.files) {
    txt <- as.String(readLines(paste(noun.startdir, noun.file, sep="")))
    wordAnnotation <- annotate(txt, list(Maxent_Sent_Token_Annotator(), Maxent_Word_Token_Annotator()))
    POSAnnotation <- annotate(txt, Maxent_POS_Tag_Annotator(), wordAnnotation)
    POSwords <- subset(POSAnnotation, type == "word")
    tags <- sapply(POSwords$features, '[[', "POS")
    ldak.pos.index <- paste("(",paste(ldak.pos,collapse="|"),")",sep="")
    thisPOSindex <- grep(paste(ldak.pos.index,"$",sep=""), tags)
    tokenizedAndTagged <- sprintf("%s/%s", txt[POSwords][thisPOSindex], tags[thisPOSindex])
    untokenizedAndTagged <- paste(tokenizedAndTagged, collapse = " ")
    untokenizedAndTagged <- gsub(paste("\\/",ldak.pos.index,sep=""), "", untokenizedAndTagged)
    noun.savefile <- paste(noun.enddir, "n", noun.file, sep="")
    write(untokenizedAndTagged, file=noun.savefile, append = FALSE, sep="")
    rm(txt, wordAnnotation, POSAnnotation, POSwords, tags, thisPOSindex, tokenizedAndTagged, untokenizedAndTagged, noun.savefile, noun.file)
  }
  rm(noun.startdir, noun.enddir, noun.files)
}


# ===== Now it's time to build a model of topics in these documents

## Modified from Neal Audenaert's example_1.R

# options(java.parameters = "-Xmx4g")
source("functions/lda.R")
source("functions/import.R")

# Set data.dir to the directory with data. 
data.dir <- ldak.dir

if (!file.exists("plots")){
  dir.create(file.path(getwd(), "plots"))
}

# This loads the documents from the directory above in a format that can be used 
# with Mallet.
docs <- loadDocuments(data.dir);

# Specify a set of stop-words, or commonly used words to be removed from the documents
# in order to improve model performance.
stoplist <- "stop-words/stop-words_english_2_en.txt"

# Train a document model with topics numbering as much as ldak.k.
# This will run Mallet on the data in the directory being used, 
# and store the results in a data structure we can later access.
model <- trainSimpleLDAModel(docs, ldak.k, stoplist=stoplist)

# Print the resulting topics as wordclouds for easy visualization.
print("printing topic word clouds")
plotTopicWordcloud(model, verbose=T)

## Now modify the output to present the results in a useful format
# load a necessary package
library(plyr)

# Get and clean up the ids and add them alongside the topics
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

# Add useful labels to the topics
ldak.topwords <- c()
for (topic in 1:ldak.k) {
  ldak.topwords[topic] <- paste(names(model$getTopic(topic)$getWords(4)), collapse=", ")
}
attr(ldak.topics, "variable.labels")[t.start:t.end] <- ldak.topwords

# Add filtered views for each additional column
ldak.topics.by <- list()
for (ldak.factor in 3:(t.start-2)){
  factorname <- colnames(ldak.topics)[ldak.factor]
  ldak.topics.by[[factorname]] <- ldak.topics[,c(ldak.factor,t.start:t.end)]
  ldak.topics.by[[factorname]] <- ddply(as.data.frame(ldak.topics.by[[factorname]]),factorname,numcolwise(mean))
  write.csv(ldak.topics.by[[factorname]],file=paste("topics-by-",factorname,".csv",sep=""))
  rm(factorname)
}

# Plot something suggestive comparing author nationality to topic counts per document
plot(unlist(ldak.topics["nationality"]), unlist(ldak.topics["topic.count"]), xlab="Nationality", ylab="Number of topics per text", main="Does author nationality affect topic diversity?", col = "dark red")

# Export useful CSV files for analysis
write.csv(ldak.topics, file=paste("topics",paste(ldak.pos,collapse="-"),".csv",sep=""))
View(ldak.topics)

# Acknowledgments (to be added to a NOTICES file)
# conversion of HTML to text adapted from Tony Breyal
# https://github.com/tonybreyal/Blog-Reference-Functions/blob/master/R/htmlToText/htmlToText.R
#
# This project includes code derived from Audenaert, "Topic Modeling R Tools"
# https://github.com/audenaert/TopicModelingRTools