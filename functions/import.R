xpdf.cmd = "C:/Apps/xpdf/bin64/pdftotext.exe"

#' Extracts the text from the supplied PDF document to a file and returns 
#' the name of the resulting file. Note that this will only attempt to extract
#' a valid text layer from a PDF. At this time, it does not attempt to perform
#' OCR or validate the correctness of the produced text file.
#' 
#' This function delegates to the XPDF library which can be found here 
#' http://www.foolabs.com/xpdf/download.html as a system level command.
#' 
#' This requires that the global variable xpdf.cmd has been set to absolute 
#' path to the xpdf 'pdftotext.exe' executable. 
#' 
#' This has not yet been tested in a *nix envrionment. 
#' 
#' @param pdf.path The path to the file to convert. This should be be an absolute  
#'                 file path
#' @return The file name of the created text file. Note that the text file will 
#'    be created within the same directory as the supplied PDF file.
extractTextFromPdf <- function(pdf.path) {
  # TODO allow for a secondary directory to be supplied for the output
  
  print(paste("Extracting text from '", pdf.path, "'"))
  
  cmdstr <- paste(xpdf.cmd,
                  " -enc UTF-8",
                  paste0('"', pdf.path, '"'),
                  collapse=" ")
  system(cmdstr, wait=T)
  return (gsub("\\.pdf$", ".txt", pdf.path))
}

#' Creates text documents from all PDF files in the supplied directory. 
#' See `extractTextFromPdf` for additional detail on how the text extraction 
#' is performed.
#' 
#' @param data.dir A fully qualified path to the directory of PDF documents. 
#'    All PDF document from this directory and optionally sub-directories
#'    will be processed and their output stored in text files alongside the 
#'    PDF file.
#' @param recursive Indicates if PDF files within sub-directories should be
#'    processed.
toText <- function(data.dir, recursive = TRUE)
{
  files.v <- dir(path=data.dir, pattern=".*\\.pdf", recursive=recursive)
  m <- sapply(strsplit(files.v, "/"), unlist)
  m <- cbind(files.v, m)
  
  paths.v <- file.path(data.dir, m[,1])
  sapply(paths.v, extractTextFromPdf)
}

#' Reads the content of a file, optionally converts it to lower case 
#' and returns the result as a single string. 
readFile <- function(txt.path, to.lower=T)
{
  print(paste("Reading text from '", txt.path, "'"))
  rawtext <- scan(txt.path, what="character", sep="\n")
  
  result <- rawtext
  if (to.lower)
  {
    result <- paste(rawtext, collapse=" ")
  }
  
  return (result)
}

#'
#'
#'
#' @param data.dir The directory from which to load files. 
#' @param recursive Whether or not to load documents from sub-directories. 
#'    Defaults to TRUE. 
loadDocuments <- function(data.dir, recursive=T) 
{
  files.v <- dir(path=data.dir, pattern=".*\\.txt", recursive=TRUE)
  m <- sapply(strsplit(files.v, "/"), unlist)
  m <- cbind(files.v, m)
  
  file.getname <- function(file.path) {
    file.path.parts <- unlist(strsplit(file.path, "/"))
    return (file.path.parts[length(file.path.parts)])
  }
  
  readFile <- function(txt.path)
  {
    print(paste("Reading text from '", txt.path, "'"))
    rawtext <- scan(txt.path, what="character", sep="\n")
    rawtext.lower <- paste(rawtext, collapse=" ")
    
    return (rawtext.lower)
  }
  
  paths.v <- file.path(data.dir, m[,1])
  docs <- sapply(paths.v, readFile)
  docs <- cbind(m[, 1], docs)
  colnames(docs) <- c("id", "text")
  
  docs <- as.data.frame(docs, stringsAsFactors=F)
  return (docs)
}

# Next up on my plate are the following:
#   * For each topic, what are the top documents in the topics 
# * For each document, what are the top topics in the document
# * For each grouping of documents (e.g., issue, volume, year) what are the percentages of each topic