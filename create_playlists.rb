#!/bin/ruby

require 'find'

class GenPlaylists
  def addToPlaylist(group, album, file)
    groupPlaylist = "./#{group}/#{group}.m3u"
    albumPlaylist = "./#{group}/#{album}/#{group}_#{album}.m3u"
    File.open(groupPlaylist, "a+") { |f|
      f.write("#{group}\\#{file}\n")
    }
    File.open(albumPlaylist, "a+") { |f|
      f.write("#{file}\n")
    }
  end
 
  def cleanOldM3u() 
      Find.find('./') do |f| 
        if /(.*\.m3u)/.match(f)
          print "Remove old m3u file #{$1}\n";
          File.unlink($1)
        end
      end
  end
  def searchFiles() 
      Find.find('./') do |f| 
        if /\.\/([^\/]+)\/([^\/]+)\/(.*\.mp3)/.match(f)
          addToPlaylist($1,$2,$3)
        end
      end
  end
end


instance = GenPlaylists.new
instance.cleanOldM3u()
instance.searchFiles()
