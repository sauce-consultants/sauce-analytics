defmodule SauceAnalytics.HTTP.Request do
  @keys ~w(
    type
    view_sequence
    event_sequence
    name
    title
    user_agent
    session_id
    client_ip
    user_id
    data
  )a

  @enforce_keys @keys
  defstruct @keys

  @type request_types() :: :visit | :event
  @type t() :: %__MODULE__{
          type: request_types(),
          view_sequence: integer(),
          event_sequence: integer(),
          name: String.t(),
          title: String.t(),
          user_agent: String.t(),
          session_id: reference(),
          client_ip: String.t(),
          user_id: String.t(),
          data: map() | nil
        }
end
