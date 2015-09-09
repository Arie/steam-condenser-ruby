# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2011-2012, Sebastian Staudt

require 'helper'

class TestMasterServer < Test::Unit::TestCase

  context 'The user' do

    should 'be able to set the number of retries' do
      Servers::MasterServer.retries = 5

      assert_equal 5, Servers::MasterServer.send(:class_variable_get, :@@retries)
    end

  end

  context 'A master server' do

    setup do
      Socket.stubs(:getaddrinfo).
        with('master', 27015, Socket::AF_INET, Socket::SOCK_DGRAM).
        returns [[nil, nil, 'master', '127.0.0.1']]

      @server = Servers::MasterServer.new 'master', 27015
    end

    should 'create a client socket upon initialization' do
      socket = mock
      Servers::Sockets::MasterServerSocket.expects(:new).with('127.0.0.1', 27015).returns socket

      @server.init_socket

      assert_same socket, @server.instance_variable_get(:@socket)
    end

    should 'be able to get a list of servers' do
      reply1 = mock servers: %w{127.0.0.1:27015 127.0.0.2:27015 127.0.0.3:27015}
      reply2 = mock servers: %w{127.0.0.4:27015 0.0.0.0:0}

      socket = @server.instance_variable_get :@socket
      socket.expects(:send_packet).with do |packet|
        packet.is_a?(Servers::Packets::A2M_GET_SERVERS_BATCH2_Packet) &&
        packet.instance_variable_get(:@filter) == 'filter' &&
        packet.instance_variable_get(:@region_code) == Servers::MasterServer::REGION_EUROPE &&
        packet.instance_variable_get(:@start_ip) == '0.0.0.0:0'
      end
      socket.expects(:send_packet).with do |packet|
        packet.is_a?(Servers::Packets::A2M_GET_SERVERS_BATCH2_Packet) &&
        packet.instance_variable_get(:@filter) == 'filter' &&
        packet.instance_variable_get(:@region_code) == Servers::MasterServer::REGION_EUROPE &&
        packet.instance_variable_get(:@start_ip) == '127.0.0.3:27015'
      end
      socket.expects(:reply).times(2).returns(reply1).returns reply2

      servers = [['127.0.0.1', '27015'], ['127.0.0.2', '27015'], ['127.0.0.3', '27015'], ['127.0.0.4', '27015']]
      assert_equal servers, @server.servers(Servers::MasterServer::REGION_EUROPE, 'filter')
    end

    should 'not timeout if returning servers is forced' do
      Servers::MasterServer.retries = 1

      reply = mock servers: %w{127.0.0.1:27015 127.0.0.2:27015 127.0.0.3:27015}

      socket = @server.instance_variable_get :@socket
      socket.expects(:send_packet).with do |packet|
        packet.is_a?(Servers::Packets::A2M_GET_SERVERS_BATCH2_Packet) &&
        packet.instance_variable_get(:@filter) == 'filter' &&
        packet.instance_variable_get(:@region_code) == Servers::MasterServer::REGION_EUROPE &&
        packet.instance_variable_get(:@start_ip) == '0.0.0.0:0'
      end
      socket.expects(:send_packet).with do |packet|
        packet.is_a?(Servers::Packets::A2M_GET_SERVERS_BATCH2_Packet) &&
        packet.instance_variable_get(:@filter) == 'filter' &&
        packet.instance_variable_get(:@region_code) == Servers::MasterServer::REGION_EUROPE &&
        packet.instance_variable_get(:@start_ip) == '127.0.0.3:27015'
      end
      socket.expects(:reply).times(2).returns(reply).then.
        raises(Error::Timeout)

      servers = [['127.0.0.1', '27015'], ['127.0.0.2', '27015'], ['127.0.0.3', '27015']]
      assert_equal servers, @server.servers(Servers::MasterServer::REGION_EUROPE, 'filter', true)
    end

    should 'timeout after a predefined number of retries' do
      retries = rand(4) + 1
      Servers::MasterServer.retries = retries

      socket = @server.instance_variable_get :@socket
      socket.expects(:send_packet).times(retries).with do |packet|
        packet.is_a?(Servers::Packets::A2M_GET_SERVERS_BATCH2_Packet) &&
        packet.instance_variable_get(:@filter) == '' &&
        packet.instance_variable_get(:@region_code) == Servers::MasterServer::REGION_ALL &&
        packet.instance_variable_get(:@start_ip) == '0.0.0.0:0'
      end
      socket.expects(:reply).times(retries).raises Error::Timeout

      assert_raises Error::Timeout do
        @server.servers
      end
    end

  end

end
