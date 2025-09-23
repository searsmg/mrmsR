pullMRMS <- function(start,
                                end,
                                destination,
                                product) {

  # create an empty vector of missing dates
  missing_dates <- vector("list", length = 0)

  # start w/ first timestep
  date <- start

  url_product <- list(
    "RQI" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarQualityIndex/RadarQualityIndex_00.00_%04d%02d%02d-%02d%02d00.grib2.gz",
    "MultiSensorQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/MultiSensor_QPE_01H_Pass2/MultiSensor_QPE_01H_Pass2_00.00_%04d%02d%02d-%02d0000.grib2.gz",
    "RadarOnlyQPE" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/RadarOnly_QPE_01H/RadarOnly_QPE_01H_00.00_%04d%02d%02d-%02d0000.grib2.gz",
    "SurfacePrecipRate" = "http://mtarchive.geol.iastate.edu/%04d/%02d/%02d/mrms/ncep/PrecipRate/PrecipRate_00.00_%04d%02d%02d-%02d%02d00.grib2.gz"
  )

  time_deltas <- list(
    "RQI" = minutes(2),
    "MultiSensorQPE" = hours(1),
    "RadarOnlyQPE" = hours(1),
    "SurfacePrecipRate" = minutes(2)
  )

  url_pattern <- url_product[[product]]
  time_delta <- time_deltas[[product]]

  while (date <= end) {
    url <- sprintf(
      url_pattern,
      year(date), month(date), day(date),
      year(date), month(date), day(date),
      hour(date), minute(date)
    )

    filename <- basename(url)
    filepath <- file.path(destination, filename)

    response <- try(GET(url), silent = TRUE)

    if (inherits(response, "try-error") || status_code(response) != 200) {
      message(sprintf("Missing or failed download for %s", date))
      missing_dates <- append(missing_dates, list(date))
    } else {
      writeBin(content(response, "raw"), filepath)

      # Only try to unzip if the file exists
      if (file.exists(filepath)) {
        tryCatch({
          gunzip(filepath, remove = TRUE, overwrite = TRUE)
        }, error = function(e) {
          message(sprintf("Error unzipping file for %s: %s", date, e$message))
          missing_dates <- append(missing_dates, list(date))
        })
      } else {
        message(sprintf("File does not exist after download attempt for %s", date))
        missing_dates <- append(missing_dates, list(date))
      }
    }

    # Increment the date
    date <- date + time_delta
  }
  # Return the list of missing dates
  return(missing_dates)
}
