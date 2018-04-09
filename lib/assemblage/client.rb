# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/db_object'


class Assemblage::Client < Assemblage::DbObject( :clients )
end # class Assemblage::Client

