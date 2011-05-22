#!/usr/bin/env ruby

#########################################################################
#
# Copyright 2011 Anders Nøklestad (noklesta; anders.noklestad@iln.uio.no)
# Licensed under the MIT license (see MIT-LICENSE.TXT)
#
#########################################################################

require 'rubygems'
require 'nokogiri'
require 'erubis'

require_relative 'lib/state'
require_relative 'lib/transition'
require_relative 'lib/printer'

if ARGV.size < 1
  puts "Usage: #{$0} XML-FILE" 
  exit
end

File.open(ARGV[0]) do |file|
  $doc = Nokogiri::XML(file)
  $project_name = $doc.>('Project').first['name']
  root_state = State.new($doc.>('Project').first, nil, 0)  # recursively builds state tree
  Transition.find_transitions
  Printer.print_statechart(root_state)
end

