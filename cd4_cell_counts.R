# Load libraries & data---------------------------------------------------------------------------------------------------------

library(ggplot2)
library(splines)
library(GGally)
library(ggpubr)
library(ggcorrplot)
library(splines)
library(nlme)
library(lme4)
library(lattice)
cd4 <- read.table(".../.../cd4data.txt", header = TRUE)

# Exploratory analysis-----------------------------------------------------------------------------------------------------------

# Compute correlation matrix
corr <- round(cor(cd4[,1:7]), 3)
corr
ggcorrplot(corr, method = "circle")  # plot correlation



popid <- unique(cd4$ID)  # Unique ID for subjects


number.cases <- length(popid)  # 369 number of cases

cd4$CD4sqrt <- cd4$CD4^0.5  # Square root CD4 cell counts/ used as response

# Time rounded to nearest year and quarter
cd4$yr <- round(cd4$Time)
cd4$quarter <- round(4*cd4$Time)/4
number.quarters <- length(unique(cd4$quarter))


# density plot of CD4 cells & square root CD4 cell
p1 <- ggplot(data=cd4, aes(CD4)) + geom_density(color="darkblue", fill="lightblue")
p2 <- ggplot(data=cd4, aes(CD4sqrt)) + geom_density(color="darkblue", fill="lightblue")
ggarrange(p1,p2, ncol=2, nrow=1)





# spaghetti plot function

spagplot.anyvar = function(subset, indiv, varname = "CD4",
                           title = NULL) {
  # Plot the line for the first subject, making sure the axes
  #  can accommodate all
  plot(cd4$Time[cd4$ID==subset[1]], cd4[,varname][cd4$ID==subset[1]],
       xlim = range(cd4$Time), ylim = range(cd4[,varname]), 
       main = title, type="l", col="grey", xlab="Time", ylab=varname)
  # Add lines for the other individuals to the plot
  # Make wider and coloured if we want individual lines
  for(i in 2:length(subset)) {
    if (!indiv) {
      lines(cd4$Time[cd4$ID==subset[i]], 
            cd4[,varname][cd4$ID==subset[i]], col="grey");      
    } else {
      lines(cd4$Time[cd4$ID==subset[i]], 
            cd4[,varname][cd4$ID==subset[i]], col=i, 
            lwd=2, type="b");
    }
  }  
  # Add the mean response for the entire subset via spline smoother  
  lines(smooth.spline(cd4$Time, cd4[,varname]), lwd = 3, col = "black")
  # Add a green vertical line at time 0
  abline(v = 0, col = "green", lwd = 3)
}


# spaghetti plot for all subjects in the data with the populaion mean overlaid
spagplot.anyvar(popid, FALSE, varname = "CD4sqrt")


# spaghetti plot for a random sample of subjects
set.seed(12345)
spagplot.anyvar(sample(popid, 20, replace = FALSE), TRUE,varname = "CD4sqrt")


# function to compute group means of cd4 cells over time stratified by a covariate
comparemeans = function(varname, sub1, sub2, title) {
  # Create a smooth spline for each subgroup
  p1 <- smooth.spline(cd4$Time[sub1], cd4[sub1,varname])
  p2 <- smooth.spline(cd4$Time[sub2], cd4[sub2,varname])
  # Make sure the plot is large enough
  xlimit <- c(min(p1$x,p2$x), max(p1$x,p2$x))
  ylimit <- c(min(p1$y,p2$y), max(p1$y,p2$y))
  # Set up the plot title
  title <- paste(varname, "by", title)
  # Plot subgroup 1 in red
  plot(p1, main = title, type = "l", lwd = 2, 
       col = "red", ylim = ylimit, xlim = xlimit, 
       xlab = "Time", ylab = "sqrt(CD4)")
  # Plot subgroup 2 in blue
  lines(p2, lwd = 2, col = "blue", 
        ylim = ylimit, xlim = xlimit)
}


# plot 
par(mfrow=c(2,2));
comparemeans(cd4$Age<=quantile(cd4$Age, 0.25), 
             cd4$Age>=quantile(cd4$Age, 0.75), 
             title="Age", varname = "CD4sqrt") 
comparemeans(cd4$Packs<=quantile(cd4$Packs, 0.25), 
             cd4$Packs>=quantile(cd4$Packs, 0.75), 
             title = "Smoking", varname = "CD4sqrt")
comparemeans(cd4$Drugs==0, cd4$Drugs==1, 
             title = "Drug use", varname = "CD4sqrt")
comparemeans(cd4$Cesd>=quantile(cd4$Cesd, 0.25),
             cd4$Cesd<=quantile(cd4$Cesd, 0.75), 
             title="CESD depression", varname = "CD4sqrt")



# Modeling----------------------------------------------------------------------------------------------------------------------


# Linear model-------------------------------------------------------------------------------------------------------------------
simple.lm <- lm(CD4sqrt ~ Time + Age + Packs + Cesd + Drugs + Sex, data = cd4)
summary(simple.lm)


# extract residuals
cd4$resid <- resid(simple.lm)
cd4$yr <- round(cd4$Time)

# function to plot trends of residuals
panel.cor <- function(x, y, digits = 2, prefix = "", cex.cor) {
  usr <- par("usr"); on.exit(par(usr))
  par(usr = c(0, 1, 0, 1))
  r <- abs(cor(x, y, use = "pairwise.complete.obs"))
  txt <- format(c(r, 0.123456789), digits=digits)[1]
  txt <- paste(prefix, txt, sep="")
  if(missing(cex.cor)) cex <- 0.8/strwidth(txt)
  text(0.5, 0.5, txt, cex = cex * r)
}

# reshape data to wide format from long
cd4.wide <- reshape(cd4[,c("ID", "resid", "yr")],
                    direction = "wide", v.names = "resid",
                    timevar = "yr", idvar = "ID")

# plot residuals with correlation
pairs(cd4.wide[,c(5, 2, 3, 6:8)], upper.panel = panel.cor)



# calculate the locations of 7 equally spaced knots
Time.range <- range(cd4$Time)
n.knots <- 7

# calculates the spaces between knots
knot.spacing <- diff(Time.range)/(n.knots+1)

# knot locations (without the min and max)
Time.knots <- seq(Time.range[1], Time.range[2],
                  knot.spacing)[-c(1,(n.knots+2))]

# Linear model with 7 knots in time---------------------------------------------------------------------------------------------
model1 <- lm(CD4sqrt ~ ns(Time,knots = Time.knots) +
               Age + Packs + Drugs + Cesd + Sex, data = cd4)



# extract the residuals and fits from model1
cd4$model1.residuals <- model1$residuals
cd4$model1.fit <- model1$fitted.values


par(mfrow=c(2,1))
spagplot.anyvar(popid, FALSE, varname = "model1.residuals")
spagplot.anyvar(popid, FALSE, varname = "model1.fit")
# Add in vertical lines at the knot locations
abline(v=Time.knots)


# Create a blank matrix to store the reshaped data
cd4.wide <- matrix(NA, nrow = number.cases, ncol = number.quarters)
# For each individual...
for (i in 1:number.cases) {
  # Identify the rows belonging to that id
  selectcase <- (cd4$ID == popid[i])
  # Work out which columns their data should go into
  quarter.col <- 4 * cd4$quarter[selectcase] + 1 - min(4*cd4$quarter)
  # Input the residuals into the matrix
  cd4.wide[i,quarter.col] <- cd4[selectcase,"model1.residuals"]
}

# Calculate sample correlations
cormat <- cor(cd4.wide, use = "pairwise.complete.obs")
nrow <- dim(cormat)[1]
# Create a blank matrix for the ACF
acf <- rep(0, nrow - 1)
# Fill it in with the means along the diagonals (equal lags)
for (lag in 1:(nrow-2)){
  acf[lag] <- mean(diag(cormat[-(nrow:(nrow-lag+1)),-(1:lag)]),
                   na.rm = TRUE)
}
acf[nrow-1] <- cormat[1,nrow]
#par(mfrow = c(1,1))
# type = "h" plots as vertical bars
#plot(1:(nrow-1), acf, type = "h", ylim = c(0,1), xlab = "lag")
#title("Autocorrelations for residuals in CD4sqrt model1")
ut <- NULL
vt <- NULL
# Loop over all individuals
for (i in 1:length(popid)) {
  # Extract the values for this id
  times <- cd4$Time[cd4$ID == popid[i]]
  resids <- cd4$model1.resid[cd4$ID == popid[i]]
  # outer performs a function on each pair of values
  # from two vectors. Use this to compute the time
  # lags between every pair of observations
  u <- outer(times, times, function(x,y) abs(x-y))
  # Just take the lower triangle, so we aren't double counting
  u <- u[lower.tri(u)]
  # Add these to the existing list
  ut <- c(ut,u)
  # Do the same for the half squared differences between each
  # pair of residuals
  v <- outer(resids, resids, function(x,y) 0.5*(x-y)^2)
  v <- v[lower.tri(v)]
  vt <- c(vt,v)
}
par(mfrow = c(1,2))
# Scatter plot of every pair of observations from the same
# individual
plot(ut, vt, type = "p",
     pch = ".", lwd = 1, ylim=c(0,50),
     xlab="Time spacing", ylab="Half squared residual")
# Fit a LOWESS curve
tmp <- loess(vt[sort.list(ut)] ~ ut[sort.list(ut)], span = 3)
# Add it to the graph
lines(ut[sort.list(ut)], tmp$fitted, col = "red", lwd = 3)
# Add a dashed horizontal line for the process variance
abline(h = var(cd4$model1.residuals), lwd = 2, lty = 2)
plot(1:(nrow-1), acf, type = "h", ylim = c(0,1), xlab = "lag")



# Compound symmetry model-------------------------------------------------------------------------------------------------------
gls.comp <- gls(CD4sqrt ~ yr + Packs + Drugs + Cesd + Sex, data = cd4,
                correlation = corCompSymm(form = ~ yr | ID))
summary(gls.comp)



# Exponential model-------------------------------------------------------------------------------------------------------------
gls.AR<- gls(CD4sqrt ~ yr + Packs + Drugs + Cesd + Sex, data = cd4,
             correlation = corAR1(form = ~ 1 | ID))
summary(gls.AR)


# Compare the two covariance structures
anova(gls.AR, gls.comp)







lme.packs <- lme(CD4sqrt ~ Time + Age + Packs + Drugs + Cesd + Sex,
                 data = cd4, random = ~ Packs | ID)
summary(lme.packs)
getVarCov(lme.packs,individual=c(1,35),type="marginal")

VarCorr(lme.packs)


xyplot(CD4sqrt ~ Time, data = cd4, type = "b", group=ID,col.line = "gray20")


# Linear Mixed Effects Modelling------------------------------------------------------------------------------------------------

# Random effects on intercept, trend pre and trend post seroconversion

cd4$time0 <- pmax(0,cd4$Time)
model1 <- lme(CD4sqrt~Time+time0, random= ~ Time + time0 | ID, data=cd4)
summary(model1)


# Standard Error for \hat \beta_2 + \hat \beta_3:
(c(0,1,1)%*%model1$varFix%*%c(0,1,1))^0.5
getVarCov(model1)


# BLUP curves--------------------------------------------------------------------------------------------------------------------
s4 <- subset(cd4,ID==20906)
s25 <- subset(cd4, ID==10191)

# Plot Subject 20906 data and overlay with Subject 10191 data
plot(CD4sqrt~Time,data=s4,pch=4, col="red",xlim=c(-3,5),ylim=c(0,60),xlab="Time relative to seroconversion",
     ylab="Square root of CD4 cell counts")
points(CD4sqrt~Time,data=s25,pch=3, col="blue")


# define time trends
t1 <- seq(-3,5,0.01)
t0 <- pmax(t1,0)
incpt<-rep(1,length(t1))
X<-cbind(incpt,t1,t0)


# get REML Fixed Effects Estimates
model1$coefficients$fixed
pmean<-X%*%model1$coefficients$fixed


#Plot the population mean using the fixed effect estimates
lines(t1,pmean,lty=1,lwd=3)

# BLUP line for subject 20906; 
# Add individual random effects for Subject 20906
l4<-X%*%model1$coefficients$random$ID[4,]+pmean
# overlay Subject 4 fit on the graph
lines(t1,l4,col="red",lty=1,lwd=2)


# BLUP line for Subject 10191;
l25<-X%*%model1$coefficients$random$ID[25,]+pmean
lines(t1,l25,col="blue",lty=1,lwd=2)


# add text
text(0,35,"Subject 20906")
text(2,10,"Subject 10191")


# Plot Subject 20906 data, overlay with Subject 10191 data
plot(CD4sqrt~Time,data=s4,pch=4,xlim=c(-5,5),ylim=c(0,60),
     xlab="Time relative to menarche (years)",ylab="Percent body fat")
points(CD4sqrt~Time,data=s25,pch=16)



# OLS Fixed Effects--------------------------------------------------------------------------------------------------------------
s4<-data.frame(s4,time0=pmax(0,s4$Time))
s25<-data.frame(s25,time0=pmax(0,s25$Time))
s4ols<-lm(CD4sqrt~Time+time0,data=s4)$coefficients
s25ols<-lm(CD4sqrt~Time+time0,data=s25)$coefficients
# REML Fixed Effects (calculated above)

lines(t1,pmean,lty=1,lwd=3)


# BLUP line for subjects
lines(t1,l4,col="red",lty=1,lwd=2)
lines(t1,l25,col="blue",lty=1,lwd=2)

# Lines for individual OLS fits for subjects
# calculated and overlayed on plot for comparison with BLUPS
olsl4<-X%*%s4ols
lines(t1,olsl4,col="red",lty=2,lwd=2)


olsl25<-X%*%s25ols
lines(t1,olsl25,col="blue",lty=2,lwd=2)


# intercept model, calculate residuals, use gls with residuals
model2=lme(CD4sqrt ~ Time + time0, random= ~ 1 | ID,data=cd4)
res=model2$residuals[,1]
fev.lm=lme(res~Time+time0,random= ~ 1 | ID,data=cd4)

# residual variogram loess
vgram=Variogram(fev.lm,form=~Time|ID,collapse="none",resType = "response")
plot(vgram$dist,vgram$variog,ylim=c(0,100),pch=16,cex=0.2,col="blue",xlab="time diff",ylab="var")
lines(lowess(vgram$dist,vgram$variog,iter=0),col="blue",lwd=2)
abline(h=var(res))

# residual variogram Gaussian
fev.lm2=update(fev.lm,correlation = corGaus(form = ~ Time|ID,nugget=TRUE,value=c(2,0.1)))
vgram2=Variogram(fev.lm2,form=~Time|ID,collapse="none",resType = "response")
gauss=attr(vgram2, "modelVariog")
lines(gauss$dist,gauss$variog,col="red",lwd=2)

# residual variogram Exponential
fev.lm3=update(fev.lm,correlation = corExp(form = ~ Time|ID,nugget=TRUE,value=c(2,0.1)))
vgram3=Variogram(fev.lm3,form=~Time|ID,collapse="none",resType = "response")
expV=attr(vgram3, "modelVariog")

lines(expV$dist,expV$variog,col="forestgreen",lwd=2)
leg.names <- c("lowess","Exponential", "Gaussian")

legend("topright",leg.names,lty=c(1,1),col=c("blue","forestgreen","red"),lwd=2)


# Fitting models with different structures---------------------------------------------------------------------------------------

# Gaussian
model2.gau <- lme(CD4sqrt ~ Time + time0, random= ~ 1 | ID,
                  corr=corGaus(form= ~ Time |ID,nugget=TRUE,value=c(2,.1)), 
                  data=cd4)
summary(model2.gau)


# Exponential
model2.exp <- lme(CD4sqrt ~ Time + time0, random= ~ 1 | ID,
                  corr=corExp(form= ~ Time | ID,nugget=TRUE,value=c(2,.1)), 
                  data=cd4)

summary(model2.exp)

