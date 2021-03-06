# Project 2 - MovieLens
# Daniel Teodoro

if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
if(!require(caret)) install.packages("caret", repos = "http://cran.us.r-project.org")

# -----------------------------------------------------------------------------------------------
# 0 - Prepare
# -----------------------------------------------------------------------------------------------

#vPath <- "/Users/Daniel/_Pessoal/Treinamentos/Hardvard-Capstone-Data-Science/Project2-MovieLens-DanielTeodoro/"
vPath <- paste(getwd(), "/", sep="")
setwd(vPath)
vMovieLensFile <- paste(vPath, "ml-10M100K/movielens.csv", sep="")
vCached <- file.exists(vMovieLensFile)

# -----------------------------------------------------------------------------------------------
# 1 - Acquire Data
# -----------------------------------------------------------------------------------------------
if (!vCached)
{
  
  # Zip
  vZIPFile <- paste(vPath, "ml-10m.zip", sep="")
  download.file("http://files.grouplens.org/datasets/movielens/ml-10m.zip", vZIPFile)
  unlink(paste(vPath, "ml-10M100K", sep=""), recursive = TRUE)
  
  # Ratings
  vRatingsFile <- "ml-10M100K/ratings.dat"
  unzip(vZIPFile, vRatingsFile)
  vRatingsDS <- readLines(vRatingsFile)
  ratings <- read.table(text = gsub("::", "\t", vRatingsDS), col.names = c("userId", "movieId", "rating", "timestamp"))
  rm(vRatingsDS)
  
  # Movies
  vMoviesFile <- "ml-10M100K/movies.dat"
  unzip(vZIPFile, vMoviesFile)
  vMoviesDS <- readLines(vMoviesFile)
  movies <- str_split_fixed(vMoviesDS, "\\::", 3)
  rm(vMoviesDS)
  colnames(movies) <- c("movieId", "title", "genres")
  movies <- as.data.frame(movies) %>% mutate(movieId = as.numeric(levels(movieId))[movieId],
                                             title = as.character(title),
                                             genres = as.character(genres))
  #MovieLens
  movielens <- left_join(ratings, movies, by = "movieId")
  
  # Cache results
  write.csv(movielens, vMovieLensFile)  
  
  rm(vZIPFile, vRatingsFile, vMoviesFile)
} else {  
  movielens <- read.csv(vMovieLensFile, row.names = 1)
}
rm(vCached, vPath, vMovieLensFile)

# -----------------------------------------------------------------------------------------------
# 2 - Process
# -----------------------------------------------------------------------------------------------

# Validation set will be 1/6 of MovieLens data
set.seed(1)
test_index <- createDataPartition(y = movielens$rating, times = 1, p = 1/6, list = FALSE)
edx <- movielens[-test_index,]  # Training Set
temp <- movielens[test_index,]  # Validation Set

# Make sure userId and movieId in validation set are also in edx set
validation <- temp %>% 
  semi_join(edx, by = "movieId") %>%
  semi_join(edx, by = "userId")

# Add rows removed from validation set back into edx set
removed <- anti_join(temp, validation)
edx <- rbind(edx, removed)

# Run algorithm on validation set to generate ratings
validation <- validation %>% select(-rating)


# -----------------------------------------------------------------------------------------------
# 3 - Quiz
# -----------------------------------------------------------------------------------------------

# Q1) How many rows and columns are there in the edx dataset?
paste('The edx dataset has',nrow(edx),'rows and',ncol(edx),'columns.')

# Q2) How many zeros and threes were given in the edx dataset?
paste(sum(edx$rating == 0), 'ratings with 0 were given and',
      sum(edx$rating == 3),'ratings with 3')

# Q3) How many different movies are in the edx dataset?
edx %>% summarize(n_movies = n_distinct(movieId))

# Q4) How many different users are in the edx dataset?
edx %>% summarize(n_users = n_distinct(userId))

# Q5) How many movie ratings are in each of the following genres in the edx dataset?
drama <- edx %>% filter(str_detect(genres,"Drama"))
paste('Drama has',nrow(drama),'movies')

comedy <- edx %>% filter(str_detect(genres,"Comedy"))
paste('Comedy has',nrow(comedy),'movies')

thriller <- edx %>% filter(str_detect(genres,"Thriller"))
paste('Thriller has',nrow(thriller),'movies')

romance <- edx %>% filter(str_detect(genres,"Romance"))
paste('Romance has',nrow(romance),'movies')

rm(drama, comedy, thriller, romance)

# Q6) Which movie has the greatest number of ratings?
edx %>% group_by(title) %>% summarise(number = n()) %>% arrange(desc(number))

# Q7) What are the five most given ratings in order from most to least?
head(sort(-table(edx$rating)),5)

# Q8) True or False: 
# In general, half star ratings are less common than whole star ratings 
# (e.g., there are fewer ratings of 3.5 than there are ratings of 3 or 4, etc.).
ratings35 <- table(edx$rating)["3.5"]
ratings3 <- table(edx$rating)["3"]
ratings4 <- table(edx$rating)["4"]
answer <- (ratings35 < ratings3 && ratings35 < ratings4)
print(answer)
rm(ratings35, ratings3, ratings4, answer)

# -----------------------------------------------------------------------------------------------
# 4 - Data Analysis
# -----------------------------------------------------------------------------------------------

# More than 10 million ratings.
str(movielens)

# The plot shows that 5 ratings are more common that 0.5.
hist(movielens$rating)
summary(movielens$rating)

# More recent movies get more ratings. 
movielens$year <- as.numeric(substr(as.character(movielens$title),nchar(as.character(movielens$title))-4,nchar(as.character(movielens$title))-1))
plot(table(movielens$year))

# Last decades, ratings average get lower.
avg_ratings <- movielens %>% group_by(year) %>% summarise(avg_rating = mean(rating))
plot(avg_ratings)


# -----------------------------------------------------------------------------------------------
# 5 - Results
# -----------------------------------------------------------------------------------------------

# Root Mean Square Error
RMSE <- function(true_ratings, predicted_ratings)
  {
    sqrt(mean((true_ratings - predicted_ratings)^2))
  }

adj_factors <- seq(0, 5, 0.5)

rmses <- sapply(adj_factors, function(l){
  
  # The mean of training set
  mts <- mean(edx$rating)
  
  # Grade down low number on ratings
  me <- edx %>% 
    group_by(movieId) %>%
    summarize(me = sum(rating - mts)/(n()+l))

  #ajdust mean by user and movie effect and penalize low number of ratings
  am <- edx %>% 
    left_join(me, by="movieId") %>%
    group_by(userId) %>%
    summarize(am = sum(rating - me - mts)/(n()+l))  
  
  # Derive penalty value 'adj_factor'
  predicted_ratings <- 
    edx %>% 
    left_join(me, by = "movieId") %>%
    left_join(am, by = "userId") %>%
    mutate(pred = mts + me + am) %>%
    .$pred
  
  return(RMSE(predicted_ratings, edx$rating))
})

plot(adj_factors, rmses)

adj_factor <- adj_factors[which.min(rmses)]
paste('Best RMSE:',min(rmses),'is achieved with Adjustment Factor:',adj_factor)


# -----------------------------------------------------------------------------------------------
# 6 - Predict - Apply Adjustment Factor on Validation set 
# -----------------------------------------------------------------------------------------------

predictions <- sapply(adj_factor,function(l){
  
  # The mean of training set
  mts <- mean(edx$rating)
  
  # Get movie effect with best adjustment factor
  me <- edx %>% 
    group_by(movieId) %>%
    summarize(me = sum(rating - mts)/(n()+l))
  
  # Best adjust
  am <- edx %>% 
    left_join(me, by="movieId") %>%
    group_by(userId) %>%
    summarize(am = sum(rating - me - mts)/(n()+l))
  
  # Predict on validation set
  predicted_ratings <- 
    validation %>% 
    left_join(me, by = "movieId") %>%
    left_join(am, by = "userId") %>%
    mutate(pred = mts + me + am) %>%
    .$pred 
  
  return(predicted_ratings)
  
})


# -----------------------------------------------------------------------------------------------
# 7 - Export
# -----------------------------------------------------------------------------------------------

write.csv(validation %>% select(userId, movieId) %>% mutate(rating = predictions), 
          "predictions.csv", na = "", row.names=FALSE)

 
# -----------------------------------------------------------------------------------------------
# 8 - Conclusion
# -----------------------------------------------------------------------------------------------
# Using 1/6 as part of the data for the MovieLens validation set and removing the low rating 
# records in the training model, it was possible to obtain an RMSE index of 0.8563 and, 
# verifying it with actual data, the model was reasonably efficient.

# -----------------------------------------------------------------------------------------------
# 9 - References
# -----------------------------------------------------------------------------------------------
# http://www.montana.edu/rotella/documents/
# https://www.calvin.edu/~rpruim/courses/
# http://www.datainsight.at/report/
# https://r4ds.had.co.nz
# http://stackoverflow/



