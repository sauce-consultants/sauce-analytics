defmodule SauceAnalytics.HTTP do
  @moduledoc """
  Responsible for parsing any `SauceAnalytics.HTTP.Request` and sending POST requests
  to the Sauce Analytics API.

  Uses `HTTPoison` as a backend for sending requests.
  """
  use Retry
  import Stream

  @doc """
  Given the `app_info`, `api_uri`, and `request`. This sends a POST request
  to the appropriate endpoint based on the `:type` field in `request`.

  Returns `{status, HTTPoison.Response{}}` depending on the status of the response.
  """
  @spec post(
          app_info :: SauceAnalytics.AppInfo.t(),
          api_url :: String.t(),
          request :: SauceAnalytics.HTTP.Request.t()
        ) ::
          {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Response.t()}
  def post(
        %SauceAnalytics.AppInfo{} = app_info,
        api_url,
        %SauceAnalytics.HTTP.Request{} = request
      ) do
    {:ok, body} = encode_request(app_info, request)

    endpoint =
      case request.type do
        :visit -> "/visits"
        :event -> "/events"
      end

    request = %HTTPoison.Request{
      method: :post,
      url: api_url <> endpoint,
      headers: %{
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Forwarded-For": request.client_ip
      },
      body: body
    }

    retry with: constant_backoff(1000) |> take(5) do
      request = HTTPoison.request(request)

      with {:ok, response} <- request,
           200 <- response.status_code do
        {:ok, response}
      else
        _ -> {:error, request}
      end
    after
      result -> result
    else
      error -> error
    end
  end

  defp encode_request(
         %SauceAnalytics.AppInfo{} = app_info,
         %SauceAnalytics.HTTP.Request{} = request
       ) do

    sid_serialized =
      request.session_id
      |> :erlang.ref_to_list()
      |> List.to_string()

    body = %{
      "environment" => app_info.environment,
      "appName" => app_info.name,
      "appVersion" => app_info.version,
      "appHash" => app_info.hash,
      "userAgent" => request.user_agent,
      "sessionId" => sid_serialized,
      "viewSequence" => request.view_sequence,
      "eventSequence" => request.event_sequence,
      "globalSequence" => request.view_sequence + request.event_sequence,
      "name" => request.name,
      "title" => request.title,
      "userId" => request.user_id
    }

    case request.type do
      :visit ->
        body
        |> Map.delete("eventSequence")
      :event ->
        body
        |> Map.put("data", request.data)
        |> Map.delete("viewSequence")
    end
    |> Jason.encode()
  end
end
