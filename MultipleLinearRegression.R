# Coursework: Multiple Linear Regression

#Preparation & packages ####

setwd("/nfs/cfs/home2/zctq/zctqarr/m_larrode_pols0010")

library(haven)
library(dplyr)
library(forcats)
library(ggplot2)
library(relaimpo)
library(survey)
library(effects)
options(survey.lonely.psu="adjust")
library(car)

longitudinal_td <- read_dta("longitudinal_td.dta")
sample.w9 <- subset(longitudinal_td, wave == "9")


#Subsetting & Pre-selection of variables of interest (theoretical basis) ####

sample <- subset (sample.w9, select = c(psu, strata, indinus_lw_9, indscus_lw_9, scghq1_dv ,age_dv, sex_dv, ethn_dv, mstat_dv, hiqual_dv, jbnssec8_dv, fihhmngrs_dv, jbstat), !fihhmngrs_dv <0.01)

#Continuous variables: centering
sample$age_dv_cen = sample$age_dv - mean(sample$age_dv)
sample$fihhmngrs_dv_cen = sample$fihhmngrs_dv - mean(sample$fihhmngrs_dv)

#Categorical variables (recode as factor, collapse & choose reference value)
sample$sex_dv <- as_factor(sample$sex_dv, levels = "labels")
sample$ethn_dv <- as_factor(sample$ethn_dv, levels = "labels")

sample$mstat_dv <- as_factor(sample$mstat_dv, levels = "labels")
levels(sample$mstat_dv) <- list('Single'="single", 'Couple'="married or civil partnership", 'Single'="separated or divorced", 'Single'="widowed", 'Couple'="living as a couple")
table(sample$mstat_dv)
sample$mstat_dv<- relevel(sample$mstat_dv, ref = "Couple")

sample$hiqual_dv <- as_factor(sample$hiqual_dv, levels = "labels")
table(sample$hiqual_dv) #highest qualification ever reported
sample$hiqual_dv<- relevel(sample$hiqual_dv, ref = "No qual")

sample$jbnssec8_dv <- as_factor(sample$jbnssec8_dv, levels = "labels")
sample$jbnssec8_dv <- dplyr::recode(sample$jbnssec8_dv, "Large employers & higher management"= "Management & professional", "Higher professional" = "Management & professional", "Lower management & professional"="Management & professional","Semi-routine"= "Semi-routine & routine", Routine="Semi-routine & routine")
table(sample$jbnssec8_dv) #Current job: 8 categories version of NS-SEC (collapsed into 5)

sample$jbstat <- as_factor(sample$jbstat, levels = "labels")
sample$jbstat <- dplyr::recode(sample$jbstat,"self employed"="Self Employed","unemployed"="Unemployed", "retired"="Retired","full-time student"="Full-time Student", "on maternity leave"="Maternity leave, family care or home", "Family care or home"="Maternity leave, family care or home", "Govt training scheme"="Other", "Unpaid, family business"="Other", "On apprenticeship"="Other", "doing something else"="Other")
table(sample$jbstat) #job status
sample$jbstat <- relevel(sample$jbstat, ref = "Paid employment(ft/pt)")



#plot wellbeing & jbstat (selection of jbstat values for better visibility)
sample.table <- subset (sample, select = c(scghq1_dv, jbstat),jbstat!='Other' & jbstat!='Maternity leave, family care or home' & jbstat!='Self Employed')

ggplot(sample.table, aes(x = scghq1_dv))+
  geom_density(aes(color=jbstat))+
  labs(title = "Fig. 1, Distribution of Psychological Distress according to Current Labour Force Status", caption = "*limited selection of labour force statuses for better readability")+
  xlab('Psychological Distress')+
  scale_color_discrete(name='Labour Force Status*')
#light positively skew, but no transformation deemed necessary



#Variable selection for regression model (w/ statistical tools) ####

#Partial F-tests: do variables improve explanatory power of regression 
full <- lm(data=sample, scghq1_dv~jbnssec8_dv+age_dv_cen+sex_dv+ethn_dv+mstat_dv+jbhrs+hiqual_dv+jbstat+fihhmngrs_dv_cen)

reduced_jbnssec8_dv <- lm(data=sampleV2, scghq1_dv~age_dv_cen+sex_dv+mstat_dv+jbhrs+hiqual_dv+jbstat+fihhmngrs_dv_cen)

anova(reduced_jbnssec8_dv, model_full)
#F-test not significant cannot reject null hypothesis that coefficient for jbnssec8_dv=0


#Variable transformations ####

#household income
ggplot(sample, aes(x = fihhmngrs_dv))+
  geom_density() #strong positive skew 
ggplot(sample, aes(x = log(fihhmngrs_dv)))+
  geom_density() #better distribution (BUT changes interpretation in linear regression)



#Adjustments for survey non-response & complex survey design ####

#clustered and stratified design: specify clustering & stratification variables
#use self-completion weights (scghq1_dv was self-completed)
adj.sample <- svydesign(data=sample, id = ~psu, weights = ~indscus_lw_9, strata=~strata, nest=TRUE)

#weighted descriptive statistics (adjusted to complex survey design)
svymean(~scghq1_dv, adj.sample, na.rm=TRUE)
svymean(~age_dv, adj.sample,na.rm=TRUE)
svymean(~fihhmngrs_dv, adj.sample, na.rm=TRUE)
#pushed up by very high values
summary(sample$fihhmngrs_dv) #median 3171 (non-adjusted)

svytable(~sex_dv,adj.sample)
svytable(~jbstat,adj.sample)
svytable(~mstat_dv,adj.sample)


#linear regression model
adj.model<-svyglm(design = adj.sample, formula = scghq1_dv~jbstat+age_dv_cen+sex_dv+mstat_dv+fihhmngrs_dv_cen+ethn_dv)
summary(adj.model)


#further variable selection: Akaike information criterion (AIC) statistic
adj.model.nested <-svyglm(design = adj.sample, formula = scghq1_dv~jbstat+age_dv_cen+sex_dv+mstat_dv+fihhmngrs_dv_cen)
AIC(adj.model.nested, adj.model)
#remove ethnicity variable  (does NOT improve explanatory power of model)



final.adj.model <- svyglm(design = adj.sample, formula = scghq1_dv~jbstat+sex_dv+age_dv_cen+fihhmngrs_dv_cen+mstat_dv)
summary(final.adj.model)


#relative importance of explanatory variables
reduced_model.relimp<-calc.relimp(final.adj.model,rela=TRUE)
plot(reduced_model.relimp)



#Interaction sex & labour force status
model.inter.sex.jbstat <- svyglm(design = adj.sample.inter, formula = scghq1_dv~jbstat*sex_dv)
summary(model.inter.sex.jbstat)

plot(effect("jbstat:sex_dv",model.inter.sex.jbstat), xlab={"Current Labour Market Status"}, ylab={"Psychological Distress"})

#higher impact of being a full-time student on subjective well-being when the respondent is a woman 