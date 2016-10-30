# TopicKit
A basic interface for planning, fetching, topic modeling, and analyzing a corpus of documents from the web. TopicKit.R automates many steps for data munging, and it applies best topic modeling practices by default, allowing for quick testing of hypotheses and for replicability in collaborative projects.

## Installation
*(here I need to talk about how to install R, how to install Java, etc.)*

## Preparing a project
A sample **import.csv** is included. Either modify that file as a start, or create your own, following these steps:

1. Create a spreadsheet with three or more columns and with one row per text.
2. In the first row, define the column headers. The first column should be for the URL, the second should be for the opening line, and the third should be for the final line. Any additional columns are optional, but they will all be used by **TopicKit.R**. Good ideas include title, author, author sex, author nationality, genre, year of publication, etc. **TopicKit.R** will automate additional visualizations for columns with binary options, like "male" and "female", so consider how you might incorporate this kind of information.
3. Devote each subsequent row to one text. In the first column, put a URL for that row's text.
4. Into the second column, copy and paste the first line of the text to be modeled. (It isn't necessary to copy the entire line, just a string of unique-enough words to bypass what comes before it.) Alternatively, include a line number for this first line. Web pages and text files often include headers with unnecessary information, and we want to ignore the irrelevant stuff.
5. Into the third column, copy and paste the last line to be modeled, excluding any irrelevant footer. Alternatively, include the line number or (as a negative number) the number of lines from the bottom.
6. Add data in additional columns for each text.
7. Save the spreadsheet as a CSV file in the same folder as **TopicKit.R**. You can name the file whatever you like, but the scripts will look for **import.csv** by default. If instead you've named your file **Woolf.csv**, make sure to add the argument `project="Woolf"` when calling each function in the next section. (See more on these arguments in the section after that.)

## Using TopicKit
Set the working directory and load TopicKit.R with `source('TopicKit.r')`. To collect a corpus and prepare it, run `tk.make.ready()`. The script will download text or HTML files, divide them into chunks of 1,000 words each, and do its best to extract a given part of speech (default is common nouns).

Optionally, to automate creation of stopwords, which will take a very long time, run `tk.make.stopwords()`. The script will search each downloaded file for names of persons and places and add these to files in an "entities" folder. This step is optional, but it only needs to be run once.

To derive a topic model, run `tk.make.model()`. The script, only slightly modified from Neal Audenaert's work, will attempt to model the topics in all the texts and create word clouds.

To analyze results, run `tk.make.analysis()`. The script will splice against each optional column in the original CSV to visualize averages for different kinds of texts.

To plot comparative graphs of the distribution of topics, run `tk.make.distribution()`. The first argument should be the column name in the original CSV, and the second argument should indicate the value of that column to analyze. An optional third argument indicates what the comparison should baseline against. Finally, use the `project=...` argument to specify your project. Typical uses of this function include the following:
- `tk.make.distribution("sex","f")`
- `tk.make.distribution("sex","f","m")`
- `tk.make.distribution("sex","f","m",project="Woolf")`

## Another way to change settings
When calling functions, you can use settings that are different from the defaults using optional arguments:

1. To modify defaults when collecting and preparing texts, use the optional `project`, `pos`, and `chunksize` arguments: `tk.make.ready(project="Woolf", pos=c("NN", "JJ"), chunksize=1500)`
2. To specify project for discovering stopwords, use the optional `project` argument: `tk.make.stopwords(project="Woolf")`
3. To modify defaults when running the topic model, use the optional `project`, `k`, and `pos` arguments: `tk.make.model(project="Woolf",k=90,pos="")` (Keep in mind that the scripts can only model texts that have been prepared using the same `pos` argument in steps 1 and 3.)
4. To specify which project when analyzing the topic model, use the optional `project` argument: `tk.make.analysis(project="Woolf")`

## Modifying defaults
By default, TopicKit will work with a CSV file called **import.csv** to create a project called "import". To direct to another CSV file, modify `tk.project`. It will download files into a project subfolder and divide documents into chunks of 1000 words before modelling the topics of a corpus, recombining the documents and their results at the end. (It does this to get something approaching parity of size among all the documents in a corpus so that one doesn't confuse the model.) To change the size of these chunks, redefine `tk.chunksize` at the beginning of **TopicKit.R**.

By default, the variable `tk.pos` tells the script to focus only on singular common nouns ("`NN`"). To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line:
> tk.pos <- c("NN", "NNS", "JJ")

Finally, set the number of topics you'd like to discover by redefining `tk.k` at the beginning of the file. 

## After the first run
After the first run of `tk.make.ready`, **TopicKit.R** will save files and will not repeat the process with the same settings. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase **\texts** directory to download texts.
2. Erase **\txt** directory to divide the text into chunks.
3. Erase directory beginning with **\txt-** to repeat the extraction of a given element.
