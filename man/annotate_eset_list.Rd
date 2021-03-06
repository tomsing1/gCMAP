\name{annotate_eset_list}
\alias{annotate_eset_list}
\title{
Function to complile a data frame with per-instance annotation for a list of eSet objects generated by the \code{\link{splitPerturbations}} function. The output can be used directly as sample.annotation for the \code{\link{NChannelSet}} function. 
}
\description{
For each eSet in the 'eset.list', the pData slot is examined. Perturbation instances are identified as a match to 'perturbation' in the 'cmap.column' of the pData slot. The first matching row is extracted and transfered into the output data.frame, which contains one row for each eSet in the 'eset.list'. Only annotation columns found in the pData slots of all eSets in the 'eset.list' are returned.
}
\usage{
annotate_eset_list(eset.list, cmap.column = "cmap", perturbation = "perturbation")
}

\arguments{
  \item{eset.list}{
 A list of eSet objects, usually generated by a call to the \code{\link{splitPerturbations}} functions
 }
  \item{cmap.column}{
 The name of the pData column for eSets in 'eset.list' identifying treatment and control samples.
 }
  \item{perturbation}{
 The character string in the 'cmap.column' of the pData column for eSets in 'eset.list' identifying perturbation associated with treated samples.
}
}

\value{
A data frame with one row for each eSet in the input 'eset.list' and all columns found in the original eSet pData slot.
}

\author{
Thomas Sandmann
}

\seealso{
\code{\link{splitPerturbations}}
}
\examples{
example( splitPerturbations )
}
