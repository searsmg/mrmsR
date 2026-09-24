#' Extract zonal statistics using boundary from MRMS rasters
#'
#' Computes a zonal statistic (the mean by default) of precipitation for each
#' raster file over each catchment in the boundary and writes results as CSV
#' files.
#'
#' @param raster_dir Directory containing processed `.tif` files.
#' @param output_dir Directory to write CSV outputs.
#' @param boundary Character. File path to the boundary (e.g., a shapefile).
#'   A path is required because `SpatVector` objects can't be sent to
#'   parallel workers; each worker reads the boundary itself.
#' @param n_workers Number of parallel workers.
#' @param id_col Character or `NULL`. Name of the boundary attribute used to
#'   label each catchment in the `catchment` column. If `NULL` (the default),
#'   uses `site` when the boundary has it, otherwise numbers the catchments
#'   `1, 2, ...` in boundary order.
#' @param fun Character. Summary statistic computed over the pixels in each
#'   catchment: `"mean"` (default), `"max"`, `"min"`, `"median"`, or `"sum"`.
#'   The result is written to the `p_mmhr` column whichever you choose.
#'
#' @return Invisibly returns NULL
#'
#' @details
#' One CSV is written per raster, named
#' `extract_<year>_<doy>_<hour>_<min>.csv` from the timestamp in the raster
#' file name.
#'
#' Pixels touching a catchment boundary are included (`touches = TRUE`), and
#' `NA` pixels are ignored.
#' @export

zonalMRMS <- function(raster_dir,
                      output_dir,
                      boundary,
                      n_workers,
                      id_col = NULL,
                      fun = c("mean", "max", "min", "median", "sum")) {

  fun <- match.arg(fun)

  # Input check
  if (!is.character(boundary)) {
    stop("boundary must be a file path when using parallel processing")
  }

  # Check the ID column up front rather than inside each worker
  boundary_cols <- names(terra::vect(boundary, what = "attributes"))

  if (is.null(id_col)) {
    if ("site" %in% boundary_cols) id_col <- "site"
  } else if (!id_col %in% boundary_cols) {
    stop(sprintf("`id_col` \"%s\" is not a column in the boundary.", id_col))
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)

  # Parallel plan, restoring the caller's plan on exit
  old_plan <- future::plan(future::multisession, workers = n_workers)
  on.exit(future::plan(old_plan), add = TRUE)

  furrr::future_walk(files, function(file, boundary_path, id_col, fun) {

    r <- terra::rast(file)
    names(r) <- "p_mmhr"

    # Read boundary in each worker; SpatVectors can't be serialized
    b <- terra::vect(boundary_path)

    # CRS handling
    b_local <- if (!terra::same.crs(r, b)) {
      terra::project(b, terra::crs(r))
    } else {
      b
    }

    # Zonal / polygon extraction
    extract <- terra::extract(
      r,
      b_local,
      fun = match.fun(fun),
      na.rm = TRUE,
      touches = TRUE
    )

    # Catchment ID
    if (!is.null(id_col)) {
      extract$catchment <- b_local[[id_col]][[1]]
    } else {
      extract$catchment <- seq_len(nrow(extract))
    }

    # Datetime parsing from filename
    timestamp <- tools::file_path_sans_ext(basename(file))
    stamp <- stringr::str_extract(timestamp, "\\d{8}-\\d{6}")

    extract$datetime <- as.POSIXct(
      stamp,
      format = "%Y%m%d-%H%M%S",
      tz = "UTC"
    )

    extract$year <- lubridate::year(extract$datetime)
    extract$doy  <- lubridate::yday(extract$datetime)
    extract$hour <- lubridate::hour(extract$datetime)
    extract$min  <- lubridate::minute(extract$datetime)

    # Output file
    out_file <- file.path(
      output_dir,
      paste0("extract_", extract$year[1], "_", extract$doy[1], "_",
             sprintf("%02d", extract$hour[1]), "_",
             sprintf("%02d", extract$min[1]), ".csv")
    )

    # Write the full timestamp; write.csv drops the time at midnight otherwise
    extract$datetime <- format(extract$datetime, "%Y-%m-%d %H:%M:%S")

    utils::write.csv(extract, out_file, row.names = FALSE)

  }, boundary_path = boundary, id_col = id_col, fun = fun, .options = furrr::furrr_options(seed = TRUE))

  message("Zonal stats complete")
  invisible(NULL)
}
