module ElibriWatermarking
  
  class ElibriException < Exception
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
  
  
end