require "./spec_helper"

private struct MockArgumentResolver
  include Athena::Routing::ArgumentResolverInterface

  def initialize(@exception : ::Exception? = nil); end

  def resolve(request : HTTP::Request, route : ART::Action) : Array
    if ex = @exception
      raise ex
    end

    [] of String
  end
end

describe Athena::Routing::RouteHandler do
  describe "#handle - request" do
    describe ART::Response do
      it "should use the returned response" do
        dispatcher = TracableEventDispatcher.new
        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new
        route = create_route(ART::Response) do
          ART::Response.new "TEST"
        end
        io = IO::Memory.new

        context = new_context request: new_request(route: route), response: new_response(io: io)

        handler.handle context

        dispatcher.emitted_events.should eq [ART::Events::Request, ART::Events::Response, ART::Events::Terminate]
        context.response.closed?.should be_true
        context.response.status.should eq HTTP::Status::OK

        io.rewind.gets_to_end.should end_with "TEST"
      end
    end

    describe "view layer" do
      it "should use the resolve the returned value into a response" do
        listener = AED.create_listener(ART::Events::View) do
          event.response = ART::Response.new event.view.data.to_json, 201, HTTP::Headers{"content-type" => "application/json"}
        end

        dispatcher = TracableEventDispatcher.new
        dispatcher.add_listener ART::Events::View, listener

        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new
        io = IO::Memory.new

        context = new_context response: new_response(io: io)

        handler.handle context

        dispatcher.emitted_events.should eq [ART::Events::Request, ART::Events::View, ART::Events::Response, ART::Events::Terminate]
        context.response.closed?.should be_true
        context.response.headers["content-type"].should eq "application/json"
        context.response.status.should eq HTTP::Status::CREATED

        io.rewind.gets_to_end.should end_with %("TEST")
      end

      it "should raise an exception if the value was not handled" do
        dispatcher = TracableEventDispatcher.new

        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new

        expect_raises Exception, "TestController#get_test must return an `ART::Response` but it returned ''." do
          handler.handle new_context
        end
      end
    end

    describe :early do
      it "should emit the proper events and set the proper response" do
        listener = AED.create_listener(ART::Events::Request) do
          event.response = ART::Response.new "", HTTP::Status::IM_A_TEAPOT, HTTP::Headers{"FOO" => "BAR"}
        end

        dispatcher = TracableEventDispatcher.new
        dispatcher.add_listener ART::Events::Request, listener

        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new
        io = IO::Memory.new

        context = new_context response: new_response(io: io)

        handler.handle context

        dispatcher.emitted_events.should eq [ART::Events::Request, ART::Events::Response, ART::Events::Terminate]
        context.response.closed?.should be_true
        context.response.headers["FOO"].should eq "BAR"
        context.response.status.should eq HTTP::Status::IM_A_TEAPOT
        io.rewind.gets_to_end.should end_with "\r\n\r\n"
      end
    end
  end

  describe "#handle - exception" do
    describe "that is handled" do
      it "should emit the proper events and set correct response" do
        listener = AED.create_listener(ART::Events::Exception) do
          event.response = ART::Response.new "HANDLED", HTTP::Status::BAD_REQUEST
        end

        dispatcher = TracableEventDispatcher.new
        dispatcher.add_listener ART::Events::Exception, listener

        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new ART::Exceptions::BadRequest.new "TEST_EX"
        io = IO::Memory.new

        context = new_context response: new_response io: io

        handler.handle context

        dispatcher.emitted_events.should eq [ART::Events::Request, ART::Events::Exception, ART::Events::Response, ART::Events::Terminate]
        context.response.closed?.should be_true
        context.response.status.should eq HTTP::Status::BAD_REQUEST

        io.rewind.gets_to_end.should end_with %(HANDLED)
      end
    end

    describe "that is not_handled" do
      it "should emit the proper events and set correct response" do
        dispatcher = TracableEventDispatcher.new

        handler = ART::RouteHandler.new dispatcher, ART::RequestStore.new, MockArgumentResolver.new ART::Exceptions::BadRequest.new "TEST_EX"
        io = IO::Memory.new

        context = new_context response: new_response io: io

        expect_raises ART::Exceptions::BadRequest, "TEST_EX" do
          handler.handle context
        end

        dispatcher.emitted_events.should eq [ART::Events::Request, ART::Events::Exception]
      end
    end
  end
end
