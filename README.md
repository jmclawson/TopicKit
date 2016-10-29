# LDAkit
A basic interface for fetching and modeling text documents on the web


## Getting started
Edit "import.csv" to get started. Each row indicates a new document. Add text URLs in the first column. The next two columns define line numbers as cutoff limits for a header and footer. Remaining columns are optional and unlimited.

Columns two and three can include either numbers (for line numbers) or text found on the first and last lines, respectively; when given a line of text, the script will automate the counting. If the third column is negative, LDAkit will count backwards from the end of the file. If the third column is empty, it'll read the file to the end.

Set the working directory and load LDAkit.R with `source('LDAkit.r')`. To collect a corpus and prepare it, run `ldak.make.ready()`. The script will download text or HTML files, divide them into chunks of 1,000 words each, and do its best to extract a given part of speech (default is common nouns).

Optionally, to automate creation of stopwords, which will take a very long time, run `ldak.make.stopwords()`. The script will search each downloaded file for names of persons and places and add these to files in an "entities" folder. This step is optional, but it only needs to be run once.

To derive a topic model, run `ldak.make.model()`. The script, only slightly modified from Neal Audenaert's work, will attempt to model the topics in all the texts and create word clouds.

To analyze results, run `ldak.make.analysis()`. The script will splice against each optional column in the original CSV to visualize averages for different kinds of texts.

To plot comparative graphs of the distribution of topics, run `ldak.make.distribution()`. The first argument should be the column name in the original CSV, and the second argument should indicate the value of that column to analyze. An optional third argument indicates what the comparison should baseline against.

## Modifying defaults
By default, LDAkit will divide longer documents into chunks of 1000 words each before modelling the topics of a corpus, recombining the documents and their results at the end. (It does this to get something approaching parity of size among all the documents in a corpus so that one doesn't confuse the model.) To change the size of these chunks, redefine `ldak.chunksize` at the beginning of **LDAkit.R**.

By default, the variable `ldak.pos` tells the script to focus only on singular common nouns ("`NN`"). To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line:
> ldak.pos <- c("NN", "NNS", "JJ")

Finally, set the number of topics you'd like to discover by redefining `ldak.k` at the beginning of the file. 

## Another way to modify defaults
When calling functions, you can set defaults as optional arguments to avoid changing global defaults:

1. To modify defaults when collecting and preparing texts, use the optional `project`, `pos`, and `chunksize` arguments with `ldak.make.ready()`: `ldak.make.ready(project="Woolf", pos=c("NN", "JJ"), chunksize=1500)`
2. To specify project for discovering stopwords, use the optional `project` argument: `ldak.make.stopwords(project="Woolf")`
3. To modify defaults when running the topic model, use the optional `project`, `k`, and `pos` arguments: `ldak.make.model(project="Woolf",k=90,pos="")` (Keep in mind that the scripts can only model texts that have been prepared using the same `pos` argument in steps 1 and 3.)
4. To specify which project when analyzing the topic model, use the optional `project` argument: `ldak.make.analysis(project="Woolf")`

## After the first run
After the first run of `ldak.make.ready`, **LDAkit.R** will save files and will not repeat the process with the same settings. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase `\texts` directory to download texts.
2. Erase `\txt` directory to divide the text into chunks.
3. Erase directory beginning with `\txt-` to repeat the extraction of a given element.
