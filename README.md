vp_to_ki.rb takes an XML export of a state machine diagram created with
Visual Paradigm for UML (including the free community edition) and
converts it to statechart code that can be used with the Ki statechart
framework (https://github.com/FrozenCanuck/Ki).

Requirements
------------
[Nokogiri](http://nokogiri.org/) and
[Erubis](http://www.kuwata-lab.com/erubis/). Normally, you can just do:

    sudo gem install nokogiri erubis

License
-------
Licensed under the MIT license (see MIT-LICENSE.TXT)
