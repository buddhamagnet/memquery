#!/usr/bin/env ruby
require 'net/telnet'

class Memquery

  MEMQUERY_PORT_STANDARD = 11211
  MEMQUERY_PORT_DURABLE = 11226

  attr_reader :cache_dump_limit, :localhost
  attr_accessor :slab_ids, :port, :regex, :host

  def self.version 
    '1.0.0'
  end

  def initialize
    select_bin
    set_host
    set_pattern
    @cache_dump_limit = 100
    set_localhost
    @slab_ids = []
  end

  def select_bin
    self.port = case ARGV[0]
      when 'd' then MEMQUERY_PORT_DURABLE
      when 'n' then MEMQUERY_PORT_STANDARD
      else
        puts "Please specify a bin - n (normal) or d (durable)"
        exit
    end
  end

  def set_host
    self.host = case ARGV[1]
      when 'l' then 'localhost'
      else ARGV[1]
    end
  end

  def set_pattern
    pattern = ARGV[2] || '.+'
    self.regex = Regexp.new(pattern)
  end

  def set_localhost
    self.localhost = Net::Telnet::new('Host' => host, 'Port' => port, 'Timeout' => 3)
  end

  def get_slabs
    localhost.cmd("String" => "stats items", "Match" => /^END/) do |c|
      matches = c.scan(/STAT items:(\d+):/)
      self.slab_ids = matches.flatten.uniq
    end
  end

  def output_slabs
    puts
    puts "Expires At\t\t\t\tCache Key"
    puts '-'* 80 
    slab_ids.each do |slab_id|
      localhost.cmd("String" => "stats cachedump #{slab_id} #{cache_dump_limit}", "Match" => /^END/) do |c|
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
    localhost.close  
  end
end

if ARGV.size > 0
  puts Memquery.new.run
end