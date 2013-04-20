#!/usr/bin/env ruby
require 'net/telnet'

class Memquery

  MEMQUERY_PORT_STANDARD = 11211
  MEMQUERY_PORT_DURABLE = 11226

  attr_accessor :cache_dump_limit, :host, :machine, :port, :regex, :slab_ids

  def self.version 
    '1.0.0'
  end

  def initialize(bin, hostname, key = nil)
    set_port(bin)
    set_host(hostname)
    set_pattern(key)
    set_machine
    @cache_dump_limit = 100
    @slab_ids = []
  end

  def set_port(bin)
    self.port = case bin
      when 'd' then MEMQUERY_PORT_DURABLE
      when 'n' then MEMQUERY_PORT_STANDARD
      else
        puts "Please specify a bin - n (normal) or d (durable)"
        exit
    end
  end

  def set_host(hostname)
    self.host = case hostname
      when 'l' then 'localhost'
      else hostname
    end
  end

  def set_pattern(key)
    pattern = key || '.+'
    self.regex = Regexp.new(pattern)
  end

  def set_machine
    self.machine = Net::Telnet::new('Host' => host, 'Port' => port, 'Timeout' => 3)
  end

  def get_slabs
    machine.cmd("String" => "stats items", "Match" => /^END/) do |c|
      matches = c.scan(/STAT items:(\d+):/)
      self.slab_ids = matches.flatten.uniq
    end
  end

  def output_slabs
    puts
    puts "Expires At\t\t\t\tCache Key"
    puts '-'* 80 
    slab_ids.each do |slab_id|
      machine.cmd("String" => "stats cachedump #{slab_id} #{cache_dump_limit}", "Match" => /^END/) do |c|
        matches = c.scan(/^ITEM (.+?) \[(\d+) b; (\d+) s\]$/).each do |key_data|
          (cache_key, bytes, expires_time) = key_data
          if (cache_key =~ regex)
            humanized_expires_time = Time.at(expires_time.to_i).to_s     
            puts "[#{humanized_expires_time}]\t#{cache_key}"
          end
        end
      end
    end
    puts
    terminate
  end

  def run
    get_slabs
    output_slabs
  end

  def terminate
    machine.close  
  end
end

if ARGV.size > 0
  puts Memquery.new(*ARGV).run
end