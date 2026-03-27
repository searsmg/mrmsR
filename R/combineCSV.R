#' Combine boundary extraction CSV files
#'
#' Reads all CSV files produced by the boundary extraction and combines them
#' into a single data frame sorted by datetime.
#' Special case: files ending with "0_0.csv" will have "00:00:00" added to datetime if missing.
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

      # Special case: filename ends with "0_0.csv" and datetime has no time
      if (grepl("0_0\\.csv$", file)) {
        # Check if datetime parsing fails (likely only dates)
        test <- try(as.POSIXct(dt$datetime, format = "%m/%d/%y %H:%M:%S"), silent = TRUE)
        if (inherits(test, "try-error") || all(is.na(test))) {
          dt$datetime <- paste0(dt$datetime, " 00:00:00")
        }
      }

      dt$datetime <- as.POSIXct(
        dt$datetime,
        format = "%m/%d/%y %H:%M:%S",
        tz = "UTC"
      )
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
