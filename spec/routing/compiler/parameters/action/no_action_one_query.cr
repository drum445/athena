require "../../../routing_spec_helper"

class CompileController < Athena::Routing::Controller
  @[Athena::Routing::Get(path: "int8/", query: {"bar" => /bar/})]
  def no_action_one_query : Int32
    123
  end
end

Athena::Routing.run