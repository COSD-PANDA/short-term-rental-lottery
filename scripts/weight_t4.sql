drop table if exists STR_APPLICANTS_T4;
create table STR_APPLICANTS_T4
(applicant_id string,
CPA string,
tot_cert number,
enforce string,
activity string,
tot_pay string);

.mode csv
.import input/input_for_weight_assignment_t4.csv str_applicants_t4

drop table if exists str_applicants_t4_points;
create table str_applicants_t4_points
as select * from
str_applicants_t4;

alter table str_applicants_t4_points add column tot_cert_point number;
alter table str_applicants_t4_points add column enforce_point number;
alter table str_applicants_t4_points add column activity_point number;
alter table str_applicants_t4_points add column tot_pay_point number;

update str_applicants_t4_points
set activity_point = case when activity = 'One to two years' then 1 
when activity = 'More than two but less than five years' then 2
when activity = 'Five years or more' then 3
else 0
end;

update str_applicants_t4_points
set tot_cert_point = case when tot_cert > 0 and tot_cert < 641073 then 1
else 0
end;

update str_applicants_t4_points
set enforce_point = case when enforce = 'Yes' then 3
else 0
end;

update str_applicants_t4_points
set tot_pay_point = case when tot_pay = 'One to two years' then 1 
when tot_pay = 'More than two but less than five years' then 2
when tot_pay = 'Five years or more' then 3
else 0
end;

alter table str_applicants_t4_points
add column weight number;

update str_applicants_t4_points
set weight = tot_cert_point+enforce_point+activity_point+tot_pay_point;

drop table if exists str_applicants_t4_lot;
create table str_applicants_t4_lot as
select applicant_id,cpa,weight
from str_applicants_t4_points; 


.headers on
.mode csv

.output output/tier_4/applicants_weighted_t4.csv
select *
from str_applicants_t4_lot;

.output output/tier_4/applicants_weight_details_t4.csv
select applicant_id,cpa,tot_cert_point,enforce_point,activity_point,tot_pay_point,weight
from str_applicants_t4_points;

.quit
