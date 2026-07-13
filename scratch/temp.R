
#' Downloads MRMS precipitation products from the Iowa State Mesonet archive
#' for a specified time range and save them locally. Files are downloaded as
#' compressed `.grib2.gz` and automatically unzipped after download.
#'
#' @param start POSIXct. Start datetime (e.g., from lubridate::ymd_hm).
#' @param end POSIXct. End datetime.
#' @param destination Character. Directory where downloaded files will be saved.
#' @param product Character. MRMS product to download. Options include:
#'   \itemize{
#'     \item \code{"RQI"}: Radar Quality Index (2-minute resolution)
#'     \item \code{"MultiSensorQPE"}: Multi-sensor QPE (hourly)
#'     \item \code{"RadarOnlyQPE"}: Radar only QPE (hourly)
#'     \item \code{"SurfacePrecipRate"}: Surface precipitation rate (2-minute resolution)
#'     \item \code{"SHSRHeight"}: Height of Seamless Hybrid Scan Reflectivity (2-minute resolution); sourced from the NOAA MRMS AWS bucket
#'   }
#' @param workers Integer. Number of parallel workers for downloading. Defaults to 4.
#'
#' @return A list of POSIXct datetimes corresponding to missing or failed downloads.
#'
#' @details
#' Data are retrieved from the Iowa State Mesonet MRMS archive:
#' \url{http://mtarchive.geol.iastate.edu/}. \code{SHSRHeight} is retrieved
#' from the NOAA MRMS AWS S3 bucket.
#'
#' @examples
#' \dontrun{
#' downloadMRMS(
#'   start = lubridate::ymd_hm("2025-07-03 20:00"),
#'   end = lubridate::ymd_hm("2025-07-04 23:00"),
#'   destination = "./NFork_GuadRiv/mrms_rasters",
#'   product = "SurfacePrecipRate"
#' )
#' }
#'
#' @export

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
    "SHSRHeight" = "https://noaa-mrms-pds.s3.amazonaws.com/CONUS/SeamlessHSRHeight_00.00/%04d%02d%02d/MRMS_SeamlessHSRHeight_00.00_%04d%02d%02d-%02d%02d00.grib2.gz"
  )

  time_deltas <- list(
    "RQI" = as.difftime(2, units = "mins"),
    "MultiSensorQPE" = as.difftime(1, units = "hours"),
    "RadarOnlyQPE" = as.difftime(1, units = "hours"),
    "SurfacePrecipRate" = as.difftime(2, units = "mins"),
    "SHSRHeight" = as.difftime(2, units = "mins")
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


#library(tictoc)
#library(mrmsR)

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2021-05-30 00:00"),
  end = lubridate::ymd_hm("2021-10-01 10:00"),
  destination = "/Users/megansears/Documents/MRMS_temp/height21",
  product = "SHSRHeight",
  workers = 10
)
toc()

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2022-05-30 00:00"),
  end = lubridate::ymd_hm("2022-10-01 10:00"),
  destination = "/Users/megansears/Documents/MRMS_temp/height22",
  product = "SHSRHeight",
  workers=8
)
toc()

tic()
downloadMRMS(
  start = lubridate::ymd_hm("2023-05-30 00:00"),
  end = lubridate::ymd_hm("2023-10-01 10:00"),
  destination = "/Users/megansears/Documents/MRMS_temp/height23",
  product = "SHSRHeight",
  workers=6
)
toc()

############################################################################################

prepMRMS <- function(dir, output_dir, num_cores, boundary) {

  if (!is.character(boundary)) {
    stop("boundary must be a file path when using parallel processing")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- base::list.files(dir, pattern = "\\.grib2$", full.names = TRUE)

  already_done <- base::list.files(output_dir, pattern = "_processed\\.tif$", full.names = TRUE)
  already_done <- already_done[file.size(already_done) > 0]
  already_done_base <- sub("_processed\\.tif$", ".grib2", base::basename(already_done))
  files <- files[!(base::basename(files) %in% already_done_base)]

  if (length(files) == 0) {
    message("All files already processed.")
    return(invisible(NULL))
  }

  message(sprintf("%d files to process.", length(files)))

  future::plan(future::multisession, workers = num_cores)

  process_file <- function(file, boundary_path, output_dir) {
    tryCatch({
      r <- terra::rast(file)
      terra::crs(r) <- "EPSG:4326"

      b <- terra::vect(boundary_path)

      if (!terra::same.crs(r, b)) {
        b <- terra::project(b, terra::crs(r))
      }

      r <- terra::crop(r, b)
      r <- terra::mask(r, b)

      new_file <- base::file.path(
        output_dir,
        paste0(tools::file_path_sans_ext(base::basename(file)), "_processed.tif")
      )

      terra::writeRaster(r, new_file, overwrite = TRUE)
    }, error = function(e) {
      message(sprintf("Failed: %s — %s", basename(file), e$message))
    })

    invisible(NULL)
  }

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

test1 <- vect('/Volumes/MSears_Mac2/Documents/MRMS/bbox_2fires/bbox_2fires.shp')

library(mapview)
mapview(test1)

prepMRMS(dir = '/Users/megansears/Documents/MRMS_temp/height23',
                     output_dir = '/Users/megansears/Documents/MRMS_temp/height23_processed',
                   num_cores = 8,
                     boundary = '/Volumes/MSears_Mac2/Documents/MRMS/bbox_2fires/bbox_2fires.shp')

library(terra)

files <- list.files(
  "/Users/megansears/Documents/MRMS_temp/height23_processed",
  pattern = "\\.tif$",
  full.names = TRUE
)

chunk_size <- 5000
chunks <- split(files, ceiling(seq_along(files) / chunk_size))

chunk_mins <- list()
chunk_maxs <- list()

for (i in seq_along(chunks)) {
  message(sprintf("Processing chunk %d of %d", i, length(chunks)))
  s <- terra::rast(chunks[[i]])
  chunk_mins[[i]] <- terra::app(s, fun = "min", na.rm = TRUE)
  chunk_maxs[[i]] <- terra::app(s, fun = "max", na.rm = TRUE)
}


min_rast <- terra::app(terra::rast(chunk_mins), fun = function(x) {
  v <- x[x >= 0]
  if (length(v) == 0) return(NA)
  min(v, na.rm = TRUE)
})

plot(min_rast)

max_rast <- terra::app(terra::rast(chunk_maxs), fun = "max", na.rm = TRUE)

plot(max_rast)

terra::writeRaster(min_rast, "/Users/megansears/Documents/MRMS_temp/height23_min.tif", overwrite = TRUE)
terra::writeRaster(max_rast, "/Users/megansears/Documents/MRMS_temp/height23_max.tif", overwrite = TRUE)

