# TopicKit
A basic interface for planning, fetching, modeling, and analyzing a corpus of documents from the web.

## Getting started
Edit **import.csv** to get started. Each row indicates a new document. Add URLs in the first column. The next two columns define line numbers as cutoff limits for a header and footer. Columns two and three can include either numbers (for line numbers) or quotations of text found on the first and last lines, respectively; when given a line of text, the script will automate the counting. If the third column is negative, TopicKit will count backwards from the end of the file. If the third column is empty, it'll read the file to the end. After column three, remaining columns are optional and unlimited; more columns will lead to richer analyses later.

Set the working directory and load TopicKit.R with `source('TopicKit.r')`. To collect a corpus and prepare it, run `do.preparation()`. The script will download text or HTML files, divide them into chunks of 1,000 words each, and do its best to extract a given part of speech (default is common nouns).

Optionally, to automate creation of stopwords, which will take a very long time, run `do.stopwords()`. The script will search each downloaded file for names of persons and places and add these to files in an "entities" folder. This step is optional, but it only needs to be run once.

To derive a topic model, run `do.model()`. The script will attempt to model the topics in all the texts and create word clouds using scripts slightly modified from Neal Audenaert's work. Next, it will splice against each optional column in the original CSV to visualize averages for different kinds of texts.

To plot comparative graphs of the distribution of topics, run `do.comparison()`. The first argument should be the column name in the original CSV, and the second argument should indicate the value of that column to analyze. An optional third argument indicates what the comparison should baseline against. Additional arguments include project and limit, the latter of which is useful when the number of topics is too big.

## Modifying defaults
By default, TopicKit will work with a CSV file called **import.csv** to create a project called "import". To direct to another CSV file, modify `set.project`. It will download files into a project subfolder and divide documents into chunks of 1000 words before modelling the topics of a corpus, recombining the documents and their results at the end. (It does this to get something approaching parity of size among all the documents in a corpus so that one doesn't confuse the model.) To change the size of these chunks, redefine `set.chunksize` at the beginning of **TopicKit.R**.

By default, the variable `set.pos` tells the script to focus only on singular common nouns ("`NN`"). To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line:
> set.pos <- c("NN", "NNS", "JJ")

Finally, set the number of topics you'd like to discover by redefining `set.k` at the beginning of the file. 

## Another way to change settings
When calling functions, you can use settings that are different from the defaults using optional arguments:

1. To modify defaults when collecting and preparing texts, use the optional `project`, `pos`, and `chunksize` arguments: `do.preparation(project="Woolf", pos=c("NN", "JJ"), chunksize=1500)`
2. To specify project for discovering stopwords, use the optional `project` argument: `do.stopwords(project="Woolf")`
3. To modify defaults when running the topic model, use the optional `project`, `k`, and `pos` arguments: `do.model(project="Woolf",k=90,pos="")` (Keep in mind that the scripts can only model texts that have been prepared using the same `pos` argument in steps 1 and 3.)
4. To limit comparison to the most dissimilar topics, add the `limit` argument: `do.comparison("sex","f",limit="5")`

## After the first run
After the first run of `do.preparation`, **TopicKit.R** will save files and will not repeat the process with the same settings. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase **\texts** directory to download texts.
2. Erase **\txt** directory to divide the text into chunks.
3. Erase directory beginning with **\txt-** to repeat the extraction of a given element.
