vp_to_ki.rb takes an XML export of a state machine diagram created with
Visual Paradigm for UML (including the free community edition) and
converts it to statechart code that can be used with the Ki statechart
framework (https://github.com/FrozenCanuck/Ki).

Note that, in Visual Paradigm, a state needs to have a region in order
to have substates (the substates will be children of the region, which
is a child of the superstate).

Requirements
------------
[Nokogiri](http://nokogiri.org/) and
[Erubis](http://www.kuwata-lab.com/erubis/). Normally, you can ust do:
  sudo gem install nokogiri erubis

License
-------
Licensed under the MIT license (see MIT-LICENSE.TXT)
