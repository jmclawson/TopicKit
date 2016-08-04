# Sets the topic to run only on singular common nouns and adjectives, but add others
ldak.pos <- c("NN")

# Start by reading the CSV
if (!file.exists("import.csv")){
  stop("Please make sure to have an import.csv file in the working directory.")
}
ldak.import <- read.csv("import.csv", colClasses=c(url="character", start.line="numeric", end.line="numeric", title="character", year="numeric"))

# Download the files into a new directory
if (!file.exists("texts")) {
  dir.create(file.path(getwd(), "texts"))
  for (number in 1:nrow(ldak.import)){
    ldak.filename <- paste("texts/",number,".txt",sep="")
    download.file(ldak.import[number,1], destfile = ldak.filename, method="auto")
  }
  rm(ldak.filename,number)
}

# Load document contents
ldak.texts <- c()
for (number in 1:nrow(ldak.import)){
  temp.list <- list()
  filename <- paste("texts/",number,".txt",sep="")
  start <- ldak.import[number,2]-1
  end <- ldak.import[number,3]-ldak.import[number,2]
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
  ldak.chunks[[number]] <- makeFlexTextChunks(ldak.texts[number], chunk.size = 1000, percentage = FALSE)
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

# Train a document model with 45 topics. This will run Mallet over the documents
# from data.dir and store the results along with some supporting information 
# in a convenient data structure
ldak.k <- 45
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

# Add filters by the different factors
ldak.topics.by.auth <- ldak.topics[,c(which(colnames(ldak.topics)=="factor.auth"),t.start:t.end)]
ldak.topics.by.auth <- ddply(as.data.frame(ldak.topics.by.auth),"factor.auth",numcolwise(mean))
ldak.topics.by.sex <- ldak.topics[,c(which(colnames(ldak.topics)=="factor.sex"),t.start:t.end)]
ldak.topics.by.sex <- ddply(as.data.frame(ldak.topics.by.sex),"factor.sex",numcolwise(mean))
ldak.topics.by.nat <- ldak.topics[,c(which(colnames(ldak.topics)=="factor.nat"),t.start:t.end)]
ldak.topics.by.nat <- ddply(as.data.frame(ldak.topics.by.nat),"factor.nat",numcolwise(mean))

# Plot something suggestive comparing author nationality to topic counts per document
plot(unlist(ldak.topics["factor.nat"]), unlist(ldak.topics["topic.count"]), xlab="Nationality", ylab="Number of topics per text", main="Does author nationality affect topic diversity?", col = "dark red")

# Export useful CSV files for analysis
write.csv(ldak.topics, file=paste("topics",paste(ldak.pos,collapse="-"),".csv",sep=""))
write.csv(ldak.topics.by.auth, file=paste("topics-by-auth",paste(ldak.pos,collapse="-"),".csv",sep=""))
write.csv(ldak.topics.by.sex, file=paste("topics-by-sex",paste(ldak.pos,collapse="-"),".csv",sep=""))
write.csv(ldak.topics.by.nat, file=paste("topics-by-nationality",paste(ldak.pos,collapse="-"),".csv",sep=""))
View(ldak.topics)

