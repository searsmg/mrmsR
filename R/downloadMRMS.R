#' Downloads MRMS precipitation products from the Iowa State Mesonet archive
#' for a specified time range and save them locally. Files are downloaded
#' concurrently via \code{curl::multi_download()} as compressed `.grib2.gz`
#' and automatically unzipped after download.
#'
#' @param start POSIXct. Start datetime (e.g., from lubridate::ymd_hm). Any
#'   time zone works; it's converted to UTC to match MRMS file names.
#' @param end POSIXct. End datetime.
#' @param destination Character. Directory where downloaded files will be saved.
#'   Created if it doesn't exist.
#' @param product Character. MRMS product to download. Options include:
#'   \itemize{
#'     \item \code{"RQI"}: Radar Quality Index (2-minute resolution)
#'     \item \code{"MultiSensorQPE"}: Multi-sensor QPE (hourly)
#'     \item \code{"RadarOnlyQPE"}: Radar only QPE (hourly)
#'     \item \code{"SurfacePrecipRate"}: Surface precipitation rate (2-minute resolution)
#'     \item \code{"SHSRHeight"}: Height of Seamless Hybrid Scan Reflectivity (2-minute resolution); sourced from the NOAA MRMS AWS bucket
#'   }
#'
#' @return A list of POSIXct datetimes (in UTC) corresponding to missing or
#'   failed downloads.
#'
#' @details
#' Data are retrieved from the Iowa State Mesonet MRMS archive:
#' \url{http://mtarchive.geol.iastate.edu/}.
#'
#' The function downloads every timestep concurrently. If a file is missing
#' or fails to download/unzip, the corresponding timestamp is recorded and
#' returned.
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

# Function to download MRMS
downloadMRMS <- function(start,
                         end,
                         destination,
                         product) {

  # URLs to Iowa State Mesonet
  url_product <- list(
    "RQI" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarQualityIndex/RadarQualityIndex_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "MultiSensorQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/MultiSensor_QPE_01H_Pass2/MultiSensor_QPE_01H_Pass2_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "RadarOnlyQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarOnly_QPE_01H/RadarOnly_QPE_01H_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "SurfacePrecipRate" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/PrecipRate/PrecipRate_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "SHSRHeight" = "https://noaa-mrms-pds.s3.amazonaws.com/CONUS/SeamlessHSRHeight_00.00/%04d%02d%02d/MRMS_SeamlessHSRHeight_00.00_%04d%02d%02d-%02d%02d00.grib2.gz"
  )

  # Temporal resolution for each product
  time_deltas <- list(
    "RQI" = lubridate::minutes(2),
    "MultiSensorQPE" = lubridate::hours(1),
    "RadarOnlyQPE" = lubridate::hours(1),
    "SurfacePrecipRate" = lubridate::minutes(2),
    "SHSRHeight" = lubridate::minutes(2)
  )

  product <- match.arg(product, names(url_product))

  if (!inherits(start, "POSIXct") || !inherits(end, "POSIXct")) {
    stop("`start` and `end` must be POSIXct datetimes (e.g., from lubridate::ymd_hm).")
  }

  # MRMS file names are in UTC
  start <- lubridate::with_tz(start, "UTC")
  end <- lubridate::with_tz(end, "UTC")

  if (!dir.exists(destination)) {
    dir.create(destination, recursive = TRUE)
  }

  url_pattern <- url_product[[product]]
  time_delta <- time_deltas[[product]]

  # Every timestep in the requested range
  dates <- seq(start, end, by = lubridate::as.duration(time_delta))

  urls <- purrr::map_chr(dates, function(date) {
    sprintf(
      url_pattern,
      lubridate::year(date), lubridate::month(date), lubridate::day(date),
      lubridate::year(date), lubridate::month(date), lubridate::day(date),
      lubridate::hour(date), lubridate::minute(date)
    )
  })

  filepaths <- file.path(destination, basename(urls))

  # Download every timestep concurrently
  results <- curl::multi_download(urls, filepaths)

  downloaded <- results$success & !is.na(results$success) & results$status_code == 200

  # curl writes the response body to disk even on failure (e.g. a 404 page);
  # remove those leftovers so only successful downloads remain
  failed_filepaths <- filepaths[!downloaded]
  failed_filepaths <- failed_filepaths[file.exists(failed_filepaths)]
  if (length(failed_filepaths) > 0) {
    file.remove(failed_filepaths)
  }

  # Unzip successful downloads
  unzip_ok <- purrr::map_lgl(filepaths[downloaded], function(filepath) {
    tryCatch({
      R.utils::gunzip(filepath, remove = TRUE, overwrite = TRUE)
      TRUE
    }, error = function(e) {
      message(sprintf("Error unzipping file %s: %s", filepath, e$message))
      FALSE
    })
  })

  failed <- !downloaded
  failed[downloaded] <- !unzip_ok

  missing_dates <- as.list(dates[failed])

  purrr::walk(dates[failed], function(date) {
    message(sprintf("Missing or failed download for %s", date))
  })

  # Return the list of missing dates
  return(missing_dates)
}
