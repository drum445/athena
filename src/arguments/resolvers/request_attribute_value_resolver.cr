@[ADI::Register(tags: ["athena.argument_value_resolver"])]
# Handles resolving a value that is stored in the request's `ART::ParameterBag`.
# This includes any path/query parameters, or custom types values stored via an `AED::EventListenerInterface`.
#
# ```
# @[ART::Get("/:id")]
# def get_id(id : Int32) : Int32
#   id
# end
# ```
struct Athena::Routing::Arguments::Resolvers::RequestAttribute
  include Athena::Routing::Arguments::Resolvers::ArgumentValueResolverInterface
  include ADI::Service

  # :inherit:
  def self.priority : Int32
    100
  end

  # :inherit:
  def supports?(request : HTTP::Request, argument : ART::Arguments::ArgumentMetadataBase) : Bool
    request.attributes.has? argument.name
  end

  # :inherit:
  def resolve(request : HTTP::Request, argument : ART::Arguments::ArgumentMetadataBase)
    value = request.attributes.get argument.name

    argument.type.from_parameter value
  rescue ex : ArgumentError
    # Catch type cast errors and bubble it up as an UnprocessableEntity
    raise ART::Exceptions::UnprocessableEntity.new "Required parameter '#{argument.name}' with value '#{value}' could not be converted into a valid '#{argument.type}'", cause: ex
  end
end