
# mrmsR

Tools for processing NOAA MRMS (Multi-Radar Multi-Sensor) gridded precipitation data and generating watershed-scale rainfall statistics.

---

## Overview

`mrmsR` provides functions to:

- Read and process MRMS GRIB2 precipitation data
- Project and clip rasters to watershed boundaries
- Compute watershed-scale rainfall statistics using zonal methods
- Export processed raster and tabular outputs
- Combine multi-file outputs into a single time series dataset

The package is designed for high-volume hydroclimatic workflows and supports efficient batch and parallel processing.

---

### Important notes:
- This version is **not yet stable or production-ready**
- Function names, arguments, and outputs may change
- No guarantee of backward compatibility at this stage
- Documentation is still in development

### Planned improvements:
- Full documentation and vignette
- Add a reproducible example (test dataset)
- Performance optimization for large datasets
- Improved error handling and input validation
- Option to pull MRMS either by catchment (boundary) or point
- Option to summarize by max and other summary stats
- Review by others


### Installation (development only):
```r
devtools::install_github("searsmg/mrmsR")
