# $Id$
#
# Author:: Francis Cianfrocca (gmail: blackhedd)
# Homepage::  http://rubyeventmachine.com
# Date:: 8 April 2006
#
# See EventMachine and EventMachine::Connection for documentation and
# usage examples.
#
#----------------------------------------------------------------------------
#
# Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
# Gmail: blackhedd
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either: 1) the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version; or 2) Ruby's License.
#
# See the file COPYING for complete licensing information.
#
#---------------------------------------------------------------------------
#
#
#
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'eventmachine'
require 'socket'
require 'test/unit'

class Receiver < EM::Connection

  @@number_of_receipts = 0

  def post_init
    @sent = rand(100000).to_s
    EM::Timer.new(0.5) { send_data @sent }
  end

  def self.get_count
    @@number_of_receipts
  end

  def receive_data data
    if data != @sent
      raise 'got back poor data' # this would also be an error
    else
      @@number_of_receipts += 1
    end
  end

end

class EchoServer < EM::Connection

  @@count = 0
  def post_init
    # new connection
    @@count += 1
    begin
      $conns << EventMachine::connect( '127.0.0.1', 8081, Receiver)
    rescue RuntimeError # no connection
      # ok -- ran out of fd's
    end
  end

  @@close_afterward = true
  def receive_data data
    send_data data # echo it back
    close_connection_after_writing if @@close_afterward
  end

  def self.get_count
    @@count
  end

end

class TestBasic < Test::Unit::TestCase

  def setup
    assert(!EM.reactor_running?)
  end

  def teardown
    assert(!EM.reactor_running?)
  end

  #-------------------------------------

  # this test is
  # connect as many as you can
  # and then send on all connections back to them all
  # and they should all get it back

  def test_use_all_descriptors_with_churn
    use_all_descriptors_available true
  end

  def test_use_all_descriptors_without_churn
    use_all_descriptors_available false
  end

  def use_all_descriptors_available close_after
    EchoServer.class_eval { @@close_afterward = close_after }

    EM.run {
      EventMachine::start_server "127.0.0.1", 8081, EchoServer
      $conns = []
      $conns << EventMachine::connect( '127.0.0.1', 8081, Receiver) # start ball rolling
      old_score = 1

      EM::PeriodicTimer.new(1.5) {
        if old_score == $conns.length
          # things appeared to have stabilized, so end loop
          # to we can analyze the connection count
          EM.stop
        else
          old_score = $conns.length
        end
      }
    }

    difference = $conns.length - Receiver.get_count
      puts $conns.length, Receiver.get_count
    unless difference <= 1
      puts $conns.length, Receiver.get_count
      raise 'didnt get enough receipts' unless difference <= 1
    end

  end

end

