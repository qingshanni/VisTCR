rm(list=ls())
gc(reset=TRUE)
cat('\f')

nt2aa <- function(nts){
  sapply(nts,function(nt){ 
    if( nchar(nt) %% 3 == 0){
      aa <- c2s(getTrans(s2c(nt)))
    }else{
      aa <- '*'
    }
    aa 
  })
}

extract_name <- function(str,pattern='TR.*\\*'){
  p <- regexpr(pattern,str)
  l <- attr(p,'match.length') - 1
  sapply(1:length(p),function(i){  substr(str[i],p[i],p[i] + l[i]-1)})
}
# 
# format_decombinator_result <- function(decombinator_path,save_path,spices){
#   fv <- file.path(decombinator_path,'humantags_trbv.txt')
#   fj <- file.path(decombinator_path,'humantags_trbj.txt')
#   fr <- file.path(decombinator_path,'results_tt1/translated_sequences_beta.txt')
#   fnsave <- file.path(save_path,'clone.csv')
#   
#   
#   v <- read.csv(fv,sep = " ",header =F, stringsAsFactors = F)
#   j <- read.csv(fj,sep = " ",header =F, stringsAsFactors = F)
#   vname <- extract_name(v[,3])
#   jname <- extract_name(j[,3])
#   
#   clone <- read.csv(fr,sep = ",",header =F, stringsAsFactors = F)  
#   cl <- cbind(vname[clone[,1]+1],jname[clone[,2]+1],clone[,c(10,11)])
#   colnames(cl) <- c('v','j','nt','aa')
#   
#   
#   cdr3 <- aggregate(rep(1,dim(cl)[1]),list(v=cl$v, j=cl$j, nt=cl$nt,aa=cl$aa),sum)
#   ii   <- sapply(cdr3, is.factor)
#   cdr3[ii] <- lapply(cdr3[ii], as.character) 
#   names(cdr3)[names(cdr3)=="x"] <- "count"
#   cdr3 <- cdr3[order(cdr3$count, decreasing = T),c('count','v','j','nt','aa')]    
#   write.table(cdr3, file=fnsave,row.names =F,quote = F,sep = "\t")
# }
# 
#  format_decombinator_result('./','./')


########
library('ShortRead')
library('seqinr')

get_mouse_v_cdr3_start <- function(fn){
  rfa <- readFasta(fn)
  seq <- as.character(sread(rfa)) 
  pl <- gregexpr('T[AT][TGC][TC][AT][TGC]TG[TC]',seq)
  p  <- sapply(pl,function(p){ p[length(p)] + 6 })
}

get_mouse_j_cdr3_end <- function(fn){
  rfa <- readFasta(fn)
  seq <- as.character(sread(rfa)) 
  p <- regexpr("TT[CT]G[CG]",seq) + 2
}

get_human_v_cdr3_start <- function(fn){
  rfa <- readFasta(fn)
  seq <- as.character(sread(rfa)) 
  pl <- gregexpr('TA[TC][ATC][TG][TGC]TG[TC]',seq)
  p  <- sapply(pl,function(p){ p[length(p)] + 6})
}

get_human_j_cdr3_end <- function(fn){
  rfa <- readFasta(fn)
  seq <- as.character(sread(rfa)) 
  p <- regexpr("TT[CT]G[CG]",seq) + 2
}


# fn <- 'mouse_TRBV_region.fasta'
# p <- get_mouse_v_cdr3_start(fn)
# 
# fn <- 'mouse_TRBJ_region.fasta'
# p <- get_mouse_j_cdr3_end(fn)

#fn <- 'human_TRBV_region.fasta'
#p <- get_human_v_cdr3_start(fn)

#fn <- 'human_TRBJ_region.fasta'
#p <- get_human_j_cdr3_end(fn)

format_decombinator_result_trb <- function(decombinator_path='.',o_fn=NULL,fnsave='clone.csv',species='human'){
  
  if(species == 'human'){
    fv <- file.path(decombinator_path,'human_TRBV_region.fasta')
    fj <- file.path(decombinator_path,'human_TRBJ_region.fasta')
    cdr3_vstart <- get_human_v_cdr3_start(fv)
    cdr3_jend   <- get_human_j_cdr3_end(fj)
  }
  if(species == 'mouse'){
    fv <- file.path(decombinator_path,'mouse_TRBV_region.fasta')
    fj <- file.path(decombinator_path,'mouse_TRBJ_region.fasta')
    cdr3_vstart <- get_mouse_v_cdr3_start(fv)
    cdr3_jend   <- get_mouse_j_cdr3_end(fj)
  }
  fr <- file.path(decombinator_path,jj, sprintf("%s_beta.txt", o_fn))  ### read beta data
  
  vname <- extract_name(as.character(id(readFasta(fv))))
  jname <- extract_name(as.character(id(readFasta(fj))))  
  vseq <- as.character(sread(readFasta(fv)))
  jseq <- as.character(sread(readFasta(fj)))
  clone <- read.csv(fr,sep = ",",header =F, stringsAsFactors = F)  
  
  nt <- sapply(1:dim(clone)[1],function(i){
    iv <- clone[i,1] + 1
    ij <- clone[i,2] + 1    
    v1 <- substr(vseq[iv], cdr3_vstart[iv], nchar(vseq[iv])- clone[i,3])
    j1 <- substr(jseq[ij], clone[i,4]+1,cdr3_jend[ij])
    s <- paste(v1,clone[i,5],j1,sep='')
    gsub(' ','',s)
  })
  
  cdr3 <- aggregate(rep(1,length(nt)),list(v=vname[clone[,1]+1], j=jname[clone[,2]+1], nt=nt),sum)
  ii   <- sapply(cdr3, is.factor)
  cdr3[ii] <- lapply(cdr3[ii], as.character) 
  names(cdr3)[names(cdr3)=="x"] <- "count"
  cdr3 <- cdr3[order(cdr3$count, decreasing = T),c('count','v','j','nt')]  
  cdr3$aa <- nt2aa(cdr3$nt)
  write.table(cdr3, file=fnsave,row.names =F,quote = F,sep = "\t")
}


format_decombinator_result_trb(decombinator_path='/Users/nqs/webcode/tcr/tools/Decombinator',
                                     o_fn='tmp',fnsave='/Users/nqs/webcode/tcr/public/sub_experiment/17/clone.csv',
                                     species='human')
