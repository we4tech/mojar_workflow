# $Id$
# *****************************************************************************
# Copyright (C) 2005 - 2007 somewhere in .Net ltd.
# All Rights Reserved.  No use, copying or distribution of this
# work may be made except in accordance with a valid license
# agreement from somewhere in .Net LTD.  This notice must be included on
# all copies, modifications and derivatives of this work.
# *****************************************************************************
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
# *****************************************************************************
require File.join(File.dirname(__FILE__), "/lib/core.rb")
require File.join(File.dirname(__FILE__), "/lib/client.rb")

Object.class_eval do

  # install all required modules or classes
  def setup_mojar_workflow_support(p_args = {})
    if ApplicationController == self.superclass
      # apply helper for controllers
      puts "setting up mojar workflow for application controller"
      extend MojarWorkflow::Helpers::ControllerClassMethods
      include MojarWorkflow::Helpers::CommonClassMethods
    else
      puts "setting up mojar workflow for normal object"
      include MojarWorkflow::Helpers::CommonClassMethods
    end    
  end
end

# load all workflow files
MojarWorkflow::Core::Resource.discover()