
downloadMRMS <- function(start,
                         end,
                         destination,
                         product,
                         workers = 4) {

  url_product <- list(
    "RQI" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarQualityIndex/RadarQualityIndex_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "MultiSensorQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/MultiSensor_QPE_01H_Pass2/MultiSensor_QPE_01H_Pass2_00.00_%04d%02d%02d-%02d0000.grib2.gz",
    "RadarOnlyQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarOnly_QPE_01H/RadarOnly_QPE_01H_00.00_%04d%02d%02d-%02d0000.grib2.gz",
    "SurfacePrecipRate" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/PrecipRate/PrecipRate_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "SHSRHeight" = "https://noaa-mrms-pds.s3.amazonaws.com/CONUS/SeamlessHSRHeight_00.00/%04d%02d%02d/MRMS_SeamlessHSRHeight_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "PrecipFlag" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/PrecipFlag/PrecipFlag_00.00_%04d%02d%02d-%02d%02d00.grib2.gz"
  )

  time_deltas <- list(
    "RQI" = as.difftime(2, units = "mins"),
    "MultiSensorQPE" = as.difftime(1, units = "hours"),
    "RadarOnlyQPE" = as.difftime(1, units = "hours"),
    "SurfacePrecipRate" = as.difftime(2, units = "mins"),
    "SHSRHeight" = as.difftime(2, units = "mins"),
    "PrecipFlag" = as.difftime(2, units = "mins")
  )

  url_pattern <- url_product[[product]]
  time_delta <- time_deltas[[product]]

  dates <- seq(start, end, by = time_delta)

  future::plan(future::multisession, workers = workers)

  progressr::with_progress({
    p <- progressr::progressor(steps = length(dates))

    missing_dates <- furrr::future_map(dates, function(date) {
      p()

      url <- sprintf(
        url_pattern,
        lubridate::year(date), lubridate::month(date), lubridate::day(date),
        lubridate::year(date), lubridate::month(date), lubridate::day(date),
        lubridate::hour(date), lubridate::minute(date)
      )

      filename <- basename(url)
      filepath <- file.path(destination, filename)
      unzipped_filepath <- tools::file_path_sans_ext(filepath)

      # Skip if already downloaded and unzipped
      if (file.exists(unzipped_filepath) && file.size(unzipped_filepath) > 0) {
        return(NULL)
      }

      response <- try(httr::GET(url), silent = TRUE)

      if (inherits(response, "try-error") || httr::status_code(response) != 200) {
        return(date)
      }

      writeBin(httr::content(response, "raw"), filepath)

      if (file.exists(filepath)) {
        tryCatch({
          R.utils::gunzip(filepath, remove = TRUE, overwrite = TRUE)
          return(NULL)
        }, error = function(e) {
          return(date)
        })
      } else {
        return(date)
      }
    }, .options = furrr::furrr_options(seed = NULL))
  })

  future::plan(future::sequential)

  Filter(Negate(is.null), missing_dates)
}


#####################################################################################

library(tictoc)

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2021-05-30 00:00"),
  end = lubridate::ymd_hm("2021-10-01 10:00"),
  destination = "/Volumes/MSears_Mac2/PrecipType21",
  product = "PrecipFlag",
  workers = 3
)
toc()

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2022-05-30 00:00"),
  end = lubridate::ymd_hm("2022-10-01 10:00"),
  destination = "/Volumes/MSears_Mac2/PrecipType22",
  product = "PrecipFlag",
  workers = 3
)
toc()

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2023-05-30 00:00"),
  end = lubridate::ymd_hm("2023-10-01 10:00"),
  destination = "/Volumes/MSears_Mac2/PrecipType23",
  product = "PrecipFlag",
  workers = 8
)
toc()


################################################################################

prepMRMS <- function(dir, output_dir, num_cores, boundary) {

  # Input check
  if (!is.character(boundary)) {
    stop("boundary must be a file path when using parallel processing")
  }

  # Create output dir if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # List GRIB2 files, skipping any already processed
  files <- base::list.files(dir, pattern = "\\.grib2$", full.names = TRUE)

  already_done <- base::list.files(output_dir, pattern = "_processed\\.tif$", full.names = FALSE)
  already_done_base <- sub("_processed\\.tif$", ".grib2", already_done)
  files <- files[!(base::basename(files) %in% already_done_base)]

  if (length(files) == 0) {
    message("All files already processed.")
    return(invisible(NULL))
  }

  message(sprintf("%d files to process.", length(files)))

  # Set parallel plan
  future::plan(future::multisession, workers = num_cores)

  # Function to process each file
  process_file <- function(file, boundary_path, output_dir) {

    r <- terra::rast(file)

    # set crs
    terra::crs(r) <- "EPSG:4326"

    b <- terra::vect(boundary_path)

    # Align CRS
    if (!terra::same.crs(r, b)) {
      b <- terra::project(b, terra::crs(r))
    }

    # Crop + mask (more robust than crop alone)
    r <- terra::crop(r, b)
    r <- terra::mask(r, b)

    # Output filename
    new_file <- base::file.path(
      output_dir,
      paste0(tools::file_path_sans_ext(base::basename(file)), "_processed.tif")
    )

    # Write
    terra::writeRaster(r, new_file, overwrite = TRUE)

    invisible(NULL)
  }

  # Run in parallel
  furrr::future_map(
    files,
    process_file,
    boundary_path = boundary,
    output_dir = output_dir,
    .options = furrr::furrr_options(seed = TRUE)
  )

  message("Processing complete!")

  invisible(NULL)
}


tb_all <- read_csv('/Users/megansears/Library/CloudStorage/OneDrive-Colostate/PhD/post-fire_rain_response/data/GIS/tb_locations_new.csv') %>%
  dplyr::select(site, x, y)

tb_locations <- vect(tb_all, geom = c("x", "y"), crs = "EPSG:4326")

# save to temp file
tmp <- tempfile(fileext = ".gpkg")
terra::writeVector(tb_locations, tmp)

prepMRMS(dir = '/Volumes/MSears_Mac2/PrecipType21',
         output_dir = '/Volumes/MSears_Mac2/PType21_processed',
         num_cores = 10,
         boundary = tmp)

library(terra)
test <- rast('/Volumes/MSears_Mac2/PType21_processed/PrecipFlag_00.00_20210720-224000_processed.tif')
plot(test)

library(mapview)
sites <- vect(
  '/Users/megansears/Library/CloudStorage/OneDrive-Colostate/PhD/post-fire_rain_response/data/GIS/catchments_all/catchments_all_lidar.shp') %>%
  project(., crs(test))


plot(test)
plot(sites, add =T)

################################################################################

zonalMRMS <- function(raster_dir,
                      output_dir,
                      boundary,
                      n_workers) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)

  future::plan(future::multisession, workers = n_workers)
  on.exit(future::plan(future::sequential), add = TRUE)

  furrr::future_walk(files, function(file) {
    tryCatch({

      # load boundary inside worker
      b_local <- terra::vect(boundary)

      r <- terra::rast(file)
      names(r) <- "p_mmhr"

      if (!terra::same.crs(r, b_local)) {
        b_local <- terra::project(b_local, terra::crs(r))
      }

      extract <- terra::extract(
        r,
        b_local,
        fun = mean,
        na.rm = TRUE,
        touches = TRUE
      )

      if ("site" %in% names(b_local)) {
        extract$catchment <- b_local$site
      } else {
        extract$catchment <- 1:nrow(extract)
      }

      timestamp <- tools::file_path_sans_ext(basename(file))
      stamp <- stringr::str_extract(timestamp, "\\d{8}-\\d{6}")
      extract$datetime <- as.POSIXct(stamp, format = "%Y%m%d-%H%M%S", tz = "UTC")
      extract$doy  <- lubridate::yday(extract$datetime)
      extract$hour <- lubridate::hour(extract$datetime)
      extract$min  <- lubridate::minute(extract$datetime)

      out_file <- file.path(
        output_dir,
        paste0("extract_", extract$doy[1], "_",
               sprintf("%02d", extract$hour[1]), "_",
               sprintf("%02d", extract$min[1]), ".csv")
      )

      utils::write.csv(extract, out_file, row.names = FALSE)

    }, error = function(e) {
      message("Skipping ", basename(file), ": ", e$message)
    })
  })

  message("Zonal stats complete")
  invisible(NULL)
}

library(tidyverse)

tb_all <- read_csv('/Users/megansears/Library/CloudStorage/OneDrive-Colostate/PhD/post-fire_rain_response/data/GIS/tb_locations_new.csv') %>%
  dplyr::select(site, x, y)

tb_locations <- vect(tb_all, geom = c("x", "y"), crs = "EPSG:4326")

# save to temp file
tmp <- tempfile(fileext = ".gpkg")
terra::writeVector(tb_locations, tmp)

prepMRMS(dir = '/Volumes/MSears_Mac2/PrecipType21',
         output_dir = '/Volumes/MSears_Mac2/PType21_processed',
         num_cores = 10,
         boundary = tmp)

zonalMRMS(raster_dir = '/Volumes/MSears_Mac2/PType21_processed',
          output_dir = '/Volumes/MSears_Mac2/ptype21_csv',
          boundary = tmp,
          n_workers = 10)

ptype21 <- combineCSV('/Volumes/MSears_Mac2/ptype21_csv')

# 2022
prepMRMS(dir = '/Volumes/MSears_Mac2/PrecipType22',
         output_dir = '/Volumes/MSears_Mac2/PType22_processed',
         num_cores = 10,
         boundary = tmp)

zonalMRMS(raster_dir = '/Volumes/MSears_Mac2/PType22_processed',
          output_dir = '/Volumes/MSears_Mac2/ptype22_csv',
          boundary = tmp,
          n_workers = 10)

ptype22 <- combineCSV('/Volumes/MSears_Mac2/ptype22_csv')

# 2023
prepMRMS(dir = '/Volumes/MSears_Mac2/PrecipType23',
         output_dir = '/Volumes/MSears_Mac2/PType23_processed',
         num_cores = 10,
         boundary = tmp)

zonalMRMS(raster_dir = '/Volumes/MSears_Mac2/PType23_processed',
          output_dir = '/Volumes/MSears_Mac2/ptype23_csv',
          boundary = tmp,
          n_workers = 10)

ptype23 <- combineCSV('/Volumes/MSears_Mac2/ptype23_csv')

################################################################################

ptype <- bind_rows(ptype21,
                   ptype22,
                   ptype23)

write_csv(ptype, '/Volumes/MSears_Mac2/ptype.csv')
