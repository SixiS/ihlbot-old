require "socket"
require "rubygems"
require "active_record"
require "active_support"
require "yaml"


class DatabaseA < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(
  :adapter => "mysql",
  :host => "localhost",
  :database => "saihl"
  )
end

class DatabaseB < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(
  :adapter => "mysql",
  :host => "localhost",
  :database => "saihl2"
  )
end


module A
  class Player < DatabaseA
  has_many :nicks
  end

  class Nick < DatabaseA
    belongs_to :player  
  end
end

module B
  class Player < DatabaseB
  has_many :nicks
  end

  class Nick < DatabaseB
    belongs_to :player  
  end
end

A::Player.find(:all, :include => :nicks).each do |p|
  unless(B::Player.find_by_nick(p.nick))
    new_player = B::Player.new 
    new_player.nick = p.nick  
    new_player.ihl = true
    new_player.save!
    p.nicks.each do |n|
      new_nick = B::Nick.new
      new_nick.player_id = new_player.id
      new_nick.nick = n.nick
      new_nick.save!
    end
  end
  
end
