#!/usr/bin/env ruby
require 'rubygems'
require 'net/ssh'
require 'pp'

module SSHTunnel
  class Connector
    attr_reader :connections, :local_ports

    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG 

    def initialize
      @connections = {}
      @@local_ports ||= []
    end

    # Nasty way to get keyboard-interactive password
    # The Net::SSH way never worked for some reason 
    def get_password host,username
      print "Password for "+username+"@"+host+": "
      system "stty -echo"
      pw = gets.delete("\n")
      system "stty echo"
      puts
      pw
    end

    # Opens an SSH Tunnel to the given host with the given username
    # Also checks whether a localhost port-forward exists for that 
    # host and uses that for connection if it does  
    def connect (host, username,port=22)
      begin
        pw = get_password(host, username)

        tunnelhost = host
        if @connections.key?(host.to_sym)
          port = @connections[host.to_sym]
          tunnelhost = 'localhost'
          @@log.debug("Found local-port forward on port "+port.to_s) 
        end

        @connections[host.to_sym] = Net::SSH.start(tunnelhost, username, :password => pw, :port => port)
      rescue Net::SSH::AuthenticationFailed
        retry
      end
    end

    # Spins off a new thread for the ssh-connection, to keep it open
    def activate_ssh_loop symbol
      @connections[symbol][:thread] = Thread.new(@connections[symbol]) {|c| c.loop {true}}
    end

    # Register a localport forward with our connections and local_ports list
    # to maintain order
    def register_ssh_forward from,to,localport,toport
      @connections[to] ||= localport
      @connections[from][:thread].exit! unless @connections[from][:thread].nil?
      @connections[from].forward.local(localport, to, toport)
      @@local_ports << localport
    end

    # This will automatically choose a local port between 2000 and 4000 if
    # not passed one explicitely. This leaves all other ranges open for 
    # manual port use. However, you are free to use a port in that range 
    # as well, the choice will be overridden if that port is already taken
    def forward (from, to, port_options = {})
      remoteport = port_options[:remote] || 22
      localport = port_options[:local]
      while (@@local_ports.include?(localport) || localport.nil?) do
	 localport = ((rand + 1) * 2000).round
      end
      @@log.debug("Adding forwarding to "+to+":"+remoteport.to_s+" on local port "+localport.to_s)

      register_ssh_forward(from.to_sym, to.to_sym, localport, remoteport)
      activate_ssh_loop(from.to_sym)
    end

    # Wait untill all open threads exit - the means for keeping connections open 
    def joinall
      @connections.each do |k,v|
	v[:thread].join
      end
    end

    # Kill all threads thus closing all open connections and resetting the tunnel
    def killall
       begin
	  @connections.each do |k,v| 
	     v[:thread].exit! unless v[:thread].nil?
	     v.shutdown!
	  end
       rescue Exception
       end
       initialize
    end
  end

  class Chain
    attr_reader :chain

    module Service
      class << self
        def new hostport,hostname,localport
	  Proc.new do |forwarder, last_host| 
            forwarder.forward(last_host, hostname, 
            {:local => localport, :remote => hostport})
	    last_host
	  end
        end

        {:vnc => 5900, :smb => 139,
         :rdesktop => 3389, :ssh => 22}.each do |k,v|
	  define_method(k) { |hostname| new(v,hostname,v) }
        end
      end
    end

    module Host
      def self.new hostname,username,ports={}
	localport = ports
	remoteport = ports[:remote] || 22
	Proc.new do |forwarder, last_host|
	  forwarder.forward(last_host, hostname, localport) unless last_host.nil?
          forwarder.connect(hostname, username, remoteport)
	  hostname
	end
      end
    end

    def initialize 
      @forwarder = Connector.new
      @chain = []
    end

    def << host_or_service
      push(host_or_service)
    end

    def push(*a_proc)
      @chain.push *a_proc
      self
    end

    def dequeue
      @chain = @chain[1..-1] 
      self
    end

    def split &block
      @chain << Proc.new do |forwarder, last_host|
	execute(block.call(Chain.new).chain, last_host)
	last_host
      end
    end

    def execute chain=@chain,last_host=nil
      chain.each do |item|
        last_host = item.call(@forwarder, last_host)
      end
      begin 
	 print "Chain running, type exit to quit> "
	 STDOUT.flush
	 input = gets.delete("\n").downcase
      end while input != "exit"
      @forwarder.killall
    end
  end

  class Configuration
    def initialize filepath="default"
      if File.exists? filepath
        parse filepath
      else
        parse "#{ENV["HOME"]}/.ssh/#{filepath}"
      end
    end

    def construct_chain
    end

    def parse file
      File.open(file).read.split("---") do |entry|
        h = YAML.load(entry)
        type = h.keys.first
        hostname = h.values.first[:hostname]
        username = h.values.first[:username]
        port = h.values.first[:port] || {}
        SSHTunnel::Chain.const_get(type).new(hostname, username, port)
      end
    end
  end
end

chain = SSHTunnel::Chain.new
#chain << SSHTunnel::Chain::Host.new('timfelgentreff.homelinux.org', 'timfelgentreff', {:remote => 2223})
#chain << SSHTunnel::Chain::Host.new('ssh-stud.hpi.uni-potsdam.de', 'tim.felgentreff')
#chain << SSHTunnel::Chain::Service.new(22,'172.16.23.120',4002)
#chain << SSHTunnel::Chain::Service.new(22,'hadoop09ws10',4001)
#chain << SSHTunnel::Chain::Service.new(50070,'hadoop09ws02',50070)
#chain << SSHTunnel::Chain::Service.new(50030,'hadoop09ws02',50030)
#chain << SSHTunnel::Chain::Host.new('placebo', 'tim.felgentreff')
#chain << SSHTunnel::Chain::Host.new('dhcpserver', 'timfel')
chain << SSHTunnel::Chain::Service.new(22, "bp2009h1ws03", 4001)
#chain << SSHTunnel::Chain::Service.smb("fs2") # Needs root privileges
#chain.split do |myTwig| 
#  myTwig << SSHTunnel::Chain::Host.new('hadoop09ws02', 'hadoop01', 1234) 
#end
#chain << SSHTunnel::Chain::Service.vnc('timfelgentreff.homelinux.org')
#chain << SSHTunnel::Chain::Service.new(4567, "timfelgentreff.homelinux.org", 4567)
chain.execute
