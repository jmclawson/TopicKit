# TopicKit
A basic interface for planning, fetching, topic modeling, and analyzing a corpus of documents from the web. TopicKit automates many steps for data munging, and it applies best topic modeling practices by default, allowing for quick testing of hypotheses and for replicability in collaborative projects.

## Installation
*(here I need to talk about how to install R, how to install Java, etc.)*

## Preparing a Project
A sample **import.csv** is included. Either modify that file as a start, or create your own, following these steps:

1. Create a spreadsheet with three or more columns and with one row per text.
2. In the first row, define the column headers. The first column should be for the URL, the second should be for the opening line, and the third should be for the final line. Any additional columns are optional, but they will all be used by TopicKit. Good ideas include title, author, author sex, author nationality, genre, year of publication, etc. TopicKit will automate additional visualizations for columns with binary options, like "male" and "female", so consider how you might incorporate this kind of information.
3. Devote each subsequent row to one text. In the first column, put a URL for that row's text.
4. Into the second column, copy and paste the first line of the text to be modeled. (It isn't necessary to copy the entire line, just a string of unique-enough words to bypass what comes before it.) Alternatively, include a line number for this first line. Web pages and text files often include headers with unnecessary information, and we want to ignore the irrelevant stuff.
5. Into the third column, copy and paste the last line to be modeled, excluding any irrelevant footer. Alternatively, include the line number or (as a negative number) the number of lines from the bottom.
6. Add data in additional columns for each text.
7. Save the spreadsheet as a CSV file in the same folder as **TopicKit.R**. You can name the file whatever you like, but the scripts will look for import.csv by default. If instead you've named your file shakespeare.csv, make sure to add the argument project="shakespeare" when calling each function in the next section. (See more on these arguments in the section after that.)

## Using TopicKit
Set the working directory and load TopicKit.R with `source('TopicKit.r')`. To collect a corpus and prepare it, run `do.preparation()`. The script will download text or HTML files, divide them into chunks of 1,000 words each, and do its best to extract a given part of speech (default is common nouns).

Optionally, to automate creation of stopwords, which will take a long time, run `do.stopwords()`. The script will search each downloaded file for names of persons and places and add these to files in an "entities" folder. This step is optional, but it only needs to be run once.

To derive a topic model, run `do.model()`. The script will attempt to model the topics in all the texts and create word clouds using scripts slightly modified from Neal Audenaert's work. Next, it will splice against each optional column in the original CSV to visualize averages for different kinds of texts.

To plot comparative graphs of the distribution of topics, run `do.comparison()`. The first argument should be the column name in the original CSV, and the second argument should indicate the value of that column to analyze. An optional third argument indicates what the comparison should baseline against, while the `limit` argument focuses the chart on a subset of data when the number of topics is great. Finally, use the project=... argument to specify your project. Typical uses of this function include the following:

- `do.comparison("sex","f")`
- `do.comparison("sex","f","m")`
- `do.comparison("sex","f","m",project="shakespeare")`
- `do.comparison("sex","f","m",project="shakespeare",limit=20)`

## Under the Hood (or, Assumptions and Defaults)
By default, TopicKit will work with a CSV file called **import.csv** to create a project called "import". To switch to a different project, redefine `set.project` in the terminal window to point to a different CSV file: `set.project <- "shakespeare"`. All work in a project will be saved in a subfolder called by that project name.

Following best practices (citation to come), TopicKit will prepare data before attempting to model the topics of a corpus. First, it divides documents into chunks of 1000 words to get something approaching parity of size among all the documents in a corpus and to avoid confusing the model. (Don't worry; it recombines these documents later.) To change the size of these chunks, redefine `set.chunksize` in the terminal window. Next, it strips out everything but singular common nouns. To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line: `set.pos <- c("NN", "NNS", "JJ")`

Unfortunately, there's no good way to programmatically set the number of topics to find in a corpus. But we need to start somewhere. With the `set.k` variable, TopicKit sets a default of 50 topics. You can change this default in the terminal window before running `d.model()`.

## After the first run
After the first run of `do.preparation()`, **TopicKit.R** will save files and will not repeat the process with the same settings. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase **\texts** directory to download texts.
2. Erase **\txt** directory to divide the text into chunks.
3. Erase directory beginning with **\txt-** to repeat the extraction of a given element.
