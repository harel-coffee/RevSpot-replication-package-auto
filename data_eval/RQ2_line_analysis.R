library(tidyverse)
library(ggplot2)
library(reshape2)
library(gridExtra)
library(patchwork)
library(effsize)
# RQ="1" will generate the figure for RQ2.1
RQ = "1"
fileName = "commented"

# RQ="2" will generate the figure for RQ2.2
# RQ = "2"
# fileName = "revised"


#load data generated from python scripts
tokens.lime = read.csv(paste0("csv_",fileName,"_limescore.csv"),stringsAsFactors = F)
raw.line = read.csv(paste0("csv_",fileName,"_lineLevel_raw.csv"),stringsAsFactors = F)

if(sum(is.na(raw.line$limeAvgScore)) > 0){
  raw.line[is.na(raw.line$limeAvgScore),]$limeAvgScore = 0
}

#RQ2:How  accurate  is  our  approach  in  predicting changed lines that reviewers should pay attention to?
lime_avg_sensitivity = data.frame()
lime_topk_sensitivity = data.frame()

for( i in 0:5){
k = i*5
top_k.tokens = tokens.lime %>% select(-lineNumber) %>% unique() %>% filter(limeScore > 0) %>% group_by(dataset, changeId, fileName) %>% top_n(k)

top_k.counts = tokens.lime %>% left_join(top_k.tokens, by=c("dataset","changeId","fileName","token")) %>% 
  ungroup() %>% mutate(isTopK = !is.na(limeScore.y) ) %>%
  group_by(dataset, changeId, fileName, lineNumber) %>% summarize(numTopK = sum(isTopK))

results = raw.line %>% left_join(top_k.counts)  %>% ungroup() %>% mutate(predict.lime = numTopK > 0 ) %>%
  group_by(dataset, changeId, fileName) %>% summarize(lime.TP = sum(predict.lime == TRUE & groundTruth == 1), lime.FN = sum(predict.lime == FALSE & groundTruth == 1),
                                            lime.FP = sum(predict.lime == TRUE & groundTruth == 0), lime.TN = sum(predict.lime == FALSE & groundTruth == 0)) 


  results$recall = results$lime.TP/(results$lime.TP + results$lime.FN)
  results$far = results$lime.FP/(results$lime.FP + results$lime.TN)
  results[is.nan(results$far),]$far = 0
  results$d2h = sqrt((   ((1-results$recall)^2) + ((0-results$far)^2))/2)
  lime_topk_sensitivity = rbind(lime_topk_sensitivity, data.frame(k = k, avg_recall = median(results$recall), avg_far = median(results$far), avg_d2h = median(results$d2h)     ))
}

lime_sensitivity = data.frame()
ngram_sensitivity = data.frame()

for(i in 0:30)
{
  ngram_t = 0.1*i
  results = raw.line %>% ungroup() %>% mutate(predict = ngramScore > ngram_t ) %>%
    group_by(dataset, changeId, fileName) %>% summarize(TP = sum(predict == TRUE & groundTruth == 1), FN = sum(predict == FALSE & groundTruth == 1),
                                              FP = sum(predict == TRUE & groundTruth == 0), TN = sum(predict == FALSE & groundTruth == 0))
  results$recall = results$TP/(results$TP + results$FN)
  results$far = results$FP/(results$FP + results$TN)
  results[is.nan(results$far),]$far = 0
  results$d2h = sqrt((   ((1-results$recall)^2) + ((0-results$far)^2))/2)

  ngram_sensitivity = rbind(ngram_sensitivity, data.frame(ngram_t = ngram_t, avg_recall = median(results$recall), avg_far = median(results$far), avg_d2h = median(results$d2h)     ))
}


lime_topk_sensitivity = lime_topk_sensitivity %>% arrange(avg_d2h) 
ngram_sensitivity = ngram_sensitivity %>% arrange(avg_d2h)
ngram_t = ngram_sensitivity$ngram_t[1]
k_t = lime_topk_sensitivity$k[1]

top_k.tokens = tokens.lime %>% select(-lineNumber) %>% unique() %>% filter(limeScore > 0) %>% group_by(dataset, changeId, fileName) %>% top_n(k_t)

top_k.tokens %>% group_by(dataset, changeId, fileName) %>% summarize(zero_score = sum(limeScore == 0), negative_score = sum(limeScore < 0)) %>% group_by(dataset) %>% summarize(num_file_zero_score = sum(zero_score > 0), num_file_negative_score = sum(negative_score > 0), total_files = n())

top_k.counts = tokens.lime %>% left_join(top_k.tokens, by=c("dataset","changeId","fileName","token")) %>% 
  ungroup() %>% mutate(isTopK = !is.na(limeScore.y) ) %>%
  group_by(dataset, changeId, fileName, lineNumber) %>% summarize(numTopK = sum(isTopK))

num_tokens = tokens.lime %>% group_by(dataset, changeId, fileName, lineNumber) %>% summarize(token.count = n())

raw.line = raw.line %>% left_join(top_k.counts) %>% left_join(num_tokens)

results = raw.line %>% ungroup() %>% mutate(predict.ngram = ngramScore > ngram_t, predict.limeTopK = numTopK > 0) %>% 
  group_by(dataset, changeId, fileName) %>% summarize(
                                            limeTopK.TP = sum(predict.limeTopK == TRUE & groundTruth == 1), limeTopK.FN = sum(predict.limeTopK == FALSE & groundTruth == 1),
                                            limeTopK.FP = sum(predict.limeTopK == TRUE & groundTruth == 0), limeTopK.TN = sum(predict.limeTopK == FALSE & groundTruth == 0),
                                            ngram.TP = sum(predict.ngram == TRUE & groundTruth == 1), ngram.FN = sum(predict.ngram == FALSE & groundTruth == 1),
                                            ngram.FP = sum(predict.ngram == TRUE & groundTruth == 0), ngram.TN = sum(predict.ngram == FALSE & groundTruth == 0)) 

results = results %>% ungroup() %>% mutate(
                                 limeTopK.recall = limeTopK.TP/(limeTopK.TP + limeTopK.FN),  
                                 limeTopK.far = limeTopK.FP/(limeTopK.FP+limeTopK.TN),
                                 ngram.recall = ngram.TP/(ngram.TP + ngram.FN),
                                 ngram.far = ngram.FP/(ngram.FP + ngram.TN))

if(sum(is.nan(results$limeTopK.far)) > 0){
  results[is.nan(results$limeTopK.far),]$limeTopK.far = 0
}

if(sum(is.nan(results$ngram.far)) > 0){
  results[is.nan(results$ngram.far),]$ngram.far = 0
}


results = results %>% ungroup() %>% mutate(
                                           limeTopK.d2h = sqrt((   ((1-limeTopK.recall)^2) + ((0-limeTopK.far)^2))/2),
                                           ngram.d2h = sqrt((   ((1-ngram.recall)^2) + ((0-ngram.far)^2))/2),
)

total = raw.line %>% group_by(dataset, changeId, fileName) %>% summarize(totalTrue = sum(groundTruth), totalLine = n())
 
top10.per = raw.line %>% group_by(dataset, changeId, fileName) %>% summarize(totalTrue = sum(groundTruth))

top10.per =  raw.line %>% group_by(dataset, changeId, fileName) %>% top_n(10, ngramScore) %>%
  summarize(ngram.Top10 = sum(groundTruth)) %>% merge(top10.per) %>% mutate(ngram.Top10Per = ngram.Top10/totalTrue)


top10.per =  raw.line %>% group_by(dataset, changeId, fileName) %>% top_n(10, numTopK) %>%
  summarize(limeTopK.Top10 = sum(groundTruth)) %>% merge(top10.per) %>% mutate(limeTopK.Top10Per = limeTopK.Top10/totalTrue)


total = raw.line %>% group_by(dataset, changeId, fileName) %>% summarize(totalTrue = sum(groundTruth), totalLine = n())

# Generate figure for RQ2
performance = results %>% select(ends_with(c("dataset","changeId","fileName","recall","far","d2h")))
performance = performance %>% replace(is.na(.), 0)
performance$dataset[performance$dataset == "base"] <- "QtBase"
performance$dataset[performance$dataset == "nova"] <- "OpenstackNova"
performance$dataset[performance$dataset == "ironic"] <- "OpenstackIronic"
performance$dataset <- factor(performance$dataset, levels = c('QtBase','OpenstackNova','OpenstackIronic'), ordered = TRUE)
colnames(performance) <- c("dataset", "changeId", "fileName", "RevSpot.Recall", "N-gram.Recall", "RevSpot.FAR", "N-gram.FAR","RevSpot.d2h", "N-gram.d2h")
perforance_new = performance %>% melt() %>%
  separate(variable, c("technique","measure"), sep = "[.]") 
perforance_new$technique <- factor(perforance_new$technique, levels = c('RevSpot','N-gram'))

perforance_d2h <- perforance_new %>% filter(measure=="d2h")
perforance_recall <- perforance_new %>% filter(measure=="Recall")
perforance_far <- perforance_new %>% filter(measure=="FAR")

perforance_d2h_our <- perforance_d2h %>% filter(technique=="RevSpot")
perforance_d2h_ngram <- perforance_d2h %>% filter(technique=="N-gram")
median(perforance_d2h_our$value)
median(perforance_d2h_ngram$value)

perforance_recall_our <- perforance_recall %>% filter(technique=="RevSpot")
perforance_recall_ngram <- perforance_recall %>% filter(technique=="N-gram")
median(perforance_recall_our$value)
median(perforance_recall_ngram$value)

perforance_far_our <- perforance_far %>% filter(technique=="RevSpot")
perforance_far_ngram <- perforance_far %>% filter(technique=="N-gram")
median(perforance_far_our$value)
median(perforance_far_ngram$value)


perforance_d2h$title <- "d2h"
perforance_recall$title <- "Recall"
perforance_far$title <- "FAR"

g1_1 <- perforance_d2h %>% ggplot() + geom_boxplot(aes(x=technique, y = value, fill=technique),show.legend = FALSE)  +
  scale_fill_brewer(palette = "Blues", direction=-1) + theme_bw() + facet_grid(. ~ title) +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1),axis.title=element_blank())

g1_2 <- perforance_recall %>% ggplot() + geom_boxplot(aes(x=technique, y = value, fill=technique),show.legend = FALSE)  +
  scale_fill_brewer(palette = "Blues", direction=-1) + theme_bw() + facet_grid(. ~ title) +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1),axis.title=element_blank())

g1_3 <- perforance_far %>% ggplot() + geom_boxplot(aes(x=technique, y = value, fill=technique),show.legend = FALSE)  +
  scale_fill_brewer(palette = "Blues", direction=-1) + theme_bw() + facet_grid(. ~ title) +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1),axis.title=element_blank())

performance_nova <- performance %>% filter(dataset == "OpenstackNova") %>% select(ends_with(c("Recall","FAR","d2h")))
performance_ironic <- performance %>% filter(dataset == "OpenstackIronic") %>% select(ends_with(c("Recall","FAR","d2h")))
performance_base <- performance %>% filter(dataset == "QtBase") %>% select(ends_with(c("Recall","FAR","d2h")))
apply(performance_nova,2,median)
apply(performance_ironic,2,median)
apply(performance_base,2,median)

top10.acc = top10.per %>% select(ends_with(c("dataset","changeId","Top10"))) %>% melt() %>% separate(variable, c("technique","measure"), sep = "[.]") %>% 
  group_by( technique) %>% summarize(Top10ACC = sum(value > 0)*100/n())

top10.acc_nova <- top10.per %>% filter(dataset == "nova") %>% select(ends_with(c("dataset","changeId","Top10"))) %>% melt() %>% separate(variable, c("technique","measure"), sep = "[.]") %>% 
  group_by( technique) %>% summarize(Top10ACC = sum(value > 0)*100/n())
top10.acc_ironic <- top10.per %>% filter(dataset == "ironic") %>% select(ends_with(c("dataset","changeId","Top10"))) %>% melt() %>% separate(variable, c("technique","measure"), sep = "[.]") %>% 
  group_by( technique) %>% summarize(Top10ACC = sum(value > 0)*100/n())
top10.acc_base <- top10.per %>% filter(dataset == "base") %>% select(ends_with(c("dataset","changeId","Top10"))) %>% melt() %>% separate(variable, c("technique","measure"), sep = "[.]") %>% 
  group_by( technique) %>% summarize(Top10ACC = sum(value > 0)*100/n())

top10_x <- c("Top10Accuracy")
top10_y <- c("RevSpot","N-gram")
top10_z <- as.numeric(formatC(top10.acc$Top10ACC/100, digits=2, format="f"))
top10_z
top10_df <- data.frame(x = top10_x, y = top10_y, z = top10_z)
top10_df$title <- "Top10Accuracy"
g2 <- ggplot(data=top10_df, mapping = aes(x = y, y = z, fill = rev(y)),show.legend = FALSE) + 
  geom_bar(color="black",stat = "identity", width=0.7, position = position_dodge(width=0)) + 
  scale_fill_brewer(palette = "Blues") + theme_bw() + 
  theme(legend.title = element_blank(),axis.title=element_blank(), strip.text = ,legend.position = 'none',axis.text = element_text(size = 10)) + 
  geom_text(mapping = aes(label = scales::percent(top10_z)), size = 3, colour = 'black', vjust = -0.3,hjust=0.4, position = position_dodge(0.5)) + coord_cartesian(ylim=c(0,1)) + scale_x_discrete(limits=c('RevSpot','N-gram')) + facet_grid(. ~ title) + 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1)) + scale_y_continuous(breaks = 0:5*0.2, labels = scales::percent)

pdf(paste0("./figures/RQ2.",RQ,".pdf"), width=6, height = 3.5)
g2+g1_1+g1_3+g1_2+plot_layout(ncol=4)
dev.off()

#Statistic Analysis
library(coin)

baseline = "ngram"
approaches = c("limeTopK")
measures = c("recall","far","d2h")
projects = c("base","ironic","nova")
perf_diff = data.frame()

median_diff_table = data.frame(matrix(ncol=259, nrow=9))
colnames(median_diff_table) <- measures
median_diff_table
performance_stat = results  %>% select(ends_with(c("dataset","changeId","fileName","recall","far","d2h","IFA"))) 

performance_stat = performance_stat %>% replace(is.na(.), 0)
nrow(performance_stat)
performance_stat = results %>% select(ends_with(c("dataset","changeId","fileName","recall","far","d2h"))) 

for(m in measures){
  for(app in approaches){
    perf_app =  as.data.frame(performance_stat[, paste0(app,".",m)])
    perf_baseline = as.data.frame(performance_stat[,paste0(baseline,".",m)])
    perf_baseline[perf_baseline == 0,1] = 1
    p_diff = (perf_app[,1] - perf_baseline[,1])*100/perf_baseline[,1]
    perf = data.frame(app = perf_app[,1], baseline = perf_baseline[,1])
    test = wilcoxsign_test(perf_app[,1] ~ perf_baseline[,1])
    test.greater = wilcoxsign_test(app ~ baseline, data=perf, alternative = "greater")
    test.lower = wilcoxsign_test(app ~ baseline, data=perf, alternative = "less")
    perf_diff = rbind(perf_diff,data.frame(approach = app, measure = m,
                                            sig_greater = round(pvalue(test.greater), 4),
                                            sig_lower = round(pvalue(test.lower), 4),
                                            eff_size = test.greater@statistic@standardizedlinearstatistic/sqrt(length(p_diff)
                                            )
    ))
  }
}

perf_diff