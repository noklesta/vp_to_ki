#!/usr/bin/env ruby

#########################################################################
#
# Copyright 2011 Anders Nøklestad
# Licensed under the MIT license (see MIT-LICENSE.TXT)
#
#########################################################################

require 'nokogiri'
require 'erubis'

require 'lib/state'
require 'lib/transition'
require 'lib/printer'

if ARGV.size < 1
  puts "Usage: #{$0} XML-FILE" 
  exit
end

File.open(ARGV[0]) do |file|
  $doc = Nokogiri::XML(file)
  $project_name = $doc.>('Project').first['name']
  root_state = State.new($doc.>('Project > Models'), nil, 0)  # recursively builds state tree
  Transition.find_transitions
  Printer.print_statechart(root_state)
end

