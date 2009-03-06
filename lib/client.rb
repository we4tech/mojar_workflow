# $Id: restful.rb 2940 2007-12-27 12:37:00Z hasan $
# *****************************************************************************
# Copyright (C) 2005 - 2007 somewhere in .Net ltd.
# All Rights Reserved.  No use, copying or distribution of this
# work may be made except in accordance with a valid license
# agreement from somewhere in .Net LTD.  This notice must be included on
# all copies, modifications and derivatives of this work.
# *****************************************************************************
# $LastChangedBy: hasan $
# $LastChangedDate: 2007-12-27 18:37:00 +0600 (Thu, 27 Dec 2007) $
# $LastChangedRevision: 2940 $
# *****************************************************************************
require "net/http"
require "uri"
require 'open-uri'

module Client

  class Http

    # send :post request and retrieve the resource from the given uri.
    def self.get_resource(p_base_url, p_uri, p_args = nil)
      response = Net::HTTP.start(p_base_url.host, p_base_url.port) {|http|
        http.get(p_base_url.path + p_uri, p_args, nil)
      }
      return response
    end
  end
end