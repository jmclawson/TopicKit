# TopicKit
A basic interface for planning, fetching, topic modeling, and analyzing a corpus of documents from the web. TopicKit automates many steps for data preparation, and it applies best topic modeling practices by default, allowing for prototyping of projects and quick testing of hypotheses for classrooms and collaborative projects.

## Installation
These steps need only to be run once for each machine.

### Setting up a working environment
1. [Install R] (https://cran.r-project.org)
  > R is the language TopicKit is written in. Installing it allows you to work with TopicKit and other tools like it.
  
2. [Install Java] (https://www.java.com/en/download/)
  > TopicKit relies on Mallet to handle the back end of running the topic model, and Mallet relies on Java, so it's necessary to have it installed from the start.
  
3. [Install RStudio] (https://www.rstudio.com/products/rstudio/download/)
  > This step is optional, but RStudio is just so good that you might as well get it. What's more, it simplifies the process of working with R.

### Setting up TopicKit
4. [Download TopicKit] (https://github.com/jmclawson/TopicKit/archive/master.zip) from GitHub and unzip the files into one directory.
5. Add the CSV file for your project into this same directory, or choose one of the sample data sets. (See below for more on project spreadsheets.)
6. In RStudio, set your working directory to the folder containing TopicKit, e.g., `setwd("~/Documents/TopicKit")`.
7. In the terminal pane, load `TopicKit.R` with the following command: `source("TopicKit.R")`.
8. Follow the directions in the terminal window.

## Using TopicKit
Set the working directory and load TopicKit.R with `source('TopicKit.R')`. To collect a corpus and prepare it, run `do.preparation()`. The script will download text or HTML files, divide them into chunks of 1,000 words each, and do its best to extract a given part of speech (defaulting to common nouns).

Optionally, to automate creation of stop words for the topic model to ignore, run `do.stopwords()`. The script will search each downloaded file for names of persons and places and add these to files in an "entities" folder. This step only needs to be run once, but it significantly improves subsequent topic models. Because finding these named entities takes a long time, consider adding the optional arguments `start` and `end` to limit the scope of the script and work in batches: `do.stopwords(start=1, end=5)`

To derive a topic model, run `do.model()`. The script will attempt to model the topics in all the texts and create word clouds using scripts slightly modified from [Neal Audenaert's work] (https://github.com/audenaert/TopicModelingRTools). To skip making word clouds, which can take time, add the optional `wordclouds` argument inside parentheses: `do.model(wordclouds=FALSE)`; skipped word clouds can always be plotted after the fact using `do.wordclouds()`.  After running the model, TopicKit will splice against each optional column in the original CSV to visualize averages for different kinds of texts.

To plot comparative graphs of the distribution of topics, run `do.comparison()`. The first argument should be the column name in the original CSV, and the second argument should indicate the value of that column to analyze. An optional third argument indicates what the comparison should baseline against, while the `limit` argument focuses the chart on a subset of most-relevant data when the number of topics is too high. Typical uses of this function include the following:

- `do.comparison("sex", "f")`
- `do.comparison("sex", "f", "m")`
- `do.comparison("sex", "f", "m", limit=20)`

## Working with Projects
By default, TopicKit will work with a CSV file called **import.csv** to create a project called "import". Run `set.project` to see which project is currently set; to change it to the sample Shakespeare data set, use the following command: `set.project <- "shakespeare"`. To create your own project, see [Preparing a Project](#preparing-a-project), below.

Alternatively, to work with a project file located online, use the command `get.project(url, projectname)`, replacing `url` with the file URL and `projectname` with whatever you'd like to call the project locally. TopicKit will download the project file and ready it for local modelling. Online project files are ideal for use with Google Spreadsheets, which allow for collaboration and which can publish a spreadsheet as a CSV file.

All work in a project will be saved in a subfolder called by that project name.

### Working in R
For analysis in R, TopicKit prepares data in a few key data frames:

1. `tk.import` includes the data imported from the project CSV file. Use the command `View(tk.import)` to see this data frame in RStudio.
2. `tk.topics` combines metadata from `tk.import` with results from the topic model. To ease use of this data in R, each topic column includes the top five words as a variable lable. Use the command `View(tk.topics)` to see this data frame in RStudio and to sort by each column.
3. `tk.topics.by` provides a list of data frames, each offering a specific splice of results against one of the columns of metadata. For example, the **shakespeare.csv** data set will offer `tk.topics.by$title`, `tk.topics.by$year`, `tk.topics.by$genre`, and `tk.topics.by$dynasty`, among others. After the dollar sign, RStudio will offer the option to choose from a menu of options, which is handy for discovery.

### Exporting data
After running the project model, TopicKit will automatically export different views of the resulting data. For example, after running the commands on the sample Shakespeare data set, a number of files will be made available in the **shakespeare/** directory on your computer. Among them will be CSV files exported for other analysis including **topicsNN.csv**—a master file containing all the information—and the following divisions, derived automatically from columns in the initial spreadsheet:
- **topics-by-dynasty.csv**
- **topics-by-genre.csv**
- **topics-by-title.csv**
- **topics-by-year.csv**

### Visualizations
In addition to exporting the data, TopicKit uses Neal Audenaert's scripts to create topic word clouds in the project's **plots/** subdirectory. These word clouds cluster most common words toward the center using a bigger font, with less-common words smaller at the margins.

Furthermore, TopicKit will export some visualizations of the topic model, including **heatmap.pdf**, a heatmap breakdown of the topics. For columns of metadata containing only two variables, TopicKit will automate comparative visualizations. For the Shakespeare project, for example, TopicKit will automatially create the **[heatmap.pdf](http://jmclawson.com/topickit/heatmap.pdf)** graphic, which it does for every topic model, and the **[Stuart vs Tudor.pdf](http://jmclawson.com/topickit/Stuart-vs-Tudor.pdf)** graphic, since there are only two categories listed in the dynasty column. The first graphic allows for a quick glance to see the strongest correlations of topics and texts. The second shows the breakdown of each topic for each of the two dynastic periods, and it orders these topics by comparative strength. A topic that is strong in both periods or is weak in both will gravitate toward the middle, while those topics that are notably stronger in one period than the other will be at the top or bottom.

Beyond any automatic comparison, you can force additional comparisons using the `do.comparison()` function, identifying the column you'd like to consider, and specifying the parameter or parameters to compare. For example, `do.comparison("title", "Julius Caesar")` will produce a **[Julius Caesar vs not Julius Caesar.pdf](http://jmclawson.com/topickit/Julius-Caesar-vs-not-Julius-Caesar.pdf)** graphic demonstrating the topics most closely associated with and against the play *Julius Caesar*, while `do.comparison("genre", "comedy", "history")` makes a **[comedy vs history.pdf](http://jmclawson.com/topickit/comedy-vs-history.pdf)** graphic that scales topics by their affinity to the genre "comedy" against that of "history". To look more closely at a subset of a large number of topics, we might limit the scale by the top and bottom five topics using `do.comparison("genre", "comedy", "history", limit=5)`, the output of which is shown below:

![chart contrasting top five topics for comedies and histories](http://jmclawson.com/topickit/comedy-vs-history.png "Topics in Shakespeare's comedies differ significantly from those found in his histories.")

This image demonstrates what we might already have expected, that histories more than comedies are concerned with *royalty* (here, topic 29) and *battle* (topic 50) and something that looks like *succession* (topic 12). Conversely, comedies are best recognized from histories for their concern with the *establishing of a household* (topic 9), with something that looks like *individual existential anxiety* (topic 41), and with *domestic relationships* (topic 49). The measures of average variance and max variance at the bottom of the chart allow for comparison among different columns of metadata, even if only to say that some divisions are better demonstrated than others in the topic model. And we can recognize this variance most easily by looking at the word clouds plotted for the most extreme two topics—first of topic 9 (strong in comedies), followed by topic 29 (strong in histories):

![Wordcloud showing prominence of words "sir," "master," "house," "fellow"](http://jmclawson.com/topickit/topic-9.png "Topic 9 is strong in comedies.")
![Wordcloud showing prominence of words "king," "crown," "head," "queen"](http://jmclawson.com/topickit/topic-29.png "Topic 29 is strong in histories.")

These word clouds suggest that the biggest topical difference between Shakespeare's comedies and his histories might be a marker of class, since both are concerned with public markers of having "made it"—whether this marker be something of reputation like a title or something physical like a house or crown. Notably, these topics also suggest that, while her role is yet diminished from that of her husband, a woman might play a bigger role in a history than in a comedy.

Keep in mind that the probabilistic workings of the topic model will make results differ from one run of the model to the next. In the future, TopicKit will add a setting to trigger stability of results across a number of runs.

## Assumptions and Defaults
Following best practices (see [Matthew Jockers](http://www.matthewjockers.net/2013/04/12/secret-recipe-for-topic-modeling-themes/ "'Secret' Recipe for Topic Modeling Themes")), TopicKit will prepare data before attempting to model the topics of a corpus. First, it divides documents into segments of 1000 words to get something approaching parity of size among all the documents in a corpus and to avoid confusing the model. (It recombines these documents after running the model.) To change the size of these chunks, redefine `set.chunksize` in the terminal window:
> `set.chunksize <- 800`

Next, it attempts to strip out everything but singular common nouns. To change this focus to other parts of speech, use the [part-of-speech tags associated with the Penn Treebank](http://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html). For example, to model singular and plural common nouns along with adjectives, use the following line: 
> `set.pos <- c("NN", "NNS", "JJ")`

When running the model, it looks for a predetermined number of topics, set by the `set.k` variable. Since there's no good way to programmatically set the number of topics to find in a corpus, TopicKit sets a default of 50 topics. To change this number, modify the `set.k` variable before running `do.model()`:
> `set.k <- 100`

Even after selecting only for common nouns and searching for named entities, some character or place names will still sneak through into your model. Use the `set.stops` variable to add names to a stop list before running `do.model()`:
>  `set.stops <- c("cleopatra", "caesar", "petruchio", "malvolio", "tranio", "antonio", "prospero", "armado", "ajax", "hector", "nestor", "gloucester", "clarence", "dromio", "timon", "cassio", "claudio", "arcite", "julia")`

These names don't persist if you reload **TopicKit.R**, so it might be a good idea to make note of those you find. To add a single name to an existing list of stopwords, just add `set.stops` within the parentheses:
> `set.stops <- c(set.stops, "bertram")`

## Preparing a Project
A sample **import.csv** is included. Either modify that file as a start, or create your own, following these steps:

1. Create a spreadsheet with three or more columns and with one row per text.
2. In the first row, define the column headers. The first column should be for the URL, the second should be for the opening line, and the third should be for the final line. Any additional columns are optional, but they will all be used by TopicKit. Good ideas include title, author, author sex, author nationality, genre, year of publication, etc. TopicKit will automate additional visualizations for columns with binary options, like "male" and "female", so consider how you might incorporate this kind of information.
3. Devote each subsequent row to one text. In the first column, put a URL for that row's text.
4. Into the second column, copy and paste the first line of the text to be modeled. (It isn't necessary to copy the entire line, just a string of unique-enough words to bypass what comes before it.) Alternatively, include a line number for this first line. Web pages and text files often include headers with unnecessary information, and we want to ignore the irrelevant stuff.
5. Into the third column, copy and paste the last line to be modeled, excluding any irrelevant footer. Alternatively, include the line number or (as a negative number) the number of lines from the bottom.
6. Add data in additional columns for each text.
7. Save the spreadsheet as a CSV file in the same folder as **TopicKit.R**. You can name the file whatever you like, but the scripts will look for **import.csv** by default. If instead you've named your file **shakespeare.csv**, make sure to set the project name before beginning using the command `set.project <- "shakespeare"`.

## After the First Run
With the first run of `do.preparation()`, **TopicKit.R** will save files to avoid repeating time-consuming processes. On subsequent runs, delete directories to repeat elements that are otherwise skipped:

1. Erase the **\texts** directory to download texts once again.
2. Erase the **\txt** directory to divide the text into chunks.
3. Erase the directory beginning with **\txt-** to repeat the extraction of a given element.

Each of these steps is currently necessary if you modify the CSV file after a first run. In fact, it might be easiest just to delete the project directory altogether, since these three directories are held within it. 

Future updates to TopicKit might try to be smarter at adding data if you add rows to a spreadsheet, but that feature is not yet in the workflow.

## Troubleshooting
TopicKit works with many packages at once, so it's inevitable that it will eventually hit a snag. If you get an error that doesn't make sense at first, try restarting R to see if a second go works better. If restarting R and re-running each of the functions in order—`do.preparation()` followed by `do.model()`—still leads to error, your problem may be one with a known solution:

* `input string 1 is invalid in this locale`

  > In the terminal, enter `Sys.setlocale('LC_ALL','C')` and then try again.
  
* `TEXT_SHOW_BACKTRACE environmental variable.`

  > I've been ignoring this one and have not noticed any problem, but I will continue work to debug it.
  
* `In postDrawDetails(x) : reached elapsed time limit`

  > I get this error intermittently, and each time seems to be for a seemingly random function in place of `postDrawDetails(x)` each time. I think it happens only after I've first overtaxed my system with a big data set. I haven't found any trouble ignoring it and running the function again.
