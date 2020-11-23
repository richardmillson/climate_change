# load packages, install if necessary
lib.loc = file.path(getwd(), 'lib')
if (!require('shiny', lib.loc = lib.loc)) {
    install.packages('shiny', lib = lib.loc)
}
library(shiny, lib.loc = lib.loc)
if (!require('leaflet', lib.loc = lib.loc)) {
    install.packages('leaflet', lib = lib.loc)
}
library(leaflet, lib.loc = lib.loc)
if (!require('readxl', lib.loc = lib.loc)) {
    install.packages('readxl', lib = lib.loc)
}
library(readxl, lib.loc = lib.loc)
if (!require('dplyr', lib.loc = lib.loc)) {
    install.packages('dplyr', lib = lib.loc)
}
library(dplyr, lib.loc = lib.loc)
if (!require('readr', lib.loc = lib.loc)) {
    install.packages('readr', lib = lib.loc)
}
library(readr, lib.loc = lib.loc)



# download and clean the data
data.loc = file.path(getwd(), 'data')

if (!file.exists(file.path(data.loc, 'stations.csv'))) {
    stations_url = 'ftp://ccrp.tor.ec.gc.ca/pub/AHCCD/Temperature_Stations.xls'
    stations_file = file.path(tempdir(), basename(stations_url))
    download.file(url = stations_url, destfile = stations_file)
    stations = read_excel(stations_file, skip = 2)
    # delete the row containing French column names
    stations = stations[-1, ]
    # TODO: clean station names
    # some stations are suffixed with a normal code indicating properties of the station
    # https://climate.weather.gc.ca/doc/Canadian_Climate_Normals_1981_2010_Calculation_Information.pdf#[{"num":25,"gen":0},{"name":"XYZ"},69,664,0]
    stations = select(stations, 'StnId', 'Station name', 'Prov', 'Lat(deg)', 'Long(deg)', 'Elev(m)')
    stations = rename(stations, id = 'StnId', city = 'Station name', province = 'Prov', lat = 'Lat(deg)', lng = 'Long(deg)', elevation = 'Elev(m)')
    write.csv(stations, file = file.path(data.loc, 'stations.csv'))
} else {
    stations = read_csv(file.path(data.loc, 'stations.csv'))
}

download_climate_data = function(download_url) {
    zip_file = file.path(tempdir(), basename(download_url))
    download.file(url = download_url, destfile = zip_file)
    unzip_dir = tools::file_path_sans_ext(zip_file)
    unzip(zip_file, exdir = unzip_dir)
    
    df = NULL
    # specify col_names to avoid warnings for unexpected final column and 
    # missing column names filled in
    col_names = c('Year', 'Jan', 'X3', 'Feb', 'X5', 'Mar', 'X7', 'Apr', 'X9', 'May', 'X11', 'Jun', 'X13', 'Jul', 'X15', 'Aug', 'X17', 'Sep', 'X19', 'Oct', 'X21', 'Nov', 'X23', 'Dec', 'X25', 'Annual', 'X27', 'Winter', 'X29', 'Spring', 'X31', 'Summer', 'X33', 'Autumn', 'X35')
    # specify col_types to avoid messages about column specification
    
    for (file_name in list.files(unzip_dir)) {
        data = read_csv(file.path(unzip_dir, file_name), skip = 4, col_names = col_names, col_types = cols())
        data = select(data, Year, Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec, Annual, Winter, Spring, Summer, Autumn)
        # replace the placeholder for missing values
        data[data == -9999.9] = NA
        
        metadata = read_csv(file.path(unzip_dir, file_name), n_max = 1, col_types = cols())
        data['id'] = as.character(metadata[1])
        data['city'] = as.character(metadata[2])
        data['province'] = as.character(metadata[3])
        
        df = bind_rows(df, data)
    }
    return(df)
}

vars = c('max_temperature', 'mean_temperature', 'min_temperature')
data_files = c('max_temperature.csv', 'mean_temperature.csv', 'min_temperature.csv')
urls = c('ftp://ccrp.tor.ec.gc.ca/pub/AHCCD/Homog_monthly_max_temp.zip',
         'ftp://ccrp.tor.ec.gc.ca/pub/AHCCD/Homog_monthly_mean_temp.zip',
         'ftp://ccrp.tor.ec.gc.ca/pub/AHCCD/Homog_monthly_min_temp.zip')

for (i in seq(length(data_files))) {
    if (!file.exists(file.path(data.loc, data_files[i]))) {
        df = download_climate_data(urls[i])
        write.csv(df, file = file.path(data.loc, data_files[i]))
    } else {
        df = read_csv(file.path(data.loc, data_files[i]))
    }
    assign(vars[i], df)
}
