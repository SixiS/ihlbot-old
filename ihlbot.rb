#!/usr/local/bin/ruby

=begin
* Require phase
*
*
*
*
=end
require "socket"
require "rubygems"
require "active_record"
require "active_support"


=begin
* Establish connection to the MYSQL server
=end
ActiveRecord::Base.establish_connection(
  :adapter => "mysql",
  :host => "localhost",
  :database => "saihl"
)

=begin
* Player Model
* Has attributes : id, nick, cg, numgames, numcaps, roll_wins, roll_losses
* Virtual Attributes: roll_rate, points
*
*
=end
class Player < ActiveRecord::Base
  has_many :nicks
  has_many :contacts
  def roll_rate
    total = self.roll_wins + self.roll_losses
    if(total == 0)
      return -1
    else
      #puts((Float(self.roll_wins) / total)*100)
      return ((Float(self.roll_wins) / Float(total))*100)      
    end
  end
  
  def points
    return(self.numgames + (self.numcapts*2))
  end  
end

=begin
* Nick Model
* Has attributes : id, player_id, nick
*
*
=end
class Nick < ActiveRecord::Base
  belongs_to :player  
end

=begin
* Contace Model
* Has attributes : id, player_id, contact_type, contact_details
*
*
=end
class Contact < ActiveRecord::Base
  belongs_to :player  
end


=begin
* Method to return the local_ip
* 
* Tries to connect to saix.net and returns the ip
* that connection goes through
*
=end
def local_ip  
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily  
   
  UDPSocket.open do |s|  
    s.connect '196.25.1.200', 1  
    s.addr.last  
  end  
ensure  
  Socket.do_not_reverse_lookup = orig  
end

=begin
* Method to return the international_ip
*
* Tries to connect through google and returns the ip
* that connection goest through
*
=end
def international_ip  
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily  
   
  UDPSocket.open do |s|  
    s.connect '64.233.187.99', 1  
    s.addr.last  
  end  
ensure  
  Socket.do_not_reverse_lookup = orig  
end  

=begin
* The main IRC class
* Talks to the IRC server and contains the main run loop.
*
* IS THE PROGRAM :D
*
*
*
=end
class IRC 
    #* * * * * * * * * * * * * * * * * * * * * * *
    # initialize the connection to the irc server.
    # 
    #
    #
    #
    #

    def initialize(server, port, nick, pass, channel)
        @server = server
        @port = port
        @nick = nick
        @pass = pass
        @channel = channel
    end
    
    #* * * * * * * * * * * * * * * * * * * * * * *
    # sends message s to the irc server.
    # 
    #
    #
    #
    def send(s)
        # Send a message to the irc server and print it to the screen
        puts "--> #{s}"
        #puts s       
         if(s.split(" ")[0].downcase == "group")
          @irc.send "#{s}\n", 0
         else
          if(s.split(" ")[1] == "#saihl" || @initialising || @source == "both")
            @irc.send "#{s}\n", 0
            @irc2.send "#{s}\n", 0
          else
            if(@source == "war3")
              @irc.send "#{s}\n", 0
            else
              @irc2.send "#{s}\n", 0
            end  
          end
         end
    end
    
    #* * * * * * * * * * * * * * * * * * * * * * *
    # connect
    # Performs the connection to the server.
    # 
    #
    #
    #
    def connect()
        # Connect to the IRC server
        @irc = TCPSocket.open(@server, @port)
        @irc2 = TCPSocket.open("za.shadowfire.org", 6667)
        @initialising = true
        send "USER blah blah blah :blah blah"
        send "PASS #{@pass}"        
        send "NICK #{@nick}"        
        send "JOIN #{@channel}"
        @initialising = false       
    end
    
    #* * * * * * * * * * * * * * * * * * * * * * *
    # Evaluate(s).
    # THe main method of the IRC class, takes in message s
    # and decides what to do with it.
    #
    #
    #
    def evaluate(s)
        if s =~ /^[-+*\/\d\s\eE.()]*$/ then
            begin
                s.untaint
                return eval(s).to_s                
            rescue Exception => detail
                puts detail.message()
            end
        end
        return "Error"
    end
    
    #* * * * * * * * * * * * * * * * * * * * * * *
    # Handes messages from the server.
    # Includes messages from other clients, evaluating
    # then and returning info, etc
    #
    #
    #
    def handle_server_input(s)
        # This isn't at all efficient, but it shows what we can do with Ruby
        # (Dave Thomas calls this construct "a multiway if on steroids")
        case s.strip
            when /^PING :(.+)$/i
                puts "[ Server ping ]"
                send "PONG :#{$1}"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i
                puts "[ CTCP PING from #{$1}!#{$2}@#{$3} ]"
                send "NOTICE #{$1} :\001PING #{$4}\001"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i
                puts "[ CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
                send "NOTICE #{$1} :\001VERSION Ruby-irc v0.042\001"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:EVAL (.+)$/i
                puts "[ EVAL #{$5} from #{$1}!#{$2}@#{$3} ]"
                send "PRIVMSG #{(($4==@nick)?$1:$4)} :#{evaluate($5)}"                
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:(.+)$/i
                sender = $1   
                allowed = true
                pn = Nick.find_by_nick $1
                if(pn)
                  if(@suspended.include? pn.player.nick)
                    allowed = false
                  end             
                end                
                if(allowed)#($4.strip != "#saihl")
                  if($4.strip == "IHLBot")
                    File.open("whisper_log.txt","a+") {|f| f.write(Time.now.strftime("%m/%d/%Y %H:%M:%S") + " " + s.strip + "\n") }
                  else
                    File.open("log.txt","a+") {|f| f.write(Time.now.strftime("%m/%d/%Y %H:%M:%S") + " " + s.strip + "\n") }
                  end
                  message = $5.split(" ")
                 
                  #* * * * * * * * * * * * * * * * * * * * * * *
                  # Main case.
                  # DOES EVERYTHING!
                  #
                  #
                  #
                  #
                  if (message[0][0] == 33)
                    log_message = Time.now.strftime("[%m/%d/%Y %H:%M:%S]") + " " + $1.strip + ": " + $5 + "\n"
                    @log << log_message
                    if(@log.length > 10)
                      @log.delete(@log.first)
                    end                    
                  end
                  case message[0].downcase                    
                        
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # Player commands.
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # sg 
                    # eg
                    # add
                    # remove
                    # vcap
                    # vlist
                    # game
#------------------## cgame
                    # pl
                    # vp
                    # top10
                    # shittest10
                    # luckiest10
                    # unluckiest10
                    # roll
                    # stats
                    # link
                    # unlink
                    # changeCaps         
                    # contacts
                    # addContact
                    # removeContact   
                    # admins
                    # mik         
                    # help
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !sg
                    # Starts a game if there is no game currently
                    # started
                    #
                    #
                    #
                    when "!sg"
                      if(Nick.find_by_nick $1)
                        if @gamestarted == false
                          @gamestarted = true
                          @trialees = 0
                          send "PRIVMSG #{$1} :Game started!"
                          
                          send "group ihl ann IHL up: use `/w ihlbot !add` to join"
                          send "PRIVMSG #saihl :IHL up: use `/w ihlbot !add` to join"
                        else
                          send "PRIVMSG #{$1} :Game already started!"
                        end
                      else
                         send "PRIVMSG #{$1} :Sorry, you are not registered as part of the SAIHL."
                      end
                      
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !eg
                    # Ends the game if it is empty or
                    # if eg is run by an admin
                    #
                    #
                    #
                    when "!eg"
                      if(Nick.find_by_nick $1)
                        if @gamestarted == true && (@playerlist.size == 0 || Nick.find_by_nick($1).player.cg > 1)
                           @playerlist.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :Game cancelled by an admin!"
                             end
                           end                          
                           @gamestarted = false
                           @playerlist.clear
                           @captains.clear
                           @starting = false
                                                     
                           send "PRIVMSG #{$1} :You have cancelled the game!"                      
                           send "PRIVMSG #saihl :The game has been cancelled!"                      
                           
                        else
                          if @gamestarted == false
                            send "PRIVMSG #{$1} :No Game in progress!"
                          else
                            send "PRIVMSG #{$1} :Game cannot be cancelled by non-admins while players are added!"
                          end
                        end
                      else
                         send "PRIVMSG #{$1} :Sorry, you are not registered as part of the SAIHL."
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !add
                    # Adds a player to the current game.
                    # Does not let more than the maximum number of trialees join.
                    # Does not let more than 10 players join 
                    # 
                    # If 10 players have added it marks the game for starting.
                    #
                    #
                    when "!add"
                      if(Nick.find_by_nick $1)
                        adder = Nick.find_by_nick($1).player
                        if((Time.now - adder.punished_at) > 24.hours) 
                          if @gamestarted == true
                            #send "PRIVMSG #{$1} :This will add!"
                            if @playerlist.size < 10
                              ingame = false
                              @playerlist.each do |p|
                                if p.downcase == adder.nick.downcase
                                  ingame = true
                                end 
                              end
                              
                              unless ingame
                                if(adder.trial == false || @trialees < Integer(@maxtrialees) )
                                  if(adder.trial == true)
                                    @trialees = @trialees + 1
                                  end
                                  @playerlist << adder.nick
                                  send "PRIVMSG #{$1} :You have been added to the game!"
                                  #temp = @source
                                  #@source = "both"
                                  @playerlist.each do |player|
                                   p = Player.find_by_nick player
                                   p.nicks.each do |n|
                                     send "PRIVMSG #{n.nick} :New player (#{adder.nick}) Added!"
                                     send "PRIVMSG #{n.nick} :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                                   end
                                  end
                                  #@source = temp                                
                                  send "PRIVMSG #saihl :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                                  
                                  if @playerlist.size == 10 #start the game
                                     #STAaart
                                     @filltime = Time.now
                                     @starting = true
                                     #temp = @source
                                     #@source = "both"
                                     @playerlist.each do |player|
                                       p = Player.find_by_nick player
                                       p.nicks.each do |n|
                                        send "PRIVMSG #{n.nick} :**The game is full and will start in 1 minute. During this time admins/players can still make changes to the current players."                      
                                       end
                                     end
                                     #@source = temp
                                     send "PRIVMSG #saihl :**The game is full and will start in 1 minute. During this time admins/players can still make changes to the current players."                              
                                  end
                                  
                                else
                                   send "PRIVMSG #{$1} :Sorry the max number of trialees are already in this game."
                                end
                              #main add                            
                              else
                                send "PRIVMSG #{$1} :You are already added to this game!"
                              end
                            else
                              send "PRIVMSG #{$1} :Game is full!"
                            end
                          else
                            send "PRIVMSG #{$1} :No game in progress!"
                          end
                        else
                          send "PRIVMSG #{$1} :You are still punished and cannot join an ihl for another #{24 - Integer((Time.now - Nick.find_by_nick($1).player.punished_at)/60/60)} hours!"
                        end
                      else
                         send "PRIVMSG #{$1} :Sorry, you are not registered as part of the SAIHL."
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !remove
                    # Removes the player from the game waiting to start.
                    # 
                    #
                    #
                    #
                    when "!remove", "!rem"
                      if(Nick.find_by_nick $1)
                        remover = Nick.find_by_nick($1).player        
                        ingame = false
                        @playerlist.each do |p|
                          if p.downcase == remover.nick.downcase
                            ingame = true
                            @playerlist.delete(p)
                          end 
                        end
                        if ingame 
                          if (remover.trial == true)
                            @trialees = @trialees - 1
                          end
                          send "PRIVMSG #{$1} :You have been removed from the game!"
                          #temp = @source
                          #@source = "both"
                          @playerlist.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                               send "PRIVMSG #{n.nick} :#{remover.nick} Removed!"
                               send "PRIVMSG #{n.nick} :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                             end
                          end
                          #@source = temp
                          
                          if(@starting)
                            @starting = false
                            @playerlist.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :Game not full anymore game starting cancelled!"
                             end
                            end
                          end
                          
                                                     
                          send "PRIVMSG #saihl :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                        else
                          send "PRIVMSG #{$1} :You are not in the IHL game"
                        
                        end                      
                      else
                        send "PRIVMSG #{$1} :Sorry, you are not registered as part of the SAIHL."
                        
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !vcap
                    # Voulenteers or Unvolunteers to be a captain in the next game
                    #
                    #
                    #
                    #
                    when "!vcap", "!vc"
                      if(Nick.find_by_nick $1)
                        volunteer = Nick.find_by_nick($1).player
                        unless(volunteer.trial == true)
                          unless @cpt.include? volunteer.nick
                            @cpt << volunteer.nick
                            send "PRIVMSG #{$1} :You have been added to the que of volunteers."
                          else
                            @cpt.delete volunteer.nick
                            send "PRIVMSG #{$1} :You have been removed from the que of volunteers"
                          end
                        else
                          send "PRIVMSG #{$1} :Sorry, you are on trial and trialees cant be captain."
                        end
                      else
                        send "PRIVMSG #{$1} :Sorry, you are not registered as part of the SAIHL."
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !vlist
                    # Lists the current volunteer que
                    #
                    #
                    #
                    #
                    when "!vlist"
                      if(@cpt.size == 0)
                        send "PRIVMSG #{$1} :No current volunteers."
                      else
                        i = 0
                        send "PRIVMSG #{$1} :#{"Current captain volunteer que".center(40,"*")}"
                        send "PRIVMSG #{$1} :#{"Pos".center(5)}#{"Nick".center(35)}"
                        @cpt.each do |c|
                          send "PRIVMSG #{$1} :#{(i+1).to_s.center(5)}#{c.center(35)}"
                          i = i + 1
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !game
                    # Displays the players currently added to the game
                    #
                    #
                    #
                    #
                    when "!game", "!games"
                      if @gamestarted == true
                       send "PRIVMSG #{$1} :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                      else
                       send "PRIVMSG #{$1} :No Game in progress!" 
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !cgame !pl
                    # Shows the information on the started game.
                    # When it started
                    # Who the captains are
                    # Who the players are
                    #
                    when "!cgame", "!playerlist", "!pl" 
                      unless @lastgame.size == 0
                          send "PRIVMSG #{$1} :Started at : #{@startTime.strftime("%I:%M %p on %A %d %B %Y")}" 
                          send "PRIVMSG #{$1} :Captains: #{@lastcaptains.to_a.join(", ")}" 
                          send "PRIVMSG #{$1} :Players: #{@lastgame.join(", ")}" 
                      else
                          send "PRIVMSG #{$1} :No Game being played!"
                      end                    
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !vp
                    # Players in the started game can vote to punish
                    # other players in the current game for various 
                    # reasons
                    # 
                    #
                    when "!vp"
                      if(Nick.find_by_nick $1)
                         vper = Nick.find_by_nick($1).player
                         unless(@lastgame.size == 0)
                           if(@lastgame.include? vper.nick)
                              unless(message[1].blank?)
                                ingame = false
                                @lastgame.each do |p|
                                 if p.downcase == message[1].downcase
                                  ingame = true
                                 end
                                end
                                if(ingame)
                                  if(@voted["#{vper.nick}#{message[1].downcase}"] == "voted")
                                    send "PRIVMSG #{$1} :You have already VP'd that player!"
                                  else
                                    @voted["#{vper.nick}#{message[1].downcase}"] = "voted"
                                    if (Integer(@DNA["#{message[1]}"]) > 5)
                                      send "PRIVMSG #{$1} :That player has already been punished!"
                                    else
                                      @DNA["#{message[1]}"] = Integer(@DNA["#{message[1]}"]) +1
                                      if (Integer(@DNA["#{message[1]}"]) > 5)
                                        p = Nick.find_by_nick(message[1]).player
                                        p.numgames -= 3
                                        p.numcapts -= 1
                                        p.punishes += 1
                                        p.punished_at = Time.now
                                        p.save!
                                        send "PRIVMSG #{$1} :Your vote has been added, that player now has #{@DNA["#{message[1]}"]} VP votes. (6 needed to punish)"
                                        send "PRIVMSG #{message[1]} :6 Players has vouched that you did not show for your game, so you have been punished."
                                         send "PRIVMSG #{message[1]} :Your games played have been reduced by 3, games captained by 1 and you cannot play and IHL for 24 hours"
                                        @lastgame.each do |player|
                                          p = Player.find_by_nick player
                                          p.nicks.each do |n|
                                            send "PRIVMSG #{n.nick} :#{message[1]} has been punished for not showing up for the game!"
                                          end
                                        end
                                        send "PRIVMSG #saihl :#{message[1]} has been punished for not showing up for the game! Make sure if you go AFK that you !remove"
                                      else
                                        send "PRIVMSG #{$1} :Your vote has been added, that player now has #{@DNA["#{message[1]}"]} DNA votes. (6 needed to punish)"
                                        send "PRIVMSG #saihl :#{message[1]} has #{@DNA["#{message[1]}"]} VP votes. (6 needed to punish)"
                                        @lastgame.each do |player|
                                          p = Player.find_by_nick player
                                          p.nicks.each do |n|
                                            send "PRIVMSG #{n.nick} :#{message[1]} has #{@DNA["#{message[1]}"]} VP votes. (6 needed to punish)" 
                                          end
                                        end
                                      end
                                    end
                                  end
                                else
                                send "PRIVMSG #{$1} :That player is not in the current game." 
                                end                              
                              else
                                send "PRIVMSG #{$1} :You have to specify a player to punish."
                              end
                            else
                            send "PRIVMSG #{$1} :You are not in the current game so you cannot DNA somebody."
                           end
                         else
                          send "PRIVMSG #{$1} :There is no current game."
                         end
                      end  
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !top10
                    # Displays the top 10 players sorted by score 
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!top10"
                      @players = Player.find(:all)
                      @players = @players.sort_by(&:points).reverse
                      send "PRIVMSG #{$1} :#{"Top 10".center(64,"*")}"
                      send "PRIVMSG #{$1} :#{"Rank".center(4)}#{"Nick".center(20)}#{"Games Played".center(20)}#{"Games Captained".center(20)}"
                      i = 0
                      10.times do
                        if($2.downcase == "w3xp")
                          send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{" "*3}#{@players[i].nick.center(20)}#{" "*5}#{@players[i].numgames.to_s.center(20)}#{" "*10}#{@players[i].numcapts.to_s.center(20)}"
                        else
                          send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{@players[i].nick.center(20)}#{@players[i].numgames.to_s.center(20)}#{@players[i].numcapts.to_s.center(20)}"
                        end
                        i += 1
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !shittest10
                    # Displays the 10 players with the least games played
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #                    
                    when "!shittest10"                      
                      @players = Player.find(:all)
                      @players = @players.sort_by(&:points)
                      send "PRIVMSG #{$1} :#{"Shittest 10".center(64,"*")}"
                      send "PRIVMSG #{$1} :#{"Rank".center(4)}#{"Nick".center(20)}#{"Games Played".center(20)}#{"Games Captained".center(20)}"
                      i = 0
                      10.times do
                        if($2.downcase == "w3xp")
                          send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{" "*3}#{@players[i].nick.center(20)}#{" "*5}#{@players[i].numgames.to_s.center(20)}#{" "*10}#{@players[i].numcapts.to_s.center(20)}"
                        else
                          send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{@players[i].nick.center(20)}#{@players[i].numgames.to_s.center(20)}#{@players[i].numcapts.to_s.center(20)}"
                        end
                        i += 1
                      end
                      #send "PRIVMSG #{$1} :#{"Shittest 10".center(24,"*")}"
                      #send "PRIVMSG #{$1} :#{"Rank".center(4)}#{"Nick".center(20)}"
                      #i = 0
                      #10.times do
                      #  send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{"Angel".center(20)}"
                      #  i += 1
                      #end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !luckiest10
                    # Displays the top10 players
                    # Sorted by roll win ratio
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!luckiest10"
                      @players = Player.find(:all)
                      @players = @players.sort_by(&:roll_rate).reverse
                      send "PRIVMSG #{$1} :#{"Luckiest 10".center(44,"*")}"
                      send "PRIVMSG #{$1} :#{"Rank".center(4)}#{"Nick".center(20)}#{"Roll Win Rate".center(20)}"
                      i = 0
                      10.times do
                        send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{@players[i].nick.center(20)}#{@players[i].roll_rate.round.to_s.center(20)}"
                        i += 1
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !unluckiest10
                    # Displays the top10 players
                    # Sorted by roll win ratio
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!unluckiest10"
                      @players = Player.find(:all)
                      @players = @players.sort_by(&:roll_rate)
                      send "PRIVMSG #{$1} :#{"Unuckiest 10".center(44,"*")}"
                      send "PRIVMSG #{$1} :#{"Rank".center(4)}#{"Nick".center(20)}#{"Roll Win Rate".center(20)}"
                      i = 0
                      j = 0
                      while(i < 10)
                        if(@players[j].roll_rate >= 0)
                          send "PRIVMSG #{$1} :#{((i+1).to_s + ".").center(4)}#{@players[j].nick.center(20)}#{@players[j].roll_rate.round.to_s.center(20)}"
                        i += 1
                        end
                        j += 1
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !roll
                    # Either rolls agaisnt specified player
                    # or returns a random number out of 100.
                    # 
                    # 
                    #
                    #
                    #
                    when "!roll"
                      unless(message[1].blank?)
                        num1 = rand(100)
                        num2 = rand(100)
                        while(num1 == num2)
                          num2 = rand(100)
                        end
                        roller1 = Nick.find_by_nick($1)
                        roller2 = Nick.find_by_nick(message[1])
                        captains = false
                        if(roller1 && roller2)
                          if(@lastcaptains.include?(roller1.player.nick) && @lastcaptains.include?(roller2.player.nick))
                          captains = true
                          end
                        end
                        
                          
                        if(captains)
                          @lastgame.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :The captains have rolled against each other."
                             end
                          end
                          if(num1 > num2)
                            @lastgame.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :#{$1} has won the roll!"
                             end
                            end
                          else
                            @lastgame.each do |player|
                             p = Player.find_by_nick player
                             p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :#{message[1]} has won the roll!"
                             end
                            end
                          end
                                                   
                        else                       
                          if($1.downcase == message[1].downcase)
                            send "PRIVMSG #{$1} :Rolling against yourself is lonely and sad."
                          else
                            send "PRIVMSG #{$1} :You have rolled against #{message[1]}"
                            send "PRIVMSG #{message[1]} :#{$1} has rolled against you."
                            if(num1 > num2)
                              send "PRIVMSG #{$1} :#{$1} has won the roll."
                              send "PRIVMSG #{message[1]} :#{$1} has won the roll."
                            else
                              send "PRIVMSG #{$1} :#{message[1]} has won the roll."
                              send "PRIVMSG #{message[1]} :#{message[1]} has won the roll."
                            end                      
                          end
                        end
                        unless($1.downcase == message[1].downcase)
                          if(roller1)
                            p1 = Nick.find_by_nick($1).player
                          else
                            p1 = nil
                          end
                          if(roller2)
                            p2 = Nick.find_by_nick(message[1]).player
                          else
                            p2 = nil
                          end
                          if(num1 > num2)                          
                            if(p1)
                              p1.roll_wins = p1.roll_wins + 1
                              p1.save!
                            end
                            if(p2)
                              p2.roll_losses = p2.roll_losses + 1
                              p2.save!
                            end
                          else
                            if(p1)
                              p1.roll_losses = p1.roll_losses + 1
                              p1.save!
                            end
                            if(p2)
                              p2.roll_wins = p2.roll_wins + 1
                              p2.save!
                            end
                          end
                        end
                      else
                        num = rand(100)+1                        
                        send "PRIVMSG #{$1} :On a d100 you rolled #{num}"
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !stats
                    # Returns a players stats.
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!stats"
                      if((Nick.find_by_nick $1 && message[1].blank?) || (Nick.find_by_nick $1))
                        player = Player.new
                        if(message[1].blank?)
                          player = Nick.find_by_nick($1).player
                          send "PRIVMSG #{$1} :Your Stats:"
                        else
                          if(Nick.find_by_nick(message[1]))
                            player = Nick.find_by_nick(message[1]).player
                          else
                            player = nil
                          end
                          send "PRIVMSG #{$1} :Player : #{message[1]}"
                        end
                         if player.blank?
                           send "PRIVMSG #{$1} :Player is not a member of the IHL"
                         else
                           send "PRIVMSG #{$1} :Main Nick: #{player.nick}"
                           send "PRIVMSG #{$1} :Other Nicks: #{(player.nicks.collect(&:nick) - player.nick.to_a).join(" ; ")}"
                           send "PRIVMSG #{$1} :Games Played: #{player.numgames}"
                           send "PRIVMSG #{$1} :Games Captain'd: #{player.numcapts}"
                           if((player.roll_losses + player.roll_wins) != 0)
                             roll_win_rate = ((Float(player.roll_wins) / (Float(player.roll_losses) + Float(player.roll_wins)))*100).round
                             roll_win_rate = roll_win_rate.to_s + "%"
                           else
                            roll_win_rate = "∞"
                           end
                           send "PRIVMSG #{$1} :Roll win rate: #{roll_win_rate} (w:#{player.roll_wins} l:#{player.roll_losses})"
                           send "PRIVMSG #{$1} :On Trial?: #{player.trial ? "Yes" : "No" }"
                           send "PRIVMSG #{$1} :Punishes: #{player.punishes}" 
                           send "PRIVMSG #{$1} :CG Level: #{player.cg}"     
                           pn = Nick.find_by_nick($1)
                           if((pn && pn.player.cg > 1) || (pn && pn.player.id == player.id))
                            if(player.contacts.size == 0)
                              send "PRIVMSG #{$1} :No Contact Info."
                            else
                              send "PRIVMSG #{$1} :Contact Infos:"    
                              player.contacts.each do |c|
                                send "PRIVMSG #{$1} :#{"".center(5)}#{c.contact_type} : #{c.contact_details}"    
                              end
                            end
                           end
                         end
                       end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !link
                    # Links a new nick to an existing player
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!link"
                      p = Player.find_by_nick $1
                      if(p)
                        if(@source == "war3")
                          unless(p.nicks.length > 2) 
                            unless(message[1].blank?)
                              unless(Nick.find_by_nick(message[1]))
                                n = Nick.new
                                n.player_id = p.id
                                n.nick = message[1]
                                n.save!
                                send "group ihl member +#{message[1]}"
                                send "PRIVMSG #{$1} :#{message[1]} has been linked to your account."
                              else                          
                                send "PRIVMSG #{$1} :Sorry that nick is already registed to another player."
                              end
                            else
                              send "PRIVMSG #{$1} :You have to specify a nick to link"                        
                            end
                          else
                            send "PRIVMSG #{$1} :You may only link a maximum of 2 extra nicks."
                          end
                        else
                          send "PRIVMSG #{$1} :You have to be in war3 to link nicks."                        
                        end
                      else
                        send "PRIVMSG #{$1} :Sorry you are not part of the IHL. NOTE: Nicks can only be linked from your main nick"
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !unlink
                    # unlinks a new nick from a player
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!unlink"
                    p = Player.find_by_nick $1
                    if(p)
                      if(@source == "war3")
                        unless(message[1].blank?)
                          n = p.nicks.find_by_nick message[1]
                          if(n)
                            unless(n.nick == p.nick)
                              Nick.delete(n)
                              send "group ihl member -#{message[1]}"
                              send "PRIVMSG #{$1} :Nick #{message[1]} has been unlinked from your account."
                            else
                              send "PRIVMSG #{$1} :You cannot unlink your main nick."
                            end                   
                          else
                            if(p.cg > 1)
                              n = Nick.find_by_nick message[1]
                              if (n)
                                unless(n.nick == n.player.nick)
                                  n.player.nicks.each do |nick|
                                    send "PRIVMSG #{nick.nick} :An admin has unlinked #{message[1]} from your account."                   
                                  end
                                  send "group ihl member -#{message[1]}"
                                  send "PRIVMSG #{$1} :#{n.nick} has been unlinked from #{n.player.nick}."   
                                  Nick.delete(n)                                
                                else
                                  send "PRIVMSG #{$1} :You cannot unlink a main nick."
                                end
                              else
                                send "PRIVMSG #{$1} :Nick #{message[1]} does not exits."                   
                              end
                            else
                              send "PRIVMSG #{$1} :Nick #{message[1]} does not belong to you."                   
                            end
                          end
                        else
                          send "PRIVMSG #{$1} :You have to specify a nick to unlink"                        
                        end
                      else
                          send "PRIVMSG #{$1} :You have to be in war3 to unlink nicks."                        
                        end
                    else
                      send "PRIVMSG #{$1} :Sorry you are not part of the IHL. NOTE: Nicks can only be unlinked from your main nick"
                    end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !changeCaps
                    # Alters the look of the nick
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!changecaps"
                      pn = Nick.find_by_nick $1
                      if(pn)
                        p = pn.player
                        if(p.nick.downcase == message[1].downcase || message[1].blank?)
                          puts message[1]
                          n = Nick.find_by_nick(message[1])
                          n.nick = message[1]
                          n.save!                                                    
                          p.nick = message[1]
                          p.save!                          
                          send "PRIVMSG #{$1} :Your main nick has been altered."
                        else
                          send "PRIVMSG #{$1} :You cannot change your main nick, just the caps."
                        end
                      else
                        send "PRIVMSG #{$1} :Sorry you are not part of the IHL."
                      end
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !contacts
                    # Lists this users contacts
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!contacts", "!contact"
                      pn = Nick.find_by_nick $1
                      if(pn)
                        p = pn.player
                        if(p.contacts.size > 0)
                          send "PRIVMSG #{$1} :#{"Your Contact Details".center(50,"*")}"
                          send "PRIVMSG #{$1} :#{"Contact ID".center(10)}#{"Contact Type".center(20)}#{"Contact Details".center(20)}"
                          p.contacts.each do |c|
                            send "PRIVMSG #{$1} :#{c.id.to_s.center(10)}#{c.contact_type.center(20)}#{c.contact_details.center(20)}"
                          end
                        else
                          send "PRIVMSG #{$1} :You have not set any contacts."
                        end                        
                      else
                        send "PRIVMSG #{$1} :Sorry you are not part of the IHL."
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !addcontact
                    # Lists this users contacts
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!addcontact"
                      pn = Nick.find_by_nick $1
                      if(pn)
                        p = pn.player
                        if(message[1].blank? || message[2].blank?)
                          send "PRIVMSG #{$1} :Usage: !addcontact <contact type> <contact details>"
                          send "PRIVMSG #{$1} :   Eg. !addcontact Cellphone 0829563399"
                          send "PRIVMSG #{$1} : Note: Both <contact type> and <contact details> must not contain spaces."
                        else
                          c = Contact.new
                          c.player_id = p.id
                          c.contact_type = message[1]
                          c.contact_details = message[2]
                          c.save!
                          send "PRIVMSG #{$1} :Contact added."
                        end    
                      else
                        send "PRIVMSG #{$1} :Sorry you are not part of the IHL."
                      end  
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !deletecontact
                    # Lists this users contacts
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!deletecontact"
                      pn = Nick.find_by_nick $1
                      if(pn)
                        p = pn.player
                        if(message[1].blank?)
                          send "PRIVMSG #{$1} :Usage: !deletecontact <contact id>"
                          send "PRIVMSG #{$1} :   Eg. !deletecontact 32"
                        else
                          c = Contact.find_by_id(message[1])
                          if (!(c.blank?) && c.player_id == p.id)
                            c.delete
                            send "PRIVMSG #{$1} :Contact info deleted."
                          else
                            send "PRIVMSG #{$1} :You have specified an invalid Contact ID."
                          end
                        end    
                      else
                        send "PRIVMSG #{$1} :Sorry you are not part of the IHL."
                      end
                    
                    when "!mik"
                      @players = Player.find(:all, :order => "numgames DESC")
                      mik = rand(@players.length)-1
                      send "PRIVMSG #{@players[mik].nick} :#{$1} Thinks your a sexy beast!"            
                    
                    
                    when "!admins"
                      @admins = Player.find(:all, :conditions => ["cg > ? AND cg <= ?",1,10])
                      send "PRIVMSG #{$1} :Admins:"
                      send "PRIVMSG #{$1} :#{@admins.collect(&:nick).join(", ")}"
                      
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # Admin commands.
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # ann 
                    # removePlayer
                    # punishPlayer
                    # unpunishPlayer
                    # newCaptains
                    # addPlayer
                    # addTrialee
#------------------## promoteTrialee
                    # demotePlayer
                    # deletePlayer
                    # maxTrialees
                    # log
                    #
                    #
                    #
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !ann
                    # Announces a message to a group.
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!ann", "!announce"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          message[0] = ""                          
                          #send "PRIVMSG #{$1} :Deprecated (saidin wants you to use): please use `/group ihl announce <message>`"
                          send "PRIVMSG #{$1} :Message has been announced!"
                          unless(message.join.blank?)
                            send "group ihl ann #{$1}: #{(message.join(' ')).to_s}"
                          else
                            send "group ihl ann IHL up: use `/w ihlbot !add` to join"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !removePlayer
                    # Removes that player from the current game
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!removeplayer", "!rp"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          done = false
                          removee = Nick.find_by_nick(message[1])
                          if(removee)
                            if(@playerlist.include? removee.player.nick)
                             @playerlist.delete removee.player.nick
                              @trialees = @trialees-1 if removee.player.trial == true
                              done = true
                            end
                          end
                          if(done == false)
                            send "PRIVMSG #{$1} :Player #{message[1]} is not currently in the pickup."
                          else
                            send "PRIVMSG #{$1} :#{message[1]} has been removed from the IHL game."
                            removee.player.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :You have been kicked from the IHL game."                          
                            end
                            #temp = @source
                            #@source = "both"
                            @playerlist.each do |player|
                              p = Player.find_by_nick player
                              p.nicks.each do |n|
                                send "PRIVMSG #{n.nick} :#{message[1]} has been removed from the IHL game." 
                                send "PRIVMSG #{n.nick} :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}" 
                              end
                            end
                            #@source = temp
                            send "PRIVMSG #saihl :Current Players: (#{@playerlist.size.to_s}) #{@playerlist.to_a.join(", ")}"
                            
                            if(@starting == true)
                              @starting = false
                              @playerlist.each do |player|
                               p = Player.find_by_nick player
                               p.nicks.each do |n|
                                send "PRIVMSG #{n.nick} :Game not full anymore game starting cancelled!"
                               end
                              end
                            end 
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !punish
                    # Punishes a player
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!punish"
                    if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          pn = Nick.find_by_nick(message[1])
                          if(pn)
                            p = Nick.find_by_nick(message[1]).player
                          else
                            p = nil
                          end
                          if(p)
                            p.numgames -= 3
                            p.numcapts -= 1
                            p.punishes += 1
                            p.punished_at = Time.now
                            p.save!
                            send "PRIVMSG #{$1} :#{message[1]} has been punished"
                            p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :You have been punished by #{$1}!"
                              send "PRIVMSG #{n.nick} :Your games played have been reduced by 3, games captained by 1 and you cannot play and IHL for 24 hours"
                            end
                          else
                            send "PRIVMSG #{$1} :#{message[1]} does not exist in the IHL"
                          end
                        end
                    end
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !unpunishPlayer
                    # Removes a players punish
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!unpunish"
                    if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          pn = Nick.find_by_nick(message[1])
                          if(pn)
                            p = Nick.find_by_nick(message[1]).player
                          else
                            p = nil
                          end
                          if(p)
                            if(p.punishes != 0)
                              p.numgames += 3
                              p.numcapts += 1
                              p.punishes -= 1
                              p.punished_at = '2009-05-01 00:00:00'
                              p.save!
                              send "PRIVMSG #{$1} :#{message[1]} has been unpunished"
                              p.nicks.each do |n|
                                send "PRIVMSG #{n.nick} :You have been unpunished by #{$1}!"
                              end
                            else
                              send "PRIVMSG #{$1} :#{message[1]} does not have any punishments to unpunish"
                            end
                          else
                            send "PRIVMSG #{$1} :#{message[1]} does not exist in the IHL"
                          end
                        end
                    end
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !newCaptains
                    # Randomly generates new captains
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!newcaptains", "!nc"
                      if(Nick.find_by_nick $1)
                        unless @lastgame.size == 0
                          if((Nick.find_by_nick $1).player.cg > 1)
                            possible_captains = Set.new
                            @lastgame.each do |player|
                              #puts "#{player} : #{Player.find_by_nick(player).trial}"
                              if(Nick.find_by_nick(player).player.trial == false)
                                #puts "Added to possible captains"
                                possible_captains = possible_captains + player
                              end
                            end                           
                            
                            @lastcaptains.each do |captain|
                              c = Player.find_by_nick captain
                              c.numcapts -= 1
                              c.save!
                            end
                                                        
                            unless(@cpt.size == 0)
                              if(@cpt.size == 1)
                                rand1 = rand(possible_captains.length)
                                while(@cpt.first.downcase == possible_captains.to_a[rand1].downcase)
                                  rand1 = rand(possible_captains.length)
                                end
                                @lastcaptains = Set.new
                                @lastcaptains = @lastcaptains + possible_captains.to_a[rand1] + @cpt.first
                                @cpt.delete(@cpt.first)
                              else
                                @lastcaptains = Set.new
                                2.times do
                                  @lastcaptains = @lastcaptains + @cpt.first
                                  @cpt.delete(@cpt.first)
                                end
                              end
                            
                            else
                              rand1 = rand(possible_captains.length)
                              while (@notme && possible_captains.to_a[rand1] == "SixiS")
                                rand1 = rand(possible_captains.length)
                              end
                              rand2 = rand(possible_captains.length)
                              while ((rand1 == rand2) || (@notme && possible_captains.to_a[rand2] == "SixiS"))                                              
                                  rand2 = rand(possible_captains.length)                             
                              end
                              @lastcaptains = Set.new
                              @lastcaptains = @lastcaptains + possible_captains.to_a[rand1] + possible_captains.to_a[rand2]
                            end    
                            
                            #print out captains and players to all players in game                                                  
                            
                            @lastgame.each do |player|
                              p = Player.find_by_nick player
                              p.nicks.each do |n|
                                send "PRIVMSG #{n.nick} :-New Capatains have been chosen!-"
                                send "PRIVMSG #{n.nick} :Captains: #{@lastcaptains.to_a.join(", ")}" 
                              end
                            end
                            
                            @lastcaptains.each do |captain|
                              c = Player.find_by_nick captain
                              c.numcapts += 1
                              c.save!
                            end
                          
                          end
                        else
                          send "PRIVMSG #{$1} :-No game in progress!-"
                        end
                     end
                      
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !addPlayer
                    # Adds a full player to the SAIHL database
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!addplayer"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          if(Nick.find_by_nick message[1])
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" already exists in the IHL"
                          else
                            p = Player.new
                            p.nick = message[1]
                            p.trial = 0
                            n = Nick.new
                            n.nick = message[1]
                            p.nicks << n
                            p.save!
                            send "group ihl member +#{message[1]}"
                            send "PRIVMSG #{$1} :Player #{message[1]} added to the IHL"
                            send "PRIVMSG #{message[1]} :You have been added to the IHL!"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !addTrialee
                    # Adds a trialee to the database.
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!addtrialee"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          if(Nick.find_by_nick message[1])
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" already exists in the IHL"
                          else
                            p = Player.new
                            p.nick = message[1]
                            p.trial = 1
                            n = Nick.new
                            n.nick = message[1]
                            p.nicks << n
                            p.save!
                            send "group ihl member +#{message[1]}"
                            send "PRIVMSG #{$1} :Trialee #{message[1]} added to the IHL"
                            send "PRIVMSG #{message[1]} :You have been added to the IHL on a trial basis!"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !promoteTrialee
                    # Promotes specified trialee to a full players
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!promotetrialee"
                        if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          if(Nick.find_by_nick message[1])
                            if((Nick.find_by_nick message[1]).player.trial == false)
                              send "PRIVMSG #{$1} :Player \"#{message[1]}\" is not on trial."
                            else
                              p = Nick.find_by_nick(message[1]).player
                              p.trial = false
                              p.save!
                              send "PRIVMSG #{$1} :Player \"#{message[1]}\" promoted from trialee status"
                              p.nicks.each do |n|
                                send "PRIVMSG #{n.nick} :You have been promoted from trialee status :)"
                              end
                            end
                          else
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" does not exists in the IHL"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !demotePlayer
                    # Demotes specified player to a trialee
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!demoteplayer"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          if(Nick.find_by_nick message[1])
                            if((Nick.find_by_nick message[1]).player.trial == true)
                              send "PRIVMSG #{$1} :Player \"#{message[1]}\" is already on trial."
                            else
                              p = Nick.find_by_nick(message[1]).player
                              p.trial = true
                              p.save!
                              send "PRIVMSG #{$1} :Player \"#{message[1]}\" demoted to trialee status"
                              p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :You have been demoted to trialee status :("
                              end
                            end
                          else
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" does not exists in the IHL"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !deletePlayer
                    # Delete's specified player from the DB
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!deleteplayer"
                        if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)
                          pn = Nick.find_by_nick(message[1])
                          if(pn)
                            p = Nick.find_by_nick(message[1]).player
                          else
                            p = nil
                          end
                          if(p)
                            p.nicks.each do |n|
                              send "PRIVMSG #{n.nick} :You have been removed from the IHL by #{$1}"
                              Nick.delete(n)
                            end
                            Player.delete(p)                            
                            send "group ihl member -#{message[1]}"
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" removed from the IHL"                            
                          else
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" does not exists in the IHL"
                          end
                        end
                      end
                      
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !maxTrialees
                    # Sets the max number of trialees allowed in this game
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!maxtrialees"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)                        
                          if(message[1].blank?)
                            send "PRIVMSG #{sender} :Max Trialees : #{@maxtrialees}"             
                          else                            
                            if(/^([1-9])*$/.match(message[1]))                               
                              @maxtrialees = message[1]
                              send "PRIVMSG #{sender} :Max Trialees set to #{@maxtrialees}"             
                            else
                              send "PRIVMSG #{sender} :Maxtrialees must be set to a number less than 8!"             
                            end               
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !log
                    # Displays the last 10 commands used
                    # 
                    # 
                    # 
                    #
                    #
                    #
                    #
                    when "!log"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1) 
                          @log.each do |l|
                            send "PRIVMSG #{$1} :#{l}"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # Super Admin commands.
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # kick
                    # ban
                    # unban
#------------------## op
                    # deop
                    # moderate
                    #
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !kick
                    # Kicks specified player from the channel
                    # 
                    # 
                    # 
                    when "!kick"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "KICK #saihl #{message[1]} :Kicked by #{$1}."
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !ban
                    # Ban's specified player from the channel
                    # 
                    # 
                    # 
                    when "!ban"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "BAN #{message[1]} :Banned by #{$1}."
                            send "PRIVMSG #{$1} :#{message[1]} has been banned."
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !unban
                    # Unbans specified player
                    # 
                    # 
                    # 
                    when "!unban"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "UNBAN #{message[1]}"
                            send "PRIVMSG #{$1} :#{message[1]} has been unbanned."
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !op
                    # gives specified player chan ops
                    # 
                    # 
                    # 
                    when "!op"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "OP #{message[1]}"
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !deop
                    # Takes operator from specified player
                    # 
                    # 
                    # 
                    when "!deop"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "DEOP #{message[1]}"
                        end
                      end
                     
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !moderate
                    # moderates the channel
                    # 
                    # 
                    # 
                     when "!moderate"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 2)                        
                            send "MODERATE"
                        end
                      end
                    
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # Other commands.
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # setcg
                    # remindplayers
                    # getip
#------------------## spam
                    # updateplayers
                    # 
                    #
                    #
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !setcg
                    # Sets specified players cg to the cg specified
                    # 
                    # 
                    # 
                    when "!setcg"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg == 10)
                          if(Nick.find_by_nick message[1])
                              p = Nick.find_by_nick(message[1]).player
                              p.cg = message[2]
                              p.save!
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" CG level set to #{message[2]}"
                            send "PRIVMSG #{message[1]} :Your CG level has been set to #{message[2]}"
                          else
                            send "PRIVMSG #{$1} :Player \"#{message[1]}\" does not exists in the IHL"
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !remindplayers
                    # Reminds players in the game to join
                    # 
                    # 
                    # 
                    when "!remindplayers"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg > 1)                        
                            @lastgame.each do |player|
                              send "PRIVMSG #{player} :Your game has started, please join."
                              
                            end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !getip
                    # Returns the bots local ip
                    # if a random parameter is given it returns the
                    # international ip
                    # 
                    when "!getip"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg == 10)
                          if(message[1].blank?)
                            send "PRIVMSG #{$1} :#{local_ip}"
                          else
                            send "PRIVMSG #{$1} :#{international_ip}"
                          end
                        end
                      end
                      
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !spam
                    # Spams specified player
                    # 
                    # 
                    # 
                    when "!spam"
                      if(Nick.find_by_nick $1)
                        if((Nick.find_by_nick $1).player.cg == 10)
                          unless((Nick.find_by_nick $1).player.cg > 4)
                            100.times do
                              send "PRIVMSG #{message[1]} :#{$1*16}"
                            end
                          else
                            message.delete(message[0])
                            spamee = message[0]
                            message.delete(message[0])                            
                            100.times do
                              unless(message[0].blank?)
                                send "PRIVMSG #{spamee} :#{message.join(" ")*16}"
                              else
                                send "PRIVMSG #{spamee} :#{$1*16}"
                              end
                            end
                          end
                          send "PRIVMSG #{$1} :#{spamee} has been spammed!"
                        else
                          send "PRIVMSG #{$1} :Sorry, you do not have access to that command"
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
                    # !updateplayers
                    # Creates a nick for each player from their default nick
                    # 
                    # 
                    # 
                    when "!updateplayers"
                      if(Player.find_by_nick $1)
                        if((Player.find_by_nick $1).cg == 10)
                          p = Player.find(:all)
                          p.each do |pl|
                            unless(Nick.find_by_nick(pl.nick))
                              n = Nick.new
                              n.player_id = pl.id
                              n.nick = pl.nick
                              n.save!
                            end
                          end
                        end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
                    # !suspend
                    # Suspends that user from bot use
                    # 
                    # 
                    # 
                    when "!suspend"
                      if(Nick.find_by_nick $1)
                          if(Nick.find_by_nick($1).player.cg > 4)
                            pn = Nick.find_by_nick message[1]
                            if(pn)
                              @suspended << pn.player.nick
                              send "PRIVMSG #{$1} :#{message[1]} has been suspended"
                              send "PRIVMSG #{message[1]} :#{$1} has suspended you from using the bot."
                            else
                              send "PRIVMSG #{$1} :#{message[1]} is not in the IHL"
                            end
                          else
                            send "PRIVMSG #{$1} :Sorry, you do not have access to that command"
                          end
                      end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
                    # !unsuspend
                    # Unsuspends a user
                    # 
                    # 
                    #  
                    when "!unsuspend"
                      if(Nick.find_by_nick $1)
                          if(Nick.find_by_nick($1).player.cg > 4)
                            pn = Nick.find_by_nick message[1]
                            if(pn)
                              if(@suspended.include? pn.player.nick)
                                @suspended.delete pn.player.nick
                                send "PRIVMSG #{$1} :#{message[1]} has been unsuspended"
                                send "PRIVMSG #{message[1]} :#{$1} has lifted your suspension."
                              else
                                send "PRIVMSG #{$1} :#{message[1]} was not suspended"
                              end
                            else
                              send "PRIVMSG #{$1} :#{message[1]} is not in the IHL"
                            end
                          else
                            send "PRIVMSG #{$1} :Sorry, you do not have access to that command"
                          end
                      end
                      
                    when "!notme"
                       if(Nick.find_by_nick $1)
                          if(Nick.find_by_nick($1).player.cg == 10)
                            if(@notme == false)
                              send "PRIVMSG #{$1} :notme set to true"
                              @notme = true;
                            else
                              send "PRIVMSG #{$1} :notme set to false"
                              @notme = false;
                            end
                          end
                        end
                    
                    #* * * * * * * * * * * * * * * * * * * * * * *
                    # !help
                    # Shows help for the bot
                    # 
                    # 
                    # 
                    when "!help"
                      if(Nick.find_by_nick $1)
                        send "PRIVMSG #{$1} :--HELP--"
                        send "PRIVMSG #{$1} :Welcome to the SAIHL please use the commands below ;)"
                        send "PRIVMSG #{$1} :"
                        send "PRIVMSG #{$1} :--Commands--"
                        send "PRIVMSG #{$1} :!sg - Starts a game"
                        send "PRIVMSG #{$1} :!eg - Cancels a game if its empty"
                        send "PRIVMSG #{$1} :!add - Adds you to the game"
                        send "PRIVMSG #{$1} :!remove - Removes you from the game"
                        send "PRIVMSG #{$1} :!vcap - Voulenteers or Unvolunteers to be a captain in the next game you play in."
                        send "PRIVMSG #{$1} :!vlist - Shows who has currently volunteered for captain."
                        send "PRIVMSG #{$1} :!game - Shows you the players currently added"
                        send "PRIVMSG #{$1} :!cgame - Shows you the currently playing (already started) games players and captains"
                        send "PRIVMSG #{$1} :!playerlist or !pl - Shows you the currently playing (already started) games players and captains"
                        send "PRIVMSG #{$1} :!vp <nick> - Add a vote for a player that did not arrive for the game (6 votes = punish)."
                        send "PRIVMSG #{$1} :!top10 - Shows the rankings w.r.t number of games played"
                        send "PRIVMSG #{$1} :!shittest10 - Shows the 10 least tank players."
                        send "PRIVMSG #{$1} :!luckiest10 - Shows the rankings w.r.t roll win rate"
                        send "PRIVMSG #{$1} :!unluckiest10 - Shows the 10 least tank players."
                        send "PRIVMSG #{$1} :!roll <nick> - Roll against a player to see who wins."
                        send "PRIVMSG #{$1} :!stats [nick] - Prints the stats for that player. Returns your stats if no [nick] is given."
                        send "PRIVMSG #{$1} :!link <nick> - Links given nick to your main nick."
                        send "PRIVMSG #{$1} :NOTE: YOU MUST BE ON YOUR MAIN NICK AND ON WAR3"
                        send "PRIVMSG #{$1} :!unlink <nick> - un-links given nick from your main nick."
                        send "PRIVMSG #{$1} :NOTE: YOU MUST BE ON YOUR MAIN NICK AND ON WAR3"
                        send "PRIVMSG #{$1} :!changeCaps <nick> - Lets you change the way your main nick looks (not change the nick itself)"                                           
                        send "PRIVMSG #{$1} :!contacts - Displays your contact information"
                        send "PRIVMSG #{$1} :!addContact <contact type> <contact details> - Adds a contact, there must be no spaces in the type or details"
                        send "PRIVMSG #{$1} :!deleteContact <contact id> - Deletes the contact"                       
                        send "PRIVMSG #{$1} :!admins - Displays a list of all the admins"
                        
                        send "PRIVMSG #{$1} :!help - Shows this help text"
                        
                        if((Nick.find_by_nick $1).player.cg > 1)
                          send "PRIVMSG #{$1} :"
                          send "PRIVMSG #{$1} :--Admin Commands--"
                          send "PRIVMSG #{$1} :!ann <message>    -   Announces Message"
                          send "PRIVMSG #{$1} :!removePlayer <nick> or !rp <nick> -  Removes the player from the current IHL game"
                          send "PRIVMSG #{$1} :!punish <nick> -  Punishes the player by removing 3 games played 1 games captained and bans them for 24 hours"
                          send "PRIVMSG #{$1} :!unpunish <nick> -  Removes one of that players punishments"
                          send "PRIVMSG #{$1} :!newCaptains or !nc  -  Picks new captains for the current game."
                          send "PRIVMSG #{$1} :!addPlayer <nick>  -  Adds player to database"
                          send "PRIVMSG #{$1} :!addTrialee <nick>   -  Adds player to database as trialee"
                          send "PRIVMSG #{$1} :!promoteTrialee <nick>  -  Promotes trialee to player."
                          send "PRIVMSG #{$1} :!demotePlayer <nick>  -  Demotes player to trail status."
                          send "PRIVMSG #{$1} :!deletePlayer <nick>  -  Removes player from the IHL."
                          send "PRIVMSG #{$1} :!maxTrialees [number]  -  Sets the max number of trialees. If no number is given it displays the max trialees."
                          send "PRIVMSG #{$1} :!log - Shows the last 10 commands used."
                          send "PRIVMSG #{$1} :!unlink <nick> - un-links given nick any player. NOTE: YOU MUST BE ON YOUR MAIN NICK AND ON WAR3"
                        end
                        if((Nick.find_by_nick $1).player.cg > 2)
                          send "PRIVMSG #{$1} :"
                          send "PRIVMSG #{$1} :--Super Admin Commands--"
                          send "PRIVMSG #{$1} :!kick <nick>  -  Kicks player from the SAIHL channel."
                          send "PRIVMSG #{$1} :!ban <nick>  -  Bans player from the SAIHL channel."
                          send "PRIVMSG #{$1} :!unban <nick>  -  Removes the ban from the SAIHL channel."
                          send "PRIVMSG #{$1} :!op <nick>  -  Gives <nick> chanops."
                          send "PRIVMSG #{$1} :!deop <nick>  -  Removes chanops from <nick>."
                          send "PRIVMSG #{$1} :!moderate <nick>  -  Moderates or Un-moderates the channel."
                          
                        end
                        
                        send "PRIVMSG #{$1} :"
                        send "PRIVMSG #{$1} :--Notes--"
                        send "PRIVMSG #{$1} :This bot is VERY beta... please msg SixiS if you find anything wrong with it."
                        send "PRIVMSG #{$1} :DONT !mik THE BOT!!!!."
                      
                      else
                        send "PRIVMSG #{$1} :--HELP--"
                        send "PRIVMSG #{$1} :You are not registered as part of the South African In House League"
                        send "PRIVMSG #{$1} :To join the league, please goto www.war3.co.za/forum and read up about the league under the \"Dota Allstars\" - \"IHL\" Section."
                        send "PRIVMSG #{$1} :If you are supposed to be in the league, please msg SixiS or Scant to get added to this bot."
                      end
                      
                  else #end case                
                    #puts s
                  end
                  
                  #send "PRIVMSG #saihl :#{$5}"
                else
                  send "PRIVMSG #{$1} :Sorry, but you are suspended from bot use."
                end #end if true
            else                
                puts s
        end
    end
    def main_loop()
      @players = Player.find(:all, :order => "numgames DESC")
      @trialees = 0                         #number of trialees currently in the game
      @gamestarted = false                  #Bool for wether the game has started yet
      @playerlist = Set.new                 #Set for the current player list
      @startTime = 0                        #Record for when the game stars
      #@playerlist = @playerlist + "1" + "2" + "3" + "4" + "5" + "6" + "7" + "8" + "9"
      @captains = Set.new                   #Set for the captains
      @lastgame = []                        #Array of the last games players
      @lastcaptains = []                    #Array for the last games captains
      @maxtrialees = "2"                    #Variable for the max number of trialees
      @filltime = Time.now                  #Time when the game filled
      @starting = false                     #bool for if the game is full
      @DNA = {}                             #Hash for recording a players VP votes
      @cpt = []                             #set for voulenteer captains
      @voted = {}                           #Hash to record who has VP'd who
      @suspended = []
      @source = "war3"      
      @initialising = false
      @notme = false
      @log = SortedSet.new                        #array to hold the last 10 commands run
      # Just keep on truckin' until we disconnect
        while true
            if @starting
              if ((Time.now-@filltime) > 60.seconds)
               puts "game starting"
                #start the game
                #randomly choose 2 captains
                possible_captains = Set.new
                @playerlist.each do |player|
                  #puts "#{player} : #{Player.find_by_nick(player).trial}"
                  if(Player.find_by_nick(player).trial == false)
                    #puts "Added to possible captains"
                    possible_captains = possible_captains + player
                  end
                end                           
                
                unless(@cpt.size == 0)
                  if(@cpt.size == 1)
                    rand1 = rand(possible_captains.length)
                    while(@cpt.first.downcase == possible_captains.to_a[rand1].downcase)
                      rand1 = rand(possible_captains.length)
                    end
                    @captains = @captains + possible_captains.to_a[rand1] + @cpt.first
                    @cpt.delete(@cpt.first)
                  else
                    2.times do
                      @captains = @captains + @cpt.first
                      @cpt.delete(@cpt.first)
                    end
                  end
                
                else
                  rand1 = rand(possible_captains.length)
                  while (@notme && possible_captains.to_a[rand1] == "SixiS")
                    rand1 = rand(possible_captains.length)
                  end
                  rand2 = rand(possible_captains.length)
                  while ((rand1 == rand2) || (@notme && possible_captains.to_a[rand2] == "SixiS"))                             
                      rand2 = rand(possible_captains.length)                             
                  end
                  @captains = @captains + possible_captains.to_a[rand1] + possible_captains.to_a[rand2]
                end              
                
                
                            
              #print out captains and players to all players in game                                                             
                @source = "war3"
                @playerlist.each do |player|
                  p = Player.find_by_nick(player)
                  p.numgames = p.numgames+1
                  p.save!
                  p.nicks.each do |n|
                    send "PRIVMSG #{n.nick} :****************************************"
                    send "PRIVMSG #{n.nick} :-Teams Finalised And game is starting! Captains and Players below!-"
                    send "PRIVMSG #{n.nick} :Captains: #{@captains.to_a.join(", ")}" 
                    send "PRIVMSG #{n.nick} :Players: #{@playerlist.to_a.join(", ")}"
                    send "PRIVMSG #{n.nick} :-Please join the game!-"
                    send "PRIVMSG #{n.nick} :****************************************"
                  end                      
                end     
                    
                send "PRIVMSG #saihl :****************************************"
                send "PRIVMSG #saihl :-Teams Finalised And game is starting! Captains and Players below!-"
                send "PRIVMSG #saihl :Captains: #{@captains.to_a.join(", ")}" 
                send "PRIVMSG #saihl :Players: #{@playerlist.to_a.join(" ")}"
                send "PRIVMSG #saihl :-Please join the game!-"
                send "PRIVMSG #saihl :****************************************"
                
                  #move lists to lastgame 
                @captains.each do |captain|
                  c = Player.find_by_nick captain
                  c.numcapts += 1
                  c.save!
                end
                                               
                @lastgame = @playerlist.to_a
                @lastcaptains = @captains.to_a  
                @startTime = Time.now
                @playerlist.clear
                @captains.clear
                @DNA.clear
                @voted.clear
                @maxtrialees = 2
                @gamestarted = false
                @starting = false                
              end
            end           
            ready = select([@irc, @irc2, $stdin], nil, nil, 0.2)            
            next if !ready   
            if (ready)
            for s in ready[0]
                if s == $stdin then
                    return if $stdin.eof
                    s = $stdin.gets
                    send s
                elsif s == @irc then
                    return if @irc.eof
                    s = @irc.gets
                    @source = "war3"
                    handle_server_input(s)  
                elsif s == @irc2 then
                    return if @irc2.eof
                    s = @irc2.gets
                    @source = "irc"
                    handle_server_input(s)                 
                end
            end
            end
        end
    end
end

# The main program
# If we get an exception, then print it out and keep going (we do NOT want
# to disconnect unexpectedly!)
irc = IRC.new('war3.co.za', 5454, 'IHLBot', 'nothello' , '#saihl')
irc.connect()
begin
    irc.main_loop()    
rescue Interrupt
rescue Exception => detail
    puts detail.message()
    print detail.backtrace.join("\n")
    ActiveRecord::Base.establish_connection(:adapter => "mysql", :host => "localhost", :database => "saihl") if detail.to_s =~ /away/   
    retry
end

