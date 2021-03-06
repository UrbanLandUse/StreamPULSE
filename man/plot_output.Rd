% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_output.R
\name{plot_output}
\alias{plot_output}
\title{Visualize metabolism model results}
\usage{
plot_output(model_out)
}
\arguments{
\item{model_out}{the output of \link{fit_metabolism}.}
}
\value{
Opens a shiny app in default browser via localhost.
}
\description{
Generates a Shiny R visualization similar to those found on the
\href{http://data.streampulse.org:3838/streampulse_diagnostic_plots/}{StreamPULSE data portal}.
}
\examples{
streampulse_data = request_data(sitecode='NC_Eno',
  startdate='2016-06-10', enddate='2016-10-23')

fitdata = prep_metabolism(d=streampulse_data, type='bayes',
  model='streamMetabolizer', interval='15 min',
  rm_flagged=list('Bad Data', 'Questionable'), fillgaps=fillgaps,
  zq_curve=list(sensor_height=NULL, Z=Z_data, Q=Q_data,
  fit='power', plot=TRUE), estimate_areal_depth=TRUE)

modelfit = fit_metabolism(fitdata)

plot_output(modelfit)
}
\seealso{
\code{\link{request_data}} for acquiring StreamPULSE data;
  \code{\link{prep_metabolism}} for organizing data and acquiring additional
  variables, and \code{\link{fit_metabolism}} for fitting models to data and
  predicting metabolism.
}
\author{
Mike Vlah, \email{vlahm13@gmail.com}
}
