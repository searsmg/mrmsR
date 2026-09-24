#' Accumulate MRMS precipitation into totals
#'
#' Converts per-timestep MRMS values into precipitation depths and sums them
#' for each catchment by hour, day, or over the whole record.
#'
#' @param data Data frame of per-timestep values, typically from
#'   [combineCSV()]. Must have `catchment`, `datetime` (POSIXct), and the
#'   column named by `value_col`.
#' @param product Character. The MRMS product the values came from; sets how
#'   each value is converted to a depth:
#'   \itemize{
#'     \item \code{"SurfacePrecipRate"}: a rate in mm/hr every 2 minutes, so
#'       each value contributes `rate * 2 / 60` mm
#'     \item \code{"RadarOnlyQPE"}, \code{"MultiSensorQPE"}: already a depth
#'       in mm for the hour, used as is
#'   }
#' @param by Character. Period to total over: `"hour"`, `"day"` (default), or
#'   `"total"` for the whole record.
#' @param tz Character. Time zone that defines hour and day boundaries
#'   (default `"UTC"`). For example, use `"America/Denver"` for local days.
#' @param value_col Character. Name of the column holding the MRMS values
#'   (default `"p_mmhr"`, the column [zonalMRMS()] writes).
#'
#' @return A data frame with one row per catchment and period:
#'   \describe{
#'     \item{catchment}{Catchment ID.}
#'     \item{period_start}{Start of the period in `tz`; for `by = "total"`,
#'       the start of the first timestep.}
#'     \item{depth_mm}{Total precipitation depth in mm.}
#'     \item{n_steps}{Number of non-missing timesteps included.}
#'     \item{expected_steps}{Number of timesteps a complete period has
#'       (`NA` for `by = "total"`). Fewer `n_steps` means missing data, so
#'       `depth_mm` may be an underestimate.}
#'   }
#'
#' @details
#' Each MRMS timestamp marks the end of the interval it covers. For example,
#' the hourly QPE file stamped 01:00 covers 00:00 to 01:00, and the one
#' stamped 00:00 is counted in the previous day. Values are assigned to
#' periods accordingly.
#'
#' Missing (`NA`) values are skipped and not counted in `n_steps`.
#'
#' @examples
#' \dontrun{
#' combined <- combineCSV("path/to/csv_dir")
#' daily <- accumulateMRMS(combined, product = "RadarOnlyQPE", by = "day")
#' }
#'
#' @export

accumulateMRMS <- function(data,
                           product,
                           by = c("day", "hour", "total"),
                           tz = "UTC",
                           value_col = "p_mmhr") {

  # Timestep length (minutes) and whether values are rates (mm/hr) or depths (mm)
  products <- list(
    "SurfacePrecipRate" = list(step_min = 2, is_rate = TRUE),
    "RadarOnlyQPE" = list(step_min = 60, is_rate = FALSE),
    "MultiSensorQPE" = list(step_min = 60, is_rate = FALSE)
  )

  if (product %in% c("RQI", "SHSRHeight")) {
    stop(sprintf("`product` \"%s\" isn't precipitation and can't be accumulated.", product))
  }
  product <- match.arg(product, names(products))
  by <- match.arg(by)

  # Input checks
  needed <- c("catchment", "datetime", value_col)
  missing_cols <- setdiff(needed, names(data))
  if (length(missing_cols) > 0) {
    stop(sprintf("`data` is missing column(s): %s", paste(missing_cols, collapse = ", ")))
  }
  if (!inherits(data$datetime, "POSIXct")) {
    stop("`data$datetime` must be POSIXct (e.g., from combineCSV()).")
  }

  step_min <- products[[product]]$step_min

  df <- data.frame(
    catchment = data$catchment,
    datetime = lubridate::with_tz(data$datetime, tz),
    value = data[[value_col]]
  )
  df <- df[!is.na(df$value), , drop = FALSE]

  # Convert each value to a depth in mm
  df$depth_mm <- if (products[[product]]$is_rate) {
    df$value * step_min / 60
  } else {
    df$value
  }

  # Timestamps mark the end of each interval; assign by the interval's start
  df$step_start <- df$datetime - lubridate::minutes(step_min)
  df$n_steps <- 1

  if (by == "total") {
    out <- stats::aggregate(cbind(depth_mm, n_steps) ~ catchment, data = df, FUN = sum)
    first_start <- stats::aggregate(step_start ~ catchment, data = df, FUN = min)
    out$period_start <- lubridate::with_tz(first_start$step_start[match(out$catchment, first_start$catchment)], tz)
    out$expected_steps <- NA_integer_
  } else {
    df$period_start <- lubridate::floor_date(df$step_start, unit = by)
    out <- stats::aggregate(
      cbind(depth_mm, n_steps) ~ catchment + period_start,
      data = df,
      FUN = sum
    )
    out$period_start <- lubridate::with_tz(out$period_start, tz)

    # Actual period length, so days with a daylight saving change are right
    period_end <- out$period_start + lubridate::period(1, units = by)
    period_min <- as.numeric(difftime(period_end, out$period_start, units = "mins"))
    out$expected_steps <- as.integer(round(period_min / step_min))
  }

  out$n_steps <- as.integer(out$n_steps)
  out <- out[order(out$catchment, out$period_start), c("catchment", "period_start", "depth_mm", "n_steps", "expected_steps")]
  rownames(out) <- NULL

  out
}
