# City of San Diego STRO license lottery

This project contains the data and scripts for the City of San Diego's Tier 4 Short-Term Residential Occupancy license lottery.

## Background

The City requires licenses for short-term residential occupancy of a dwelling unit. Out of the four types of licenses, two (Tier 3 and Tier 4) have a limited number available, and potential hosts were invited to apply for these through November 30, 2022. The number of Tier 4 applicants exceeded the number of available licenses, so licenses were awarded by lottery.

To learn more about STRO regulation, visit [sandiego.gov/treasurer/short-term-residential-occupancy](https://www.sandiego.gov/treasurer/short-term-residential-occupancy).

## The lottery application

The City's lottery application executes within a secure Amazon Web Services environment. Instructions for replicating that environment are included here; however, anyone wishing to inspect the methodology or reproduce the lottery can do so using the lottery script written in R along with the applicant data and the seed number.

### Amazon Web Services environment

A cloud formation template at the root of this directory, strlottery-cf.yml, will automate the deployment of the lottery environment. To deploy, you will need to log into an AWS account with a role that has permissions to create resources.

Once logged in, browse to the CloudFormation service and complete the following steps:

1.	Select Create Stack.
2.	Select Template is ready, and Upload a template. Then, Choose file and upload the strlottery-cf.yml file. Select Next.
3.	Enter a Stack name as appropriate, such as prod-sandiego-str, and select the corresponding Environment drop down. Enter a Unique ID only if this is not an official San Diego environment (e.g. for isolated development work).
4.	Select Next (accept all defaults).
5.	Check the I acknowledge boxes at the bottom of the page and select Submit.
6.	Wait while all resources are created. You can monitor progress by selecting the reload icon. This typically takes 5 minutes.

The environment is now deployed. You should have three related S3 buckets, all prefixed with *UniqueID*sandiego-strlottery-*env* (see step 3 above). Next, you will need to put certain files into *UniqueID*sandiego-strlottery-*env*-scripts.

File name | Purpose | Bucket
----------|---------|---------
Weighted_T4.R | R script for the Tier 4 lottery | *UniqueID*sandiego-strlottery-*env*-scripts
weight_t4.sql | SQLite3 script to calculate weights | *UniqueID*sandiego-strlottery-*env*-scripts
str-run-lottery.sh | Bash script to invoke lottery | *UniqueID*sandiego-strlottery-*env*-scripts

#### Executing the lottery in Amazon Web Services

To execute the lottery, browse to the *UniqueID*sandiego-strlottery-*env*-input S3 bucket. Upload a file ending in _t4.csv that contains raw applicant data. This data is not provided in this public repository to protect applicant privacy. 

After about one minute, two files should appear within *UniqueID*sandiego-strlottery-*env*-output/tier_4. One is applicants_weighted_t4.csv, which is the data file used in the lottery R script. This applicant data contains only application id, Community Planning Area, and total weight points, and it is available in this public repository for anyone who wants to reproduce the lottery results using the R script and the same seed number. The City's seed number was generated at runtime.

The other output file is the lottery results. The official results are available in a City of San Diego [Tableau dashboard](https://public.tableau.com/views/STROTier4lotteryresults/STROApplications?:language=en-US&publish=yes&:display_count=n&:origin=viz_share_link). For questions about lottery results, please contact panda@sandiego.gov.

### Lottery R script

To reproduce the exact results for the official City lottery, you will need to run the lottery R script, Weighted_T4.R, using the same seed number and input data. The script requires two arguments: the name of the input file, and the seed number. The official lottery seed number is `1671165508`.

Example command: `Rscript Weighted_T4.R applicants_weighted_t4.csv 1671165508`

If running in R Studio, replace lines 16 and 17 with their respective values.