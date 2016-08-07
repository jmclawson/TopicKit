# LDAkit
A basic interface for fetching and modeling text documents on the web


## Getting started
Edit "import.csv" to get started. Each row indicates a new document. Add text URLs in the first column. The next two columns define line numbers as cutoff limits for a header and footer. The fourth column is reserved for the text title or some other unique identifier, but remaining columns are optional and unlimited.

Set the working directory and run LDAkit.R to download textfiles, divide them into chunks of 1,000 words each, extract user-defined text elements, and run mallet to model a user-defined set of topics on the corpus. 

## Modifying defaults
In **LDAkit.R**, redefine `ldak.pos` to extract text elements other than singular common nouns ("`NN`"). For example, to model singular and plural common nouns along with adjectives, use the following line:
> ldak.pos <- c("NN", "NNS", "JJ")

Use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html) to choose other elements.

## After the first run
After the first run, **LDAkit.R** will only rerun the topic model, skipping the steps to download texts, to chunk them, and to extract text elements. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase `\texts` directory to download texts.
2. Erase `\txt` directory to divide the text into chunks.
3. Erase directory beginning with `\txt-` to repeat the extraction of a given element.
