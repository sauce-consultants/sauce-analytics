defmodule SauceAnalytics.AppInfo do
  @moduledoc """
  Information which identifies your app on the Sauce Analytics API.

  ## Fields
  * `:name` - A unique string which represents the name of the app.
  * `:uid` - A unique string which represents the user.
  * `:user_agent` - The user agent of the client's web browser.
  * `:environment` - A string which represents the application's environment.
  """
  @keys ~w(name version hash environment)a
  @enforce_keys @keys
  defstruct @keys

  @type t() :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          hash: String.t(),
          environment: String.t()
        }
end
