#!/usr/bin/env ruby

# simple-daemon acts_as_s3_image daemon
# check http://simple-daemon.rubyforge.org/

RAILS_ENV = ARGV[1] || "development"

require File.dirname(__FILE__) + "/../../config/environment.rb"

class S3ImageDeamon < SimpleDaemon::Base
  
  SimpleDaemon::WORKING_DIRECTORY = "#{RAILS_ROOT}/log"
  
  def self.start
    ActiveRecord::Base.allow_concurrency = true
    loop do
      ImageVersion.find(:all, 
        :conditions=>['state = ? and label is null', 'unprocessed'], 
        :order=>'priority desc',
        :limit=>5, :lock=>true).each do |version|
          version.process_versions
          version.state = 'processed'
          version.save!
      end
      sleep 40
    end
  end
  
  def self.stop
    puts "Stopping S3ImageDeamon..."
  end
  
  S3ImageDeamon.daemonize
  
end

