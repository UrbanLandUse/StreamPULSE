#' Prepare StreamPULSE data for metabolism modeling
#'
#' Formats the output of \code{\link{request_data}} for stream metabolism model
#' of choice. Filters flagged data and imputes missing data. Acquires/estimates
#' additional variables if necessary. NOTE: support for modeling with
#' \code{BASE} is currently in development. Please use \code{streamMetabolizer}
#' in the meantime.
#'
#' \code{BASE} and \code{streamMetabolizer}, the two metabolism modeling
#' platforms available via StreamPULSE, require different data input formats.
#' Formatting also varies depending on whether one is using a Bayesian framework
#' or MLE. This function supplements and rearranges the raw output of
#' \code{\link{request_data}} to prepare it for a desired set of model
#' specifications.
#'
#' Both \code{BASE} and \code{streamMetabolizer} require dissolved oxygen (DO)
#' concentration, water temperature, and light (PAR) data. If light is missing,
#' it will automatically be estimated based on solar angle. In addition to these
#' variables,
#' \code{streamMetabolizer} requires DO \% saturation and depth, and
#' \code{BASE} requires atmospheric pressure. If DO \% saturation is missing,
#' it will be calculated automatically from DO concentration, water temperature,
#' and atmospheric pressure. In turn, atmospheric pressure estimates will
#' be automatically retrieved from NOAA (NCDC), if missing,
#' for sites anywhere on earth.
#'
#' If \code{streamMetabolizer} is being used and
#' \code{type='bayes'}, discharge time series data are also required.
#' In the absence of such data, they can be estimated from the relationship
#' between discharge and depth (i.e. the vertical distance between streambed and
#' surface) or
#' level (AKA stage; i.e. the vertical distance between some arbitrary datum,
#' such as sensor
#' height, and surface), via the \code{zq_curve} parameter.
#' Here, depth or level is referred to as Z, discharge
#' is reffered to as Q, and the relationship between them is called a rating
#' curve. In order to fit such a curve, one must collect, sometimes
#' manually, a set of data points for both Z and Q. Here we assume the user
#' also has time series data for Z, which can then be used to predict a series
#' of Q at each time point. If the sampled Z data used to fit the curve
#' represent level, and the Z time series data represent depth, the
#' \code{sensor_height} parameter can be used to make them commensurable.
#'
#' If Z is supplied, Q must be supplied, and vice-versa. Likewise with a and b.
#' If all are supplied, Z and Q will be ignored. Rating curves can take many
#' forms. Options here include power, exponential, and linear. A common
#' difficulty of
#' fitting these curves is that it's hard to accurately measure discharge in
#' high flow conditions, yet without accounting for these conditions
#' in the curve,
#' high flow discharge estimates can be far off from reality, especially if
#' the curve's form is power or exponential. In these cases, it's often safest
#' to omit high flow data points from the curve entirely by setting
#' \code{ignore_oob_Z=TRUE}. In some cases it makes sense to model the curve
#' with a linear fit, though of course this too will misrepresent reality.
#' Using \code{fit='linear'} may also result in negative discharge estimates.
#'
#' All single-station models assume that, where applicable, variables
#' represent averages
#' throughout an area delineated by the width of the stream and the approximate
#' oxygen turnover distance. More on this and other considerations can be
#' found by clicking the "Before modeling stream metabolism..." button on
#' \url{https://data.streampulse.org}.
#'
#' The between-sample interval is determined programmatically
#' for each variable within \code{d}. It is assumed to be the mode
#' if the between-sample interval varies within a series. If the
#' between-sample interval varies across series, the longest interval is
#' used for the whole dataset, unless \code{interval} is specified.
#' If the user-specified interval is a multiple of the programmatically
#' determined longest interval, the dataset will be quietly coerced to the
#' user-specified interval.
#' This is useful for thinning extremely long datasets in order to
#' avoid out-of-memory errors while running models. If intervals vary across
#' series, the user may specify which of the available intervals to coerce
#' all series to. If user-specified and
#' programmatically-determined intervals are identical, no action is taken.
#'
#' @author Mike Vlah, \email{vlahm13@gmail.com}
#' @author Aaron Berdanier
#' @param d the output of \code{request_data},
#'   or a \code{list} of \code{data.frame}s so organized.
#' @param model either 'streamMetabolizer' (the default) or 'BASE'. If 'BASE',
#'   \code{type} must be set to \code{'bayes'}.
#' @param type either 'mle' or 'bayes'. If \code{model='BASE'}, \code{type}
#'   must be set to \code{'bayes'}.
#' @param interval a string specifying the between-sample time interval to
#'   which the dataset should be coerced, or NA to determine automatically.
#'   If not NA, Must be
#'   of the form '<number> <unit>', as in '15 min'. Unit can be
#'   'min' or 'hour'. Non-integer hours are tolerated, but minutes must be
#'   specified as integers. See details.
#' @param rm_flagged a list containing any of 'Interesting', 'Questionable',
#'   and 'Bad Data'. Any data points flagged with these specified tags will be
#'   removed (replaced with NA), and then imputed according to \code{fillgaps}.
#'   If data for a selected site and timespan have been cleaned using
#'   \url{https://data.streampulse.org/clean}, it is a good idea to remove any
#'   data points flagged as "Questionable" or "Bad Data". Set this argument to
#'   'none' to keep all flagged data points. Defaults to
#'   \code{list('Questionable', 'Bad Data')}.
#' @param fillgaps a string specifying one of the imputation methods available
#'   to \code{imputeTS::na.seasplit}, namely: 'interpolation', 'locf', 'mean',
#'   'random', 'kalman', or 'ma'. May also be 'none'. The
#'   imputation method, if specified, will be attempted after seasonal decomposition.
#'   Periodicity depends on the between-sample interval, and is determined
#'   programmatically (see details for \code{interval}). If the desired
#'   imputation method
#'   fails, which sometimes occurs when series consist largely of NAs, basic
#'   linear interpolation will be performed instead and the user will be
#'   notified. See \code{maxhours}.
#' @param maxhours the maximum number of hours of consecutive NAs to impute.
#' @param zq_curve a list containing specifications for a rating curve, used
#'   to estimate discharge from level or depth. Elements of this list may
#'   include any of the following: Z (a vector of level or depth data), Q (a
#'   vector of discharge data), a (the first parameter of an existing rating
#'   curve), b (the second parameter of an existing rating curve),
#'   sensor_height (the vertical distance between streambed and sensor,
#'   in meters), fit
#'   (the form of the rating curve to predict discharge from and, if Z and Q
#'   supplied, to fit), ignore_oob_Z (if there are depth or level readings that
#'   exceed the maximum measured Z value of the rating curve, whether to
#'   replace these with NA), and plot (whether to plot the fitted curve, if
#'   applicable, as well as predicted discharge). See details for more.
#' @param estimate_areal_depth logical;
#'   Metabolism models expect that input depth time series represent depth
#'   averaged
#'   over an area delineated by the width of the stream and the approximate O2
#'   turnover distance. Set to TRUE if you'd like to estimate this
#'   average depth, or FALSE if your depth data already approximate it. For
#'   example, if your depth data represent average depth over the aforementioned
#'   area already, or average depth for a stream cross-section, you'd probably
#'   want
#'   to use FALSE. If your depth data represent only depth-at-sensor, or worse,
#'   level-at-sensor, you might be
#'   better off with TRUE, assuming you have discharge data to estimate areal
#'   depth
#'   from, or a rating curve by which to generate discharge data.
#' @param estimate_PAR logical; should Photosynthetically Active Radiation (PAR)
#'   be estimated from geographic coordinates and time? Only use light data if
#'   you're confident that your light sensors accurately represent light reaching
#'   the upstream area defined by O2 turnover distance.
#' @param retrieve_air_pres logical; if some AirPres_kPa values are missing, should
#'   they be retrieved from NCDC (NOAA)? Retrieval will happen automatically if air
#'   pressure data are required and entirely missing.
#' @param ... additional arguments passed to \code{imputeTS::na.seasplit}.
#' @return returns an S4 object containing a \code{data.frame} formatted for
#'   the model specified by \code{model} and \code{type}.
#' @seealso \code{\link{request_data}} for acquiring StreamPULSE data;
#'   \code{\link{fit_metabolism}} for fitting models.
#' @export
#' @examples
#' query_available_data(region='all')
#'
#' streampulse_data = request_data(sitecode='NC_Eno',
#'     startdate='2016-06-10', enddate='2016-10-23')
#'
#' fitdata = prep_metabolism(d=streampulse_data, type='bayes',
#'     model='streamMetabolizer', interval='15 min',
#'     rm_flagged=list('Bad Data', 'Questionable'), fillgaps=fillgaps,
#'     zq_curve=list(sensor_height=NULL, Z=Z_data, Q=Q_data,
#'     fit='power', plot=TRUE), estimate_areal_depth=TRUE)
prep_metabolism = function(d, model="streamMetabolizer", type="bayes",
    interval=NA, rm_flagged=list('Bad Data', 'Questionable'),
    fillgaps='interpolation', maxhours=3,
    zq_curve=list(sensor_height=NULL, Z=NULL, Q=NULL, a=NULL, b=NULL,
        fit='power', ignore_oob_Z=TRUE, plot=TRUE),
    estimate_areal_depth=FALSE, estimate_PAR=TRUE, retrieve_air_pres=FALSE, ...){
    # zq_curve=list(Z=NULL, Q=NULL, a=NULL, b=NULL), ...){

    # type is one of "bayes" or "mle"
    # model is one of "streamMetabolizer" or "BASE"
    # interval is the desired gap between successive observations. should be a
    # multiple of your sampling interval.
    # rm_flagged is a list containing some combination of 'Bad Data',
    # 'Questionable', or 'Interesting'. Values corresponding to flags of
    # the specified type(s) will be replaced with NA, then interpolated
    # if fillgaps is not 'none'. rm_flagged can also be set to 'none' to
    # retain all flag information.
    # fillgaps must be one of the imputation methods available to
    # imputeTS::na.seasplit or 'none'
    # ... passes additional arguments to na.seasplit
    # get_windspeed and get_airpressure query NOAA's ESRL-PSD.
    # units are m/s and pascals, respectively

    # checks
    if(model=="BASE"){
        stop('BASE not yet supported', call.=FALSE) ###
        type="bayes" #can't use mle mode with BASE
    }
    if(! is.na(interval) &&
            ! grepl('\\d+ (min|hour)', interval, perl=TRUE)){
        stop(paste('Interval (if not NA) must be of the form "length [space] unit"\n\twhere',
            'length is numeric and unit is either "min" or "hour".'), call.=FALSE)
    }
    if(!fillgaps %in% c('interpolation','locf','mean','random','kalman','ma',
        'none')){
        stop(paste0("fillgaps must be one of 'interpolation', 'locf', 'mean',",
            "\n\t'random', 'kalman', 'ma', or 'none'"), call.=FALSE)
    }
    if(any(! rm_flagged %in% list('Bad Data','Questionable','Interesting')) &
            any(rm_flagged != 'none')){
        stop(paste0("rm_flagged must either be 'none' or a list containing any",
            " of:\n\t'Bad Data', 'Questionable', 'Interesting'."), call.=FALSE)
    }
    if(any(rm_flagged != 'none') & ! 'flagtype' %in% colnames(d$data)){
        stop(paste0('No flag data available.\n\t',
            'Please visit https://data.streampulse.org/qaqc_sensordata\n\t',
            'to supply flag (QA/QC) information.'), call.=FALSE)
    }
    if(! 'list' %in% class(zq_curve)){
        stop('Argument "zq_curve" must be a list.', call.=FALSE)
    }
    if(type == 'mle'){
        stop('MLE mode is not currently available. Please use type="bayes".',
            call.=FALSE)
    }

    ab_supplied = zq_supplied = FALSE
    using_zq_curve = !all(unlist(lapply(zq_curve[c('sensor_height',
        'a','b','Z','Q')], is.null)))
    if(using_zq_curve){

        #unpack arguments supplied to zq_curve
        sensor_height = Z = Q = a = b = fit = ignore_oob_Z = zqplot = NULL
        if(!is.null(zq_curve$sensor_height)){
            sensor_height = zq_curve$sensor_height
        }
        if(!is.null(zq_curve$Z)) Z = zq_curve$Z
        if(!is.null(zq_curve$Q)) Q = zq_curve$Q
        if(!is.null(zq_curve$a)) a = zq_curve$a
        if(!is.null(zq_curve$b)) b = zq_curve$b
        if(!is.null(zq_curve$fit)){
            fit = zq_curve$fit
            if(! fit %in% c('power', 'exponential', 'linear')){
                stop(paste0('Argument to "fit" must be one of: "power", ',
                    '"exponential", "linear".'), call.=FALSE)
            }
        }
        if(!is.null(zq_curve$ignore_oob_Z)) ignore_oob_Z = zq_curve$ignore_oob_Z
        if(!is.null(zq_curve$plot)) zqplot = zq_curve$plot

        # message(paste0('NOTE: You have specified arguments to zq_curve.\n\t',
        #     'These are only needed if time-series data for discharge cannot',
        #     '\n\tbe found.'))
        if(is.numeric(a) & is.numeric(b)){
            ab_supplied = TRUE
        }
        if(length(Z) > 1 & length(Q) > 1){
            zq_supplied = TRUE
        }
        if(ab_supplied & zq_supplied){
            warning(paste0('Parameters (a, b) and data (Z, Q) supplied for ',
                'rating curve.\n\tOnly one set needed, so ignoring data.'),
                call.=FALSE)
            zq_supplied = FALSE
        } else {
            if(!ab_supplied & !zq_supplied){
                stop(paste0('Argument zq_curve must include either Z and Q as ',
                    'vectors of data\n\tor a and b as parameters of a rating ',
                    'curve.'), call.=FALSE)
            }
        }
    }

    # d2 <<- d
    # stop('a')
    # d = d2

    #### Format data for models
    cat(paste("Formatting data for ", model, ".\n", sep=""))
    dd = d$data

    #check for consistent sample interval (including cases where there are gaps
    #between samples and where the underying sample pattern changes)
    varz = unique(dd$variable)
    ints_by_var = data.frame(var=varz, int=rep(NA, length(varz)))
    for(i in 1:length(varz)){

        #get lengths and values for successive repetitions of the same
        #sample interval (using run length encoding)
        dt_by_var = sort(unique(dd$DateTime_UTC[dd$variable == varz[i]]))

        run_lengths = rle(diff(as.numeric(dt_by_var)))
        if(length(run_lengths$lengths) != 1){

            # if gaps or interval change, get mode interval
            uniqv = unique(run_lengths$values)
            input_int = as.numeric(names(which.max(tapply(run_lengths$lengths,
                run_lengths$values, sum)))) / 60

            if(any(uniqv %% min(uniqv) != 0)){ #if underlying pattern changes
                warning(paste0('Sample interval is not consistent for ', varz[i],
                    '\n\tGaps will be introduced!\n\t',
                    'Using the most common interval: ',
                    as.character(input_int), ' mins.'), call.=FALSE)
            } else {
                message(paste0(length(run_lengths$lengths)-1,
                    ' sample gap(s) detected in ', varz[i], '.'))
            }

            #store the (most common) sample interval for each variable
            ints_by_var[i,2] = as.difftime(input_int, unit='mins')

        } else {

            # if consistent, just grab the diff between the first two times
            ints_by_var[i,2] = difftime(dt_by_var[2],  dt_by_var[1],
                units='mins')
        }
    }

    #will later coerce all vars to the longest sample interval
    #unless `interval` is specified
    if(length(unique(ints_by_var$int)) > 1){
        input_int = max(ints_by_var$int)
        if(! is.na(interval)){
            message(paste0('Multiple sample intervals detected across variables (',
                paste(unique(ints_by_var$int), collapse=' min, '),
                ' min).\n\tWill attempt to coerce all variables to desired ',
                'interval: ', interval, '.'))
        } else {
            interval = paste(input_int, 'min')
            message(paste0('Multiple sample intervals detected across variables (',
                paste(unique(ints_by_var$int), collapse=' min, '),
                ' min).\n\tUsing ', input_int, ' so as not to introduce gaps.\n\t',
                'You may control this behavior with the "interval" parameter.'))
        }
    } else {
        input_int = ints_by_var$int[1] #all intervals equal
        interval = paste(input_int, 'min')
    }

    #remove (replace with NA) flagged data if desired
    if(any(rm_flagged != 'none')){
        flags_to_remove = unique(unlist(rm_flagged))
        dd$value[dd$flagtype %in% flags_to_remove] = NA
    }
    if('flagtype' %in% colnames(dd)){
        dd = subset(dd, select=-c(flagtype, flagcomment))
    }

    # Use USGS level and discharge if missing local versions
    #level currenty not used, but could be used in the absence of discharge and depth
    if("USGSLevel_m" %in% dd$variable && !"Level_m" %in% dd$variable){
        dd$variable[dd$variable=="USGSLevel_m"] = "Level_m"
    }
    if("USGSDischarge_m3s" %in% dd$variable && !"Discharge_m3s" %in% dd$variable){
        dd$variable[dd$variable=="USGSDischarge_m3s"] = "Discharge_m3s"
    }


    # dd2 <<- dd; d2 <<- d
    # stop('a')
    # dd = dd2; d = d2

    vd = unique(dd$variable) # variables
    dd = tidyr::spread(dd, variable, value) # spread out data
    md = d$sites # metadata

    #deal with "level"/"depth" naming issue. These measure the same thing.
    #UPDATE: level=stage=gage_height=vertical distance from sensor to surface
    #depth = vertical distance from bed to surface.
    #can be depth-at-gage OR averaged across width OR
    #averaged across area defined by width and O2 turnover distance.
    #this last metric is what the model actually needs
    #the code below may be party useful depending on what "depth" means for a given site
    using_level = 'Level_m' %in% vd && ! 'Depth_m' %in% vd &&
        !('Discharge_m3s' %in% vd && estimate_areal_depth)
    if(using_level){
        dd$Depth_m = dd$Level_m
        vd = c(vd, 'Depth_m')
        warning(paste0('Using supplied level data in place of missing depth data.',
            '\n\tDepth would be more accurate!'), call.=FALSE)
    }
    # if('Level_m' %in% vd & 'Depth_m' %in% vd){ #use col with more data if both
    #     na_cnt = sapply(dd[,c('Level_m','Depth_m')], function(x) sum(is.na(x)))
    #     level_or_depth = names(which.min(na_cnt))
    #     dd$Depth_m = dd[,level_or_depth]
    #     warning(paste0('Both level and depth data found. These measure the ',
    #         'same thing.\n\tUsing ', level_or_depth,
    #         ' because it has better coverage.'), call.=FALSE)
    # }

    #another test, now that depth has been acquired if available
    #UPDATE: turns out rating curves can directly relate level and discharge,
    #so depth is not needed at this point (though areal depth is needed, ultimately)
    #and sensor height is not needed as a result. This would only be useful
    #for correcting level to depth, which would be no better for buiding a rating curve
    missing_depth = ! 'Depth_m' %in% vd
    # missing_sens_height = !is.numeric(zq_curve$sensor_height)
    # if(using_zq_curve & missing_depth & missing_sens_height){
    # if(using_zq_curve & missing_depth){
    #     stop(paste0('Need either sensor_height or depth (level) time-series',
    #         ' data\n\tto compute discharge via rating curve.'),
    #         call.=FALSE)
    # }

    # check if desired interval is compatible with sample interval
    int_parts = strsplit(interval, ' ')[[1]] #get num and str components
    desired_int = as.difftime(as.numeric(int_parts[1]),
        units=paste0(int_parts[2], 's')) #get desired interval as difftime
    desired_int_num = as.double(desired_int, units='mins')
    remainder = desired_int_num %% as.double(input_int)

    if(! desired_int_num %in% ints_by_var$int &&
            remainder != 0){
        #warning doesn't bubble up properly if imputation error occurs,
        #so using message instead
        # message(paste0('Warning: Desired time interval (', interval,
        #     ') is not a multiple of sample interval (',
        #     as.character(as.numeric(input_int)),
        #     ' min).\n\tGaps will be introduced!'))
        stop(paste0('Desired time interval (', interval,
            ') must conform to at least one\n\tof the supplied variables:\n',
            paste0('\t\t', ints_by_var$var, ': ', ints_by_var$int, ' min',
                collapse='\n'), '\n\tIt can also be a multiple of the ',
            'largest interval (if you want to thin the dataset).'), call.=FALSE)
    }

    #convert user-specified interval to minutes if it's in hours (because
    #fractional hours wont work with seq.POSIXct below)
    if(int_parts[2] == 'hour'){
        interval = paste(as.numeric(int_parts[1]) * 60, 'min')
    }

    # #coerce all variables to a particular interval if intervals differ
    # if(length(unique(ints_by_var$int)) > 1 || ){

    #this chunk thins the dataset if desired, and ensures no missing records.
    #(i.e. not just NAs, but entirely missing rows for some dates).
    #if some data are offset from the starting row, this may grab NAs instead
    #of data, so it iterates until it finds the right starting row.
    na_props = 1
    starting_row = 1
    while( (sum(na_props > 0.8) / length(na_props)) > 0.4){ #heuristic test

        if(starting_row > 10){
            stop(paste0('Unable to coerce data to desired time interval.',
                '\n\tTry specifying a different interval.'), call.=FALSE)
        }
        alldates = data.frame(DateTime_UTC=seq.POSIXt(dd[starting_row,1],
            dd[nrow(dd), 1], by=interval))
        dd_temp = left_join(alldates, dd, by='DateTime_UTC')

        #get new NA proportions for each column
        na_props = apply(dd_temp[,-c(1:3)], 2,
            function(x){ sum(is.na(x)) / length(x) })
        starting_row = starting_row + 1
    }
    dd = dd_temp

    # #if just one sample interval is found, just ensure no missing records
    # } else {
    #     alldates = data.frame(DateTime_UTC=seq.POSIXt(dd[1,1],
    #         dd[nrow(dd),1], by=interval))
    #     dd = left_join(alldates, dd, by='DateTime_UTC')
    # }

    #acquire air pressure data if necessary or desired
    missing_DOsat = all(! c('satDO_mgL','DOsat_pct') %in% vd)
    # missing_waterTemp = ! 'WaterTemp_C' %in% vd
    missing_airPres = ! 'AirPres_kPa' %in% vd
    need_airPres_for_DOsat = missing_DOsat & missing_airPres
    need_airPres_for_Q = using_zq_curve & missing_airPres & missing_depth #revisit "depth" here and elsewhere

    if(need_airPres_for_DOsat || need_airPres_for_Q || retrieve_air_pres){

        got_airpres = FALSE
        airpres = try(retrieve_air_pressure(md, dd), silent=TRUE)

        if(class(airpres) == 'try-error' || nrow(airpres) == 0) {

            cat('Failed to retrieve air pressure data from NCDC.\n',
                '\tTrying NCEP. This method is slow and only works in U.S.A.\n')

            airpres = try(retrieve_air_pressure2(md, dd), silent=TRUE)

            if(class(airpres) == 'try-error') {
                warning(paste('Failed to retrieve air pressure data.'),
                    call.=FALSE)
            } else {
                got_airpres = TRUE
            }

        } else {
            got_airpres = TRUE
            # linearly interpolate missing values for wind speed and air pressure
            # dd$wind_speed = approx(x=dd$wind_speed, xout=which(is.na(dd$wind_speed)))$y
            # dd$AirPres_kPa = approx(x=dd$AirPres_kPa,
            #     xout=which(is.na(dd$AirPres_kPa)))$y
        }

        #just join airpres to dataframe if AirPres_kPA entirely missing
        #if AirPres_kPA partly missing, fill in the blanks.
        if(got_airpres){
            if(missing_airPres){
                dd = left_join(dd, airpres, by='DateTime_UTC')
            } else {
                colnames(airpres)[colnames(airpres) == 'AirPres_kPa'] = 'x'
                dd = left_join(dd, airpres, by='DateTime_UTC')
                missing_airpres = is.na(dd$AirPres_kPa)
                dd$AirPres_kPa[missing_airpres] = dd$x[missing_airpres]
                dd$x = NULL
            }

            #then impute any remaining blanks
            dd$AirPres_kPa = zoo::na.approx(dd$AirPres_kPa,
                na.rm=FALSE, rule=2)
        }
    }

    airpres_coverage = sum(! is.na(dd$AirPres_kPa)) / nrow(dd)
    if(! need_airPres_for_DOsat && ! need_airPres_for_Q && ! retrieve_air_pres &&
        airpres_coverage < 0.5){
        warning(paste0('Air pressure coverage is ',
            round(airpres_coverage * 100, 1),
            '%.\n\tIf you need it to estimate DO saturation or depth, ',
            'streamMetabolizer may fail.\n\tYou may be able to solve this (or improve ',
            'your results)\n\tby setting retrieve_air_pres=TRUE.'), call.=FALSE)
    }

    #correct any negative or 0 depth values (these break streamMetabolizer)
    if('Depth_m' %in% vd){
        if(any(na.omit(dd$Depth_m) <= 0)){
            warning('Depth values <= 0 detected. Replacing with 0.01 m.',
                call.=FALSE)
            dd$Depth_m[dd$Depth_m <= 0] = 0.01
        }
    }

    #estimate discharge from depth (or eventually level too) using Z-Q rating curve
    #if arguments have been supplied to zq_curve.
    if('Discharge_m3s' %in% vd & using_zq_curve){
        warning(paste0('Arguments supplied to zq_curve, so ignoring available',
            '\n\tdischarge time-series data.'), call.=FALSE)
    }
    if(zq_supplied){
        cat(paste0('Modeling discharge from rating curve.\n\tCurve will be ',
            'generated from supplied Z and Q samples.\n'))
        depth_disch = estimate_discharge(Z=Z, Q=Q, sh=sensor_height,
            dd=dd, fit=fit, ignore_oob_Z=ignore_oob_Z, plot=zqplot)
        dd$Discharge_m3s = depth_disch$discharge
        dd$Depth_m = depth_disch$depth
        vd = c(vd, 'Discharge_m3s', 'Depth_m')
    } else {
        if(ab_supplied){
            cat(paste0('Modeling discharge from rating curve determined by',
                '\n\tsupplied a and b parameters.\n'))
            depth_disch = estimate_discharge(a=a, b=b,
                sh=sensor_height, dd=dd, fit=fit, ignore_oob_Z=ignore_oob_Z,
                plot=zqplot)
            dd$Discharge_m3s = depth_disch$discharge
            dd$Depth_m = depth_disch$depth
            vd = c(vd, 'Discharge_m3s', 'Depth_m')
        }
        # if(ab_supplied & missing_depth){
        #     cat(paste0('Modeling discharge from rating curve determined by',
        #         '\n\tsupplied a and b parameters.\n\tEstimating depth or level',
        #         ' from water pressure, air pressure, and sensor height.\n'))
        #     dd$Discharge_m3s = estimate_discharge(a=zq_curve$a, b=zq_curve$b,
        #         sh=zq_curve$sensor_height, dd=dd)
        # } else {
        #     cat(paste0('Modeling discharge from rating curve determined by',
        #         '\n\tsupplied a and b parameters.\n\tUsing available ',
        #         'time-series data for depth.\n'))
        #     dd$Discharge_m3s = estimate_discharge(a=zq_curve$a, b=zq_curve$b,
        #         dd=dd)
        # }
    }

    # if(zq_supplied | ab_supplied){
    #     if('Discharge_m3s' %in% vd){
    #         warning(paste0('Discharge data available, so ignoring ',
    #             'zq_curve argument.'), call.=FALSE)
    #     } else {
    #         if(any(! c('AirPres_kPa', 'WaterPres_kPa', 'WaterTemp_C') %in% vd)){

    # if(! 'Discharge_m3s' %in% vd){

    # dd2 <<- dd
    # stop('a')
    # dd = dd2
    # }

    #correct any negative or 0 discharge values
    if('Discharge_m3s' %in% vd){
        if(any(na.omit(dd$Discharge_m3s) <= 0)){
            warning('Discharge values <= 0 detected. Replacing with 0.01.',
                call.=FALSE)
            dd$Discharge_m3s[dd$Discharge_m3s <= 0] = 0.01
        }
    }

    # convert UTC to solar time
    dd$solar.time = suppressWarnings(streamMetabolizer::convert_UTC_to_solartime(
        date.time=dd$DateTime_UTC, longitude=md$lon[1], time.type="mean solar"))

    # estimate par
    apparentsolartime = suppressWarnings(
        streamMetabolizer::convert_UTC_to_solartime(date.time=dd$DateTime_UTC,
            longitude=md$lon[1], time.type="apparent solar"))
    dd$light = suppressWarnings(streamMetabolizer::calc_solar_insolation(
        app.solar.time=apparentsolartime, latitude=md$lat[1], format="degrees"))

    if("Light_PAR" %in% vd && ! estimate_PAR){
        message(paste0("Using supplied light data. Unless you're quite ",
            "confident in these data,\n\tit may be preferable to set ",
            "estimate_PAR=TRUE."))
        dd$light[! is.na(dd$Light_PAR)] = dd$Light_PAR[! is.na(dd$Light_PAR)]
    } else {
        cat("Estimating PAR from latitude and time.\n")
    }

    dd$Light_PAR = NULL
    dd$Light_lux = NULL

    # impute missing data. code found in gapfill_functions.R (maxspan_days deprecated)
    dd = select(dd, -c(region, site, DateTime_UTC))
    if(fillgaps != 'none') dd = gap_fill(dd, maxspan_days=5, knn=3,
        sint=desired_int, algorithm=fillgaps, maxhours, ...)

    #rename variables
    if("DO_mgL" %in% vd) dd$DO.obs = dd$DO_mgL
    if("WaterTemp_C" %in% vd) dd$temp.water = dd$WaterTemp_C
    if('Discharge_m3s' %in% vd) dd$discharge = dd$Discharge_m3s

    #use discharge to estimate mean depth of area defined
    #by stream width and O2 turnover distance (if necessary or desired)
    if("Discharge_m3s" %in% vd & estimate_areal_depth){
        dd$depth = streamMetabolizer::calc_depth(dd$discharge) #estimate mean areal depth
    } else {

        #otherwise just use depth directly.
        if("Depth_m" %in% vd){
            dd$depth = dd$Depth_m

            # if(! using_level){
            #     warning(paste0('Passing "Depth_m" values from StreamPULSE database',
            #         ' directly to streamMetabolizer.\n\tMetabolism estimates will',
            #         ' be best if "Depth_m" represents mean depth\n\tfor the ',
            #         'area defined by the width of the stream and the oxygen\n\t',
            #         'turnover distance. "Depth_m" may also represent depth-at-gage',
            #         ' or,\n\tworse, level-at-gage. These may result in poor ',
            #         'metabolism estimates.\n\tYou may want to use zq_curve ',
            #         'or estimate_areal_depth.'),
            #         call.=FALSE)
            # }

        } else {

            if(estimate_areal_depth){
                stop(paste0('Missing discharge and depth data.\n\tNot enough ',
                    'information to proceed.\n\tMight parameter "zq_curve"',
                    ' be of service?'), call.=FALSE)
            } else {
                stop(paste0('Missing depth data.\n\tNot enough information to ',
                    'proceed.\n\tTry setting estimate_areal_depth to TRUE.'),
                    call.=FALSE)
            }
        }
    }

    # kPa to atm
    if(! 'DO_mgL' %in% vd){
        stop(paste0('streamMetabolizer cannot',
            ' be run without DO_mgL.'), call.=FALSE)
    }

    if("AirPres_kPa" %in% vd) dd$atmo.pressure = dd$AirPres_kPa / 101.325
    if(model == "streamMetabolizer"){
        if("satDO_mgL" %in% vd){
            dd$DO.sat = dd$satDO_mgL
        } else {
            if("DOsat_pct" %in% vd){

                # define multiplicative factor, to catch if variable is
                # fraction or percent... could do this on server first in future
                if(quantile(dd$DOsat_pct, 0.9, na.rm=TRUE) > 10){
                    ff=0.01
                } else { ff=1 }
                dd$DOsat_pct[dd$DOsat_pct == 0] = 0.000001 #prevent NaNs
                dd$DO.sat = dd$DO.obs / (dd$DOsat_pct*ff)
            } else {
                if(!all(c("temp.water","AirPres_kPa") %in% colnames(dd))){
                    stop(paste('Insufficient data to fit this model.\n\tNeed',
                        'either DO sat OR water temp and\n\tair ',
                        'pressure.'), call.=FALSE)
                }
                cat('Modeling DO.sat based on water temperature and',
                    'air pressure.\n')
                dd$DO.sat = LakeMetabolizer::o2.at.sat.base(temp=dd$temp.water,
                    baro=dd$AirPres_kPa*10, salinity=0, model='garcia-benson')
            }
        }
    }

    # Select variables for model
    if(model == "BASE"){
        model_variables = c("solar.time","DO.obs","temp.water","light",
            "atmo.pressure")
    } else { # streamMetabolizer
        model_variables = c("solar.time","DO.obs","DO.sat","depth",
            "temp.water","light")
        # if(type=="bayes") model_variables = c(model_variables,"discharge")
    }

    if(!all(model_variables %in% colnames(dd))){
        missing = model_variables[which(! model_variables %in% colnames(dd))]
        stop(paste0('Insufficient data to fit this model.\n\t',
            'Missing variable(s): ', paste0(missing, collapse=', ')),
            call.=FALSE)
    }
    if(model == 'streamMetabolizer' && type == 'bayes' &&
            ! 'discharge' %in% colnames(dd)){
        warning(paste("Without discharge data (or estimates), you'll have to",
            "\n\trun fit_metabolism with pool_K600='none'."), call.=FALSE)
    }

    # Structure data, add class for model name
    if(model=="BASE"){ # rename variables for BASE
        # fitdata = dd %>% select_(.dots=model_variables) %>%
        fitdata = dd %>% select(model_variables) %>%
            mutate(Date=as.Date(solar.time),
                Time=strftime(solar.time, format="%H:%M:%S"), salinity=0) %>%
            rename(I=light, tempC=temp.water, DO.meas=DO.obs) %>%
            select(Date, Time, I, tempC, DO.meas, atmo.pressure, salinity)
        BASE = setClass("BASE", contains="data.frame")
        outdata = as(fitdata, "BASE")
    }else if(model=="streamMetabolizer"){
        if('discharge' %in% colnames(dd)){
            # fitdata = select_(dd, .dots=c(model_variables, 'discharge'))
            fitdata = select(dd, c(model_variables, 'discharge'))
        } else {
            fitdata = select(dd, model_variables)
        }
        # streamMetabolizer = create_sm_class()
        outdata = as(fitdata, "streamMetabolizer")
        outdata@type = type
    }

    # #extract start and end date from input data (will be used to determine
    # #whether this model should be considered for
    # #inclusion on the data portal as the best model for this site and year)
    # mod_startdt = d$data$DateTime_UTC[1]
    # mod_enddt = d$data$DateTime_UTC[nrow(d$data)]
    # dtbounds = c(mod_startdt, mod_enddt)
    # attr(dtbounds, 'tzone') = 'UTC'

    #return list of specs passed on from request_date,
    #as well as new list of specs passed into this function
    out = list(data=outdata,
        specs=append(d$specs,
            list(model=model, type=type, interval=interval,
                rm_flagged=paste0(unlist(rm_flagged), collapse=','),
                fillgaps=fillgaps, used_rating_curve=using_zq_curve,
                estimate_areal_depth=estimate_areal_depth)))

    return(out)
}
