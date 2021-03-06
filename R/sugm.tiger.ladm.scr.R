#----------------------------------------------------------------------------------#
# Package: flare                                                                   #
# sugm.tiger.ladm.scr(): Tuning insensitive method for                             #
#                        sparse precision matrix estimation                        #
# Authors: Xingguo Li                                                              #
# Emails: <xingguo.leo@gmail.com>                                                  #
# Date: Jan 3rd, 2018                                                              #
# Version: 1.6.0                                                                   #
# ------
# Modified
# Author: Giuseppe Forte                                                           #
# Date: Mar 27th 2019                                                              #
#----------------------------------------------------------------------------------#

sugm.tiger.ladm.scr <- function(data, n, d, maxdf, rho, lambda,
                                shrink, prec, max.ite, verbose, doPar.clusters,
                                doPar.verbose){
  if(verbose==TRUE)
    cat("Tuning-Insensitive Graph Estimation and Regression.\n")
  Z = data
  rm(data)
  ZZ = crossprod(Z)
  nlambda = length(lambda)
  lambda = lambda-shrink*prec
  d1 = d-1
  num.scr = d1
  if(d1>=n){
    if(n<=3){
      num.scr1 = n
      num.scr2 = n
    }else{
      num.scr1 = ceiling(n/log(n))
      num.scr2 = n-1
    }
  }else{
    if(d1<=3){
      num.scr1 = d1
      num.scr2 = d1
    }else{
      num.scr1 = ceiling(sqrt(d1))
      num.scr2 = ceiling(d1/log(d1))
    }
  }
  ite.int = matrix(0,nrow=d,ncol=nlambda)
  ite.int1 = matrix(0,nrow=d,ncol=nlambda)
  ite.int2 = matrix(0,nrow=d,ncol=nlambda)
  ite.int3 = matrix(0,nrow=d,ncol=nlambda)
  ite.int4 = matrix(0,nrow=d,ncol=nlambda)
  ite.int5 = matrix(0,nrow=d,ncol=nlambda)
  x = rep(0,d*maxdf*nlambda)
  col.cnz = rep(0,d+1)
  row.idx = rep(0,d*maxdf*nlambda)
  icov.list1 = vector("list", nlambda)
  for(i in 1:nlambda){
    icov.list1[[i]] = matrix(0,d,d)
  }
  if (!is.null(doPar.clusters)) doParallel::registerDoParallel(doPar.clusters)
  foreachlist <- foreach (j = 1:d, .verbose = doPar.verbose, .combine = list,
                          .multicombine = T, .maxcombine = d+1,
                          .packages = "flare") %dopar% { # d = ncol(Z)
      Z.j = Z[,j]
      Z.resj = Z[,-j]
      Zy = ZZ[-j,j]
      idx.scr0 = order(Zy)
      idx.scr1 = idx.scr0[1:num.scr1]
      idx.scr2 = idx.scr0[1:num.scr2]
      ZZ0 = ZZ[-j,-j]
      Z.order = ZZ0[idx.scr0,idx.scr0]
      gamma = max(colSums(abs(Z.order)))
      icov0 = rep(0,d*nlambda)
      ite0.int = rep(0,nlambda)
      ite0.int1 = rep(0,nlambda)
      ite0.int2 = rep(0,nlambda)
      ite0.int3 = rep(0,nlambda)
      ite0.int4 = rep(0,nlambda)
      ite0.int5 = rep(0,nlambda)
      x0 = rep(0,maxdf*nlambda)
      col.cnz0 = 0
      row.idx0 = rep(0,maxdf*nlambda)
      if (verbose) cat("Column ",j," of ",d,"\n")
      str=.C("sugm_tiger_ladm_scr", as.double(Z.j), as.double(Z.resj),
             as.double(Zy), as.double(Z.order), as.double(icov0), as.double(x0),
             as.integer(d), as.integer(n), as.double(gamma), as.double(lambda),
             as.integer(nlambda), as.double(rho), as.integer(col.cnz0),
             as.integer(row.idx0), as.integer(ite0.int), as.integer(ite0.int1),
             as.integer(ite0.int2), as.integer(ite0.int3), as.integer(ite0.int4),
             as.integer(ite0.int5), as.integer(num.scr1), as.integer(num.scr2),
             as.integer(idx.scr0), as.integer(idx.scr1), as.integer(idx.scr2),
             as.integer(max.ite), as.double(prec), as.integer(j), PACKAGE="flare")
      # str is a list with elements in the sequence provided to .C; e.g. [27] = prec.
      # drop burdensome returned data that is not used in further computations.
      str[[1]] <- str[[2]] <- str[[3]] <- str[[4]] <- NA
      return(str)
    }
  for (j in 1:d) {
    icov = matrix(unlist(foreachlist[[j]][5]), byrow = FALSE, ncol = nlambda)
    for(i in 1:nlambda){
      icov.list1[[i]][,j] = icov[,i]
    }
    cnt = unlist(foreachlist[[j]][13])
    col.cnz[j+1] = cnt+col.cnz[j]

    if(cnt>0){
      x[(col.cnz[j]+1):col.cnz[j+1]] = unlist(foreachlist[[j]][6])[1:cnt]
      row.idx[(col.cnz[j]+1):col.cnz[j+1]] = unlist(foreachlist[[j]][14])[1:cnt]

      ite.int[j,] = unlist(foreachlist[[j]][15])
      ite.int1[j,] = unlist(foreachlist[[j]][16])
      ite.int2[j,] = unlist(foreachlist[[j]][17])
      ite.int3[j,] = unlist(foreachlist[[j]][18])
      ite.int4[j,] = unlist(foreachlist[[j]][19])
      ite.int5[j,] = unlist(foreachlist[[j]][20])
    }
  }
  if (!is.null(doPar.clusters)) foreach::registerDoSEQ()
   icov.list = vector("list", nlambda)
  # for(i in 1:nlambda){
  #       icov.i = icov.list1[[i]]
  #       icov.list[[i]] = icov.i*(abs(icov.i)<=abs(t(icov.i)))+t(icov.i)*(abs(t(icov.i))<abs(icov.i))
  #}
  ite = list()
  ite[[1]] = ite.int1
  ite[[2]] = ite.int2
  ite[[3]] = ite.int
  #   ite[[4]] = ite.int4
  #   ite[[5]] = ite.int5
  #   ite[[6]] = ite.int3
  return(list(icov=icov.list, icov1=icov.list1,ite=ite, x=x[1:col.cnz[d+1]], col.cnz=col.cnz, row.idx=row.idx[1:col.cnz[d+1]]))
}
