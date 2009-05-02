require 'rubygems'
require 'net/ssh'

module SSHTunnel
  class Connector
    attr_reader :jobs, :local_ports

    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG 
    def initialize
      @jobs = {}
      @local_ports = []
    end

    def get_password host,username
      print "Password for "+username+"@"+host+": "
      system "stty -echo"
      pw = gets.delete("\n")
      system "stty echo"
      puts
      pw
    end

    def add_job (host, username)
      pw = get_password(host, username)

      if @jobs.key?(host.to_sym)
        port = @jobs[host.to_sym]
        @@log.debug("Found local-port forward on port "+port.to_s) 
        @jobs[host.to_sym] = Net::SSH.start('localhost', 
        username, :password=> pw, :port => port)
      else
        @jobs[host.to_sym] = Net::SSH.start(host, username, :password=>pw)
      end
    end

    def activate_ssh_loop symbol,port
      @jobs[symbol][:thread] = Thread.new(@jobs[symbol]) {|c| c.loop {true}}
    end

    def register_ssh_forward from,to,localport,toport
      @jobs[to] ||= localport
      @jobs[from][:thread].exit! unless @jobs[from][:thread].nil?
      @jobs[from].forward.local(localport, to, toport)
    end

    def add_forward (from, to, port_options = {})
      remoteport = port_options[:remote] || 22
      begin
        localport = port_options[:local] || ((rand + 1) * 2222).round
      end while @local_ports.include?(localport)
      @@log.debug("Adding forwarding to "+to+":"+remoteport.to_s+" on local port "+localport.to_s)

      register_ssh_forward(from.to_sym, to.to_sym, localport, remoteport)
      activate_ssh_loop(from.to_sym, localport)
    end

    def killall
      @jobs.each do |k,v| 
        v[:thread].exit! unless v[:thread].nil?
        v.shutdown!
      end
      initialize
    end
  end

  class Chain
    class Service
      attr_reader :local, :host, :remote
      def initialize (local, host, remote)
        @local = local
        @host = host
        @remote = remote
      end

      def is_a? service
        service == :Service
      end

      def self.vnc hostname
        self.new(5900,hostname,5900)
      end

      def self.smb hostname
        self.new(139,hostname,139)
      end

      def self.rdesktop hostname
        self.new(3389,hostname,3389)
      end
    end

    class Host
      attr_reader :name, :user
      def initialize(hostname, username)
        @name = hostname
        @user = username
      end

      def is_a? host
        host == :Host
      end
    end

    def initialize hostname, username
      @forwarder = Connector.new
      @chain = [Host.new(hostname,username)]
    end

    def << host_or_service
      push(host_or_service)
    end

    def push(host_or_service)
      @chain << host_or_service
    end

    def pop
      @chain.pop
    end

    def split &block
      # The plan: Save the block + current scope.
      # On execution, run the block at the 
      # appropriate position, rewind the stack
      # and continue.
      @chain << block
    end

    def execute
      last_host = nil
      @chain.each do |item|
        if item.respond_to? 'call'
          item.call(@chain.clone)
        elsif item.is_a? :Service
          @forwarder.add_forward(last_host, item.host, 
          {:local => item.local, :remote => item.remote})
        elsif item.is_a? :Host
          @forwarder.add_forward(last_host, item.name) unless last_host.nil?
          @forwarder.add_job(item.name, item.user)
          last_host = item.name
        end
      end
    end
  end
end

chain = SSHForwarder::Chain.new('ssh-stud.hpi.uni-potsdam.de', 'tim.felgentreff')
chain << SSHForwarder::Chain::Host.new('placebo', 'tim.felgentreff')
chain.push SSHForwarder::Chain::Host.new('dhcpserver', 'timfel')
chain.push SSHForwarder::Chain::Service.rdesktop("admin2")
#chain.push SSHForwarder::Chain::Service.smb("fs2") # Needs root privileges
chain.split do |myTwig| 
  myTwig.push SSHForwarder::Chain::Host.new('hadoop09ws02', 'hadoop01') 
end
chain.push SSHForwarder::Chain::Host.new('172.16.23.120', 'tim')
chain.push SSHForwarder::Chain::Service.vnc('localhost')
chain.execute
