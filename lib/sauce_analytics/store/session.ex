defmodule SauceAnalytics.Store.Entry do
  @moduledoc """
  This struct represents an entry obtained from the Store.

  ## Fields
  * `:sid` - The id of the session.
  * `:view_sequence` - The number of times that track_visit has been called.
  * `:event_sequence` - The number of times that track_event has been called.
  * `:last_modified` - The unix timestamp of when the session was last modified.
  """
  @keys ~w(sid view_sequence event_sequence last_modified)a

  @enforce_keys @keys
  defstruct @keys

  @type t() :: %__MODULE__{
          sid: reference(),
          view_sequence: integer(),
          event_sequence: integer(),
          last_modified: integer()
        }
end
