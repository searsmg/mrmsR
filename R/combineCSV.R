#' Combine boundary extraction CSV files
#'
#' Reads all CSV files produced by the boundary extraction and combines them
#' into a single data frame sorted by datetime.
#' Timestamps with no time (e.g., midnight values written as a date only)
#' are read as 00:00:00 UTC. Older `m/d/y H:M:S` timestamps are also supported.
#'
#' @param csv_dir Character. Directory containing watershed CSV files.
#'
#' @return A combined data.frame sorted by datetime.
#' @export

combineCSV <- function(csv_dir) {

  # Check dir
  if (!dir.exists(csv_dir)) {
    stop("`csv_dir` does not exist.")
  }

  # Get csv list
  files <- list.files(csv_dir, pattern = "\\.csv$", full.names = TRUE)

  if (length(files) == 0) {
    stop("No CSV files found in `csv_dir`.")
  }

  # Read csv function
  read_csv_file <- function(file) {

    dt <- data.table::fread(
      file,
      na.strings = c("NA", "NaN", "N/A")
    )

    if ("datetime" %in% names(dt)) {

      if (is.character(dt$datetime)) {
        # Older m/d/y format; midnight values may have been written without a time
        no_time <- !grepl(":", dt$datetime)
        dt$datetime[no_time] <- paste0(dt$datetime[no_time], " 00:00:00")

        dt$datetime <- as.POSIXct(
          dt$datetime,
          format = "%m/%d/%y %H:%M:%S",
          tz = "UTC"
        )
      } else {
        # fread parses ISO datetimes as POSIXct and date-only values as IDate
        dt$datetime <- as.POSIXct(dt$datetime, tz = "UTC")
      }
    }

    dt
  }

  # Read
  result <- lapply(files, read_csv_file)

  # Combine
  final_data <- data.table::rbindlist(result, fill = TRUE)

  # Arrange to make sure in order
  if ("datetime" %in% names(final_data)) {
    datetime <- NULL
    final_data <- dplyr::arrange(final_data, datetime)
  }

  return(final_data)
}
