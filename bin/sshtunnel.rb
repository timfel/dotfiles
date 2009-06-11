#!/usr/bin/env ruby19
require 'rubygems'
require 'net/ssh'
require 'pp'

module SSHTunnel
  class Connector
    attr_reader :jobs, :local_ports

    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG 

    def initialize
      @connections = {}
      @@local_ports ||= []
      puts @@local_ports
    end

    def get_password host,username
      print "Password for "+username+"@"+host+": "
      system "stty -echo"
      pw = gets.delete("\n")
      system "stty echo"
      puts
      pw
    end

    def connect (host, username)
      pw = get_password(host, username)

      if @connections.key?(host.to_sym)
        port = @connections[host.to_sym]
	host = 'localhost'
        @@log.debug("Found local-port forward on port "+port.to_s) 
      end
      @connections[host.to_sym] = Net::SSH.start(host, username, :password => pw, :port => port)
    end

    def activate_ssh_loop symbol,port
      @connections[symbol][:thread] = Thread.new(@connections[symbol]) {|c| c.loop {true}}
    end

    def register_ssh_forward from,to,localport,toport
      @connections[to] ||= localport
      @connections[from][:thread].exit! unless @connections[from][:thread].nil?
      @connections[from].forward.local(localport, to, toport)
    end

    def forward (from, to, port_options = {})
      remoteport = port_options[:remote] || 22
      begin
        localport = port_options[:local] || ((rand + 1) * 2000).round
      end while @@local_ports.include?(localport)
      @@log.debug("Adding forwarding to "+to+":"+remoteport.to_s+" on local port "+localport.to_s)

      register_ssh_forward(from.to_sym, to.to_sym, localport, remoteport)
      activate_ssh_loop(from.to_sym, localport)
    end

    def killall
      @connections.each do |k,v| 
        v[:thread].exit! unless v[:thread].nil?
        v.shutdown!
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
         :rdesktop => 3389, :ssh => 22,
         :ftp => 21}.each do |k,v|
	  define_method(k) { |hostname| new(v,hostname,v) }
        end
      end
    end

    module Host
      def self.new hostname,username,port=nil
	localport = {}
	localport[:local] = port if port
	Proc.new do |forwarder, last_host|
          forwarder.forward(last_host, hostname, localport) unless last_host.nil?
          forwarder.connect(hostname, username)
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
    end
  end
end

chain = SSHTunnel::Chain.new
chain << SSHTunnel::Chain::Host.new('ssh-stud.hpi.uni-potsdam.de', 'tim.felgentreff')
chain << SSHTunnel::Chain::Host.new('placebo', 'tim.felgentreff')
chain << SSHTunnel::Chain::Host.new('dhcpserver', 'timfel')
chain << SSHTunnel::Chain::Service.rdesktop("admin2")
#chain << SSHTunnel::Chain::Service.smb("fs2") # Needs root privileges
chain.split do |myTwig| 
  myTwig << SSHTunnel::Chain::Host.new('hadoop09ws02', 'hadoop01', 1234) 
end
chain << SSHTunnel::Chain::Host.new('172.16.23.120', 'tim')
chain << SSHTunnel::Chain::Service.vnc('localhost')
chain.execute
