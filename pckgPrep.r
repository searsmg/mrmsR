library(devtools)

# use_r('pullMRMS')
# then paste the code into the R script that was created

load_all()

exists("pullMRMS", where = globalenv(), inherits = FALSE)

# check the function
check()

use_mit_license()

# use this anytime a function is updated
document()

# install the package and use it like any other package
#install()

use_package('lubridate')

# rename files if we want ot rename the R functions
# rename_files("strsplit1", "str_split_one")
