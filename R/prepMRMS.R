#' Project and clip MRMS GRIB2 files using terra and furrr
#'
#' Reads MRMS GRIB2 files, assigns a coordinate reference system (CRS),
#' crops them to a specified boundary, and writes the results as tif files.
#' Processing is performed in parallel using furrr.
#'
#' @param dir Character. Directory containing MRMS `.grib2` files.
#' @param output_dir Character. Directory where processed `.tif` files will be saved.
#' @param num_cores Integer. Number of cores to use for parallel processing.
#' @param boundary `SpatVector` object defining the spatial extent to crop to.
#'
#' @return Invisibly returns `NULL`. Writes processed raster files to `output_dir`.
#'
#' @details
#' Uses the `terra` package for raster processing and `furrr` for parallel execution.
#' The CRS is WGS84 (EPSG:4326).
#'
#' @examples
#' \dontrun{
#' prepMRMS(
#'   dir = "path/to/grib2_files",
#'   output_dir = "path/to/output",
#'   num_cores = 4,
#'   boundary = spatvector boundary
#' )
#' }
#'
#' @export
#'
prepMRMS <- function(dir,
                     output_dir,
                     num_cores,
                     boundary) {

# Directory check
  if (!dir.exists(dir)) {
    stop("`dir` does not exist.")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(dir, pattern = "\\.grib2$", full.names = TRUE)

  if (length(files) == 0) {
    stop("No .grib2 files found in `dir`.")
  }

# Make spatvector for terra
  if (!inherits(boundary, "SpatVector")) {
    boundary <- terra::vect(boundary)
  }

# Function to process grib2 files
  process_file <- function(file) {

    r <- terra::rast(file)

    # assign CRS if missing
    if (is.na(terra::crs(r))) {
      terra::crs(r) <- "EPSG:4326"
    }

    # Make boundary and raster have same crs
    if (!terra::same.crs(r, boundary)) {
      boundary_local <- terra::project(boundary, terra::crs(r))
    } else {
      boundary_local <- boundary
    }

    # crop + mask
    r <- terra::crop(r, boundary)
    r <- terra::mask(r, boundary)

    # output name
    new_file_name <- paste0(
      tools::file_path_sans_ext(basename(file)),
      "_processed.tif")

    new_file_path <- file.path(output_dir, new_file_name)

    terra::writeRaster(r, new_file_path, overwrite = TRUE)

    return(NULL)
  }

# Set up parallel
  future::plan(future::multisession, workers = num_cores)
  on.exit(future::plan(future::sequential), add = TRUE)

# Run in parallel
  furrr::future_walk(
    files,
    ~ tryCatch(
      process_file(.x),
      error = function(e) {
        message(sprintf("Error processing file: %s", .x))
        message(e$message)
      }
    )
  )

  message("Processing complete!")

  invisible(NULL)
}
