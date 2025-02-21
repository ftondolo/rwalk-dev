library(ggplot2)
library(openxlsx)
library(dplyr)
library(data.table)

input_dir <- "./input"           # Input directory, on GitHub
par_dir <- "./scripts"           # File params need a trackable directory

# File parameters, on GitHub
fil_params_all <- read.xlsx(paste(par_dir, "file_params.xlsx", sep = "/"))

fils <- unique(fil_params_all[ , c("filename", "sample_rate", "animal", "genotype",
                                   "pulses", "pulse_freq", "bin_size", "electrode_distance",
                                   "dead_space_distance", "diffusion_coefficient", "convert_current",
                                   "calibration_current", "calibration_concentration")])

fil_not_exists <- sum(!file.exists(paste(input_dir, fils$filename, sep = "/")))
if (fil_not_exists) {stop("Input file not found")}



# Files for merging.
print(fils$filename)

# Initialize data frame for merge.
stim_df <- data.frame(animal = character(),
                      stimulus = integer(),
                      stim_time_sec = double(),
                      genotype = character(),
                      include = logical(),
                      time_sec = double(),
                      electrode = integer())

# Read data
for (i in 38:(nrow(fils) - 4)) {
        print(fils[i, "filename"])
        
        dat <- read_experiment_csv(paste(input_dir, fils[i, "filename"], sep = "/"),
                                   sr = fils[i, "sample_rate"])
        
        if (fils[i, "convert_current"] == TRUE) {
                dat <- current_to_concentration(dat, calibration_current = fils[i, "calibration_current"],
                                                calibration_concentration = fils[i, "calibration_concentration"])
        }
        
        fil_params_cur <- fil_params_all[fil_params_all$filename == fils[i, "filename"], ]
        # dat_list <- list()
        max_stim <- max(fil_params_cur$stimulus)
        
        for (j in seq_along(fil_params_cur$stimulus)) {
                start_idx <- fil_params_cur$start[j] # start_idx <- fil_params_cur[fil_params_cur$stimulus == stim, "start"]
                if (start_idx > nrow(dat)) {
                        stop(paste0("Stimulus start overflows data: ", fil_params_cur$filename[j],
                                    " #", fil_params_cur$stimulus[j]))
                        
                } else if (fil_params_cur$stimulus[j] == max_stim) {
                        top_row_idx <- nrow(dat)
                } else {
                        top_row_idx <- fil_params_cur$start[(j + 1)] -1 # , "start"] - 1 # fil_params_cur[fil_params_cur$stimulus == (stim + 1), "start"] - 1
                }
                
                #dat_list[[stim]] <- dat[start_idx:top_row_idx, ] # Don't really need the list
                
                sr_s <- fil_params_cur$sample_rate * 10^-3
                
                stim_time_sec <- seq(from = 0, by = sr_s,
                                     length.out = nrow(dat[start_idx:top_row_idx, ]))
                
                one_stim_df <- cbind(animal = fils[i, "animal"], stimulus = fil_params_cur$stimulus[j],
                                     stim_time_sec = stim_time_sec, genotype = fils[i, "genotype"],
                                     include = fil_params_cur$include[j], #fil_params_cur[fil_params_cur$stimulus == stim, "include"],
                                     dat[start_idx:top_row_idx, ])
                
                stim_df <- rbind(stim_df, one_stim_df)
        }
}

# Analysis of NA
ok <- complete.cases(stim_df)
sum(!ok)

# Global variable initialisation
desired_genotype <- "syntko"

# Pre-AMPH (1-3)
dat_merge_pre <- select(stim_df, animal, stim_time_sec, electrode, genotype, stimulus, include) %>%
        filter(genotype == desired_genotype & stimulus >= 1 & stimulus <= 3 & include == TRUE & stim_time_sec <= 120) %>%
        group_by(stim_time_sec) %>%
        summarize(mean(electrode))
dat_merge_pre <- rename(dat_merge_pre, time_sec = stim_time_sec, "electrode" = "mean(electrode)")
qplot(dat_merge_pre$time_sec, dat_merge_pre$electrode, geom = "line")

# AMPH (6-10)
dat_merge_amph_0610 <- select(stim_df, animal, stim_time_sec, electrode, genotype, stimulus, include) %>%
        filter(genotype == desired_genotype & stimulus >= 6 & stimulus <= 10 & include == TRUE & stim_time_sec <= 120) %>%
        group_by(stim_time_sec) %>%
        summarize(mean(electrode))
dat_merge_amph_0610 <- rename(dat_merge_amph_0610, time_sec = stim_time_sec, "electrode" = "mean(electrode)")
qplot(dat_merge_amph_0610$time_sec, dat_merge_amph_0610$electrode, geom = "line")

# AMPH (16-20)
dat_merge_amph_1620 <- select(stim_df, animal, stim_time_sec, electrode, genotype, stimulus, include) %>%
        filter(genotype == desired_genotype & stimulus >= 16 & stimulus <= 20 & include == TRUE & stim_time_sec <= 120) %>%
        group_by(stim_time_sec) %>%
        summarize(mean(electrode))
dat_merge_amph_1620 <- rename(dat_merge_amph_1620, time_sec = stim_time_sec, "electrode" = "mean(electrode)")
qplot(dat_merge_amph_1620$time_sec, dat_merge_amph_1620$electrode, geom = "line")

# Plot and compile results.
results <- data.frame(genotype = character(),
                      amphetamine = character(),
                      release = double(),
                      vmax = double(),
                      km = double(),
                      stringsAsFactors = FALSE)

# Constants
pulses <- 30
pulse_freq <- 50
bin_size <- 2.0
electrode_distance <- 1000
dead_space_distance <- 4
diffusion_coefficient <- 2.7 * 10^-6
convert_current <- FALSE
fit_region = "fall"

# ----------------- BEGIN KNOCKOUT -----------------#

# SYNTKO - Pre-AMPH

# Variables
genotype <- desired_genotype
amphetamine <- "PRE"
release <- 1.07
vmax <- 4.8
km <- 5
base_tolerance <- 0.05
plot_duration_sec = 10

if (nrow(results[results$genotype == genotype & results$amphetamine == amphetamine, ]) == 0) {
        results[(nrow(results)+1), ] <- c(genotype, amphetamine, release, vmax, km)
} else {
        results[results$genotype == genotype & 
                        results$amphetamine == amphetamine, ] <- cbind(genotype, amphetamine, release, vmax, km)
}

compare_pulse(dat = dat_merge_pre, fil = "Synuclein Triple Knockout - Pre-AMPH",
              vmax = vmax, km = km,
              pulses = pulses,
              pulse_freq = pulse_freq,
              release = release,
              bin_size = bin_size,
              electrode_distance = electrode_distance,
              dead_space_distance = dead_space_distance,
              diffusion_coefficient = diffusion_coefficient,
              convert_current = convert_current,
              fit_region = fit_region,
              base_tolerance = base_tolerance,
              plot_duration_sec = plot_duration_sec)

# SYNTKO - Post-AMPH 6-10

# Variables
genotype <- desired_genotype
amphetamine <- "POST_06-10"
release <- 2.97
vmax <- 4.8
km <- 24
base_tolerance <- 0.05
plot_duration_sec = 30

if (nrow(results[results$genotype == genotype & results$amphetamine == amphetamine, ]) == 0) {
        results[(nrow(results)+1), ] <- c(genotype, amphetamine, release, vmax, km)
} else {
        results[results$genotype == genotype & 
                        results$amphetamine == amphetamine, ] <- cbind(genotype, amphetamine, release, vmax, km)
}

compare_pulse(dat = dat_merge_amph_0610, fil = "Synuclein Triple Knockout - Post-AMPH 06-10",
              vmax = vmax, km = km,
              pulses = pulses,
              pulse_freq = pulse_freq,
              release = release,
              bin_size = bin_size,
              electrode_distance = electrode_distance,
              dead_space_distance = dead_space_distance,
              diffusion_coefficient = diffusion_coefficient,
              convert_current = convert_current,
              fit_region = fit_region,
              base_tolerance = base_tolerance,
              plot_duration_sec = plot_duration_sec)

# SYNTKO - Post-AMPH 16-20

# Variables
genotype <- desired_genotype
amphetamine <- "POST_16-20"
release <- 1.25
vmax <- 4.8
km <- 24
base_tolerance <- 0.05
plot_duration_sec = 50

if (nrow(results[results$genotype == genotype & results$amphetamine == amphetamine, ]) == 0) {
        results[(nrow(results)+1), ] <- c(genotype, amphetamine, release, vmax, km)
} else {
        results[results$genotype == genotype & 
                        results$amphetamine == amphetamine, ] <- cbind(genotype, amphetamine, release, vmax, km)
}

compare_pulse(dat = dat_merge_amph_1620, fil = "Synuclein Triple Knockout - Post-AMPH 16-20",
              vmax = vmax, km = km,
              pulses = pulses,
              pulse_freq = pulse_freq,
              release = release,
              bin_size = bin_size,
              electrode_distance = electrode_distance,
              dead_space_distance = dead_space_distance,
              diffusion_coefficient = diffusion_coefficient,
              convert_current = convert_current,
              fit_region = fit_region,
              base_tolerance = base_tolerance,
              plot_duration_sec = plot_duration_sec)

results

