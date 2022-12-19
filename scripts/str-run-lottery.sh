#!/bin/bash
if [ $# -ne 6 ]; then
	echo "Usage: run_lottery.sh r_script input_file random_seed input_bucket output_bucket scripts_bucket"
	exit -1
fi

# Example arguments
# Weighted_T4.R accela_extract_t4.csv 12345678 1234-sandiego-strlottery-dev-input 1234-sandiego-strlottery-dev-output 1234-sandiego-strlottery-dev-scripts

# receive arguments from Lambda function
RSCRIPT=$1
INPUT_FILE=$2
RANDOM_SEED=$3
S3INPUT=$4
S3OUTPUT=$5
S3SCRIPTS=$6

REGION=us-west-2
TARGET=/home/ec2-user/Code/STR
DIR_SCRIPTS=$TARGET
DIR_INPUT=$TARGET/data/input
DIR_OUTPUT=$TARGET/data/output

echo "Making clean input and output directories"
rm -fr DIR_INPUT $DIR_OUTPUT
mkdir -p $DIR_SCRIPTS $DIR_INPUT $DIR_OUTPUT/tier_3 $DIR_OUTPUT/tier_4

# download controlled copies of input and script files
aws --region=$REGION s3 cp s3://$S3INPUT/$INPUT_FILE $DIR_INPUT --no-progress
aws --region=$REGION s3 cp s3://$S3INPUT/CPA_names.csv $DIR_INPUT --no-progress
aws --region=$REGION s3 cp s3://$S3SCRIPTS/$RSCRIPT $DIR_SCRIPTS --no-progress
aws --region=$REGION s3 cp s3://$S3SCRIPTS/weight_t3.sql $DIR_SCRIPTS --no-progress
aws --region=$REGION s3 cp s3://$S3SCRIPTS/weight_t4.sql $DIR_SCRIPTS --no-progress

# output checksum of lottery files
md5sum $DIR_INPUT/$INPUT_FILE $DIR_INPUT/CPA_names.csv $DIR_SCRIPTS/$RSCRIPT $DIR_SCRIPTS/*.sql

# input file must have a header that begins with applicant_id (not case sensitive)
check_header=`head -1 $DIR_INPUT/$INPUT_FILE | grep -i ^applicant_id`
if [ -z "$check_header" ]
then
	echo "ERROR: input file is missing header"
	echo "EXIT without running lottery"
	exit 1
fi

# input file must have exactly six columns
count_lines=`cat $DIR_INPUT/$INPUT_FILE | wc -l`
count_columns=`awk -F, ' {print NF; exit}' $DIR_INPUT/$INPUT_FILE`
echo "Input file has $count_lines lines and $count_columns columns (CSV format)"
if [[ $count_columns -ne 6 ]]
then
	echo "ERROR: input file must be CSV format with 6 columns, this file has $count_columns"
	echo "EXIT without running lottery"
	exit 1
fi
 
# assign weights to the applications based on established criteria
# the weight assignment script looks for files named 
# input_for_weight_assignment_t3.csv and ..._t4.csv    and produces outputs
# ../output/tier_3/applicants_weighted_t3.csv and .../tier_4/..._t4.csv
cd $TARGET/data
case $INPUT_FILE in
	*t3.csv | *T3.csv)
		echo "Beginning Tier 3 Weight Assignment (header row is removed from input)"
		tail -n +2 input/$INPUT_FILE > input/input_for_weight_assignment_t3.csv
		md5sum input/input_for_weight_assignment_t3.csv
		sqlite3 lottery.db < $DIR_SCRIPTS/weight_t3.sql
		WEIGHTED_FILE=$DIR_OUTPUT/tier_3/applicants_weighted_t3.csv
		;;
	*t4.csv | *T4.csv)
		echo "Beginning Tier 4 Weight Assignment (header row is removed from input)"
		# consider only line 2 and beyond for input, removing the header line
		tail -n +2 input/$INPUT_FILE > input/input_for_weight_assignment_t4.csv
		md5sum input/input_for_weight_assignment_t4.csv
		sqlite3 lottery.db < $DIR_SCRIPTS/weight_t4.sql
		WEIGHTED_FILE=$DIR_OUTPUT/tier_4/applicants_weighted_t4.csv
		;;
	*)
		echo "UNKNOWN TIER - Exiting without running Weight Assignment, NO LOTTERY WILL BE RUN"
		exit
		;;
esac


# run lottery script 
cd $TARGET
echo "Beginning Lottery with command   Rscript $DIR_SCRIPTS/$RSCRIPT $WEIGHTED_FILE $RANDOM_SEED"
Rscript $DIR_SCRIPTS/$RSCRIPT $WEIGHTED_FILE $RANDOM_SEED

# output checksum of all results (this may also include outputs from previous runs)
md5sum  $DIR_OUTPUT/*/* 

# upload results to S3 bucket (includes any results that exist, which may include from previous runs)
aws --region=$REGION s3 cp $DIR_OUTPUT s3://$S3OUTPUT/ --recursive --no-progress

echo "Lottery Run Complete, Results Uploaded to S3"

exit
