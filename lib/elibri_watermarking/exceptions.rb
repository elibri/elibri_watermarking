module ElibriWatermarking
  
  class ElibriException < StandardError
  end
  
  class ParametersError < ElibriException
  end
  
  class AuthenticationError < ElibriException
  end
  
  class AuthorizationError < ElibriException
  end
  
  class ServerException < ElibriException
  end
  
  class WrongFormats < ElibriException
  end
  
  class RequestExpired < ElibriException
  end
 
  class NoWorkingServer < ElibriException
  end 
  
end
