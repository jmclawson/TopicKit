# LDAkit
A basic interface for fetching and modeling text documents on the web


## Getting started
Edit "import.csv" to get started. Each row indicates a new document. Add text URLs in the first column. The next two columns define line numbers as cutoff limits for a header and footer. The fourth column is reserved for the text title or some other unique identifier, but remaining columns are optional and unlimited.

If the third column is negative, LDAkit will count backwards from the end of the file. If it is empty, LDAkit will search the file for something indicating the end of a Project Gutenberg book; lacking that, it'll read the file to the end.

Set the working directory and run LDAkit.R to download textfiles, divide them into chunks of 1,000 words each, extract user-defined text elements, and run mallet to model a user-defined set of topics on the corpus. 

## Modifying defaults
By default, LDAkit will divide longer documents into chunks of 1000 words each before modelling the topics of a corpus, recombining the documents and their results at the end. (It does this to get something approaching parity of size among all the documents in a corpus so that one doesn't confuse the model.) To change the size of these chunks, redefine `ldak.chunksize` at the beginning of **LDAkit.R**.

By default, the variable `ldak.pos` tells the script to focus only on singular common nouns ("`NN`"). To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line:
> ldak.pos <- c("NN", "NNS", "JJ")

Finally, set the number of topics you'd like to discover by redefining `ldak.k` at the beginning of the file. 

## After the first run
After the first run, **LDAkit.R** will only rerun the topic model, skipping the steps to download texts, to chunk them, and to extract text elements. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase `\texts` directory to download texts.
2. Erase `\txt` directory to divide the text into chunks.
3. Erase directory beginning with `\txt-` to repeat the extraction of a given element.
