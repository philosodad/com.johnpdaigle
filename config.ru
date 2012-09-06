require 'rubygems'
require 'middleman/rack'
require 'rack/codehighlighter'
require 'pygments'

use Rack::Codehighlighter, 
  :pygments,
  :element => "pre>code",
  :pattern => /\A:::([-_+\w]+)\s*\n/,
  :markdown => true,
  :options => {:noclasses => true, :style => "colorful"}

run Middleman.server
