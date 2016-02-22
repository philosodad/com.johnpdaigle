require 'rubygems'
require 'middleman/rack'
require 'rack/codehighlighter'
require 'pygments'
require 'rubypython'

use ::Rack::Codehighlighter, 
  :pygments,
  :element => "pre>code",
  :pattern => /\A:::([-_+\w]+)\s*\n/,
  :markdown => true,
  :options => {:noclasses => true, :style => "colorful"}

run Middleman.server
RubyPython.start(:python_exe => "python2.7.6")
