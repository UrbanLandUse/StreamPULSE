#' Retrieve data from the StreamPULSE database
#'
#' Uses StreamPULSE API to query data via MySQL. Visit the data portal at
#' \url{https://data.streampulse.org} to download data via a browser.
#'
#' Request data for a single region and site within the StreamPULSE database.
#' All sites are embargoed for 1 year or more from the time they first appear
#' in the database. Embargoed data are only available to the user who submits
#' them, and can be accessed via a unique token.
#'
#' @author Mike Vlah, \email{vlahm13@gmail.com}
#' @author Aaron Berdanier
#' @param sitecode underscore-separated region and site code, e.g. 'NC_Eno'.
#'   Full list of regions and site codes available at
#'   \url{https://data.streampulse.org/sitelist}.
#' @param startdate date string formatted 'YYYY-MM-DD', representing the first
#'   day of data to be
#'   requested. All available records for the specified day will be requested.
#'   If data coverage does not extend this far in time, the argument
#'   will be adjusted to the first day with available data. Omit this argument
#'   to include all records back to the first available. To see full available
#'   date range, select a site from the dropdown at
#'   \url{https://data.streampulse.org/visualize}. This will populate the date
#'   input field with the first and last available dates.
#' @param enddate date string formatted 'YYYY-MM-DD', representing the last day of
#'   data to be
#'   requested. All available records for the specified day will be requested.
#'   If data coverage does not extend this far in time, the argument
#'   will be adjusted to the last day with available data. Omit this argument to
#'   include all records up to the last available. To see full available
#'   date range, select a site from the dropdown at
#'   \url{https://data.streampulse.org/visualize}. This will populate the date
#'   input field with the first and last available dates.
#' @param variables character vector of variable names to request. To see which
#'   variables are available for a given site, select a site from the dropdown
#'   at \url{https://data.streampulse.org/visualize}. Omit this argument to
#'   request all variables potentially useful for metabolism modeling.
#' @param flags logical. If \code{TRUE}, information about data points flagged
#'   as interesting, questionable, or "bad data" will be included. If
#'   \code{FALSE}, data will still be included, but without accompanying flag
#'   information (There's no good reason to omit flag information, and this
#'   parameter will eventually be deprecated.).
#' @param token a unique alphanumeric string for each registered user of
#'   StreamPULSE. Only necessary for accessing embargoed data.
#' @return returns a \code{list} containing two \code{data.frame}s.
#'   The first contains all requested
#'   data. The second contains site metadata. Variable names and corresponding
#'   values are stacked in two long columns. Use \code{prep_metabolism} to
#'   format the output of this function.
#' @seealso \code{\link{prep_metabolism}} for organizing data returned by this
#'   function.
#' @export
#' @examples
#' streampulse_data = request_data(sitecode='NC_Eno',
#'     startdate='2016-06-10', enddate='2016-10-23')
request_data = function(sitecode, startdate=NULL, enddate=NULL, variables=NULL,
    flags=TRUE, token=NULL){
    # Download data from the streampulse platform

    # sitecode is a site name
    # startdate and enddate are YYYY-MM-DD strings, e.g., '1983-12-09'
    # variables is a vector of c('variable_one', ..., 'variable_n')
    # flags is logical, include flag data or not

    #basic checks
    if(length(sitecode)>1){
        stop("Please only enter one site to model.", call.=FALSE)
    }
    if(!is.null(startdate) & !is.null(enddate)){
        if(as.Date(enddate) < as.Date(startdate)){
            stop("Start date is after end date.", call.=FALSE)
        }
    }
    if(!all(is.null(variables)) & !all(is.character(variables))){
        stop('Argument to "variables" must be a character vector.', call.=FALSE)
    }
    if(all(is.null(variables))){
        variables = c('DO_mgL','DOsat_pct','satDO_mgL','WaterPres_kPa',
            'Depth_m','WaterTemp_C','Light_PAR','AirPres_kPa','Discharge_m3s')
        # 'Level_m', #level is currently not used, but could be soon
        cat(paste0('Requesting all variables potentially useful for ',
            'metabolism modeling.\n'))
    } else {
        variables = unique(variables) #just makin' sure
        message(paste0('You may omit the "variables" parameter to ',
            'automatically retrieve\n\tall variables necessary for metabolism ',
            'modeling.'))
    }

    #assemble url based on user input
    u = paste0("http://data.streampulse.org/api?sitecode=",sitecode)
    # u = paste0("localhost:5000/api?sitecode=",sitecode)
    if(!is.null(startdate)) u = paste0(u,"&startdate=",startdate)
    if(!is.null(enddate)) u = paste0(u,"&enddate=",enddate)
    u = paste0(u,"&variables=",paste0(variables, collapse=","))
    if(flags) u = paste0(u,"&flags=true")
    cat(paste0('\nAPI call: ',u,'\n\n'))

    #retrieve json; read into r object; format date
    if(is.null(token)){
        r = httr::GET(u)
    }else{
        r = httr::GET(u, httr::add_headers(Token = token))
    }
    json = httr::content(r, as="text", encoding="UTF-8")

    #check for errors
    d = try(jsonlite::fromJSON(json), silent=TRUE)
    if(class(d) == 'try-error'){
        stop(paste0('Unable to process request. Are you requesting an\n\t',
            'Unavailable date range? If not, notify Mike:\n\t',
            'vlahm13@gmail.com'), call.=FALSE)
    }

    if(length(d$data) == 1 && d$data == 'USGS_error'){
        stop(paste0('USGS servers are down. Try again later\n\t',
            'or omit Depth_m and Discharge_m3s from variables requested.'),
            call.=FALSE)
    }

    #d = RJSONIO::fromJSON(json) # supposed to take care of NaN
    d$data$DateTime_UTC = as.POSIXct(d$data$DateTime_UTC,tz="UTC")

    #rearrange columns if flag data present
    if(flags){
        notflagcols = colnames(d$data)[which(!colnames(d$data) %in%
                c('flagtype','flagcomment'))]
        d$data = cbind(d$data[,notflagcols], d$data[,c('flagtype','flagcomment')])

        #remove unneeded flag table returned by API
        d$flags = NULL
    }

    #format and print variables acquired
    retrieved_vars = unique(d$data$variable)
    n_print_batches = ceiling(length(retrieved_vars) / 5)
    cat('Retrieved the following variables:\n')
    for(b in 1:n_print_batches){

        s = (5 * (b - 1)) + 1 #first index to grab

        if(b == n_print_batches){
            e = length(retrieved_vars)
        } else {
            e = s + 4
        }

        cat('\t', paste0(retrieved_vars[s:e], collapse=', '), '\n')
    }

    #do the same for those not acquired (if necessary)
    missing_vars = variables[! variables %in% retrieved_vars]
    if(length(missing_vars)){

        n_print_batches = ceiling(length(missing_vars) / 5)
        cat('Could not find:\n')
        for(b in 1:n_print_batches){

            s = (5 * (b - 1)) + 1 #first index to grab

            if(b == n_print_batches){
                e = length(missing_vars)
            } else {
                e = s + 4
            }

            cat('\t', paste0(missing_vars[s:e], collapse=', '), '\n')
        }
    }

    return(d)
}