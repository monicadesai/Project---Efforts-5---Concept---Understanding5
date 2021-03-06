# Project 5 - Banking
# Language Used - R 
# Model Used - Linear Regression, RandomForest
# Target Variable - 'y'
# Aim - KS Score ---> which should be greater than o.47





# get the working directory --------------------------------------------------------------------------------------------------------------------
getwd()

## set the working directory where to work and your data exists
setwd("C:\\Users\\Monica\\Desktop\\Projects\\R Projects\\Project5")

## Data loading phase ---------------------------------------------------------------------------------------------------------------------------
## load the train and test data
train_data = read.csv("bank-full_train.csv", stringsAsFactors = F)
test_data = read.csv("bank-full_test.csv",stringsAsFactors = F)

## Data Preparation phase -----------------------------------------------------------------------------------------------------------------------
## combine data for data preparation
test_data$y = NA


# put place holder for train and test data for identification
train_data$data = 'train'
test_data$data = 'test'

# combining train and test data
All_data = rbind(train_data,test_data)


# loading library dplyr for data preparation
install.packages("dplyr")  # Keep net connection on while installing libraries    
library(dplyr)

# view the data
glimpse(All_data)

## check all the column concatinating NA values
for(col in names(All_data)){
  if(sum(is.na(All_data[,col]))>0 & !(col %in% c("data","y")))
    print(col)
}

## finding names of the column which are of character type
char_logical=sapply(All_data, is.character)
cat_cols=names(All_data)[char_logical]
cat_cols

## taking only those columns which are categorical from cat_cols and cat_cols1
cat_cols = cat_cols[c(-10,-11)]


## function for creating dummies ---------------------------------------------------------------------------------------------------------
CreateDummies=function(data,var,freq_cutoff=100){
  t=table(data[,var])
  t=t[t>freq_cutoff]
  t=sort(t)
  categories=names(t)[-1]
  for( cat in categories){
    name=paste(var,cat,sep="_")
    name=gsub(" ","",name)
    name=gsub("-","_",name)
    name=gsub("\\?","Q",name)
    name=gsub("<","LT_",name)
    name=gsub("\\+","",name)
    name=gsub(">","GT_",name)
    name=gsub("=","EQ_",name)
    name=gsub(",","",name)
    name=gsub("/","_",name)
    data[,name]=as.numeric(data[,var]==cat)
  }
  data[,var]=NULL
  return(data)
}

## creating dummy variable for all the categorical columns of character types
for(col in cat_cols){
  All_data=CreateDummies(All_data,col,50)
}


## Separtion of data into train and test
train_data=All_data %>% filter(data=='train') %>% select(-data)
test_data= All_data %>% filter(data=='test') %>% select(-data,-y)
## converting the went_on_backorder in the form of numeric 0 and 1
train_data$y = as.numeric(train_data$y == "yes")


## separate train and test data from train_data
set.seed(2)
v= sample(nrow(train_data), 0.80 * (nrow(train_data)))
training_data = train_data[v,]
testing_data = train_data[-v,]


## model making phase starts -----------------------------------------------------------------------------------------------------------------
## making linear model -----------------------------------------------------------------------------------------------------------------------
lin.fit = lm(y~. - ID,data=training_data)

## finding aliased coefficents --------------------------------------------------------------------------------------------------------------
ld.vars <- attributes(alias(lin.fit)$Complete)$dimnames[[1]]
ld.vars


## use Vif for eliminating non contributing parameter-----------------------------------------------------------------------------------------
library(car)
sort(vif(lin.fit),decreasing = T)[1:3]

## eliminating vif value above 10 -------------------------------------------------------------------------------------------------------------
lin.fit = lm(y~. -ID-month_may,data=training_data)
sort(vif(lin.fit),decreasing = T)[1:3]
lin.fit = lm(y~. -ID-month_may-job_blue_collar,data=training_data)
sort(vif(lin.fit),decreasing = T)[1:3]

## on the basis of vif model is as
formula(lin.fit)

## summarize
summary(lin.fit)

## now with the help of step function we remove variable which have probability greater than 0.05
lin.fit = step(lin.fit)
summary(lin.fit)
formula(lin.fit)

## the final model is below ------------------------------------------------------------------------------------------------------------------
log.fit = glm(y ~  balance + day + duration + campaign + job_student + 
                job_housemaid + job_retired + job_admin. + job_technician + 
                job_management + marital_married + education_tertiary + 
                housing_yes + loan_no + contact_unknown + 
                month_mar + month_sep + month_oct + month_jan + month_feb + 
                month_apr + month_nov + month_jun + month_aug + month_jul + 
                poutcome_other + poutcome_failure + poutcome_unknown
              , data = training_data, family = "binomial")
summary(log.fit)

## predict the score on testing data
predict.score=predict(log.fit,newdata = testing_data,type='response')
## obtaining auc on testing_data ---------------------------------------------------------------------------------------------------------------
install.packages(ROCR)
library(ROCR)
install.packages(pROC)
library(pROC)
auc(roc(as.numeric(testing_data$y),as.numeric(predict.score)))
## score is less(AUC IS 0.906) so linear model we can try randomForest model ----------------------------------------------------------------------------------


## making random forest model
install.packages("randomForest")
library(randomForest)
library(pROC)
rf.tree=randomForest(factor(y)~.- ID, data=training_data , do.trace = T)
## predict the score on testing data
predict.score=predict(rf.tree,newdata = testing_data,type='prob')[,2]
## obtaining auc on testing_data ---------------------------------------------------------------------------------------------------------------
auc(roc(as.numeric(testing_data$y),as.numeric(predict.score)))
## auc score is fine as it is ~ 0.924 so this is the best fitted model here ------------------------------------------------------------------


## lets make the final model now ---------------------------------------------------------------------------------------------------------------
final.model =randomForest(factor(y)~.- ID, data=train_data, do.trace = T)
## predict the probability on test_data 
final.probability.prediction = predict(final.model,newdata = test_data,type='prob')[,2]

## we have to give answer in hard class values so  lets do it , here KS Score----------------------------------------------------------------------------------
train.score=predict(final.model,newdata = train_data,type='prob')[,2]
real=train_data$y
cutoffs=seq(0.001,0.999,0.001)
cutoff_data=data.frame(cutoff=99,Sn=99,Sp=99,KS=99)

for(cutoff in cutoffs){
  
  predicted=as.numeric(train.score>cutoff)
  
  TP=sum(real==1 & predicted==1)
  TN=sum(real==0 & predicted==0)
  FP=sum(real==0 & predicted==1)
  FN=sum(real==1 & predicted==0)
  
  P=TP+FN
  N=TN+FP
  
  Sn=TP/P ## sensitivity
  Sp=TN/N  ## specificity
  precision=TP/(TP+FP)
  recall=Sn
  
  KS=(TP/P)-(FP/N)
  cutoff_data=rbind(cutoff_data,c(cutoff,Sn,Sp,KS))
}

## removing the first row from the cutoff_data ----------------------------------------------------------------------------------------------
cutoff_data=cutoff_data[-1,]

## deciding the final cutoff on the basis of Maximaum KS score ------------------------------------------------------------------------------
my_cutoff=cutoff_data$cutoff[which.max(cutoff_data$KS)]
my_cutoff

## score can be calculated as --------------------------------------------------------------------------------------------------------------
score = 1-(0.025/max(cutoff_data$KS))
score
## predicting the value in the form of 1 and 0 ---------------------------------------------------------------------------------------------
final.test.prediction =as.numeric(final.probability.prediction >my_cutoff)

## predicting the value in the form of Yes and NO 
final.test.prediction = as.character(final.test.prediction == 1)
final.test.prediction = gsub("FALSE","No",final.test.prediction)
final.test.prediction = gsub("TRUE","Yes",final.test.prediction)


## writing the results in csv file ---------------------------------------------------------------------------------------------------------
write.csv(final.test.prediction,"Monica_Desai_P5_part2.csv",row.names = F)


