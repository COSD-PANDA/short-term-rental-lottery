#rm(list = ls()) #Clear workspace
#setwd("data") # Set working directory


# Load Libraries
require("readr")
require("readxl")
require("dplyr")
require("data.table")
require("janitor")

args = commandArgs(trailingOnly=TRUE)
if (length(args)!=2) {
  stop("Two arguments must be supplied: input_file  random_seed.n", call.=FALSE)
}
input_filename = args[1]
random_seed = strtoi(args[2],10)

# Read applicants data
df <- read_csv(input_filename)

## -------------------------------------------------
### Data quality check
## -------------------------------------------------

# VALID CPA
stopifnot(df$CPA=="MISSION BEACH")

# DUPLICATES: Make sure there are no duplicates in applicant id 
stopifnot(df[duplicated(df$applicant_id), ]== 0 )

# stopifnot: Weight point is not between 0 and 10 (adding 1 does not happen until next block)
stopifnot(between(df$weight, 0, 10))

# Note that in source data weights will go from 0 to 10, we will transform to
# a 1-11 scale to run the weighted lottery
df$app_weight <- df$weight
df$weight <- df$weight + 1
df$applicant_id <- as.character(df$applicant_id)

# Define key values for lottery
total_applicants <- nrow(df) # total applicants
kAvailableLicenses <- 1081 # available licenses

# unweigthed probability of selection= available licenses
# divided by total applicants
prob <- kAvailableLicenses / total_applicants

# Set randomization seed to make results replicable
kSeed <- random_seed

# Make randomization seed fixed throughout script
addTaskCallback(function(...) {
  set.seed(kSeed)
  TRUE
})


## -------------------------------------------------
### Run weighted lottery
## -------------------------------------------------
lot_w <- df %>%
  slice_sample(prop = prob, weight_by = weight)

#Add win value
lot_w$win<-"Yes"


## -------------------------------------------------
### Create waitlist
## -------------------------------------------------

# Remove selected applicants from total applicants
selected <- lot_w[, 1]
waitlist <- anti_join(df, selected) # create list of all not selected applicants

# order not selected applicants randomly
waitlist$random_n <- runif(nrow(waitlist))

# Using random number to sort applicants 
waitlist <- waitlist %>% arrange(random_n)

# 5.3) Add "waitlist_place" column 

waitlist <- waitlist %>%
  dplyr::mutate(waitlist_place = row_number())
# Use waitlist place to follow waitlist criteria detailed on documentation


#Add win value
waitlist$win<-"No"

## -------------------------------------------------
### Save output
## -------------------------------------------------

results_detail <-bind_rows(lot_w, waitlist)
results_detail$record_id <- results_detail$applicant_id

# Save more detailed output for dashboarding
write_csv(results_detail, "output/tier_4/results_detail_t4.csv")

# Save output for Accela usage
results <- subset(results_detail, select = c(record_id, win, waitlist_place))
write_csv(results, "output/tier_4/tier4_lottery_results.csv")

