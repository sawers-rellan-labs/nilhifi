#!/usr/bin/env Rscript
# Parameterized dotplot script for Nextflow pipeline
# Usage: Rscript plot_dotplot.R --sample NAME --tab_b73 FILE --tab_pt FILE --outdir DIR

library(optparse)
library(ggplot2)
library(svglite)

option_list <- list(
  make_option("--sample",    type = "character", help = "Sample name"),
  make_option("--tab_b73",   type = "character", help = "Dotplot tab file vs B73"),
  make_option("--tab_ref2",  type = "character", help = "Dotplot tab file vs ref2"),
  make_option("--tab_pt",    type = "character", help = "[deprecated] Alias for --tab_ref2"),
  make_option("--ref2_name", type = "character", default = "PT", help = "Name of second reference"),
  make_option("--outdir",    type = "character", default = ".", help = "Output directory")
)
opts <- parse_args(OptionParser(option_list = option_list))

# Support both --tab_pt (legacy) and --tab_ref2 (new)
if (is.null(opts$tab_ref2) && !is.null(opts$tab_pt)) {
  opts$tab_ref2 <- opts$tab_pt
}
ref2 <- opts$ref2_name

changetoM <- function(position) {
  paste0(position / 1e6, "M")
}

chrlevels <- c("chr1", "chr2", "chr3", "chr4", "chr5",
               "chr6", "chr7", "chr8", "chr9", "chr10")

find_dominant_scaffold <- function(data) {
  counts <- as.data.frame(table(data$V1, data$V3))
  names(counts) <- c("refChr", "queryChr", "n")
  counts <- counts[counts$n > 0, ]
  dominant <- do.call(rbind, lapply(split(counts, counts$refChr), function(x) {
    x[which.max(x$n), ]
  }))
  return(dominant)
}

# --- Whole-genome dotplots ---

for (ref_name in c("B73", ref2)) {
  tab_file <- if (ref_name == "B73") opts$tab_b73 else opts$tab_ref2
  if (is.null(tab_file) || !file.exists(tab_file)) {
    message("Skipping ", ref_name, ": file not found")
    next
  }

  data <- read.table(tab_file)

  data <- data[data$V1 %in% chrlevels, ]

  dominant <- find_dominant_scaffold(data)
  message(ref_name, " chromosome-scaffold mapping:")
  for (i in seq_len(nrow(dominant))) {
    message("  ", dominant$refChr[i], " -> ", dominant$queryChr[i],
            " (", dominant$n[i], " anchors)")
  }

  keep <- paste(data$V1, data$V3) %in% paste(dominant$refChr, dominant$queryChr)
  data <- data[keep, ]

  data$V1 <- factor(data$V1, levels = chrlevels)
  scf_order <- dominant$queryChr[match(chrlevels, dominant$refChr)]
  scf_order <- scf_order[!is.na(scf_order)]
  data$V3 <- factor(data$V3, levels = rev(scf_order))

  if (nrow(data) == 0) {
    message("No data after filtering for ", ref_name, ", skipping")
    next
  }

  p <- ggplot(data, aes(x = V2, y = V4)) +
    geom_point(size = 0.3, aes(color = V5)) +
    scale_color_manual(values = c("+" = "blue", "-" = "red")) +
    facet_grid(V3 ~ V1, scales = "free", space = "free") +
    labs(x = ref_name, y = paste0(opts$sample, " assembly")) +
    scale_x_continuous(labels = changetoM) +
    scale_y_continuous(labels = changetoM) +
    theme(
      axis.line = element_blank(),
      panel.background = element_blank(),
      panel.border = element_rect(fill = NA, color = "black", linewidth = 0.5),
      axis.text.y = element_text(size = 5, colour = "black"),
      axis.text.x = element_text(angle = 300, size = 5, hjust = 0, vjust = 1, colour = "black"),
      legend.position = "none"
    )

  outbase <- file.path(opts$outdir, paste0(opts$sample, "_dotplot_vs_", ref_name))
  ggsave(paste0(outbase, ".pdf"), p, width = 12, height = 10)
  ggsave(paste0(outbase, ".svg"), p, width = 12, height = 10)
  message("Saved: ", outbase, ".pdf/.svg")
}

# --- Chr4 zoom: side-by-side B73 vs ref2 ---

data_list <- list()
for (ref_name in c("B73", ref2)) {
  tab_file <- if (ref_name == "B73") opts$tab_b73 else opts$tab_ref2
  if (is.null(tab_file) || !file.exists(tab_file)) next
  d <- read.table(tab_file)

  d_chr4 <- d[d$V1 == "chr4", ]
  dom <- find_dominant_scaffold(d_chr4)
  chr4_scf <- as.character(dom$queryChr[dom$refChr == "chr4"])
  message(ref_name, " chr4 dominant scaffold: ", chr4_scf)

  d <- d[d$V1 == "chr4" & d$V3 == chr4_scf, ]
  # Zoom to inversion region on reference axis
  d <- d[d$V2 >= 150e6 & d$V2 <= 220e6, ]
  # Compute robust query bounds (2-98th percentile) to match ref span as a square
  q_lo <- as.numeric(quantile(d$V4, 0.02))
  q_hi <- as.numeric(quantile(d$V4, 0.98))
  d <- d[d$V4 >= q_lo & d$V4 <= q_hi, ]
  d$ref <- ref_name
  data_list[[ref_name]] <- d
  message(ref_name, " chr4 zoom: ref 150-220 Mb, query ",
          round(q_lo/1e6, 1), "-", round(q_hi/1e6, 1), " Mb (",
          nrow(d), " points)")
}

if (length(data_list) == 2 && all(sapply(data_list, nrow) > 0)) {
  chr4 <- do.call(rbind, data_list)
  chr4$ref <- factor(chr4$ref, levels = c("B73", ref2))

  # Use shared query limits across both panels for comparability
  q_min <- min(chr4$V4)
  q_max <- max(chr4$V4)

  p4 <- ggplot(chr4, aes(x = V2, y = V4)) +
    geom_point(size = 0.5, aes(color = V5)) +
    scale_color_manual(values = c("+" = "blue", "-" = "red"),
                       labels = c("+" = "collinear", "-" = "inverted")) +
    coord_fixed(ratio = 1) +
    facet_wrap(~ ref, ncol = 2) +
    labs(x = "Reference chr4 position", y = paste0(opts$sample, " assembly (chr4 scaffold)"),
         color = "Strand") +
    scale_x_continuous(labels = changetoM) +
    scale_y_continuous(labels = changetoM, limits = c(q_min, q_max)) +
    theme_minimal() +
    theme(
      panel.border = element_rect(fill = NA, color = "black", linewidth = 0.5),
      axis.text = element_text(size = 8, colour = "black"),
      legend.position = "bottom",
      strip.text = element_text(size = 12, face = "bold")
    )

  outbase4 <- file.path(opts$outdir, paste0(opts$sample, "_chr4_inv4m_dotplot"))
  ggsave(paste0(outbase4, ".pdf"), p4, width = 10, height = 5)
  ggsave(paste0(outbase4, ".svg"), p4, width = 10, height = 5)
  message("Saved: ", outbase4, ".pdf/.svg")
} else {
  message("Chr4 zoom: insufficient data for one or both references")
}
