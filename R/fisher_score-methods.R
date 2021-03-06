setMethod(
  "fisher_score",
  signature( query = "CMAPCollection", sets = "CMAPCollection", universe = "character" ),
  function( query, sets, universe, keep.scores=FALSE) {
    signed(sets) <- rep(FALSE, ncol(sets)) ## fisher test does not consider gene signs
    
    query  <- query[intersect(featureNames( query), universe),]
    sets   <- sets[ intersect(featureNames( sets),  universe),]
    
    common.genes <- intersect( featureNames(query), featureNames(sets))
    
    if( length( common.genes) == 0 ) {
      stop( "None of the query gene identifiers could be found in the reference dataset.",
            call. = FALSE)
    }
    
    query.common  <- abs( matrix( members( query )[common.genes,], nrow=length( common.genes) ) )
    
    sets.common   <- abs( matrix( members( sets  )[common.genes,], nrow=length( common.genes) ) )
    
    coincidence <- Matrix::crossprod(query.common, sets.common) ## rows = query.target's sets
    
    ## 2x2 table
    ##              query  1         query  0
    ##   sets 1  query.and.sets  sets.not.query    || sets.all
    ##   sets 0  query.not.sets      neither 
    ##   ========================================
    ##            query.all        query.colsum
    
    query.and.sets <- t( matrix( coincidence, ncol=ncol(sets), dimnames=list(sampleNames(query), sampleNames(sets))))
    
    query.all <- matrix( rep( Matrix::colSums( abs( members( query ) ) ), ncol(sets)),
                         nrow=ncol(sets), ncol=ncol(query), byrow=TRUE, dimnames=dimnames(query.and.sets))
    
    sets.all <- matrix( rep( Matrix::colSums( abs( members( sets ) ) ), ncol(query)),
                        nrow=ncol(sets), ncol=ncol(query), byrow=FALSE, dimnames=dimnames(query.and.sets))
    
    neither <- length(universe) - sets.all - query.all + query.and.sets
    
    sets.not.query <- length(universe) - query.all - neither
    
    query.not.sets <- query.all - query.and.sets
    
    query.colsum <- sets.not.query + neither
    
    ## p-value calculation
    p.values <- matrix(
      unlist(
        mclapply( row.names( query.and.sets ), function( k ) {
          fisher_p(query.and.sets[k,], sets.not.query[k,], query.all[k,], query.colsum[k,]) 
        })
      ),
      ncol=ncol(query), byrow=TRUE,
      dimnames=list(sampleNames(sets), sampleNames(query))
    )
    
    lor <- log( ( query.and.sets * neither) / (query.not.sets * sets.not.query ) )
    lor[query.not.sets == 0] <- Inf
    lor[sets.not.query == 0] <- Inf
    lor[query.and.sets == 0] <- 0
    
    ## store per-gene scores as data-column:gene-set list-of-list
    if( keep.scores == TRUE) {
      gene.scores <- featureScores( query, sets)
    } else {
      gene.scores <- NA
    }
    
    ## store results
    results <- mclapply( seq( ncol( query) ), function( g ) {
      
      if(! all(is.na( gene.scores ))) { 
        geneScores <- I(gene.scores[[g]])
      } else {
        geneScores <- NA
      }
      
      res <- CMAPResults(
        data=data.frame(
          set = sampleNames(sets),
          trend = ifelse(lor[,g] <= 0, "under", "over"),
          pval = p.values[,g ],
          padj = p.adjust( p.values[,g ], method="BH"),
          effect = round(zScores( p.values[,g], direction=lor[,g]),2),
          LOR = lor[,g],
          nSet = Matrix::colSums( abs( members ( sets ) ) ),
          nFound = query.and.sets[,g ],
          geneScores = geneScores,
          pData(sets)),
        docs ="\n Results from Fisher exact tests.\n P-values were adjusted using the 'p.adjust' function with method 'BH'."
      )
      
      varMetadata(res)$labelDescription <- 
        c("SetName",
          "Deviation from random expectation",
          "Fisher's exact test p-value",
          "Adjusted p-value (BH)",
          "z-score based on the standard normal distribution",
          "Log Odds Ratio",
          "Number of genes annotated in the reference set",
          "Number of genes found in query and target sets",
          "Identifiers of genes found in query and target sets",
          colnames(pData(sets)))
      
      res
    })
    
    names(results) <- sampleNames(query)
    if( length( results) == 1 ) return( results[[1]] )
    return( results)              
    
  }
)

setMethod(
  "fisher_score",
  signature( query = "CMAPCollection", sets = "NChannelSet", universe = "character" ),
  function( query, sets, universe, element, lower=NULL, higher=NULL, 
            keep.scores=FALSE, min.set.size=5) {
    
    if(all( is.null( c(lower, higher )))){
      stop("Please provide at least one of the 'higher' and 'lower' parameters.")
    }
    
    ## induce CMAPCollection from NChannelSet
    induced.sets <- induceCMAPCollection( sets, element=element, 
                                          lower=lower, higher=higher)
    if( ncol(induced.sets) == 0){
      stop("None of the genes in the reference dataset passed the score cutoff to induce gene sets.")
    }
    
    if( !is.null( min.set.size )){
      induced.sets <- minSetSize(induced.sets, min.members = min.set.size)
      if( ncol(induced.sets) == 0){
        stop(sprintf("None of the induced gene sets had more than %s members.", min.set.size))
      }
    }
    
    results <- fisher_score( query, induced.sets, universe=universe, keep.scores=FALSE)
    if( class( results ) != "list"){
      results <- list( results )
    }
    
    ## store per-gene scores as data-column:gene-set list-of-list
    query  <- query[intersect(featureNames( query), universe),]
    sets   <- sets[ intersect(featureNames( sets ),  universe), sampleNames( induced.sets)]
    
    ## store per-gene scores as data-column:gene-set list-of-list
    if( keep.scores == TRUE) {
      gene.scores <- featureScores( query, sets, simplify=FALSE)
    } else {
      gene.scores <- NA
    }
    
    ## create separate CMAPResults object for each query column
    for( n in seq( ncol( query ))){
      if(! all(is.na( gene.scores ))) {
        geneScores <- gene.scores[[n]]
        results[[n]]@data$geneScores <- I(geneScores)
      }
    }
    if( length( results ) == 1 ){
      return( results[[ 1 ]])
    } else {
      return( results )
    }
  }
)

setMethod(
  "fisher_score",
  signature( query = "SignedGeneSet", sets = "CMAPCollection", universe = "character" ),
  function( query, sets, universe) {
    fisher_score(as(query,"CMAPCollection"), sets, universe=universe)
  }
)

setMethod(
  "fisher_score",
  signature( query = "SignedGeneSet", sets = "NChannelSet", universe = "character" ),
  function( query, sets, universe) {
    fisher_score(as(query,"CMAPCollection"), sets, universe=universe)
  }
)

setMethod(
  "fisher_score",
  signature( query = "GeneSet", sets = "CMAPCollection", universe = "character" ),
  function( query, sets, universe) {
    fisher_score(as(query, "CMAPCollection"), sets, universe=universe)
  })

setMethod(
  "fisher_score",
  signature( query = "GeneSet", sets = "NChannelSet", universe = "character" ),
  function( query, sets, universe) {
    fisher_score(as(query, "CMAPCollection"), sets, universe=universe)
  })

setMethod(
  "fisher_score",
  signature( query = "GeneSetCollection", sets = "CMAPCollection", universe = "character" ),
  function( query, sets, universe ) {
    fisher_score(as(query, "CMAPCollection"), sets, universe)
  })

setMethod(
  "fisher_score",
  signature( query = "GeneSetCollection", sets = "NChannelSet", universe = "character" ),
  function( query, sets, universe ) {
    fisher_score(as(query, "CMAPCollection"), sets, universe)
  })

setMethod(
  "fisher_score",
  signature( query = "GeneSetCollection", sets = "GeneSetCollection", universe = "character" ),
  function( query, sets, universe ) {
    fisher_score(as(query, "CMAPCollection"), as(sets, "CMAPCollection"), universe=universe)
  }
)

setMethod(
  "fisher_score",
  signature( query = "CMAPCollection", sets = "GeneSetCollection", universe = "character" ),
  function( query, sets, universe ) {
    fisher_score(query, as(sets, "CMAPCollection"), universe=universe)
  }
)

setMethod(
  "fisher_score",
  signature( query = "GeneSet", sets = "GeneSetCollection", universe = "character" ), ## sets from cmap
  function( query, sets, universe) {
    fisher_score(query, as(sets, "CMAPCollection"), universe)
  }
)


setMethod(
  "fisher_score",
  signature( query = "GeneSet", sets = "GeneSet", universe = "character" ),
  function( query, sets, universe ) {
    fisher_score(query, as(sets, "CMAPCollection"), universe)
  }
)


fisher_p <- function( x, y, m, n, relErr = 1 + 1e-7 ) {
  ## 'x' and 'y' are entries in the top two cells; 'm' and 'n' are column totals.
  ## Code is excerpted from fisher.test, for efficiency. Note that 'support'
  ## varies in length with the input variables, so vectorization is only possible
  ## via an mapply.
  mapply(
    function( x, y, m, n ) {
      k <- x + y
      lo <- max( 0, k - n )
      hi <- min( k, m )
      support <- lo:hi
      d <- dhyper( support, m, n, k, log = TRUE )
      d <- exp( d - max( d ) )
      d <- d / sum( d )
      sum( d[ d <= d[ x - lo + 1 ] * relErr ] )
    },
    x, y, m, n
  )
}
