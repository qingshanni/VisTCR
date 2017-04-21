library('Biostrings')
library('seqinr')
library('ShortRead')
library('stringdist')
library('gplots')
library('ggplot2')
library('vegan')
#  create ShortReadQ object
#  ShortReadQ(sread=DNAStringSet(c('ACGTA','TTGCA')), quality = BStringSet(c('HHHHH','GGGGG')), id = BStringSet(c('aa','bb')))


######## nt2aa ########
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


##############################################################################
######  fn : input fastq file
######       or  sequence data     正向序列
#####  type: 'f'  file
#####        's'  sequence
extract_cdr3_ni_file <- function(fn,type='f',lmin=90,v_cutoff=0.05,v_min_align_len=10,v_max_align_len =50,
                                 j_cutoff=0.05,j_min_align_len=10,j_max_align_len =30 ){
  cat("\nStart: ", format(Sys.time(), "%Y %b %d %X") ,'\n')
  load("~/tcr/tools/R/vdj.RData")
  if(type=='f'){
    cat("Handle file: ", fn,'\n')
    rfq <- readFastq( fn )
    seq <- sread(rfq)
    seq <- reverseComplement( seq[nchar(seq) >= lmin] )
    seq_s <- as.character(seq)
  }
  if(type=='s'){
    seq_s <- fn
    fn <- ''
  }
  
  n_v   <- dim(V)[1]
  
  
  cat("Read raw reads: ", length(seq_s),'\n')
  if(length(seq_s) < 1) { return (NULL) }
  
  #   dd <- read.xlsx2('template_desc.xlsx',1,stringsAsFactors =F)
  #   seq_s <- dd$Sequence
  rr <- lapply(seq_s,function(read){
    #### identify v segment
    pos  <-  gregexpr(vmotif,read)[[1]] + 5
    pos  <- pos[pos >= v_min_align_len ] 
    if(length(pos) < 1){
      return(-1)
    }
    
    vseg <- list(mis= 100)
    for(i in 1:length(pos)){
      lc      <- min(v_max_align_len,pos[i])
      
      readv  <- substr(read,pos[i]-lc + 1,pos[i])
      d      <- stringdist(readv,substr(V$seq,nchar(V$seq)-lc+1,nchar(V$seq)))
      dmin   <- min(d)
      if(dmin > lc * v_cutoff){  next }
      idx <- which(d==dmin)
      mis <-  dmin / lc
      if(vseg$mis >= mis ){
        vseg <- list(name = paste(V$name[idx],collapse='|'),pos = pos[i]+1, mis=mis,lencmp=lc)
      }  
    }
    if(vseg$mis > 1){ return(-1)}
    
    ##### identify j segment
    read1 <- substr(read,vseg$pos,nchar(read))
    lread1 <- nchar(read1)
    pos    <-  gregexpr(jmotif,read1)[[1]]
    pos    <- pos[lread1-pos+1 >= j_min_align_len ] 
    if(length(pos) < 1){
      return(-1)
    }
    
    jseg <- list(mis= 100)
    for(i in 1:length(pos)){
      lc      <- min(j_max_align_len,lread1 - pos[i] +1)
      
      readj  <- substr(read1,pos[i],pos[i]+lc-1)
      d      <- stringdist(readj,substr(J$seq,1,lc))
      dmin   <- min(d)
      if(dmin > lc * j_cutoff){  next }
      idx <- which(d==dmin)
      mis <-  dmin / lc
      if(jseg$mis >= mis ){
        jseg <- list(name = paste(J$name[idx],collapse='|'),pos = vseg$pos + pos[i]-2, mis=mis,lencmp=lc)
      }  
    }
    if(jseg$mis > 1){ return(-1)}
    
    ######### cdr3 #######
    cdr3 <- substr(read,vseg$pos,jseg$pos)
    list(v_name=vseg$name,v_mis=vseg$mis,v_lencmp=vseg$lencmp,
         j_name=jseg$name,j_mis=jseg$mis,j_lencmp=jseg$lencmp,
         cdr3 = cdr3,read=read)  
  })  
  ff  <- sapply(rr,function(r){ is.list(r)})
  rr  <- rr[ff]
  cat("True clones:", sum(ff), '\n')
  cat("Ratio:", sum(ff)/length(ff), '\n')
  cat("Finish: ", format(Sys.time(), "%Y %b %d %X") ,'\n')
  
  cdr3 <- sapply(rr,function(r){ r$cdr3 })
  kk <-  data.frame(v_name=sapply(rr,function(r){ r$v_name }),
                    v_mis = sapply(rr,function(r){ r$v_mis }),
                    v_lencmp=sapply(rr,function(r){ r$v_lencmp }),
                    j_name=sapply(rr,function(r){ r$j_name }),
                    j_mis=sapply(rr,function(r){ r$j_mis }),
                    j_lencmp=sapply(rr,function(r){ r$j_lencmp }),
                    cdr3_nt = cdr3,
                    cdr3_aa = nt2aa(cdr3),    ####   out frame or with stop codon marked with '*'
                    read=sapply(rr,function(r){ r$read }),stringsAsFactors =F)
  
}

#####  extract cdr3 from all files in dir
extract_cdr3_ni_dir <- function(fndir,pattern="fastq",lmin=90,v_cutoff=0.05,v_min_align_len=10,v_max_align_len =50,
                                j_cutoff=0.05,j_min_align_len=10,j_max_align_len =30 ){
  fns <- dir(fndir,pattern="fastq",full.names =T)
  dd <- lapply(fns,function(fn){
    extract_cdr3_ni_file(fn,type='f',lmin=lmin,v_cutoff=v_cutoff,v_min_align_len=v_min_align_len,v_max_align_len =v_max_align_len,
                         j_cutoff=j_cutoff,j_min_align_len=j_min_align_len,j_max_align_len =j_max_align_len)
  })
  names(dd) <- fns
  dd
}

##### 
cdr3_simple <- function(cdr3_detail){
  cdr3 <- aggregate(rep(1,dim(cdr3_detail)[1]),list(v=cdr3_detail$v_name, j=cdr3_detail$j_name, nt=cdr3_detail$cdr3_nt),sum)
  ii <- sapply(cdr3, is.factor)
  cdr3[ii] <- lapply(cdr3[ii], as.character) 
  names(cdr3)[names(cdr3)=="x"] <- "count"
  cdr3 <- cdr3[order(cdr3$count, decreasing = T),]    
  cdr3$aa <- nt2aa(cdr3$nt)
  cdr3
}

######  delete multiple V segment
del_multiple_v_segment <- function(cdr3.cluster,sep='\\|'){
  ###### delete multiple V segment
  idx <- grep(sep, cdr3.cluster$v)
  if(length(idx) > 0){
    cdr3 <- cdr3.cluster[-idx,]
  }else{
    cdr3 <- cdr3.cluster
  }
  cdr3
}



#############################################################################
#############################################################################
#### fn_or_seq:     fastq data file name or vector of reads
#### intype:    'f'  fn_or_seq is file name
####            's'  fn_or_seq is vector of reads 
#### type:   'mm' or 'hs'
#### fnout:  the file to save
#### otype:  0   combine same {v,j,nt,aa} and count them
####         1   each good read a line 
#############################################################################


extract_cdr3 <- function(fn_or_seq,intype='f',type='mm',fnout=NULL,otype=0,primer_use=1){
  
  if(type == 'mm'){
    vmotif    <- 'T[AT][TGC][TC][AT][TGC]TG[TC]';
    if(primer_use == 1){
      vprimer   <- t(matrix(c('V01',  'CCAGGGCAGAACCTTGTACTG',
                              'V02',  'GACTCGGCCACATACTTCTG',
                              'V03',  'GACTCAGCTGTGTACTTCTGTGC',
                              'V04',  'GACTCTGCTGTGTATCTCTGTGC',
                              'V05',  'GACTCAGCTGTCTATTTTTGTGC',
                              'V12-1','AACTGGAGGACTCTGCTATGTAC',
                              'V12-2','TAGAGGACTCTGCCGTGTACTTC',
                              'V13-1','TCAGACATCTTTGTACTTCTGTGC',
                              'V13-2','CAGACATCAGTGTACTTCTGTGCC',
                              'V13-3','CAGACAGCTGTATATTTCTGTGCC',
                              'V14',  'GGCGACACAGCCACCTATC',
                              'V15',  'GACTCAGCTGTGTATCTGTGTGCC',
                              'V16',  'GACTCAGCGGTGTATCTTTGTGCA',
                              'V17',  'ATTCTGCCATGTACCTCTGTGCTA',
                              'V19',  'CGAGATGGCCGTTTTTCTCTGTG',
                              'V20',  'GAAGACAGAGGCTTATATCTCTGTG',
                              'V21',  'GATTCAGCTGTGTACTTCTGTGCTA',
                              'V23',  'GACTCAGCACTGTACTTGTGCTC',
                              'V24',  'GACTCAGCACTGTAGCTCTGTG',
                              'V26',  'GACATCCAGTTGTATTCTGG',
                              'V29',  'CAGACATCTGTGTACTTCTGTGCTA',
                              'V30',  'GGAGACAGCAGTATCTATTTCTGTA',
                              'V31',  'GCCACTCTGGCTTCTACCTC'),2,23) )  
    }
    if(primer_use == 2){
    vprimer   <- t(matrix(c(
      'V01','CAAAGAGGTCAAATCTCTTCCCGGTG',
      'V02','GCCTCAAGTCGCTTCCAACCTC',
      'V03','GGTAAAGTCATGGAGAAGTCTAAAC',
      'V04','GCAACTCATTGTAAACGAAACAG',
      'V05','ACGGTGCCCAGTCGTTTTAT',
      'V12-1','GGATTCCTACCCAGCAGATTC',
      'V12-2','GGAGAGAGATAAAGGAAACC',
      'V13-1','TGCTGGCAACCTTCGAATAGGA',
      'V13-2','CATTATTCATATGGTGCTGGC',
      'V13-3','GGCTGATCCATTACTCATATGTC',
      'V14','AGGCCTAAAGGAACTAACTCCACT',
      'V15','GATGGTGGGGCTTTCAAGGATC',
      'V16','GCACTCAACTCTGAAGATCCAGAGC',
      'V17','ATGATAAGATTTTGAACAGGGA',
      'V19','CTCTCACTGTGACATCTGCCC',
      'V20','CCCATCAGTCATCCCAACTTATCC',
      'V21','CTGCTAAGAAACCATGTACCA',
      'V23','CAGCCTGGGAATCAGAACG',
      'V24','CTAAGTGTTCCTCGAACTCAC',
      'V26','CCTTGCAGCCTAGAAATTCAGT',
      'V29','TACAGGGTCTCACGGAAGAAGC',
      'V30','CAGCCGGCCAAACCTAACATTCTC',
      'V31','ACGACCAATTCATCCTAAGCAC' ),2,23) )  
    }
    #      jmotif = 'TT[CT]G[CG]....GG.[AT][CG]';
    jtag    <- t( matrix(c('J1-1','TTTGGTAAAGGAACC',
                           'J1-2','TTCGGCTCAGGGACC',
                           'J1-3','TTTGGAGAAGGAAGC',
                           'J1-4','TTCGGTCATGGAACC',
                           'J1-5','TTTGGAGAGGGGACT',
                           'J1-6','TTTGCGGCAGGCACC',
                           'J2-1','TTCGGACCAGGGACA',
                           'J2-2','TTTGGTGAAGGCTCA',
                           'J2-3','TTTGGCTCAGGAACC',
                           'J2-4','TTTGGTGCGGGCACC',
                           'J2-5','TTTGGGCCAGGCACT',
                           'J2-7','TTCGGTCCCGGCACC'),2,12))
    lmin  = 90
  }
  
  if(type == 'hs'){
    vmotif      = 'TA[TC][ATC][TG][TGC]TG[TC]';
    
    vprimer   <- t(matrix(c('V2',  'TCAAATTTCACTCTGAAGATCCGGTCCACAA',
                            'V3-1','GCTCACTTAAATCTTCACATCAATTCCCTGG',
                            'V4-1','CTTAAACCTTCACCTACACGCCCTGC',
                            'V4-2,3','CTTATTCCTTCACCTACACACCCTGC',
                            'V5-1',  'GCTCTGAGATGAATGTGAGCACCTTG',
                            'V5-3','GCTCTGAGATGAATGTGAGTGCCTTG',
                            'V5-4to8','GCTCTGAGCTGAATGTGAACGCCTTG',
                            'V6-1','TCGCTCAGGCTGGAGTCGGCTG',
                            'V6-2,3','GCTGGGGTTGGAGTCGGCTG',
                            'V6-4','CCCTCACGTTGGCGTCTGCTG',
                            'V6-5','GCTCAGGCTGCTGTCGGCTG',
                            'V6-6','CGCTCAGGCTGGAGTTGGCTG',
                            'V6-7','CCCCTCAAGCTGGAGTCAGCTG',
                            'V6-8','CACTCAGGCTGGTGTCGGCTG',
                            'V6-9','CGCTCAGGCTGGAGTCAGCTG',
                            'V7-1','CCACTCTGAAGTTCCAGCGCACAC',
                            'V7-2','CACTCTGACGATCCAGCGCACAC',
                            'V7-3','CTCTACTCTGAAGATCCAGCGCACAG',
                            'V7-4','CCACTCTGAAGATCCAGCGCACAG',
                            'V7-6','CACTCTGACGATCCAGCGCACAG',
                            'V7-7','CCACTCTGACGATTCAGCGCACAG',
                            'V7-8','CCACTCTGAAGATCCAGCGCACAC',
                            'V7-9','CACCTTGGAGATCCAGCGCACAG',
                            'V9','GCACTCTGAACTAAACCTGAGCTCTCTG',
                            'V10-1','CCCCTCACTCTGGAGTCTGCTG',
                            'V10-2','CCCCCTCACTCTGGAGTCAGCTA',
                            'V10-3','CCTCCTCACTCTGGAGTCCGCTA',
                            'V11-1,3','CCACTCTCAAGATCCAGCCTGCAG',
                            'V11-2','CTCCACTCTCAAGATCCAGCCTGCAA',
                            'V12-3,4,5','CCACTCTGAAGATCCAGCCCTCAG',
                            'V13','CATTCTGAACTGAACATGAGCTCCTTGG',
                            'V14','CTACTCTGAAGGTGCAGCCTGCAG',
                            'V15','GATAACTTCCAATCCAGGAGGCCGAACA',
                            'V16','CTGTAGCCTTGAGATCCAGGCTACGA',
                            'V17','CTTCCACGCTGAAGATCCATCCCG',
                            'V18','GCATCCTGAGGATCCAGCAGGTAG',
                            'V19','CCTCTCACTGTGACATCGGCCC',
                            'V20-1','CTTGTCCACTCTGACAGTGACCAGTG',
                            'V23-1','CAGCCTGGCAATCCTGTCCTCAG',
                            'V24-1','CTCCCTGTCCCTAGAGTCTGCCAT',
                            'V25-1','CCCTGACCCTGGAGTCTGCCA',
                            'V27','CCCTGATCCTGGAGTCGCCCA',
                            'V28','CTCCCTGATTCTGGAGTCCGCCA',
                            'V29-1','CTAACATTCTCAACTCTGACTGTGAGCAACA',
                            'V30','CGGCAGTTCATCCTGAGTTCTAAGAAGC'),2,45))
    
    #       jmotif = 'TT[CT]G[CG]....GG.[AT][CG]';
    jtag   <- t(matrix(c('J1-1','TTTGGACAAGGCACC',
                         'J1-2','TTCGGTTCGGGGACC',
                         'J1-3','TTTGGAGAGGGAAGT',
                         'J1-4','TTTGGCAGTGGAACC',
                         'J1-5','TTTGGTGATGGGACT',
                         'J1-6','TTTGGGAACGGGACC',
                         'J2-1','TTCGGGCCAGGGACA',
                         'J2-2','TTTGGAGAAGGCTCT',
                         'J2-3','TTTGGCCCAGGCACC',
                         'J2-4','TTCGGCGCCGGGACC',
                         'J2-5','TTCGGGCCAGGCACG',
                         'J2-6','TTCGGGGCCGGCAGC',
                         'J2-7','TTCGGGCCGGGCACC'),2,13))
    lmin  = 90; 
  }
  
  if(intype == 'f'){
    rfq <- readFastq( fn_or_seq )
    seq <- sread(rfq)
    seq <- reverseComplement( seq[nchar(seq) >= lmin] )
    seq_s <- as.character(seq)
  }else{
    seq_s <- as.character(reverseComplement(DNAStringSet(fn_or_seq )))
  }
  rm('fn_or_seq')
  
  mx_v  <- sapply(vprimer[,2],function(s){ 
    substr(seq_s,1,nchar(s)) == s
  })
  
  v_idx <- unlist(apply(mx_v,1,function(x){ 
    id <- which(x)
    if(length(id) == 0){
      id <- 0
    }
    id
  }))
  
  idx_u <- which(v_idx > 0 )
  seq_s <- seq_s[idx_u]
  v_idx <- v_idx[idx_u]
  
  vpos <- as.vector(regexpr(vmotif,seq_s))
  idx_u <- which(vpos > 0 )
  seq_s <- seq_s[idx_u]
  v_idx <- v_idx[idx_u]
  vpos  <- vpos[idx_u]
  
  ####  j
  mx_j  <- sapply(jtag[,2],function(s){ 
    as.vector(regexpr(s,seq_s))
  })
  j_idx_pos <- apply(mx_j,1,function(x){ 
    id <- which(x > 0)
    if(length(id) == 1){
      id_pos <- c(id,x[id])
    }else{
      id_pos <- c(0,0)
    }
    id_pos
  })
  
  idx <- which(j_idx_pos[1,] > 0)
  j_idx <- j_idx_pos[1,idx]
  jpos  <- j_idx_pos[2,idx]
  seq_s <- seq_s[idx]
  v_idx <- v_idx[idx]
  vpos  <- vpos[idx]
  
  d      <- jpos - vpos
  idx    <- which(d > 12 & d < 72 & d%%3==0)
  j_idx  <- j_idx[idx]
  jpos   <- jpos[idx]
  seq_s  <- seq_s[idx]  ####
  v_idx  <- v_idx[idx]
  vpos   <- vpos[idx]
  
  cdr3_nt <- substr(seq_s,vpos+6,jpos-1)
  cdr3_aa <- sapply(cdr3_nt,function(s){ c2s(getTrans(s2c(s)))})
  idx <- grep('\\*',cdr3_aa)
  if(length(idx)>0){
    j_idx  <- j_idx[-idx]
    jpos   <- jpos[-idx]
    seq_s  <- seq_s[-idx]  ####
    v_idx  <- v_idx[-idx]
    vpos   <- vpos[-idx]
    cdr3_nt <- cdr3_nt[-idx]
    cdr3_aa <- cdr3_aa[-idx]
  }
  
  
  if(otype == 1){
    out <- data.frame(Read_count = rep(1,length(vpos)),
                      v_pos = vpos + 6,
                      j_pos = jpos - 1,
                      cdr3_start = vpos + 6,
                      cdr3_end  = jpos - 1,
                      V_segments = vprimer[v_idx,1],
                      J_segments = jtag[j_idx,1],                    
                      CDR3_nucleotide_sequence = cdr3_nt,
                      CDR3_amino_acid_sequence = cdr3_aa,
                      read_sequence = seq_s,
                      stringsAsFactors = F)
  }
  else{
    dd <- aggregate(rep(1,length(seq_s)),list(v=vprimer[v_idx,1], j=jtag[j_idx,1], nt=cdr3_nt, aa= cdr3_aa),sum)
    dd <- dd[order(dd$x, decreasing = T),]
    n  <- dim(dd)[1]
    out <- data.frame(Read_count=dd$x,
                      Percentage=rep('',n),
                      CDR3_nucleotide_sequence=dd$nt,
                      CDR3_nucleotide_quality=rep('',n),
                      Min_quality=rep('',n),
                      CDR3_amino_acid_sequence=dd$aa,
                      V_alleles=rep('',n),
                      V_segments=dd$v,
                      J_alleles=rep('',n),
                      J_segments=dd$j,
                      D_alleles=rep('',n),
                      D_segments=rep('',n),
                      Last_V_nucleotide_position=rep('',n),
                      First_D_nucleotide_position=rep('',n),
                      Last_D_nucleotide_position=rep('',n),
                      First_J_nucleotide_position=rep('',n),
                      VD_insertions=rep('',n),
                      DJ_insertions=rep('',n),
                      Total_insertions=rep('',n),
                      stringsAsFactors = F)
  }
  
  if(!is.null(fnout)){
    write.csv(out,fnout,row.names = F,quote = F)
    write.csv(get_item_count(dd$v,count=dd$x),gsub('\\.','_V\\.',fnout),row.names = F,quote = F)
    write.csv(get_item_count(dd$j,count=dd$x),gsub('\\.','_J\\.',fnout),row.names = F,quote = F)
    write.csv(get_item_count(dd$nt,count=dd$x),gsub('\\.','_NT\\.',fnout),row.names = F,quote = F)
    write.csv(get_item_count(dd$aa,count=dd$x),gsub('\\.','_AA\\.',fnout),row.names = F,quote = F)
  }
  
  out
}


#############################################################################
# # species  <- 'mm'    ## hs = Homo sapiens
# ## mm = Mus musculus
# # gene     <- 'TRB'   ## TRB = beta chain of TCR
# ## TRA = alpha chain of TCR
# # cysphe   <- 1       ## 0 = do not include cys & phe into CDR3
# ## 1 = include cys & phe into CDR3
# # ec       <- 2       ## 0 = don't correct errors; for preliminary analysis
# ## 1 = correct low quality sequencing errors only (see -quality and -lq options for details); for preliminary analysis
# ## 2 = also corrects PCR errors and high quality sequencing errors (see -pcrec option)
# # quality   <- 25     ##  PHRED quality value
# ## 0 tells the program not to use quality information
# # lq        <- 'map'  ## drop = filter off reads that contain low quality (PHRED quality value
# #         less than 25 by default or as specified by -quality parameter)
# #         nucleotides within CDR3
# # map = map reads that contain low quality (PHRED quality value less
# #       than 25 used by default or as specified by -quality parameter)
# #       nucleotides within CDR3 onto clonotypes created from the high
# #       quality CDR3s
# #pcrec     <- 'ete'  # smd = "save my diversity" corrects PCR errors and high quality
# #       sequencing errors in germline regions only (corrects 65-85% of all
# #       errors with minimal risk to lose real TCR diversity)
# # ete = "eliminate these errors" maximal correction of errors (each
# #       sinlge mismatch within CDR3 is considered as possible error) with a
# #       risk of losing a minor portion of real TCR diversity
#############  intype : type of input (input), 'file' : file of fastq
############                                   'fastq': variable of class ShortReadQ
############                                   'strv': variable of string vector
extract_cdr3_mitcr <- function(input,intype='file',species='mm',gene='TRB',cysphe=1,ec=2,quality=25,lq='map',pcrec='ete'){
  mitcr <- '/Users/nqs/Documents/work/TCR/code/lib_tcr/mitcr.jar'
  fn <- '_tmp_mitcr_input'
  fnout <- '_tmp_mitcr_out'
  if(file.exists(fn)){
    file.remove(fn)
  }
  
  if(intype=='file'){
    fn <- input
  }else if(intype=='fastq'){
    writeFastq(input, fn, mode="w", full=FALSE, compress=FALSE) 
  }else if(intype=='strv'){
    input <- input
    sread   <- DNAStringSet(input)
    quality <- BStringSet(gsub("^.","I",gsub(".","L",input)))
    id      <- BStringSet(paste('seq',1:length(input),sep=''))
    fq <-ShortReadQ(sread   = sread, quality = quality, id      = id)
    writeFastq(fq, fn, mode="w", full=FALSE, compress=FALSE) 
  } 
  cmd <- paste('java -jar', mitcr,
               '-pset flex',
               '-species', species,
               '-gene', gene,
               '-cysphe', cysphe,
               '-ec', ec,
               '-lq', lq,
               '-pcrec', pcrec,
               fn,fnout,sep=' ')
  cat(cmd, '\n')
  system(cmd)
  dd <- read.csv(fnout,skip=1,stringsAsFactors = F, sep = '\t')
  #  write.csv(get_item_count(dd$V.segments,count=dd$Read.count),gsub('\\.','_V\\.',fnout),row.names = F,quote = F)
  #  write.csv(get_item_count(dd$J.segments,count=dd$Read.count),gsub('\\.','_J\\.',fnout),row.names = F,quote = F)
  #  write.csv(get_item_count(dd$CDR3.nucleotide.sequence,count=dd$Read.count),gsub('\\.','_NT\\.',fnout),row.names = F,quote = F)
  #  write.csv(get_item_count(dd$CDR3.amino.acid.sequence,count=dd$Read.count),gsub('\\.','_AA\\.',fnout),row.names = F,quote = F)
  if(intype!='file'){
    file.remove(fn,fnout)
  }else{
    file.remove(fnout)
  }
  dd
}


#########  统计频数
get_item_count <- function(obj,count=rep(1,length(obj))){
  d     <- tapply(count,obj,sum)
  d     <- d[d > 0]
  freq  <- d / sum(d)
  dd    <- data.frame(name=names(d),count=d,freq=freq,stringsAsFactors=F)
  dd[order(dd[,2],decreasing = T),]
}

############# 两组数据全局比对 #########################
golbal_align_two_group_dnaseq <- function(seq1,seq2){
  seq1  <- DNAStringSet(seq1)
  seq2  <- DNAStringSet(seq2)
  mat <- nucleotideSubstitutionMatrix(match = 1, mismatch = -1, baseOnly = TRUE)
  lapply(1:length(seq1),function(i){
    cat('align: ',i,'   ',length(seq1),'\n')
    pairwiseAlignment(seq2, seq1[i], type = "global-local", substitutionMatrix = mat,
                      gapOpening = 2, gapExtension = 1,scoreOnly = FALSE)  
  }) 
}

############# 计算两组序列间的编辑距离 得到归类类别                            #########################
############# seq1 中每个序列为一个类别， 将seq2中的序列分配类别  -1 没有归类  #########################
#############  
get_seq_class <- function(seq1,seq2,mink=2){
  mx  <- stringdistmatrix(seq1,seq2)
  
  idx <- apply(mx,2,function(x){
    k <- min(x)
    if(k <= mink){
      idt <- which(x == k)
      if(length(idt)>1){
        id <- idt[1]
      }else{
        id <- idt
      }
    }else{
      id <- -1  ##### 没有被归类，unmapped
    }
    c(id,k)
  })
  t(idx)
}





################ 计算位置错误  位置上的碱基替换 
################  seq_ref:  参考序列（1个）
################  seqs  ：  归为该序列的序列集合(vector)
pos_err_one <- function(seq_ref,seqs,count=rep(1,length(seqs))){
  ncl <- nchar(seq_ref)
  nt <- c('A','C','G','T','-')
  n_err   <- rep(0,ncl)
  n_all   <- rep(0,ncl)
  nt_mx <- matrix(rep(0,length(nt)*ncl),length(nt),ncl)
  rownames(nt_mx) <- nt
  
  if(length(seqs) > 0 ){
    aln <- golbal_align_two_group_dnaseq(seq_ref,seqs)[[1]] 
    pa  <- strsplit(as.character(pattern(aln)),'')   ####  seqs
    sa  <- strsplit(as.character(subject(aln)),'')   ####  seq_ref
    st <- start(subject(aln))  ####  seq_ref
    for(k in 1:length(pa)){
      
      idx <- which(sa[[k]] != '-')
      pak <- pa[[k]][idx]
      sak <- sa[[k]][idx]
      
      f  <- (pak != sak) + 0
      idx1  <- 1:length(idx) + st[k] - 1
      n_err[idx1]   <- n_err[idx1] + f*count[k]
      n_all[idx1]   <- n_all[idx1] + count[k]
      
      for(i in 1:length(nt)){
        nt_mx[i,idx1] <- nt_mx[i,idx1] + (pak==nt[i])*count[k]
      }
      
    }    
  }
  list(ref=seq_ref,pos_err = n_err / pmax(1,n_all),nt_pos=nt_mx,nall=n_all,nErr=n_err)
}


#############  将测序reads mapping 到参考序列上，测序read可为参考序列的前面一部分
#############  seq1 参考序列  seq1为向量
#############  seq2 测序序列  seq2为向量
#############  d_cut >1  为错配个数， d_cut < 1为错配百分比
mapping_seq_to_ref <- function(seq1,seq2,d_cut=0.1,len_cut=0){
  seq2    <- seq2[nchar(seq2) > len_cut] 
  idx_cl  <- sapply(seq2,function(s){
    d   <- stringdist(s,substr(seq1,1,nchar(s)))
    dmin <- min(d)
    if(d_cut < 1){
      d_cut <- d_cut * nchar(s)
    }
    
    if(dmin > d_cut){
      idx <- -1
    }else{
      idx <- which(d == dmin)
    }   
    idx[1]
  })
  
  n_seq1 <- length(seq1)
  lapply(1:n_seq1,function(i){
    idx <- which(idx_cl == i)
    seq2[idx]
  })
}

#########   find primer type in seq 
#########  prm : primer sequence set
#########  seq:  sequences set
#########  d_cut:  0<= d_cut <1   mismatch ratio
###    return   primer id
mapping_primer <- function(prm,seq,d_cut = 0.1){
  d_mx <- sapply(prm,function(s){
    stringdist(s,substr(seq,1,nchar(s))) / nchar(s)
  })
  
  apply(d_mx,1,function(d){
    dmin <- min(d)
    if(dmin > d_cut){
      idx <- -1
    }else{
      idx <- which(d == dmin)
    }   
    idx[1]
  }) 
}


#######  计算浓度 比例 ##########
get_clone_percent <- function(seq_cl,read_seq,mink=mink){
  t             <- table(read_seq)
  read_count     <- as.numeric(t)
  read_seq_u    <- names(t)
  read_class_id <- get_seq_class(seq_cl, read_seq_u,mink=mink)
  
  n   <- max(read_class_id[,1])
  dat <- cbind(read_class_id,read_count)
  d_match    <- dat[which(dat[,2] == 0),]
  count_match <- rep(0,n)
  names(count_match) <- paste(1:n)
  for(i in 1:n){
    id <- which(d_match[,1] == i)
    if(length(id)<1){ 
      cat('\n Not find clone ',i, '\n')
    }else{
      count_match[i] <- d_match[id,3]
    }
  }
  
  count_all <- tapply(read_count,read_class_id[,1],sum)
  count_match_k <- count_all[paste(1:n)]
  id <- which(is.na(count_match_k))
  count_match_k[i] <- 0
  names(count_match_k) <- paste(1:n)
  
  mismatch <- read_count[read_class_id[,1]==-1]
  list(count_match=count_match, count_match_k=count_match_k, mismatch=mismatch,all=sum(read_count))
}

#####################  统计配对错误个数  ####################
#####################  seq_ref：参考序列  c('ACTGT','CATTAC', ... )
#####################  seq_class: 已分类别到seq_ref的序列  
#####################             data.frame(seq=序列, class_id=类别id, count=该序列数目)
#####################   output:   'AC' 表示原来为A，变为C的个数
get_ACGT_mismatch_count <- function(seq_ref,seq_class){
  n         <- length(seq_ref) 
  Dict      <- c('A','C','G','T','-')
  pair_count <- matrix(rep(0,length(Dict)^2*n),n,length(Dict)^2)
  colnames(pair_count) <- as.vector(t(outer(Dict, Dict, paste, sep = "")))
  for(i in 1:n){
    ss   <- seq_class[which(seq_class$class_id == i ),]
    if( dim(ss)[1] >0){
      aln <- golbal_align_two_group_dnaseq(seq_ref[i],ss$seq)[[1]] 
      pa  <- strsplit(as.character(pattern(aln)),'')
      sa  <- strsplit(as.character(subject(aln)),'')
      for( j in 1:length(pa)){
        for(idx in paste(sa[[j]],pa[[j]],sep='')){
          pair_count[i,idx] <- pair_count[i,idx] + ss$count[j]
        }
      }
    }
  }
  pair_count
}


########################## 按照因素对样本进行分组 ##############
####### dat:       data.frame  样本描述表
####### group_by:  c(factor1,  factor2,...)  

group_data_by_factor <- function(dat,group_by){
  types <- apply(dat[,group_by],1,paste,collapse ='_')
  type_u <- unique(types)
  
  n_u        <- length(type_u)
  group_idx  <- lapply(1:n_u,function(i){
    which(types == type_u[i])
  })
  names(group_idx) <-  type_u
  group_idx
}

########################## 按分组 对样本进行合并，序列相同则合并 ##############
####### samples:      list  
####### group_idx:    list  
combine_sample_clones <- function(samples,group_idx){
  lapply(group_idx,function(idx){
    sp <- samples[idx]
    sp_all <- NULL
    for(i in 1:length(sp)){
      sp_all <- rbind(sp_all, sp[[i]])
    }
    get_item_count(sp_all$name,count=sp_all$count)
  })
}
#########






#########
list_vector_to_mx <- function(lv){
  s <- unique(unlist(lapply(lv,names)))
  ns <- length(s)
  nl <- length(lv)
  mx <- matrix(rep(0,ns*nl),nl,ns)
  colnames(mx) <- s
  rownames(mx) <- names(lv)
  
  for(i in 1:nl){
    mx[i,names(lv[[i]])] <- lv[[i]] 
  }
  mx
}


##########  计算样本相似性
######    dd_list:  list of   dd$name dd$count
###### return   相似性向量
similarity_vector <- function(dd_list,method="morisita"){
  lv_list <- lapply(dd_list,function(dd){
    dd <- get_item_count(dd$name,count=dd$count)
    lv <- dd$count
    names(lv) <- dd$name
    lv
  })
  cl_mx  <- list_vector_to_mx(lv_list)
  sm <- 1-as.vector(vegdist(cl_mx,method=method))
}

##########  计算样本相似性
######    dd_list:  list of   dd$name dd$count
###### return   相似性向量
similarity_matrix <- function(dd_list,method="morisita"){
  lv_list <- lapply(dd_list,function(dd){
    dd <- get_item_count(dd$name,count=dd$count)
    lv <- dd$count
    names(lv) <- dd$name
    lv
  })
  cl_mx  <- list_vector_to_mx(lv_list)
  sm <- 1-as.matrix(vegdist(cl_mx,method=method))
}
#######  计算 PAM 矩阵（有方向）
#######  mx: mx(i,j)  j 突变为 i 的个数
#### Dayhoff, M.O, Nat. Biomed. Res. Found. 5:345–358
getPAM <- function(mx){
  f <- colSums(mx) / sum(mx)
  lamada <- 0.01 / (sum(mx) - sum(diag(mx))) * sum(mx)
  
  A_mx     <-  apply(mx,2,function(v){ v / sum(v)})
  Mfull_mx <- A_mx * lamada
  M1_mx    <- Mfull_mx - diag(diag(Mfull_mx))   
  M_mx     <- M1_mx + diag(1 - colSums(M1_mx))
  rownames(M_mx) <- rownames(mx)
  colnames(M_mx) <- colnames(mx)
  
  PAM <- log(M_mx / f)
}


get_ntsub_mx <- function(pos_errs,onlynt=TRUE){
  ntsub_mx <- matrix(rep(0,20),5,4)
  nt       <- c('A','C','G','T')  
  colnames(ntsub_mx) <- nt
  rownames(ntsub_mx) <- c(nt,'-')
  for(i in 1:length(pos_errs)){
    s <- strsplit( pos_errs[[i]]$ref,'')[[1]]
    for(j in 1:length(nt)){
      ntsub_mx[,j] <- ntsub_mx[,j] + rowSums( pos_errs[[i]]$nt_pos[,s==nt[j]])
    }
  }
  if(onlynt){ ntsub_mx <- ntsub_mx[nt,nt] }
  ntsub_mx
}
##########  pos_errs  list of pos errs
##########            [[i]]$ref  参考序列
##########            [[i]]$nt_pos   5 x length(ref)   rownames() : 'A' 'C' 'G' 'T'
##########  return:   PAM matrix           

get_pam_from_pos_err <- function(pos_errs){
  ntsub_mx <- get_ntsub_mx(pos_errs,onlynt=T)
  getPAM(ntsub_mx)
}



######## 得到反向互补序列
revcomp <- function (.seq) {
  rc.table <- c(A = "T", T = "A", C = "G", G = "C")
  sapply(strsplit(.seq, "", T, F, T), function(l) paste0(rc.table[l][length(l):1], 
                                                         collapse = ""), USE.NAMES = F)
}


####### template
maping_tmpl_by_barcode <- function(tmpl,fn_fastq){
  
  tmpl$amplify_seq <-  revcomp(tmpl$amplify_seq)
  seq     <- as.character(sread(readFastq(fn_fastq)))
  n_reads <- length(seq)
  cat("\n\n\n time: ", date(),'\n')
  cat("Handle file: ", fn_fastq,'\n')
  cat("Read raw reads: ", length(seq),'\n')
  
  
  bcd <- paste0('G',tmpl$barcode,'GAG')  ##### 延长brcode 防止位移错误
  bcd <- revcomp(bcd)
  
  seq_short <- substr(seq,1,45)
  d_mx     <- sapply(bcd,function(s){
    regexpr(s,seq_short)
  })
  
  ids <- apply(d_mx,1,function(d){
    id <- which(d >0)
    if(length(id) < 1 ){
      id <- -1 
    }
    id[1]
  }) 
  
  mapped <- lapply(1:length(bcd),function(i){
    ###### filter with the second barcode
    ss       <- seq[ids==i]
    id <- grep(revcomp(tmpl$barcode[i]),substr(ss,82,102) ) 
    
    cdr3all <- extract_cdr3_ni_file(revcomp(ss[id]),type='s')
    tmpl_cdr3 <- extract_cdr3_ni_file(revcomp(tmpl$amplify_seq[i]),type='s')$cdr3_nt
    if( is.null(cdr3all)){
      rr <- list(tmpl=revcomp(tmpl$amplify_seq[i]),tmpl_cdr3=tmpl_cdr3,seqs=NULL,
                 cdr3= NULL)
    }else{    
      if(dim(cdr3all)[1] < 1){ 
        rr <- list(tmpl=revcomp(tmpl$amplify_seq[i]),tmpl_cdr3=tmpl_cdr3,seqs=NULL,
                   cdr3= NULL)
      }else{
        cdr3 <- aggregate(rep(1,dim(cdr3all)[1]),list(v=cdr3all$v_name, j=cdr3all$j_name, nt=cdr3all$cdr3_nt),sum)
        ii <- sapply(cdr3, is.factor)
        cdr3[ii] <- lapply(cdr3[ii], as.character) 
        names(cdr3)[names(cdr3)=="x"] <- "count"
        cdr3 <- cdr3[order(cdr3$count, decreasing = T),]     
        
        cdr3_crrect <-crrect_DGG_mis(tmpl_cdr3,cdr3$nt,cdr3$count)
        
        
        rr <- list(tmpl=revcomp(tmpl$amplify_seq[i]),tmpl_cdr3=tmpl_cdr3,seqs=ss[id],
                   cdr3= data.frame(nt=cdr3_crrect$s,count=cdr3_crrect$count,stringsAsFactors =F))
      } 
    }
    rr
  })
  names(mapped) <- tmpl$v
  
  ###### 辨识v d j 
  seq_sp  <- seq[ids < 0]
  cdr3all <- extract_cdr3_ni_file(revcomp(seq_sp),type='s')
  cdr3    <- aggregate(rep(1,dim(cdr3all)[1]),list(v=cdr3all$v_name, j=cdr3all$j_name, nt=cdr3all$cdr3_nt),sum)
  ii      <- sapply(cdr3, is.factor)
  cdr3[ii]<- lapply(cdr3[ii], as.character)
  
  names(cdr3)[names(cdr3)=="x"] <- "count"
  cdr3 <- cdr3[order(cdr3$count, decreasing = T),]
  
  list(n_reads = n_reads,tmpl_mapped = mapped, sample = cdr3,seqs = seq_sp)
  
}

###### compute template parameters

compute_template_parameters <- function(tmpl_mapped){
  pos_errs   <- lapply(tmpl_mapped,function(d){
    dc <- get_item_count(d$seqs)
    pos_err_one(d$tmpl,dc$name,count=dc$count)
  })
  mat_pam <- get_pam_from_pos_err(pos_errs)
  
  ### cent
  cents <- lapply(tmpl_mapped,function(dd){
    sc <- pairwiseAlignment(dd$cdr3$nt, dd$tmpl_cdr3, type = "global", substitutionMatrix = mat_pam,
                            gapOpening = 4 , gapExtension = 2,scoreOnly = T) 
    sc1 <- pairwiseAlignment(dd$tmpl_cdr3, dd$tmpl_cdr3, type = "global", substitutionMatrix = mat_pam,
                             gapOpening = 4 , gapExtension = 2,scoreOnly = T) 
    data.frame(score=sc / sc1, count=dd$cdr3$count)
  })
  
  cents <- data.frame(score=unlist(sapply(cents,function(cent){cent$score})),
                      count=unlist(sapply(cents,function(cent){cent$count})) )
  
  cents <- cents[order(cents$score, decreasing = T),]
  count <- cumsum(cents$count) / sum(cents$count)
  cut    <- 0.95
  idx   <- which(count < cut)
  cent_cutoff <- cents$score[ length(idx)]
  
  
  ### frequence
  freq_ratio <- sapply(tmpl_mapped,function(dd){
    count=dd$cdr3$count
    if(length(count) > 1){ 
      ratio <- count[2] / count[1]
    }else{
      ratio <- 0
    }
  })
  # ratio_cutoff <- median(freq_ratio)
  ratio_cutoff <- max(freq_ratio)
  
  #### number of template
  tmpl_num <- sapply(tmpl_mapped,function(dd){
    length(dd$seqs)
  } )
  
  ABI          <- mean(tmpl_num) / tmpl_num
  list(tmpl_num=tmpl_num,pos_errs=pos_errs, mat_pam = mat_pam,ABI=ABI,
       cents=cents, cent_cutoff=cent_cutoff,freq_ratio=freq_ratio,ratio_cutoff = ratio_cutoff)
  
}


########  reference cell and contaminant
extract_ref_cdr3 <- function(cdr3,ref_cdr3,tmpl_par){  
  #### 
  mat_pam      <- tmpl_par$mat_pam
  cutoff       <- tmpl_par$cent_cutoff
  ratio_cutoff <- tmpl_par$ratio_cutoff
  
  n        <- dim(ref_cdr3)[1]
  ref_cdr3 <- data.frame(ref_cdr3,match_all=rep(0,n),match_exact=rep(0,n),stringsAsFactors = F )
  
  for(i in 1:n){
    nt <- ref_cdr3$CDR3[i]
    v  <- ref_cdr3$V[i]
    j  <- ref_cdr3$J[i]
    idx <- which(cdr3$v==v & cdr3$j==j)
    
    if(length(idx) > 0) { 
      idx1 <- which(cdr3$nt[idx] == nt)
      count_match <- sum(cdr3$count[idx[idx1]])
      if(length(idx1) > 0 ){
        id <- idx[idx1]
        idx    <- idx[-idx1]
        sc     <- pairwiseAlignment(cdr3$nt[idx], nt, type = "global", substitutionMatrix = mat_pam,
                                    gapOpening = 4 , gapExtension = 2,scoreOnly = T) 
        sc1    <- pairwiseAlignment(nt, nt, type = "global", substitutionMatrix = mat_pam,
                                    gapOpening = 4 , gapExtension = 2,scoreOnly = T)     
        score  <- sc / sc1      
        idx1   <- which( score >= cutoff & cdr3$count[idx] <= cdr3$count[id] * ratio_cutoff )  
        
        
        idx        <- c(id,idx[idx1] )
        count      <- sum(cdr3$count[idx])
        cdr3_sp    <- cdr3[-idx,]
      }else{
        cdr3_sp   <- cdr3
        count <- 0 
      }  
    } else{
      cdr3_sp   <- cdr3
      count <- 0 
      count_match <- 0
    }
    
    ref_cdr3$match_all[i]   <- count
    ref_cdr3$match_exact[i] <- count_match
    cdr3 <- cdr3_sp
  }
  list(ref_cdr3=ref_cdr3,cdr3_sp=cdr3) 
}


###############  stepwise extraction clustering ###############
###############          seqreads: data.frame(seq= string_vector,count= count)
stepwise_extraction_clustering_trained <- function(seq_reads,mat_pam=NULL,cent_cutoff=0.8,cutoff_ratio=0.2){
  seq_reads <- seq_reads[order(seq_reads$count, decreasing = T),]
  
  seq_cl <- NULL
  repeat{
    if( length(seq_reads) < 1){ break }
    if(seq_reads$count[1] == 1 ){
      seq_cl <- rbind(seq_cl,seq_reads)
      break
    }
    ss <- seq_reads[1,]
    
    idx1 <- which(seq_reads$v== seq_reads$v[1] & seq_reads$j==seq_reads$j[1]  &  seq_reads$count < seq_reads$count[1] * cutoff_ratio)
    if(length(idx1) > 0) { 
      
      sc <- pairwiseAlignment(seq_reads$nt[idx1], seq_reads$nt[1], type = "global", substitutionMatrix = mat_pam,
                              gapOpening = 4 , gapExtension = 2,scoreOnly = T) 
      sc1 <- pairwiseAlignment(seq_reads$nt[1], seq_reads$nt[1], type = "global", substitutionMatrix = mat_pam,
                               gapOpening = 4 , gapExtension = 2,scoreOnly = T)     
      score <- sc / sc1
      idx   <- idx1[which(score > cent_cutoff )]
      seq_reads$count[1] <- sum(seq_reads$count[c(1,idx )])
      seq_cl    <- rbind(seq_cl,seq_reads[1,])
      seq_reads <- seq_reads[-c(1,idx),] 
    } else{
      seq_cl    <- rbind(seq_cl,seq_reads[1,])
      seq_reads <- seq_reads[-1,]   
    }
    
  }
  seq_cl[order(seq_cl$count,decreasing =T ),]
}

#########  correct by ABI and cutoff of cell number 
correct_freq_ABI_cutoff <- function(cdr3_stc,ABI,ref_cell ){
  count <- sum(cdr3_stc$count)
  cdr3_stc$count <- cdr3_stc$count * ABI[cdr3_stc$v]
  cdr3.ABI <- cdr3_stc[order(cdr3_stc$count,decreasing =T ),]
  cdr3.ABI$count <- cdr3.ABI$count / sum(cdr3.ABI$count) * count
  
  cutoff       <- mean(ref_cell$match_all * ABI[ref_cell$V]) / mean(ref_cell$number) 
  cdr3.cutoff  <- cdr3.ABI[cdr3.ABI$count > cutoff, ] 
  cdr3.cell    <- cdr3.cutoff
  cdr3.cell$count <- cdr3.cell$count / cutoff 
  list(cdr3.ABI=cdr3.ABI,cdr3.cutoff=cdr3.cutoff,cdr3.cell=cdr3.cell)
}

#########################################################
split_sequence_tcrd <- function(s,mf= 'GGGAC[AT]GGG'){
  pos <- as.numeric(regexpr(mf,s))
  if(pos > 1){
    
    sg <- (strsplit(s,'')[[1]] == 'G')
    p1 <- pos
    repeat{
      p1 <- p1 -1
      if(!sg[p1]){ break }
    }
    
    p2 <- pos+8
    repeat{
      p2 <- p2 + 1
      if(!sg[p2]){ break }
    }
    ss <- c(substr(s,1,p1), substr(s,(p1+1),(p2-1)), substr(s,p2,nchar(s)))
  }else{
    ss <- c('', '', '')
  }
  ss  
}


### 校正由于连续的 G引起的G丢失或增加
### ref : 参考CDR3cdr3
### ss  : 待校正的序列
### count: ss的数目
crrect_DGG_mis <- function(ref,ss,count){
  refs <- split_sequence_tcrd(ref)
  s    <- sapply(ss,split_sequence_tcrd)  
  idx  <- which(s[1,] == refs[1] & s[3,] == refs[3])
  if(length(idx) > 1){
    dd <- rbind( data.frame(s=ref, count=sum(count[idx]),stringsAsFactors = F),  
                 data.frame(s=ss[-idx],count=count[-idx],stringsAsFactors = F))
  }else{
    dd <- data.frame(s=ss,count=count,stringsAsFactors =F )
  }  
}

sort_vj_name  <- function(v,index.return = F){  
  s <- strsplit(gsub("[a-zA-Z]","",v),"\\D")
  n <- max(sapply(s,function(ss){ length(ss)}))
  l <- max(sapply(s,function(ss){ max(nchar(ss))}))
  
  fs <- sapply(s,function(ss){ paste(sprintf(paste("%0",l,"d",sep=""), c(as.numeric(ss), rep(0,n-length(ss)))),collapse ="") })
  r  <- sort(fs, index.return = T)
  if(index.return){
    d <- list(x=v[r$ix],ix=r$ix)
  }else{
    d <- v[r$ix]
  }
  d
}

#######  for Decombinator  ########
extract_name <- function(str,pattern='TR.*\\*'){
  p <- regexpr(pattern,str)
  l <- attr(p,'match.length') - 1
  sapply(1:length(p),function(i){  substr(str[i],p[i],p[i] + l[i]-1)})
}

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
  fr <- file.path(decombinator_path,sprintf("results_%s", o_fn), sprintf("%s_beta.txt", o_fn))  ### read beta data
  
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


