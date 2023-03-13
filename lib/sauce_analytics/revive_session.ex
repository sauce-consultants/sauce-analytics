defmodule SauceAnalytics.ReviveSession do
  @moduledoc """
  This struct contains the minimum amount of information that can be used to
  revive a session.

  This struct exists to handle cases where the session expires after inactivity or
  if the session in the store is lost from an event such as a server deploy/restart.

  ## Fields
  * `:sid` - The id of the session.
  * `:uid` - The id of the user. Can be nil.
  * `:user_agent` - The user agent of the client's web browser.
  * `:client_ip` - The IP address of the client.
  """
  @keys ~w(sid uid user_agent)a

  @enforce_keys @keys
  defstruct @keys ++ [:client_ip]

  @type t() :: %__MODULE__{
          sid: reference(),
          uid: String.t() | nil,
          user_agent: String.t(),
          client_ip: String.t() | nil
        }
end
