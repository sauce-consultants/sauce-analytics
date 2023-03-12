defmodule SauceAnalytics.Store.Session do
  @moduledoc """
  This struct represents a session obtained from the Store.

  ## Fields
  * `:sid` - The id of the session.
  * `:uid` - The id of the user. Can be nil.
  * `:user_agent` - The user agent of the client's web browser.
  * `:view_sequence` - The number of times that track_visit has been called.
  * `:event_sequence` - The number of times that track_event has been called.
  * `:last_modified` - The unix timestamp of when the session was last modified.
  """
  @keys ~w(sid uid user_agent view_sequence event_sequence last_modified)a

  @enforce_keys @keys
  defstruct @keys

  @type t() :: %__MODULE__{
          sid: String.t(),
          uid: String.t(),
          user_agent: String.t(),
          view_sequence: integer(),
          event_sequence: integer(),
          last_modified: integer()
        }
end
