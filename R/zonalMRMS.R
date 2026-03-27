#' Extract zonal mean using boundary from MRMS rasters
#'
#' Computes zonal mean precipitation for each raster file over the boundary
#' and writes results as CSV files.
#'
#' @param raster_dir Directory containing processed `.tif` files.
#' @param output_dir Directory to write CSV outputs.
#' @param boundary Path to boundary SpatVector object.
#' @param n_workers Number of parallel workers.
#'
#' @return Invisibly returns NULL
#' @export

zonalMRMS <- function(raster_dir,
                      output_dir,
                      boundary,
                      n_workers) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)

  # Load boundary once
  b <- terra::vect(boundary)

  # Parallel plan
  future::plan(future::multisession, workers = n_workers)
  on.exit(future::plan(future::sequential), add = TRUE)

  furrr::future_walk(files, function(file) {

    r <- terra::rast(file)
    names(r) <- "p_mmhr"

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
      fun = mean,
      na.rm = TRUE,
      touches = TRUE
    )

    # Catchment ID (adjust if your field name differs)
    if ("site" %in% names(b_local)) {
      extract$catchment <- b_local$site
    } else {
      extract$catchment <- 1:nrow(extract)
    }

    # Datetime parsing from filename
    timestamp <- tools::file_path_sans_ext(basename(file))
    stamp <- stringr::str_extract(timestamp, "\\d{8}-\\d{6}")

    extract$datetime <- as.POSIXct(
      stamp,
      format = "%Y%m%d-%H%M%S",
      tz = "UTC"
    )

    extract$doy  <- lubridate::yday(extract$datetime)
    extract$hour <- lubridate::hour(extract$datetime)
    extract$min  <- lubridate::minute(extract$datetime)

    # Output file
    out_file <- file.path(
      output_dir,
      paste0("extract_", extract$doy[1], "_",
             sprintf("%02d", extract$hour[1]), "_",
             sprintf("%02d", extract$min[1]), ".csv")
    )

    utils::write.csv(extract, out_file, row.names = FALSE)

  })

  message("Zonal stats complete")
  invisible(NULL)
}
