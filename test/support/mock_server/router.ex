defmodule MockServer.Router do
  use Plug.Router

  plug Plug.Parsers, parsers: [:json],
                     pass: ["text/*"],
                     json_decoder: Jason
  plug :match
  plug :dispatch

  post "/visits" do
    what(conn, conn.body_params)
  end

  defp what(conn, body) do
    IO.inspect(body, label: "what")
    conn
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
