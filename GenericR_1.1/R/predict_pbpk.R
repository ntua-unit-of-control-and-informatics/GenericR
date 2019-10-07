predict.pbpk <- function(dataset, rawModel, additionalInfo){

  ###########################################
  ### Create input vector from Jaqpot format
  ##########################################

  # Get the number of compartments of the PBPK model
  n_comp <- length(additionalInfo$predictedFeatures) - 1
  # Get feature keys (a key number that points to the url)
  feat.keys <-  dataset$features$key
  # Get feature names (actual name)
  feat.names <- dataset$features$name
  # Create a dataframe that includes the feature key and the corresponding name
  key.match <- data.frame(cbind(feat.keys, feat.names))
  # Convert factor to string (feat.names is converted factor by data.frame())
  key.match[] <- lapply(key.match, as.character)
  # Initialize a dataframe with as many rows as the number of values per feature
  rows_data <- length(dataset$dataEntry$values[,2])
  df <- data.frame(matrix(0, ncol = 0, nrow = rows_data))

  for(key in feat.keys){
    # For each key (feature) get the vector of values (of length 'row_data')
    feval <- dataset$dataEntry$values[key][,1]
    # Name the column with the corresponding name that is connected with the key
    df[key.match[key.match$feat.keys == key, 2]] <- feval
  }

  ####################################
  ### Continue with prediction process
  ####################################


  # Unserialize the ODEs and the covariate model
  mod <- unserialize(jsonlite::base64_dec(rawModel))
  # Extract function for parameter creation
  create.params <- mod$create.params
  # Extract function for initial conditions of odes creation
  create.inits <- mod$create.inits
  # Extract function for event creation
  create.events <- mod$create.inits
  # Extract custom function
  custom.func <- mod$custom.func
  # Extract odes function
  ode.func <- mod$ode.func



  # Create parameter vector
  params <- create.params(df)
  # Create initial conditions
  inits <- create.inits(params)
  # Create events
  events <- create.events(params)


  # Get the names of compartments in the same order as represented by the ODEs
  ###comp  <- additionalInfo$fromUser$comp


  # Generate a time vector based on the user input
  sample_time <- seq(df$sim.start , df$sim.end, df$sim.step)
  if (!(df$solver %in%  c( "lsoda", "lsode", "lsodes", "lsodar", "vode","daspk", "bdf",
                           "adams", "impAdams", "radau") ) ){
    solver <- "lsodes"
    ## TODO : create correpsonding error message
  }else{
    solver <- df$solver
  }
  # Integrate the ODEs using the deSolve package
  solution <- deSolve::ode(times = sample_time,  func = ode.func, y = inits, parms = params,
                           custom.func = custom.func, method = solver,  events = events)

  for(i in 1:dim(solution)[1]){
    prediction<- data.frame(t(solution[i,]))
    # Name the predictions
  ###  colnames(prediction)<- c("time", comp)
    # Bring everything into a format that cooperates with Jaqpot
    if(i==1){lh_preds<- list(jsonlite::unbox(prediction))
    }else{
      lh_preds[[i]]<- jsonlite::unbox(prediction)
    }
  }
  datpred <-list(predictions=lh_preds)

  return(datpred)
}