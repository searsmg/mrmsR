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
#'
#' @return A list of POSIXct datetimes corresponding to missing or failed downloads.
#'
#' @details
#' Data are retrieved from the Iowa State Mesonet MRMS archive:
#' \url{http://mtarchive.geol.iastate.edu/}.
#'
#' The function attempts to download each timestep sequentially. If a file is
#' missing or fails to download/unzip, the corresponding timestamp is recorded
#' and returned.
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

  # Create an empty vector of missing dates
  missing_dates <- vector("list",
                          length = 0)

  # Start w/ first timestep
  date <- start

  # URLs to Iowa State Mesonet
  url_product <- list(
    "RQI" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarQualityIndex/RadarQualityIndex_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "MultiSensorQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/MultiSensor_QPE_01H_Pass2/MultiSensor_QPE_01H_Pass2_00.00_%04d%02d%02d-%02d0000.grib2.gz",
    "RadarOnlyQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarOnly_QPE_01H/RadarOnly_QPE_01H_00.00_%04d%02d%02d-%02d0000.grib2.gz",
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

  url_pattern <- url_product[[product]]
  time_delta <- time_deltas[[product]]

  while (date <= end) {
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
      message(sprintf("Missing or failed download for %s", date))
      missing_dates <- append(missing_dates, list(date))
    } else {
      writeBin(httr::content(response, "raw"), filepath)

      if (file.exists(filepath)) {
        tryCatch({
          R.utils::gunzip(filepath, remove = TRUE, overwrite = TRUE)
        }, error = function(e) {
          message(sprintf("Error unzipping file for %s: %s", date, e$message))
          missing_dates <- append(missing_dates, list(date))
        })
      } else {
        message(sprintf("File does not exist after download attempt for %s", date))
        missing_dates <- append(missing_dates, list(date))
      }
    }

    # Date + timestep
    date <- date + time_delta
  }

  # Return the list of missing dates
  return(missing_dates)
}
