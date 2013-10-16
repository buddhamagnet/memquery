#!/usr/bin/env ruby
require 'net/telnet'

class Memquery

  MEMQUERY_PORT_STANDARD = 11211
  MEMQUERY_PORT_DURABLE = 11226

  attr_accessor :cache_dump_limit, :host, :machine, :regex, :port, :slab_ids, :slabs, :op

  def self.version
    '1.1.0'
  end

  def initialize(op, bin, key = nil)
    self.op = op
    self.host = 'localhost'
    self.port = bin
    self.regex= key
    self.machine = Net::Telnet::new('Host' => 'localhost', 'Port' => port, 'Timeout' => 3)
    self.cache_dump_limit = 100
    self.slab_ids = []
    self.slabs = []
  end

  def port=(bin)
    @port = case bin
      when 'd' then MEMQUERY_PORT_DURABLE
      when 'n' then MEMQUERY_PORT_STANDARD
      else
        puts "Please specify a bin - n (normal) or d (durable)"
        exit
    end
  end

  def regex=(key)
    @regex = Regexp.new(key || '.+')
  end

  def get_items
    machine.cmd("String" => "stats items", "Match" => /^END/) do |c|
      matches = c.scan(/STAT items:(\d+):/)
      self.slab_ids = matches.flatten.uniq
    end
  end

  def get_slabs
    machine.cmd("String" => "stats slabs", "Match" => /^END/) do |c|
      matches = c.scan(/^(.+)(chunk_size)(.+)$/)
      for m in matches
        self.slabs << "#{m.join(' ')}\n"
      end
    end
  end

  def output_slabs
    puts
    puts '-'* 80
    slabs.each do |slab|
      puts slab
    end
    puts
    terminate
  end

  def output_items
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

  def command(command)
    machine.cmd("String" => command, "Match" => /^END/)
  end

  def flush_all(seconds = '')
    command("flush_all #{seconds}")
  end

  def version
    command("version")
  end

  def stats
    command("stats")
  end


  def run
    send(op)
  end

  def slabbage
    get_slabs
    output_slabs
  end

  def items
    get_items
    output_items
  end

  def terminate
    machine.close
  end
end

if ARGV.size > 0
  mem = Memquery.new(*ARGV)
  puts mem.run
end
