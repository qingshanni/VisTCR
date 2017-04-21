source('lib_tcr.R')

###################
seperate_template_cell_sample <- function(in_dir,out_dir){
    #### read reference file
    cell <- read.csv(file.path(in_dir,"ref_file_cell"),sep="\t",stringsAsFactors = F)
    cont <- read.csv(file.path(in_dir,"ref_file_contaminate"),sep="\t",stringsAsFactors = F)
    tmpl <- read.csv(file.path(in_dir,"ref_file_template"),sep="\t",stringsAsFactors = F)
    
    
    ####  template
    fn_fastq    <- file.path(in_dir,"sample.fastq")
    mapped_tmpl  <- maping_tmpl_by_barcode(tmpl,fn_fastq)
    tmpl_par    <- compute_template_parameters(mapped_tmpl$tmpl_mapped)
    
    #load("mapped.RData")
    #### reference cell
    mapped_cell <- extract_ref_cdr3(mapped_tmpl$sample,cell,tmpl_par)
    
    #### contaminant
    mapped_con <- extract_ref_cdr3(mapped_cell$cdr3_sp,cont,tmpl_par)
    
    cdr3        <- del_multiple_v_segment(mapped_con$cdr3_sp)
    ##### stepwise clustering
    cdr3_stc <- stepwise_extraction_clustering_trained(cdr3,
                                                       mat_pam  = tmpl_par$mat_pam, cent_cutoff=tmpl_par$cent_cutoff,cutoff_ratio=tmpl_par$ratio_cutoff)  
    ### 
    
    cdr3_correct  <- correct_freq_ABI_cutoff(cdr3_stc,tmpl_par$ABI,mapped_cell$ref_cdr3 )
    
    sp <- list(n_reads            = mapped_tmpl$n_reads,
               tmpl_mapped        = mapped_tmpl$tmpl_mapped,
               tmpl_par           = tmpl_par,
               cell_mapped        = mapped_cell$ref_cdr3,
               contaminate_mapped = mapped_con$ref_cdr3,
               cdr3               = cdr3,
               cdr3_stc           = cdr3_stc,
               cdr3_correct       = cdr3_correct)
    save(sp,file=file.path(out_dir,"sample.RData"))
    1
}





########### 
sample_details_simple <- function(fn,method='mitcr'){
  dd <- list()
  if( method == 'mitcr' | method == 'mixcr' | method == 'dcnt'){   
    nt <- read_clone_data(fn,'nt')
    aa <- read_clone_data(fn,'aa')
    
    dd <- list(name = c("reads_nt","types_nt","reads_aa","types_aa"),
               value = c(sum(nt$count),length(nt$name),sum(aa$count),length(aa$name)))
  }

#   if( method == 'cdr3'){    
#     fn <- file.path(in_dir,"sample.RData")
#     load(fn)
#     
#     
#     tmpl  <- sum(sp$tmpl_par$tmpl_num)
#     n2b4  <- sp$cell_mapped$match_all
#     raw   <- sum(sp$cdr3$count)
#     raw_u <- dim(sp$cdr3)[1]
#     stc   <- sum(sp$cdr3_stc$count)
#     stc_u <- dim(sp$cdr3_stc)[1]
#     ABI   <- round(sum(sp$cdr3_correct$cdr3.ABI$count))
#     ABI_u <- dim(sp$cdr3_correct$cdr3.ABI)[1]
#     remove <- round(sum(sp$cdr3_correct$cdr3.cutoff$count))
#     remove_u <- dim(sp$cdr3_correct$cdr3.cutoff)[1]
#     correct <- round(sum(sp$cdr3_correct$cdr3.cell$count))
#     correct_u <- dim(sp$cdr3_correct$cdr3.cell)[1]
#     
#     dd <- list(name  = c('tmpl','n2b4','raw','raw_u','stc','stc_u','ABI','ABI_u','remove','remove_u','correct','correct_u'),
#                value = c(tmpl,n2b4,raw,raw_u,stc,stc_u,ABI,ABI_u,remove,remove_u,correct,correct_u))    
#   }
  dd
}

get_cdr3_by_type <- function(fn,type="cell"){
  load(fn)
  switch(type,
         raw = sp$cdr3,
         stc = sp$cdr3_stc,
         ABI = sp$cdr3_correct$cdr3.ABI,
         remove = sp$cdr3_correct$cdr3.cutoff,
         cell   = sp$cdr3_correct$cdr3.cell
  )  
}
######  
seg_usage_statistics <- function(fn,type="v"){
  cdr3 <- get_cdr3_by_type(fn,type=dtype)
  if(type=='v'){
    d = get_item_count(cdr3$v,count=cdr3$count)
  }else if(type == 'j'){
    d = get_item_count(cdr3$j,count=cdr3$count)
  }else{    
  }
  r <- sort_vj_name(d$name,index.return = T)
  d <- d[r$ix,]
  list(name=d$name, count=d$count, freq = d$freq) 
}


######
get_top_proportion <- function(fns_str,type='aa', hd = c(10, 100, 1000, 10000, 30000, 1e+05, 3e+05, 1e+06)){
  
  fns <- strsplit(fns_str,";")
  mx <- sapply(fns,function(fn){
    dd <- combine_sample_data(fn,type=type)$count
    r <- sapply(hd,function(hdt){ sum(head(dd,hdt))})  
    (r-c(0,r)[1:length(r)]) / sum(dd) 
    
  })
  col <- sprintf("%d-%d",c(0,hd) + 1, c(hd,0))[1:length(hd)]
  
  list(mx=mx,col=col)
}

######
get_clone_space <- function(fns_str,type='aa', clone_type= c(Rare = 1e-05, Small = 1e-04, 
                                                                           Medium = 0.001, Large = 0.01, Hyperexpanded = 1)){
  
  fns <- strsplit(fns_str,";")
  clone_type <- c(None = 0, clone_type)
  mx <- sapply(fns,function(fn){
    dd <- combine_sample_data(fn,type=type)$count
    dd <- dd / sum(dd)
    sapply(2:length(clone_type),function(i){
      sum(dd[dd > clone_type[i-1] & dd <= clone_type[i]])
    })
  })
  col <- sapply(2:length(clone_type),function(i){  
    paste0(names(clone_type[i]),  " (", clone_type[i - 1], " < X <= ", clone_type[i], ")")
  } )
  
  list(mx=mx,col=col)
}
#######
get_clonotype_tracking <- function(fns_str,type='aa'){
  
  fns <- strsplit(fns_str,";")
  
  lv_list <- lapply(fns,function(fn){
    dd <- combine_sample_data(fn,type=type)
    lv <- dd$count
    names(lv) <- dd$name
    lv
  })
  cl_mx1  <- list_vector_to_mx(lv_list)
  cl_mx2 <- cl_mx1
  cl_mx2[cl_mx1 >0] <- 1
  num2 <- colSums(cl_mx2)
  
  share_n <- sapply(2:length(fns),function(k){  sum(num2 >= k)})
  
  
  cl_mx1  <- cl_mx1[,num2 > 1]
  cl_mx2 <- cl_mx2[,num2 > 1]
  num1 <- colSums(cl_mx1)
  num2 <- colSums(cl_mx2) 
  
  d <- rbind(num2,num1,cl_mx1)
  s <- names(num1)  
  idx <- order( num2 * max(num1 + 1) + num1, decreasing = TRUE)
  
  list(mx=t(d[,idx]),col=s[idx],share_k = 2:length(fns),share_n=share_n)
}
######
get_overlap_analysis <- function(fns_str,type='aa'){
  
  fns <- strsplit(fns_str,";")
  
  lv_list <- lapply(fns,function(fn){
    dd <- combine_sample_data(fn,type=type)
    lv <- dd$count
    names(lv) <- dd$name
    lv
  })
  
  n   <- length(lv_list)
  r <- matrix(n*(n+1) * 5, n*(n+1)/2 ,10)
  k <- 1
  for(i in 1:n )
    for(j in i:n){
      s1 <- lv_list[[i]]
      s2 <- lv_list[[j]]
      n1 <- sum(s1)
      n2 <- sum(s2)
      
      names_u <- intersect(names(s1),names(s2))      
      ct      <-  length(names_u)
      ctm     <-  2 * length(names_u) / (length(s1) + length(s2))
      cr      <-  sum(sapply(names_u,function(t){ min(s1[t],s2[t])}))
      crm     <- 2 * cr / (n1 + n2 )
      r[k,] <- c(i,length(s1),n1,j,length(s2),n2,ct,ctm,cr,crm)
      k = k+1   
    }      
  r
}



#####
get_similarity_within_group <- function(fns,type="aa",method="horn"){
  if(length(fns) > 1){
    dd_list <- lapply(fns,function(fn){
      read_clone_data(fn,type = type)
    })    
    sv <- similarity_vector(dd_list,method=method)
  }else{
    sv <- 1
  }
  sv
}

#####
get_group_similarity_matrix <- function(fns_str,type="aa",method="horn"){
  fns <- strsplit(fns_str,";")
  dd_list <- list()
  for(i in 1:length(fns)){
    d <- lapply(fns[[i]],function(fn){
      dd  <- read_clone_data(fn,type=type)
      dd  <- get_item_count(dd$name,count = dd$count)
    })  
    dd_list <- c(dd_list,d)
  }
  sv    <- similarity_matrix(dd_list,method=method)
  idx   <- c(0,cumsum(sapply(fns,function(fns1){ length(fns1)})))
  
  mx <- sapply(1:length(fns),function(i){
    sapply(1:length(fns),function(j){
      cat(i,' ', j ,'   ',(idx[i]+1):idx[i+1] , '   ', (idx[j]+1):idx[j+1] ,'\n')
      mean( sv[(idx[i]+1):idx[i+1], (idx[j]+1):idx[j+1] ])
    })
  })
}

######
get_two_group_similarity <- function(fns1,fns2,type="aa",method="horn"){
  dd_list <- lapply(list(g1=fns1,g2=fns2),function(fn){
    dd <- combine_sample_data(fn,type=type)  
  })
  sv <- similarity_vector(dd_list,method=method)
}

#######
tcr_diversity <- function(dd,method="shan",q=2){
  v <-   switch(method,
                shan  =  { md <- dd / sum(dd)
                           -sum(md * log(md)) },
                smp  =  { md <- dd / sum(dd)
                          sum(md^2) },
                ismp =  { md <- dd / sum(dd)
                          1 / sum(md^2)   },
                gsi  =  { md <- dd / sum(dd)
                          1 - sum(md^2)  },
                bpi  =  max(dd) / sum(dd) ,
                renyi=  {  md <- dd / sum(dd)
                           log(sum(md^q))/(1-q) }
  )
}
#######
group_diversity <- function(fns_str,type="aa",method="shan" ,q=2){
  fns <- strsplit(fns_str,";")
  dv <- sapply(fns,function(fn){
    dd <- combine_sample_data(fn,type=type)
    tcr_diversity(dd$count,method=method )
  })
  dv
}
#######
diversity_test <- function(fns,facs,type="aa",method="shan",q=2){
  dv <- sapply(fns,function(fn){
    dd <- read_clone_data(fn,type=type)
    tcr_diversity(dd$count,method=method,q=q )
  })
  t <- oneway.test(dv ~ facs,data.frame(dv=dv,fac=facs))
  list(p=t$p.value,dv=dv,facs=facs)
}

###############
pairwise_diversity_analysis <- function(fns1,fns2,type="aa",method="shan",q=2,t_method = "1",paired = "1"){
  
  x <- group_diversity(fns1,type=type,method=method,q=q)
  y <- group_diversity(fns2,type=type,method=method,q=q)  

  if(paired == "1"){ 
    ispaired = TRUE
  }else{
    ispaired = FALSE 
  }
  
  if(t_method == "0"){
    d = t.test(x,y,paired=ispaired)
  }else{
    d = wilcox.test(x,y,paired=ispaired)
  } 
  list(p=d$p.value,dv1=x,dv2=y,method=d$method)
}


######  cdr3:  data frame 
######

vj_usage_statistics <- function(cdr3){
  ###  del 
  idx1 <- grep(",",cdr3$v)
  idx2 <- grep(",",cdr3$j)
  idx  <- union(idx1, idx2)
  if( length(idx) > 0){
    cdr3 <- cdr3[-idx,] 
  }
  vj <- aggregate(cdr3$count,list(v=cdr3$v, j=cdr3$j),sum)
  v  <- sort_vj_name(unique( vj$v ))
  j  <- sort_vj_name(unique( vj$j ))
  mx <- matrix(rep(0,length(j)*length(v)),length(j),length(v))
  colnames(mx) <- v
  rownames(mx) <- j
  for(i in 1:dim(vj)[1]){
    mx[vj$j[i],vj$v[i]] <- vj$x[i]
  }
  list(v=v,j=j,mx=mx,mx_norm=mx/sum(mx))
}


read_clone_data <- function(fn,type = "nt"){
  cdr3 <- read.csv(fn,sep="\t",stringsAsFactors = F)
  
  d  = switch(type,
              #######
              all = { 
                dd <- list(v=cdr3$v, j=cdr3$j, count=cdr3$count,nt=cdr3$nt,aa=cdr3$aa)
                return(dd) },
              aa  = { idx <- grep("[-\\*]",cdr3$aa)
                      if(length(idx)>0){
                        t <- list(name=cdr3$aa[-idx],count=cdr3$count[-idx])
                      }else{
                        t <- list(name=cdr3$aa,count=cdr3$count)
                      }
                      t
              },
              nt  = list(name=cdr3$nt,count=cdr3$count),
              vj  = { d <- vj_usage_statistics(cdr3)
                      return(d) },
              v   = { idx <- grep(",",cdr3$v)
                      if(length(idx)>0){
                        t <- list(name=cdr3$v[-idx],count=cdr3$count[-idx])
                      }else{
                        t <- list(name=cdr3$v,count=cdr3$count)
                      }
                      t
              },
              j   = { idx <- grep(",",cdr3$j)
                      if(length(idx)>0){
                        t <- list(name=cdr3$j[-idx],count=cdr3$count[-idx])
                      }else{
                        t <- list(name=cdr3$j,count=cdr3$count)
                      }
                      t
              }
  )  
  dd <- get_item_count(d$name,count=d$count)
  if(type == "v" | type == "j" ){
    r  <- sort_vj_name(dd$name,index.return = T)
    dd <- dd[r$ix,]
  }
  dd <- list(name=dd$name,count=dd$count,freq=dd$freq)
}


######
combine_sample_data <- function(fns,type = "nt"){ 
  dd_comb <- list(name=c(),count=c())
  for(i in 1:length(fns)){
    dd <- read_clone_data(fns[i],type=type)
    dd_comb$name <- c(dd_comb$name,dd$name)
    dd_comb$count <- c(dd_comb$count,dd$count)
  }
  dd = get_item_count(dd_comb$name,count = dd_comb$count)
}